# frozen_string_literal: true

class AddDealAttributeToCustomAttributeDefinitions < ActiveRecord::Migration[7.0]
  def up
    # Rails enum integer value 2 for deal_attribute is handled by the model
    # No column change needed - attribute_model is already an integer column
    # We just need to ensure the new enum value is recognized
  end

  def down
    # Remove any deal_attribute records if rolling back
    CustomAttributeDefinition.where(attribute_model: 2).destroy_all
  end
end
