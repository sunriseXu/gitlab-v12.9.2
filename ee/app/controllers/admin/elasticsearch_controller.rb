# frozen_string_literal: true

class Admin::ElasticsearchController < Admin::ApplicationController
  before_action :check_elasticsearch_web_indexing_feature_flag!

  def check_elasticsearch_web_indexing_feature_flag!
    render_404 unless Feature.enabled?(:elasticsearch_web_indexing, default_enabled: true)
  end

  # POST
  # Scheduling indexing jobs
  def enqueue_index
    if Gitlab::Elastic::Helper.index_exists?
      ::Elastic::IndexProjectsService.new.execute

      notice = _('Elasticsearch indexing started')
      queue_link = helpers.link_to(_('(check progress)'), sidekiq_path + '/queues/elastic_full_index')
      flash[:notice] = "#{notice} #{queue_link}".html_safe
    else
      flash[:warning] = _('Please create an index before enabling indexing')
    end

    redirect_to integrations_admin_application_settings_path(anchor: 'js-elasticsearch-settings')
  end
end
