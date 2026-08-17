class NormalizeEvolutionGoDelayTime < ActiveRecord::Migration[7.1]
  # provider_config['delay_time'] is entered in seconds, but older builds persisted it in
  # milliseconds and the send path told the two apart with a "> 100 means milliseconds"
  # heuristic — which silently turned a 120 second delay into 120 milliseconds. Values above
  # the old threshold are the millisecond ones, so they are converted back to seconds and the
  # heuristic is dropped from the code.
  def up
    execute <<~SQL.squish
      UPDATE channel_whatsapp
      SET provider_config = jsonb_set(
            provider_config,
            '{delay_time}',
            to_jsonb(GREATEST(round((provider_config->>'delay_time')::numeric / 1000), 1)::int)
          )
      WHERE provider = 'evolution_go'
        AND provider_config->>'delay_time' IS NOT NULL
        AND provider_config->>'delay_time' ~ '^[0-9]+$'
        AND (provider_config->>'delay_time')::numeric > 100
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
