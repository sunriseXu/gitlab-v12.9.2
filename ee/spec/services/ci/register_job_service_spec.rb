# frozen_string_literal: true

require 'spec_helper'

describe Ci::RegisterJobService do
  let_it_be(:shared_runner) { create(:ci_runner, :instance) }
  let!(:project) { create :project, shared_runners_enabled: true }
  let!(:pipeline) { create :ci_empty_pipeline, project: project }
  let!(:pending_build) { create :ci_build, pipeline: pipeline }

  describe '#execute' do
    context 'checks database loadbalancing stickiness' do
      subject { described_class.new(shared_runner).execute }

      before do
        project.update(shared_runners_enabled: false)
      end

      it 'result is valid if replica did caught-up' do
        allow(Gitlab::Database::LoadBalancing).to receive(:enable?)
          .and_return(true)

        expect(Gitlab::Database::LoadBalancing::Sticking).to receive(:all_caught_up?)
          .with(:runner, shared_runner.id) { true }

        expect(subject).to be_valid
      end

      it 'result is invalid if replica did not caught-up' do
        allow(Gitlab::Database::LoadBalancing).to receive(:enable?)
          .and_return(true)

        expect(Gitlab::Database::LoadBalancing::Sticking).to receive(:all_caught_up?)
          .with(:runner, shared_runner.id) { false }

        expect(subject).not_to be_valid
      end
    end

    context 'shared runners minutes limit' do
      subject { described_class.new(shared_runner).execute.build }

      shared_examples 'returns a build' do |runners_minutes_used|
        before do
          project.namespace.create_namespace_statistics(
            shared_runners_seconds: runners_minutes_used * 60)
        end

        it { is_expected.to be_kind_of(Ci::Build) }
      end

      shared_examples 'does not return a build' do |runners_minutes_used|
        before do
          project.namespace.create_namespace_statistics(
            shared_runners_seconds: runners_minutes_used * 60)
        end

        it { is_expected.to be_nil }
      end

      context 'when limit set at global level' do
        before do
          stub_application_setting(shared_runners_minutes: 10)
        end

        context 'and usage is below the limit' do
          it_behaves_like 'returns a build', 9
        end

        context 'and usage is above the limit' do
          it_behaves_like 'does not return a build', 11

          context 'and project is public' do
            before do
              project.update(visibility_level: Project::PUBLIC)
            end

            it_behaves_like 'returns a build', 11
          end
        end

        context 'and extra shared runners minutes purchased' do
          before do
            project.namespace.update(extra_shared_runners_minutes_limit: 10)
          end

          context 'and usage is below the combined limit' do
            it_behaves_like 'returns a build', 19
          end

          context 'and usage is above the combined limit' do
            it_behaves_like 'does not return a build', 21
          end
        end
      end

      context 'when limit set at namespace level' do
        before do
          project.namespace.update(shared_runners_minutes_limit: 5)
        end

        context 'and limit set to unlimited' do
          before do
            project.namespace.update(shared_runners_minutes_limit: 0)
          end

          it_behaves_like 'returns a build', 10
        end

        context 'and usage is below the limit' do
          it_behaves_like 'returns a build', 4
        end

        context 'and usage is above the limit' do
          it_behaves_like 'does not return a build', 6
        end

        context 'and extra shared runners minutes purchased' do
          before do
            project.namespace.update(extra_shared_runners_minutes_limit: 5)
          end

          context 'and usage is below the combined limit' do
            it_behaves_like 'returns a build', 9
          end

          context 'and usage is above the combined limit' do
            it_behaves_like 'does not return a build', 11
          end
        end
      end

      context 'when limit set at global and namespace level' do
        context 'and namespace limit lower than global limit' do
          before do
            stub_application_setting(shared_runners_minutes: 10)
            project.namespace.update(shared_runners_minutes_limit: 5)
          end

          it_behaves_like 'does not return a build', 6
        end

        context 'and namespace limit higher than global limit' do
          before do
            stub_application_setting(shared_runners_minutes: 5)
            project.namespace.update(shared_runners_minutes_limit: 10)
          end

          it_behaves_like 'returns a build', 6
        end
      end

      context 'when group is subgroup' do
        let!(:root_ancestor) { create(:group) }
        let!(:group) { create(:group, parent: root_ancestor) }
        let!(:project) { create :project, shared_runners_enabled: true, group: group }

        context 'and usage below the limit on root namespace' do
          before do
            root_ancestor.update(shared_runners_minutes_limit: 10)
          end

          it_behaves_like 'returns a build', 9
        end

        context 'and usage above the limit on root namespace' do
          before do
            # limit is ignored on subnamespace
            group.update(shared_runners_minutes_limit: 20)

            root_ancestor.update(shared_runners_minutes_limit: 10)
            root_ancestor.create_namespace_statistics(
              shared_runners_seconds: 60 * 11)
          end

          it_behaves_like 'does not return a build', 11
        end
      end
    end
  end
end
