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

  # Captain is asked only when its answer can change the outcome. AND and OR never negate a condition,
  # so a rule that gives the same result with every Captain condition unmet and met gives that result
  # whatever Captain would answer.
  def perform
    return false unless rule_valid?
    return matches?({}) if captain_indexes.empty?

    unmet_result = matches?(captain_indexes.index_with(false))
    return unmet_result if unmet_result == matches?(captain_indexes.index_with(true))

    matches?(Captain::AutomationConditionService.new(
      conditions: @rule.conditions, conversation: @conversation, message: @options[:message]
    ).perform)
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

    if query_hash['attribute_key'] == Captain::AutomationConditionService::ATTRIBUTE_KEY
      @query_string += captain_query_string(query_hash, current_index)
    elsif AutomationRule::DEAL_CONDITION_ATTRIBUTES.include?(query_hash['attribute_key'])
      @query_string += boolean_query_string(evaluate_crm_condition(query_hash), query_hash)
    elsif query_hash['attribute_key'] == 'is_first_message'
      @query_string += boolean_query_string(evaluate_is_first_message_condition(query_hash), query_hash)
    elsif definition&.attribute_model == 'deal_attribute'
      @query_string += boolean_query_string(evaluate_deal_custom_attribute(query_hash, definition), query_hash)
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

  # Conditions evaluated in Ruby (CRM, first message) take part in the AND/OR chain as a constant.
  def boolean_query_string(result, query_hash)
    " #{result ? '1=1' : '1=0'} #{query_hash['query_operator']} "
  end

  # Captain's answer is bound as a boolean so it takes part in the AND/OR chain like any SQL condition.
  def captain_query_string(query_hash, current_index)
    @filter_values["value_#{current_index}"] = @captain_answers[current_index]
    " :value_#{current_index} #{query_hash['query_operator']} "
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

    if attribute_key == 'assignee_id' && query_hash['filter_operator'].in?(%w[is_present is_not_present])
      return assignee_presence_filter(table_name, query_hash)
    end

    return " #{tag_filter_query(query_hash, current_index)} " if attribute_key == 'labels'

    filter_operator_value = filter_operation(query_hash, current_index)

    case current_filter['attribute_type']
    when 'additional_attributes'
      " #{table_name}.additional_attributes ->> '#{attribute_key}' #{filter_operator_value} #{query_operator} "
    when 'standard'
      " #{table_name}.#{attribute_key} #{filter_operator_value} #{query_operator} "
    end
  end

  private

  def captain_indexes
    @captain_indexes ||= @rule.conditions.each_index.select do |index|
      @rule.conditions[index]['attribute_key'] == Captain::AutomationConditionService::ATTRIBUTE_KEY
    end
  end

  def matches?(captain_answers)
    @captain_answers = captain_answers
    @query_string = ''
    @filter_values = {}
    @attribute_changed_query_filter = []

    @rule.conditions.each_with_index do |query_hash, current_index|
      @attribute_changed_query_filter << query_hash and next if query_hash['filter_operator'] == 'attribute_changed'

      apply_filter(query_hash, current_index)
    end

    records = base_relation.where(@query_string, @filter_values.with_indifferent_access)
    records = perform_attribute_changed_filter(records) if @attribute_changed_query_filter.any?

    records.any?
  end

  def filter_config
    {
      entity: 'Conversation',
      table_name: 'conversations'
    }
  end

  def base_relation
    records = Conversation.where(id: @conversation.id).joins(
      'LEFT OUTER JOIN contacts on conversations.contact_id = contacts.id'
    ).joins(
      'LEFT OUTER JOIN messages on messages.conversation_id = conversations.id'
    )

    records = records.where(messages: { id: @options[:message].id }) if @options[:message].present?
    records
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
      expected = values.first.to_s == 'true'
      case filter_operator
      when 'equal_to'
        has_deal == expected
      when 'not_equal_to'
        has_deal != expected
      when 'is_present'
        has_deal
      when 'is_not_present'
        !has_deal
      else
        false
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

  # The message that creates a conversation is an ordinary incoming message like any reply,
  # so content-based rules can't tell it apart from a real reply to a greeting/menu sent right
  # after. This checks the DB directly (lowest message id in the conversation) instead of a
  # marker set by another rule, so it isn't sensitive to which async job runs first.
  def evaluate_is_first_message_condition(query_hash)
    message = @options[:message]
    return false if message.blank?

    is_first_message = message.id == message.conversation.messages.minimum(:id)
    expected = (query_hash['values'] || []).first.to_s == 'true'

    query_hash['filter_operator'] == 'not_equal_to' ? is_first_message != expected : is_first_message == expected
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
