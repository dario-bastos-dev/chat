# frozen_string_literal: true

class RemoveFinancialMetricsFromDeals < ActiveRecord::Migration[7.0]
  def change
    remove_column :deals, :value, :decimal, precision: 15, scale: 2, default: 0.0
    remove_column :deals, :currency, :string, limit: 3, default: "BRL"
    remove_column :deals, :expected_close_date, :date
  end
end
