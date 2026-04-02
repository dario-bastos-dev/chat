class MigrateWaitTimeFormatToDays < ActiveRecord::Migration[7.0]
  def up
    MessageSequenceStep.where("wait_time ~ ?", '^\d{2}:\d{2}$').find_each do |step|
      step.update_column(:wait_time, "0:#{step.wait_time}:00")
    end
  end

  def down
    MessageSequenceStep.where("wait_time ~ ?", '^\d+:\d{2}:\d{2}:\d{2}$').find_each do |step|
      parts = step.wait_time.split(':')
      step.update_column(:wait_time, "#{parts[1]}:#{parts[2]}")
    end
  end
end
