module Filters::DateFilterHelper
  TIMESTAMP_ATTRIBUTES = %w[created_at last_activity_at].freeze

  def self.timezone(identifier)
    raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: 'timezone') unless identifier.is_a?(String)

    ActiveSupport::TimeZone[TZInfo::Timezone.get(identifier)]
  rescue TZInfo::InvalidTimezoneIdentifier
    raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: 'timezone')
  end

  def date_filter(current_filter, query_hash, filter_operator_value)
    column = "#{filter_config[:table_name]}.#{query_hash[:attribute_key]}"
    return "#{column} #{filter_operator_value} #{query_hash[:query_operator]}" if timestamp_attribute?(query_hash)

    "(#{column})::#{current_filter['data_type']} #{filter_operator_value} #{query_hash[:query_operator]}"
  end

  # Timestamp attributes hold a moment, so "equal to" matches the whole day in the filter timezone
  # instead of comparing against midnight.
  def equality_filter_query(query_hash, current_index)
    return same_day_filter_query(query_hash, current_index) if query_hash[:filter_operator] == 'equal_to' && timestamp_attribute?(query_hash)

    @filter_values["value_#{current_index}"] = filter_values(query_hash)
    equals_to_filter_string(query_hash[:filter_operator], current_index)
  end

  def relative_date_filter_query(query_hash, current_index)
    return hours_before_filter_query(query_hash, current_index) if query_hash[:filter_operator] == 'hours_before'

    days_before_filter_query(query_hash, current_index)
  end

  def timezone_aware_filter_operation(query_hash, current_index, filter_value)
    return unless timestamp_attribute?(query_hash)

    @filter_values["value_#{current_index}"] = timestamp_filter_boundary(filter_value, query_hash)
    operator = query_hash['filter_operator'] == 'is_less_than' ? '<' : '>='
    "#{operator} :value_#{current_index}"
  end

  private

  def timestamp_attribute?(query_hash)
    TIMESTAMP_ATTRIBUTES.include?(query_hash['attribute_key'])
  end

  # The browser sends its timezone with the filter; requests without one (saved views created before
  # that, API clients) fall back to the account reporting timezone.
  def filter_timezone(query_hash)
    return Filters::DateFilterHelper.timezone(query_hash['timezone']) if query_hash.key?('timezone')

    ActiveSupport::TimeZone[@account&.reporting_timezone.presence || 'UTC'] || ActiveSupport::TimeZone['UTC']
  end

  def start_of_day(date, query_hash)
    filter_timezone(query_hash).local(date.year, date.month, date.day).utc
  end

  def timestamp_filter_boundary(date, query_hash)
    start_of_day(query_hash['filter_operator'] == 'is_greater_than' ? date.tomorrow : date, query_hash)
  end

  def same_day_filter_query(query_hash, current_index)
    date = coerce_lt_gt_value(query_hash['values'][0], 'date', query_hash[:attribute_key])
    @filter_values["value_#{current_index}"] = start_of_day(date, query_hash)
    @filter_values["value_#{current_index}_end"] = filter_timezone(query_hash).local(date.year, date.month, date.day).end_of_day.utc

    "BETWEEN :value_#{current_index} AND :value_#{current_index}_end"
  end

  def days_before_filter_query(query_hash, current_index)
    days = Integer(query_hash['values'][0].to_s, 10, exception: false)
    raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: query_hash['attribute_key']) unless days&.between?(1, 998)

    date = filter_timezone(query_hash).today - days.days
    updated_query_hash = query_hash.to_h.with_indifferent_access.merge(
      values: [date.strftime],
      filter_operator: 'is_less_than'
    )

    lt_gt_filter_query(updated_query_hash, current_index)
  end

  def hours_before_filter_query(query_hash, current_index)
    hours = Integer(query_hash['values'][0].to_s, 10, exception: false)
    # Same 1..998 bound as days_before, enforced by the UI validation too
    raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: query_hash['attribute_key']) unless hours&.between?(1, 998)

    @filter_values["value_#{current_index}"] = Time.current - hours.hours
    "< :value_#{current_index}"
  end
end
