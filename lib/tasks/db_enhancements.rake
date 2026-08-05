# A full `rails db:migrate` run (e.g. on a brand new install) executes every
# pending migration back-to-back on a single Postgres connection. Any
# migration that alters a table's columns and then queries that table (or
# an unrelated table whose shape changed earlier in the same run) via
# ActiveRecord can hit `PG::FeatureNotSupported: cached plan must not
# change result type`, because Postgres/the pg gem cache prepared
# statement plans per-connection and don't know the result shape changed.
# Rather than patching every individual migration that happens to run into
# this, clear the connection's prepared statement cache after each
# migration step so every migration always queries against a fresh plan.
ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.prepend(Module.new do
    def exec_migration(conn, direction)
      super
    ensure
      conn.clear_cache! if conn.respond_to?(:clear_cache!)
    end
  end)
end

# We are hooking config loader to run automatically everytime migration is executed
Rake::Task['db:migrate'].enhance do
  if ActiveRecord::Base.connection.table_exists? 'installation_configs'
    puts 'Loading Installation config'
    ConfigLoader.new.process
  end
end

# we are creating a custom database prepare task
# the default rake db:prepare task isn't ideal for environments like heroku
# In heroku the database is already created before the first run of db:prepare
# In this case rake db:prepare tries to run db:migrate from all the way back from the beginning
# Since the assumption is migrations are only run after schema load from a point x, this could lead to things breaking.
# ref: https://github.com/rails/rails/blob/main/activerecord/lib/active_record/railties/databases.rake#L356
db_namespace = namespace :db do
  desc 'Runs setup if database does not exist, or runs migrations if it does'
  task chatwoot_prepare: :load_config do
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
      begin
        ActiveRecord::Base.establish_connection(db_config.configuration_hash)
        unless ActiveRecord::Base.connection.table_exists? 'ar_internal_metadata'
          # Run migrations sequentially from scratch instead of loading a potentially outdated schema.rb
          db_namespace['migrate'].invoke
          db_namespace['seed'].invoke
        end

        db_namespace['migrate'].invoke
      rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad
        db_namespace['create'].invoke
        ActiveRecord::Base.establish_connection(db_config.configuration_hash)
        db_namespace['migrate'].invoke
        db_namespace['seed'].invoke
      end
    end
  end
end
