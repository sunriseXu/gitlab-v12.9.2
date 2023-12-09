namespace :gitlab do
  namespace :elastic do
    desc "GitLab | Elasticsearch | Index eveything at once"
    task :index do
      # UPDATE_INDEX=true can cause some projects not to be indexed properly if someone were to push a commit to the
      # project before the rake task could get to it, so we set it to `nil` here to avoid that. It doesn't make sense
      # to use this configuration during a full re-index anyways.
      ENV['UPDATE_INDEX'] = nil

      Rake::Task["gitlab:elastic:create_empty_index"].invoke
      Rake::Task["gitlab:elastic:clear_index_status"].invoke
      Rake::Task["gitlab:elastic:index_projects"].invoke
      Rake::Task["gitlab:elastic:index_snippets"].invoke
    end

    desc "GitLab | Elasticsearch | Index projects in the background"
    task index_projects: :environment do
      print "Enqueuing projects"

      project_id_batches do |ids|
        args = ids.collect do |id|
          [:index, 'Project', id, nil] # es_id is unused for :index
        end

        ElasticIndexerWorker.bulk_perform_async(args) # rubocop:disable Scalability/BulkPerformWithContext
        print "."
      end

      puts "OK"
    end

    desc "GitLab | ElasticSearch | Check project indexing status"
    task index_projects_status: :environment do
      indexed = IndexStatus.count
      projects = Project.count
      percent = (indexed / projects.to_f) * 100.0

      puts "Indexing is %.2f%% complete (%d/%d projects)" % [percent, indexed, projects]
    end

    desc 'GitLab | Elasticsearch | Unlock repositories for indexing in case something gets stuck'
    task clear_locked_projects: :environment do
      Gitlab::Redis::SharedState.with { |redis| redis.del(:elastic_projects_indexing) }

      puts 'Cleared all locked projects. Incremental indexing should work now.'
    end

    desc "GitLab | Elasticsearch | Index all snippets"
    task index_snippets: :environment do
      logger = Logger.new(STDOUT)
      logger.info("Indexing snippets...")

      Snippet.es_import

      logger.info("Indexing snippets... " + "done".color(:green))
    end

    desc "GitLab | Elasticsearch | Create empty index"
    task create_empty_index: :environment do
      Gitlab::Elastic::Helper.create_empty_index
      puts "Index created".color(:green)
    end

    desc "GitLab | Elasticsearch | Clear indexing status"
    task clear_index_status: :environment do
      IndexStatus.delete_all
      puts "Index status has been reset".color(:green)
    end

    desc "GitLab | Elasticsearch | Delete index"
    task delete_index: :environment do
      Gitlab::Elastic::Helper.delete_index
      puts "Index deleted".color(:green)
    end

    desc "GitLab | Elasticsearch | Recreate index"
    task recreate_index: :environment do
      Gitlab::Elastic::Helper.create_empty_index
      puts "Index recreated".color(:green)
    end

    desc "GitLab | Elasticsearch | Display which projects are not indexed"
    task projects_not_indexed: :environment do
      not_indexed = Project.where.not(id: IndexStatus.select(:project_id).distinct)

      if not_indexed.count.zero?
        puts 'All projects are currently indexed'.color(:green)
      else
        display_unindexed(not_indexed)
      end
    end

    def project_id_batches(&blk)
      relation = Project

      unless ENV['UPDATE_INDEX']
        relation = relation.includes(:index_status).where('index_statuses.id IS NULL').references(:index_statuses)
      end

      if ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?
        relation = relation.where(id: ::Gitlab::CurrentSettings.elasticsearch_limited_projects.select(:id))
      end

      relation.all.in_batches(start: ENV['ID_FROM'], finish: ENV['ID_TO']) do |relation| # rubocop: disable Cop/InBatches
        ids = relation.reorder(:id).pluck(:id)
        Gitlab::Redis::SharedState.with { |redis| redis.sadd(:elastic_projects_indexing, ids) }
        yield ids
      end
    end

    def display_unindexed(projects)
      arr = if projects.count < 500 || ENV['SHOW_ALL']
              projects
            else
              projects[1..500]
            end

      arr.each do |p|
        puts "Project '#{p.full_path}' (ID: #{p.id}) isn't indexed.".color(:red)
      end

      puts "#{arr.count} out of #{projects.count} non-indexed projects shown."
    end
  end
end
