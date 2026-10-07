module Filters::DateFilterHelper
  # Standard date attributes are timestamps, so "equal to" matches the whole day
  # in the account's reporting timezone instead of comparing against midnight.
  def equality_filter_query(query_hash, current_index)
    if query_hash[:filter_operator] == 'equal_to' && standard_attribute_data_type(query_hash[:attribute_key]) == 'date'
      return same_day_filter_query(query_hash, current_index)
    end

    @filter_values["value_#{current_index}"] = filter_values(query_hash)
    equals_to_filter_string(query_hash[:filter_operator], current_index)
  end

  def relative_date_filter_query(query_hash, current_index)
    return hours_before_filter_query(query_hash, current_index) if query_hash[:filter_operator] == 'hours_before'

    days_before_filter_query(query_hash, current_index)
  end

  private

  def same_day_filter_query(query_hash, current_index)
    date = coerce_lt_gt_value(query_hash['values'][0], 'date', query_hash[:attribute_key])
    @filter_values["value_#{current_index}"] = date_to_utc_boundary(date, 'is_less_than')
    @filter_values["value_#{current_index}_end"] = date_to_utc_boundary(date, 'is_greater_than')

    "BETWEEN :value_#{current_index} AND :value_#{current_index}_end"
  end

  def hours_before_filter_query(query_hash, current_index)
    hours = Integer(query_hash['values'][0].to_s, 10, exception: false)
    # Same 1..998 bound as days_before, enforced by the UI validation too
    raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: query_hash['attribute_key']) unless hours&.between?(1, 998)

    @filter_values["value_#{current_index}"] = Time.current - hours.hours
    "< :value_#{current_index}"
  end
end
