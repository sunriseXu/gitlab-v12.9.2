# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::UsageData do
  before do
    allow(ActiveRecord::Base.connection).to receive(:transaction_open?).and_return(false)
  end

  [true, false].each do |usage_ping_batch_counter_on|
    describe "when the feature flag usage_ping_batch_counter is set to #{usage_ping_batch_counter_on}" do
      before do
        stub_feature_flags(usage_ping_batch_counter: usage_ping_batch_counter_on)
      end

      describe '.uncached_data' do
        context 'when the :usage_activity_by_stage feature is not enabled' do
          before do
            stub_feature_flags(usage_activity_by_stage: false)
          end

          it "does not include usage_activity_by_stage data" do
            expect(described_class.uncached_data).not_to include(:usage_activity_by_stage)
            expect(described_class.uncached_data).not_to include(:usage_activity_by_stage_monthly)
          end
        end

        context 'when the :usage_activity_by_stage feature is enabled' do
          it 'includes usage_activity_by_stage data' do
            expect(described_class.uncached_data).to include(:usage_activity_by_stage)
            expect(described_class.uncached_data).to include(:usage_activity_by_stage_monthly)
          end

          context 'for configure' do
            it 'includes accurate usage_activity_by_stage data' do
              for_defined_days_back do
                user = create(:user)
                cluster = create(:cluster, user: user)
                project = create(:project, creator: user)
                create(:clusters_applications_cert_manager, :installed, cluster: cluster)
                create(:clusters_applications_helm, :installed, cluster: cluster)
                create(:clusters_applications_ingress, :installed, cluster: cluster)
                create(:clusters_applications_knative, :installed, cluster: cluster)
                create(:cluster, :disabled, user: user)
                create(:cluster_provider_gcp, :created)
                create(:cluster_provider_aws, :created)
                create(:cluster_platform_kubernetes)
                create(:cluster, :group, :disabled, user: user)
                create(:cluster, :group, user: user)
                create(:slack_service, project: project)
                create(:slack_slash_commands_service, project: project)
                create(:prometheus_service, project: project)
              end

              expect(described_class.uncached_data[:usage_activity_by_stage][:configure]).to eq(
                clusters_applications_cert_managers: 2,
                clusters_applications_helm: 2,
                clusters_applications_ingress: 2,
                clusters_applications_knative: 2,
                clusters_disabled: 2,
                clusters_enabled: 8,
                clusters_platforms_gke: 2,
                clusters_platforms_eks: 2,
                clusters_platforms_user: 2,
                group_clusters_disabled: 2,
                group_clusters_enabled: 2,
                project_clusters_disabled: 2,
                project_clusters_enabled: 8,
                projects_slack_notifications_active: 2,
                projects_slack_slash_active: 2,
                projects_with_prometheus_alerts: 2
              )
              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:configure]).to eq(
                clusters_applications_cert_managers: 1,
                clusters_applications_helm: 1,
                clusters_applications_ingress: 1,
                clusters_applications_knative: 1,
                clusters_disabled: 1,
                clusters_enabled: 4,
                clusters_platforms_gke: 1,
                clusters_platforms_eks: 1,
                clusters_platforms_user: 1,
                group_clusters_disabled: 1,
                group_clusters_enabled: 1,
                project_clusters_disabled: 1,
                project_clusters_enabled: 4,
                projects_slack_notifications_active: 1,
                projects_slack_slash_active: 1,
                projects_with_prometheus_alerts: 1
              )
            end
          end

          context 'for create' do
            it 'includes accurate usage_activity_by_stage data' do
              for_defined_days_back do
                user = create(:user)
                project = create(:project, :repository_private, :github_imported,
                                  :test_repo, :remote_mirror, creator: user)
                merge_request = create(:merge_request, source_project: project)
                create(:deploy_key, user: user)
                create(:key, user: user)
                create(:project, creator: user)
                create(:protected_branch, project: project)
                create(:remote_mirror, project: project)
                create(:snippet, author: user)
                create(:suggestion, note: create(:note, project: project))
                create(:code_owner_rule, merge_request: merge_request, approvals_required: 3)
                create(:code_owner_rule, merge_request: merge_request, approvals_required: 7)
                create_list(:code_owner_rule, 3, approvals_required: 2)
                create_list(:code_owner_rule, 2)
              end

              expect(described_class.uncached_data[:usage_activity_by_stage][:create]).to eq(
                deploy_keys: 2,
                keys: 2,
                merge_requests: 12,
                projects_enforcing_code_owner_approval: 0,
                merge_requests_with_optional_codeowners: 4,
                merge_requests_with_required_codeowners: 8,
                projects_imported_from_github: 2,
                projects_with_repositories_enabled: 12,
                protected_branches: 2,
                remote_mirrors: 2,
                snippets: 2,
                suggestions: 2
              )
              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:create]).to eq(
                deploy_keys: 1,
                keys: 1,
                merge_requests: 6,
                projects_enforcing_code_owner_approval: 0,
                merge_requests_with_optional_codeowners: 2,
                merge_requests_with_required_codeowners: 4,
                projects_imported_from_github: 1,
                projects_with_repositories_enabled: 6,
                protected_branches: 1,
                remote_mirrors: 1,
                snippets: 1,
                suggestions: 1
              )
            end
          end

          context 'for manage' do
            it 'includes accurate usage_activity_by_stage data' do
              for_defined_days_back do
                user = create(:user)
                create(:event, author: user)
                create(:group_member, user: user)
                create(:key, type: 'LDAPKey', user: user)
                create(:group_member, ldap: true, user: user)
              end

              expect(described_class.uncached_data[:usage_activity_by_stage][:manage]).to eq(
                events: 2,
                groups: 2,
                ldap_keys: 2,
                ldap_users: 2
              )
              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:manage]).to eq(
                events: 1,
                groups: 1,
                ldap_keys: 1,
                ldap_users: 1
              )
            end
          end

          context 'for monitor' do
            it 'includes accurate usage_activity_by_stage data' do
              for_defined_days_back do
                user    = create(:user, dashboard: 'operations')
                cluster = create(:cluster, user: user)
                project = create(:project, creator: user)

                create(:clusters_applications_prometheus, :installed, cluster: cluster)
                create(:users_ops_dashboard_project, user: user)
                create(:prometheus_service, project: project)
                create(:project_error_tracking_setting, project: project)
                create(:project_tracing_setting, project: project)
              end

              expect(described_class.uncached_data[:usage_activity_by_stage][:monitor]).to eq(
                clusters: 2,
                clusters_applications_prometheus: 2,
                operations_dashboard_default_dashboard: 2,
                operations_dashboard_users_with_projects_added: 2,
                projects_prometheus_active: 2,
                projects_with_error_tracking_enabled: 2,
                projects_with_tracing_enabled: 2
              )
              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:monitor]).to eq(
                clusters: 1,
                clusters_applications_prometheus: 1,
                operations_dashboard_default_dashboard: 1,
                operations_dashboard_users_with_projects_added: 1,
                projects_prometheus_active: 1,
                projects_with_error_tracking_enabled: 1,
                projects_with_tracing_enabled: 1
              )
            end
          end

          context 'for package' do
            it 'includes accurate usage_activity_by_stage data' do
              for_defined_days_back do
                create(:project, packages: [create(:package)] )
              end

              expect(described_class.uncached_data[:usage_activity_by_stage][:package]).to eq(
                projects_with_packages: 2
              )
              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:package]).to eq(
                projects_with_packages: 1
              )
            end
          end

          context 'for plan' do
            it 'includes accurate usage_activity_by_stage data' do
              stub_licensed_features(board_assignee_lists: true, board_milestone_lists: true)

              for_defined_days_back do
                user = create(:user)
                project = create(:project, creator: user)
                issue = create(:issue, project: project, author: User.support_bot)
                create(:issue, project: project, author: user)
                board = create(:board, project: project)
                create(:user_list, board: board, user: user)
                create(:milestone_list, board: board, milestone: create(:milestone, project: project), user: user)
                create(:list, board: board, label: create(:label, project: project), user: user)
                create(:note, project: project, noteable: issue, author: user)
                create(:epic, author: user)
                create(:todo, project: project, target: issue, author: user)
                create(:jira_service, :jira_cloud_service, active: true, project: create(:project, :jira_dvcs_cloud, creator: user))
                create(:jira_service, active: true, project: create(:project, :jira_dvcs_server, creator: user))
              end

              expect(described_class.uncached_data[:usage_activity_by_stage][:plan]).to eq(
                assignee_lists: 2,
                epics: 2,
                issues: 3,
                label_lists: 2,
                milestone_lists: 2,
                notes: 2,
                projects: 2,
                projects_jira_active: 2,
                projects_jira_dvcs_cloud_active: 2,
                projects_jira_dvcs_server_active: 2,
                service_desk_enabled_projects: 2,
                service_desk_issues: 2,
                todos: 2
              )
              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:plan]).to eq(
                assignee_lists: 1,
                epics: 1,
                issues: 2,
                label_lists: 1,
                milestone_lists: 1,
                notes: 1,
                projects: 1,
                projects_jira_active: 1,
                projects_jira_dvcs_cloud_active: 1,
                projects_jira_dvcs_server_active: 1,
                service_desk_enabled_projects: 1,
                service_desk_issues: 1,
                todos: 1
              )
            end
          end

          context 'for release' do
            it 'includes accurate usage_activity_by_stage data' do
              for_defined_days_back do
                user = create(:user)
                create(:deployment, :failed, user: user)
                create(:project, :mirror, mirror_trigger_builds: true)
                create(:release, author: user)
                create(:deployment, :success, user: user)
              end

              expect(described_class.uncached_data[:usage_activity_by_stage][:release]).to eq(
                deployments: 2,
                failed_deployments: 2,
                projects_mirrored_with_pipelines_enabled: 2,
                releases: 2,
                successful_deployments: 2
              )
              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:release]).to eq(
                deployments: 1,
                failed_deployments: 1,
                projects_mirrored_with_pipelines_enabled: 1,
                releases: 1,
                successful_deployments: 1
              )
            end
          end

          context 'for secure' do
            let_it_be(:user) { create(:user, group_view: :security_dashboard) }

            before do
              for_defined_days_back do
                create(:ci_build, name: 'container_scanning', user: user)
                create(:ci_build, name: 'dast', user: user)
                create(:ci_build, name: 'dependency_scanning', user: user)
                create(:ci_build, name: 'license_management', user: user)
                create(:ci_build, name: 'sast', user: user)
              end
            end

            it 'includes accurate usage_activity_by_stage data' do
              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:secure]).to eq(
                user_preferences_group_overview_security_dashboard: 1,
                user_container_scanning_jobs: 1,
                user_dast_jobs: 1,
                user_dependency_scanning_jobs: 1,
                user_license_management_jobs: 1,
                user_sast_jobs: 1
              )
            end

            it 'combines license_scanning into license_management' do
              for_defined_days_back do
                create(:ci_build, name: 'license_scanning', user: user)
              end

              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:secure]).to eq(
                user_preferences_group_overview_security_dashboard: 1,
                user_container_scanning_jobs: 1,
                user_dast_jobs: 1,
                user_dependency_scanning_jobs: 1,
                user_license_management_jobs: 2,
                user_sast_jobs: 1
              )
            end

            it 'has to resort to 0 for counting license scan' do
              allow(Gitlab::Database::BatchCount).to receive(:batch_distinct_count).and_raise(ActiveRecord::StatementInvalid)
              allow(::Ci::Build).to receive(:distinct_count_by).and_raise(ActiveRecord::StatementInvalid)

              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:secure]).to eq(
                user_preferences_group_overview_security_dashboard: 1,
                user_container_scanning_jobs: -1,
                user_dast_jobs: -1,
                user_dependency_scanning_jobs: -1,
                user_license_management_jobs: -1,
                user_sast_jobs: -1
              )
            end
          end

          context 'for verify' do
            it 'includes accurate usage_activity_by_stage data' do
              for_defined_days_back do
                user = create(:user)
                create(:ci_build, user: user)
                create(:ci_empty_pipeline, source: :external, user: user)
                create(:ci_empty_pipeline, user: user)
                create(:ci_pipeline, :auto_devops_source, user: user)
                create(:ci_pipeline, :repository_source, user: user)
                create(:ci_pipeline_schedule, owner: user)
                create(:ci_trigger, owner: user)
                create(:clusters_applications_runner, :installed)
                create(:github_service)
              end

              expect(described_class.uncached_data[:usage_activity_by_stage][:verify]).to eq(
                ci_builds: 2,
                ci_external_pipelines: 2,
                ci_internal_pipelines: 2,
                ci_pipeline_config_auto_devops: 2,
                ci_pipeline_config_repository: 2,
                ci_pipeline_schedules: 2,
                ci_pipelines: 2,
                ci_triggers: 2,
                clusters_applications_runner: 2,
                projects_reporting_ci_cd_back_to_github: 2
              )
              expect(described_class.uncached_data[:usage_activity_by_stage_monthly][:verify]).to eq(
                ci_builds: 1,
                ci_external_pipelines: 1,
                ci_internal_pipelines: 1,
                ci_pipeline_config_auto_devops: 1,
                ci_pipeline_config_repository: 1,
                ci_pipeline_schedules: 1,
                ci_pipelines: 1,
                ci_triggers: 1,
                clusters_applications_runner: 1,
                projects_reporting_ci_cd_back_to_github: 1
              )
            end
          end
        end
      end
    end
  end

  def for_defined_days_back(days: [29, 2])
    days.each do |n|
      Timecop.travel(n.days.ago) do
        yield
      end
    end
  end
end
