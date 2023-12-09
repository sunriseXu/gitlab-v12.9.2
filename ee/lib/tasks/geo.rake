require 'action_view/helpers'

task spec: ['geo:db:test:prepare']

namespace :geo do
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::NumberHelper

  GEO_LICENSE_ERROR_TEXT = 'GitLab Geo is not supported with this license. Please contact the sales team: https://about.gitlab.com/sales.'.freeze
  GEO_STATUS_COLUMN_WIDTH = 40

  namespace :db do |ns|
    desc 'GitLab | Geo | DB | Drops the Geo tracking database from config/database_geo.yml for the current RAILS_ENV.'
    task drop: [:environment] do
      Gitlab::Geo::DatabaseTasks.drop_current
    end

    desc 'GitLab | Geo | DB | Creates the Geo tracking database from config/database_geo.yml for the current RAILS_ENV.'
    task create: [:environment] do
      Gitlab::Geo::DatabaseTasks.create_current
    end

    desc 'GitLab | Geo | DB | Create the Geo tracking database, load the schema, and initialize with the seed data.'
    task setup: ['geo:db:schema:load', 'geo:db:seed']

    desc 'GitLab | Geo | DB | Migrate the Geo tracking database (options: VERSION=x, VERBOSE=false, SCOPE=blog).'
    task migrate: [:environment] do
      Gitlab::Geo::DatabaseTasks.migrate

      ns['_dump'].invoke
    end

    desc 'GitLab | Geo | DB | Rolls the schema back to the previous version (specify steps w/ STEP=n).'
    task rollback: [:environment] do
      Gitlab::Geo::DatabaseTasks.rollback

      ns['_dump'].invoke
    end

    desc 'GitLab | Geo | DB | Retrieves the current schema version number.'
    task version: [:environment] do
      puts "Current version: #{Gitlab::Geo::DatabaseTasks.version}"
    end

    desc 'GitLab | Geo | DB | Drops and recreates the database from ee/db/geo/schema.rb for the current environment and loads the seeds.'
    task reset: [:environment] do
      ns['drop'].invoke
      ns['create'].invoke
      ns['setup'].invoke
    end

    desc 'GitLab | Geo | DB | Load the seed data from ee/db/geo/seeds.rb'
    task seed: [:environment] do
      ns['abort_if_pending_migrations'].invoke

      Gitlab::Geo::DatabaseTasks.load_seed
    end

    desc 'GitLab | Geo | DB | Refresh Foreign Tables definition in Geo Secondary node'
    task refresh_foreign_tables: [:environment] do
      if Gitlab::Geo::GeoTasks.foreign_server_configured?
        print "\nRefreshing foreign tables for FDW: #{Gitlab::Geo::Fdw::FOREIGN_SCHEMA} ... "
        Gitlab::Geo::GeoTasks.refresh_foreign_tables!
        puts 'Done!'
      else
        puts "Error: Cannot refresh foreign tables, there is no foreign server configured."
        exit 1
      end
    end

    # IMPORTANT: This task won't dump the schema if ActiveRecord::Base.dump_schema_after_migration is set to false
    task _dump: [:environment] do
      if Gitlab::Geo::DatabaseTasks.dump_schema_after_migration?
        ns["schema:dump"].invoke
      end

      # Allow this task to be called as many times as required. An example is the
      # migrate:redo task, which calls other two internally that depend on this one.
      ns['_dump'].reenable
    end

    # desc "Raises an error if there are pending migrations"
    task abort_if_pending_migrations: [:environment] do
      pending_migrations = Gitlab::Geo::DatabaseTasks.pending_migrations

      if pending_migrations.any?
        puts "You have #{pending_migrations.size} pending #{pending_migrations.size > 1 ? 'migrations:' : 'migration:'}"
        pending_migrations.each do |pending_migration|
          puts '  %4d %s' % [pending_migration.version, pending_migration.name]
        end
        abort %{Run `rake geo:db:migrate` to update your database then try again.}
      end
    end

    namespace :schema do
      desc 'GitLab | Geo | DB | Schema | Load a schema.rb file into the database'
      task load: [:environment] do
        Gitlab::Geo::DatabaseTasks.load_schema_current(:ruby, ENV['SCHEMA'])
      end

      desc 'GitLab | Geo | DB | Schema | Create a ee/db/geo/schema.rb file that is portable against any DB supported by AR'
      task dump: [:environment] do
        Gitlab::Geo::DatabaseTasks::Schema.dump

        ns['schema:dump'].reenable
      end
    end

    namespace :migrate do
      desc 'GitLab | Geo | DB | Migrate | Runs the "up" for a given migration VERSION.'
      task up: [:environment] do
        Gitlab::Geo::DatabaseTasks::Migrate.up

        ns['_dump'].invoke
      end

      desc 'GitLab | Geo | DB | Migrate | Runs the "down" for a given migration VERSION.'
      task down: [:environment] do
        Gitlab::Geo::DatabaseTasks::Migrate.down

        ns['_dump'].invoke
      end

      desc 'GitLab | Geo | DB | Migrate | Rollbacks the database one migration and re migrate up (options: STEP=x, VERSION=x).'
      task redo: [:environment] do
        if ENV['VERSION']
          ns['migrate:down'].invoke
          ns['migrate:up'].invoke
        else
          ns['rollback'].invoke
          ns['migrate'].invoke
        end
      end

      desc 'GitLab | Geo | DB | Migrate | Display status of migrations'
      task status: [:environment] do
        Gitlab::Geo::DatabaseTasks::Migrate.status
      end
    end

    namespace :test do
      desc 'GitLab | Geo | DB | Test | Check for pending migrations and load the test schema'
      task prepare: [:environment] do
        ns['test:load'].invoke
      end

      # desc "Recreate the test database from the current schema"
      task load: [:environment, 'geo:db:test:purge'] do
        Gitlab::Geo::DatabaseTasks::Test.load
      end

      # desc "Empty the test database"
      task purge: [:environment] do
        Gitlab::Geo::DatabaseTasks::Test.purge
      end

      desc 'GitLab | Geo | DB | Test | Refresh Foreign Tables definition for test environment'
      task refresh_foreign_tables: [:environment] do
        old_env = ActiveRecord::Tasks::DatabaseTasks.env
        ActiveRecord::Tasks::DatabaseTasks.env = 'test'

        ns['geo:db:refresh_foreign_tables'].invoke

        ActiveRecord::Tasks::DatabaseTasks.env = old_env
      end
    end
  end

  desc 'GitLab | Geo | Run orphaned project registry cleaner'
  task run_orphaned_project_registry_cleaner: :environment do
    abort GEO_LICENSE_ERROR_TEXT unless Gitlab::Geo.license_allows?

    unless Gitlab::Geo.secondary?
      abort 'This is not a secondary node'
    end

    from_project_id = ENV['FROM_PROJECT_ID'] || Geo::ProjectRegistry.minimum(:project_id)
    to_project_id = ENV['TO_PROJECT_ID'] || Geo::ProjectRegistry.maximum(:project_id)

    if from_project_id > to_project_id
      abort 'FROM_PROJECT_ID can not be greater than TO_PROJECT_ID'
    end

    batch_size = 1000
    total_count = 0
    current_max_id = 0

    until current_max_id >= to_project_id
      current_max_id = [from_project_id + batch_size, to_project_id + 1].min

      project_ids = Project
        .where('id >= ? AND id < ?', from_project_id, current_max_id)
        .pluck_primary_key

      orphaned_registries = Geo::ProjectRegistry
        .where('project_id NOT IN(?)', project_ids)
        .where('project_id >= ? AND project_id < ?', from_project_id, current_max_id)
      count = orphaned_registries.delete_all
      total_count += count

      puts "Checked project ids from #{from_project_id} to #{current_max_id} registries. Removed #{count} orphaned registries"

      from_project_id = current_max_id
    end

    puts "Orphaned registries removed(total): #{total_count}"
  end

  desc 'GitLab | Geo | Make this node the Geo primary'
  task set_primary_node: :environment do
    abort GEO_LICENSE_ERROR_TEXT unless Gitlab::Geo.license_allows?
    abort 'GitLab Geo primary node already present' if Gitlab::Geo.primary_node.present?

    Gitlab::Geo::GeoTasks.set_primary_geo_node
  end

  desc 'GitLab | Geo | Make this secondary node the primary'
  task set_secondary_as_primary: :environment do
    abort GEO_LICENSE_ERROR_TEXT unless Gitlab::Geo.license_allows?

    ActiveRecord::Base.transaction do
      primary_node = GeoNode.primary_node

      unless primary_node
        abort 'The primary is not set'
      end

      primary_node.destroy

      current_node = GeoNode.current_node

      unless current_node.secondary?
        abort 'This is not a secondary node'
      end

      current_node.update!(primary: true)
    end
  end

  desc 'GitLab | Geo | Update Geo primary node URL'
  task update_primary_node_url: :environment do
    abort GEO_LICENSE_ERROR_TEXT unless Gitlab::Geo.license_allows?

    Gitlab::Geo::GeoTasks.update_primary_geo_node_url
  end

  desc 'GitLab | Geo | Print Geo node status'
  task status: :environment do
    abort GEO_LICENSE_ERROR_TEXT unless Gitlab::Geo.license_allows?

    current_node_status = GeoNodeStatus.current_node_status
    geo_node = current_node_status.geo_node

    unless geo_node.secondary?
      puts 'This command is only available on a secondary node'.color(:red)
      exit
    end

    puts
    puts "Name: #{GeoNode.current_node_name}"
    puts "URL: #{GeoNode.current_node_url}"
    puts '-----------------------------------------------------'.color(:yellow)

    unless Gitlab::Database.postgresql_minimum_supported_version?
      puts
      puts 'WARNING: Please upgrade PostgreSQL to version 9.6 or greater. The status of the replication cannot be determined reliably with the current version.'.color(:red)
      puts
    end

    print 'GitLab Version: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    puts Gitlab::VERSION

    print 'Geo Role: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    role =
      if Gitlab::Geo.primary?
        'Primary'
      else
        Gitlab::Geo.secondary? ? 'Secondary' : 'unknown'.color(:yellow)
      end

    puts role

    print 'Health Status: '.rjust(GEO_STATUS_COLUMN_WIDTH)

    if current_node_status.healthy?
      puts current_node_status.health_status
    else
      puts current_node_status.health_status.color(:red)
    end

    unless current_node_status.healthy?
      print 'Health Status Summary: '.rjust(GEO_STATUS_COLUMN_WIDTH)
      puts current_node_status.health.color(:red)
    end

    print 'Repositories: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    show_failed_value(current_node_status.repositories_failed_count)
    print "#{current_node_status.repositories_synced_count}/#{current_node_status.projects_count} "
    puts using_percentage(current_node_status.repositories_synced_in_percentage)

    if Gitlab::Geo.repository_verification_enabled?
      print 'Verified Repositories: '.rjust(GEO_STATUS_COLUMN_WIDTH)
      show_failed_value(current_node_status.repositories_verification_failed_count)
      print "#{current_node_status.repositories_verified_count}/#{current_node_status.projects_count} "
      puts using_percentage(current_node_status.repositories_verified_in_percentage)
    end

    print 'Wikis: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    show_failed_value(current_node_status.wikis_failed_count)
    print "#{current_node_status.wikis_synced_count}/#{current_node_status.projects_count} "
    puts using_percentage(current_node_status.wikis_synced_in_percentage)

    if Gitlab::Geo.repository_verification_enabled?
      print 'Verified Wikis: '.rjust(GEO_STATUS_COLUMN_WIDTH)
      show_failed_value(current_node_status.wikis_verification_failed_count)
      print "#{current_node_status.wikis_verified_count}/#{current_node_status.projects_count} "
      puts using_percentage(current_node_status.wikis_verified_in_percentage)
    end

    print 'LFS Objects: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    show_failed_value(current_node_status.lfs_objects_failed_count)
    print "#{current_node_status.lfs_objects_synced_count}/#{current_node_status.lfs_objects_count} "
    puts using_percentage(current_node_status.lfs_objects_synced_in_percentage)

    print 'Attachments: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    show_failed_value(current_node_status.attachments_failed_count)
    print "#{current_node_status.attachments_synced_count}/#{current_node_status.attachments_count} "
    puts using_percentage(current_node_status.attachments_synced_in_percentage)

    print 'CI job artifacts: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    show_failed_value(current_node_status.job_artifacts_failed_count)
    print "#{current_node_status.job_artifacts_synced_count}/#{current_node_status.job_artifacts_count} "
    puts using_percentage(current_node_status.job_artifacts_synced_in_percentage)

    if Gitlab.config.geo.registry_replication.enabled
      print 'Container repositories: '.rjust(GEO_STATUS_COLUMN_WIDTH)
      show_failed_value(current_node_status.container_repositories_failed_count)
      print "#{current_node_status.container_repositories_synced_count || 0}/#{current_node_status.container_repositories_count || 0} "
      puts using_percentage(current_node_status.container_repositories_synced_in_percentage)
    end

    print 'Design repositories: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    show_failed_value(current_node_status.design_repositories_failed_count)
    print "#{current_node_status.design_repositories_synced_count || 0}/#{current_node_status.design_repositories_count || 0} "
    puts using_percentage(current_node_status.design_repositories_synced_in_percentage)

    if Gitlab::CurrentSettings.repository_checks_enabled
      print 'Repositories Checked: '.rjust(GEO_STATUS_COLUMN_WIDTH)
      show_failed_value(current_node_status.repositories_checked_failed_count)
      print "#{current_node_status.repositories_checked_count}/#{current_node_status.projects_count} "
      puts using_percentage(current_node_status.repositories_checked_in_percentage)
    end

    print 'Sync Settings: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    puts  geo_node.namespaces.any? ? 'Selective' : 'Full'

    print 'Database replication lag: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    puts "#{Gitlab::Geo::HealthCheck.new.db_replication_lag_seconds} seconds"

    print 'Last event ID seen from primary: '.rjust(GEO_STATUS_COLUMN_WIDTH)
    last_event = Geo::EventLog.last

    if last_event
      print last_event&.id
      puts " (#{time_ago_in_words(last_event&.created_at)} ago)"

      print 'Last event ID processed by cursor: '.rjust(GEO_STATUS_COLUMN_WIDTH)
      cursor_last_event_id = Geo::EventLogState.last_processed&.event_id

      if cursor_last_event_id
        print cursor_last_event_id
        last_cursor_event_date = Geo::EventLog.find_by(id: cursor_last_event_id)&.created_at
        print " (#{time_ago_in_words(last_cursor_event_date)} ago)" if last_cursor_event_date
        puts
      else
        puts 'N/A'
      end
    else
      puts 'N/A'
    end

    print 'Last status report was: '.rjust(GEO_STATUS_COLUMN_WIDTH)

    if current_node_status.updated_at
      puts "#{time_ago_in_words(current_node_status.updated_at)} ago"
    else
      # Only primary node can create a status record in the database so if it does not exist
      # we get unsaved record where updated_at is nil
      puts "Never"
    end

    puts
  end

  def show_failed_value(value)
    print "#{value}".color(:red) + '/' if value > 0
  end

  def using_percentage(value)
    "(#{number_to_percentage(value.floor, precision: 0, strip_insignificant_zeros: true)})"
  end
end
