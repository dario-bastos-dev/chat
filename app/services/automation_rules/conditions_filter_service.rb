require 'json'

class AutomationRules::ConditionsFilterService < FilterService
  ATTRIBUTE_MODEL = 'contact_attribute'.freeze

  def initialize(rule, conversation = nil, options = {})
    super([], nil)
    # assign rule, conversation and account to instance variables
    @rule = rule
    @conversation = conversation
    @account = conversation.account

    # setup filters from json file
    file = File.read('./lib/filters/filter_keys.yml')
    @filters = YAML.safe_load(file)

    @conversation_filters = @filters['conversations']
    @contact_filters = @filters['contacts']
    @message_filters = @filters['messages']

    @options = options
    @changed_attributes = options[:changed_attributes]
  end

  def perform
    return false unless rule_valid?

    @attribute_changed_query_filter = []

    @rule.conditions.each_with_index do |query_hash, current_index|
      @attribute_changed_query_filter << query_hash and next if query_hash['filter_operator'] == 'attribute_changed'

      apply_filter(query_hash, current_index)
    end

    records = base_relation.where(@query_string, @filter_values.with_indifferent_access)
    records = perform_attribute_changed_filter(records) if @attribute_changed_query_filter.any?

    records.any?
  rescue StandardError => e
    Rails.logger.error "Error in AutomationRules::ConditionsFilterService: #{e.message}"
    Rails.logger.info "AutomationRules::ConditionsFilterService failed while processing rule #{@rule.id} for conversation #{@conversation.id}"
    false
  end

  def rule_valid?
    is_valid = AutomationRules::ConditionValidationService.new(@rule).perform
    Rails.logger.info "Automation rule condition validation failed for rule id: #{@rule.id}" unless is_valid
    @rule.authorization_error! unless is_valid

    is_valid
  end

  def filter_operation(query_hash, current_index)
    if query_hash[:filter_operator] == 'starts_with'
      @filter_values["value_#{current_index}"] = "#{string_filter_values(query_hash)}%"
      like_filter_string(query_hash[:filter_operator], current_index)
    else
      super
    end
  end

  def apply_filter(query_hash, current_index)
    conversation_filter = @conversation_filters[query_hash['attribute_key']]
    contact_filter = @contact_filters[query_hash['attribute_key']]
    message_filter = @message_filters[query_hash['attribute_key']]
    definition = custom_attr_definition(query_hash['attribute_key'])

    if %w[has_active_deal deal_stage_id deal_labels].include?(query_hash['attribute_key'])
      result = evaluate_crm_condition(query_hash)
      query_operator = query_hash['query_operator'] || 'AND'
      @query_string += " #{result ? '1=1' : '1=0'} #{query_operator} "
    elsif definition&.attribute_model == 'deal_attribute'
      result = evaluate_deal_custom_attribute(query_hash, definition)
      query_operator = query_hash['query_operator'] || 'AND'
      @query_string += " #{result ? '1=1' : '1=0'} #{query_operator} "
    elsif conversation_filter
      @query_string += conversation_query_string('conversations', conversation_filter, query_hash.with_indifferent_access, current_index)
    elsif contact_filter
      @query_string += contact_query_string(contact_filter, query_hash.with_indifferent_access, current_index)
    elsif message_filter
      @query_string += message_query_string(message_filter, query_hash.with_indifferent_access, current_index)
    elsif custom_attribute(query_hash['attribute_key'], @account, query_hash['custom_attribute_type'])
      # send table name according to attribute key right now we are supporting contact based custom attribute filter
      @query_string += custom_attribute_query(query_hash.with_indifferent_access, query_hash['custom_attribute_type'], current_index)
    end
  end

  # If attribute_changed type filter is present perform this against array
  def perform_attribute_changed_filter(records)
    @attribute_changed_records = []
    current_attribute_changed_record = base_relation
    filter_based_on_attribute_change(records, current_attribute_changed_record)

    @attribute_changed_records.uniq
  end

  # Loop through attribute_changed_query_filter
  def filter_based_on_attribute_change(records, current_attribute_changed_record)
    @attribute_changed_query_filter.each do |filter|
      @changed_attributes = @changed_attributes.with_indifferent_access
      changed_attribute = @changed_attributes[filter['attribute_key']].presence

      if changed_attribute[0].in?(filter['values']['from']) && changed_attribute[1].in?(filter['values']['to'])
        @attribute_changed_records = attribute_changed_filter_query(filter, records, current_attribute_changed_record)
      end
      current_attribute_changed_record = @attribute_changed_records
    end
  end

  # We intersect with the record if query_operator-AND is present and union if query_operator-OR is present
  def attribute_changed_filter_query(filter, records, current_attribute_changed_record)
    if filter['query_operator'] == 'AND'
      @attribute_changed_records + (current_attribute_changed_record & records)
    else
      @attribute_changed_records + (current_attribute_changed_record | records)
    end
  end

  def message_query_string(current_filter, query_hash, current_index)
    attribute_key = query_hash['attribute_key']
    query_operator = query_hash['query_operator']

    attribute_key = 'processed_message_content' if attribute_key == 'content'
    attribute_key = 'private' if attribute_key == 'private_note'

    filter_operator_value = filter_operation(query_hash, current_index)

    case current_filter['attribute_type']
    when 'standard'
      if current_filter['data_type'] == 'text'
        " LOWER(messages.#{attribute_key}) #{filter_operator_value} #{query_operator} "
      else
        " messages.#{attribute_key} #{filter_operator_value} #{query_operator} "
      end
    end
  end

  # This will be used in future for contact automation rule
  def contact_query_string(current_filter, query_hash, current_index)
    attribute_key = query_hash['attribute_key']
    query_operator = query_hash['query_operator']

    filter_operator_value = filter_operation(query_hash, current_index)

    case current_filter['attribute_type']
    when 'additional_attributes'
      " contacts.additional_attributes ->> '#{attribute_key}' #{filter_operator_value} #{query_operator} "
    when 'standard'
      " contacts.#{attribute_key} #{filter_operator_value} #{query_operator} "
    end
  end

  def conversation_query_string(table_name, current_filter, query_hash, current_index)
    attribute_key = query_hash['attribute_key']
    query_operator = query_hash['query_operator']
    filter_operator_value = filter_operation(query_hash, current_index)

    case current_filter['attribute_type']
    when 'additional_attributes'
      " #{table_name}.additional_attributes ->> '#{attribute_key}' #{filter_operator_value} #{query_operator} "
    when 'standard'
      if attribute_key == 'labels'
        build_label_query_string(query_hash, current_index, query_operator)
      else
        " #{table_name}.#{attribute_key} #{filter_operator_value} #{query_operator} "
      end
    end
  end

  def build_label_query_string(query_hash, current_index, query_operator)
    case query_hash['filter_operator']
    when 'equal_to'
      return " 1=0 #{query_operator} " if query_hash['values'].blank?

      value_placeholder = "value_#{current_index}"
      @filter_values[value_placeholder] = query_hash['values'].first
      " tags.name = :#{value_placeholder} #{query_operator} "
    when 'not_equal_to'
      return " 1=0 #{query_operator} " if query_hash['values'].blank?

      value_placeholder = "value_#{current_index}"
      @filter_values[value_placeholder] = query_hash['values'].first
      " tags.name != :#{value_placeholder} #{query_operator} "
    when 'is_present'
      " tags.id IS NOT NULL #{query_operator} "
    when 'is_not_present'
      " tags.id IS NULL #{query_operator} "
    else
      " tags.id #{filter_operation(query_hash, current_index)} #{query_operator} "
    end
  end

  private

  def base_relation
    records = Conversation.where(id: @conversation.id).joins(
      'LEFT OUTER JOIN contacts on conversations.contact_id = contacts.id'
    ).joins(
      'LEFT OUTER JOIN messages on messages.conversation_id = conversations.id'
    )

    # Only add label joins when label conditions exist
    if label_conditions?
      records = records.joins(
        'LEFT OUTER JOIN taggings ON taggings.taggable_id = conversations.id AND taggings.taggable_type = \'Conversation\''
      ).joins(
        'LEFT OUTER JOIN tags ON taggings.tag_id = tags.id'
      )
    end

    records = records.where(messages: { id: @options[:message].id }) if @options[:message].present?
    records
  end

  def label_conditions?
    @rule.conditions.any? { |condition| condition['attribute_key'] == 'labels' }
  end

  def custom_attr_definition(key)
    @account.custom_attribute_definitions.find_by(attribute_key: key)
  end

  def active_deal
    @active_deal ||= @options[:deal] || @conversation.deals.where(status: 'open').first
    @active_deal ||= @account.deals.where(contact_id: @conversation.contact_id, status: 'open').first
    @active_deal
  end

  def evaluate_crm_condition(query_hash)
    attr_key = query_hash['attribute_key']
    filter_operator = query_hash['filter_operator']
    values = query_hash['values'] || []

    case attr_key
    when 'has_active_deal'
      has_deal = active_deal.present?
      val = values.first.to_s
      if filter_operator == 'equal_to'
        val == 'true' ? has_deal : !has_deal
      elsif filter_operator == 'is_present'
        has_deal
      elsif filter_operator == 'is_not_present'
        !has_deal
      else
        has_deal
      end
    when 'deal_stage_id'
      return false if active_deal.blank?
      stage_id = active_deal.stage_id.to_s
      case filter_operator
      when 'equal_to'
        values.map(&:to_s).include?(stage_id)
      when 'not_equal_to'
        !values.map(&:to_s).include?(stage_id)
      when 'is_present'
        active_deal.stage_id.present?
      when 'is_not_present'
        active_deal.stage_id.blank?
      else
        false
      end
    when 'deal_labels'
      return false if active_deal.blank?
      deal_tags = active_deal.label_list || []
      case filter_operator
      when 'equal_to'
        (deal_tags & values).any?
      when 'not_equal_to'
        (deal_tags & values).empty?
      when 'is_present'
        deal_tags.any?
      when 'is_not_present'
        deal_tags.empty?
      else
        false
      end
    else
      false
    end
  end

  def evaluate_deal_custom_attribute(query_hash, definition)
    return false if active_deal.blank?

    attr_key = query_hash['attribute_key']
    val = active_deal.custom_attributes[attr_key]
    filter_operator = query_hash['filter_operator']
    values = query_hash['values'] || []

    case filter_operator
    when 'equal_to'
      values.map(&:to_s).include?(val.to_s)
    when 'not_equal_to'
      !values.map(&:to_s).include?(val.to_s)
    when 'is_present'
      val.present?
    when 'is_not_present'
      val.blank?
    when 'starts_with'
      val.to_s.downcase.start_with?(values.first.to_s.downcase)
    when 'contains'
      val.to_s.downcase.include?(values.first.to_s.downcase)
    when 'does_not_contain'
      !val.to_s.downcase.include?(values.first.to_s.downcase)
    else
      false
    end
  end
end
