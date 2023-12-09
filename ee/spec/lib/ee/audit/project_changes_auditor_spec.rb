# frozen_string_literal: true

require 'spec_helper'

describe EE::Audit::ProjectChangesAuditor do
  describe '.audit_changes' do
    let(:user) { create(:user) }
    let(:project) do
      create(
        :project,
        visibility_level: 0,
        name: 'interesting name',
        path: 'interesting-path',
        repository_size_limit: 10,
        packages_enabled: true,
        merge_requests_author_approval: false,
        merge_requests_disable_committers_approval: true
      )
    end

    subject(:foo_instance) { described_class.new(user, project) }

    before do
      project.reload
      stub_licensed_features(extended_audit_events: true)
    end

    describe 'non audit changes' do
      it 'does not call the audit event service' do
        project.update!(description: 'new description')

        expect { foo_instance.execute }.not_to change { SecurityEvent.count }
      end
    end

    describe 'audit changes' do
      it 'creates an event when the visibility change' do
        project.update!(visibility_level: 20)

        expect { foo_instance.execute }.to change { SecurityEvent.count }.by(1)
        expect(SecurityEvent.last.details[:change]).to eq 'visibility'
      end

      it 'creates an event when the name change' do
        project.update!(name: 'new name')

        expect { foo_instance.execute }.to change { SecurityEvent.count }.by(1)
        expect(SecurityEvent.last.details[:change]).to eq 'name'
      end

      it 'creates an event when the path change' do
        project.update!(path: 'newpath')

        expect { foo_instance.execute }.to change { SecurityEvent.count }.by(1)
        expect(SecurityEvent.last.details[:change]).to eq 'path'
      end

      it 'creates an event when the namespace change' do
        new_namespace = create(:namespace)

        project.update!(namespace: new_namespace)

        expect { foo_instance.execute }.to change { SecurityEvent.count }.by(1)
        expect(SecurityEvent.last.details[:change]).to eq 'namespace'
      end

      it 'creates an event when the repository size limit changes' do
        project.update!(repository_size_limit: 100)

        expect { foo_instance.execute }.to change { SecurityEvent.count }.by(1)
        expect(SecurityEvent.last.details[:change]).to eq 'repository_size_limit'
      end

      it 'creates an event when the packages enabled setting changes' do
        project.update!(packages_enabled: false)

        expect { foo_instance.execute }.to change { SecurityEvent.count }.by(1)
        expect(SecurityEvent.last.details[:change]).to eq 'packages_enabled'
      end

      it 'creates an event when the merge requests author approval changes' do
        project.update!(merge_requests_author_approval: true)

        aggregate_failures do
          expect { foo_instance.execute }.to change { SecurityEvent.count }.by(1)
          expect(SecurityEvent.last.details).to include(
            change: 'prevent merge request approval from authors',
            from: true,
            to: false
          )
        end
      end

      it 'creates an event when the merge requests committers approval changes' do
        project.update!(merge_requests_disable_committers_approval: false)

        aggregate_failures do
          expect { foo_instance.execute }.to change { SecurityEvent.count }.by(1)
          expect(SecurityEvent.last.details).to include(
            change: 'prevent merge request approval from reviewers',
            from: true,
            to: false
          )
        end
      end
    end
  end
end
