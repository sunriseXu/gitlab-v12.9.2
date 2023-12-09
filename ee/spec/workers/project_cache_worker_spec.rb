# frozen_string_literal: true

require 'spec_helper'

describe ProjectCacheWorker do
  let(:worker) { described_class.new }
  let(:project) { create(:project, :repository) }

  describe '#perform' do
    context 'with an existing project' do
      context 'when in Geo secondary node' do
        before do
          allow(Gitlab::Geo).to receive(:secondary?).and_return(true)
        end

        it 'updates only non database cache' do
          expect(worker).to receive(:perform_geo_secondary).and_call_original
          expect_any_instance_of(Repository).to receive(:refresh_method_caches)
            .and_call_original

          expect_any_instance_of(Project).not_to receive(:update_repository_size)
          expect_any_instance_of(Project).not_to receive(:update_commit_count)

          worker.perform(project.id, %w(readme))
        end
      end
    end
  end
end
