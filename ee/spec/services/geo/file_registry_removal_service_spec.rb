# frozen_string_literal: true

require 'spec_helper'

describe Geo::FileRegistryRemovalService do
  include ::EE::GeoHelpers
  include ExclusiveLeaseHelpers

  let_it_be(:secondary) { create(:geo_node) }

  before do
    stub_current_geo_node(secondary)
  end

  describe '#execute' do
    it 'delegates log_error to the Geo logger' do
      stub_exclusive_lease_taken("file_registry_removal_service:lfs:99")

      expect(Gitlab::Geo::Logger).to receive(:error)

      described_class.new(:lfs, 99).execute
    end

    shared_examples 'removes' do
      subject(:service) { described_class.new(registry.file_type, registry.file_id) }

      before do
        stub_exclusive_lease("file_registry_removal_service:#{registry.file_type}:#{registry.file_id}",
          timeout: Geo::FileRegistryRemovalService::LEASE_TIMEOUT)
      end

      it 'file from disk' do
        expect do
          service.execute
        end.to change { File.exist?(file_path) }.from(true).to(false)
      end

      it 'registry when file was deleted successfully' do
        expect do
          service.execute
        end.to change(Geo::UploadRegistry, :count).by(-1)
      end
    end

    shared_examples 'removes artifact' do
      subject(:service) { described_class.new('job_artifact', registry.artifact_id) }

      before do
        stub_exclusive_lease("file_registry_removal_service:job_artifact:#{registry.artifact_id}",
          timeout: Geo::FileRegistryRemovalService::LEASE_TIMEOUT)
      end

      it 'file from disk' do
        expect do
          service.execute
        end.to change { File.exist?(file_path) }.from(true).to(false)
      end

      it 'registry when file was deleted successfully' do
        expect do
          service.execute
        end.to change(Geo::JobArtifactRegistry, :count).by(-1)
      end
    end

    shared_examples 'removes LFS object' do
      subject(:service) { described_class.new('lfs', registry.lfs_object_id) }

      before do
        stub_exclusive_lease("file_registry_removal_service:lfs:#{registry.lfs_object_id}",
          timeout: Geo::FileRegistryRemovalService::LEASE_TIMEOUT)
      end

      it 'file from disk' do
        expect do
          service.execute
        end.to change { File.exist?(file_path) }.from(true).to(false)
      end

      it 'registry when file was deleted successfully' do
        expect do
          service.execute
        end.to change(Geo::LfsObjectRegistry, :count).by(-1)
      end
    end

    context 'with LFS object' do
      let!(:lfs_object) { create(:lfs_object, :with_file) }
      let!(:registry) { create(:geo_lfs_object_registry, lfs_object_id: lfs_object.id) }
      let!(:file_path) { lfs_object.file.path }

      it_behaves_like 'removes LFS object'

      context 'migrated to object storage' do
        before do
          stub_lfs_object_storage
          lfs_object.update_column(:file_store, LfsObjectUploader::Store::REMOTE)
        end

        it_behaves_like 'removes LFS object'
      end

      context 'no lfs_object record' do
        before do
          lfs_object.delete
        end

        it_behaves_like 'removes LFS object' do
          subject(:service) { described_class.new('lfs', registry.lfs_object_id, file_path) }
        end
      end
    end

    context 'with job artifact' do
      let!(:job_artifact) { create(:ci_job_artifact, :archive) }
      let!(:registry) { create(:geo_job_artifact_registry, artifact_id: job_artifact.id) }
      let!(:file_path) { job_artifact.file.path }

      it_behaves_like 'removes artifact'

      context 'migrated to object storage' do
        before do
          stub_artifacts_object_storage
          job_artifact.update_column(:file_store, JobArtifactUploader::Store::REMOTE)
        end

        it_behaves_like 'removes artifact'
      end

      context 'no job artifact record' do
        before do
          job_artifact.delete
        end

        it_behaves_like 'removes artifact' do
          subject(:service) { described_class.new('job_artifact', registry.artifact_id, file_path) }
        end
      end
    end

    context 'with avatar' do
      let!(:upload) { create(:user, :with_avatar).avatar.upload }
      let!(:registry) { create(:geo_upload_registry, :avatar, file_id: upload.id) }
      let!(:file_path) { upload.retrieve_uploader.file.path }

      it_behaves_like 'removes'

      context 'migrated to object storage' do
        before do
          stub_uploads_object_storage(AvatarUploader)
          upload.update_column(:store, AvatarUploader::Store::REMOTE)
        end

        it_behaves_like 'removes'
      end
    end

    context 'with attachment' do
      let!(:upload) { create(:note, :with_attachment).attachment.upload }
      let!(:registry) { create(:geo_upload_registry, :attachment, file_id: upload.id) }
      let!(:file_path) { upload.retrieve_uploader.file.path }

      it_behaves_like 'removes'

      context 'migrated to object storage' do
        before do
          stub_uploads_object_storage(AttachmentUploader)
          upload.update_column(:store, AttachmentUploader::Store::REMOTE)
        end

        it_behaves_like 'removes'
      end
    end

    context 'with file' do
      let!(:upload) { create(:user, :with_avatar).avatar.upload }
      let!(:registry) { create(:geo_upload_registry, :avatar, file_id: upload.id) }
      let!(:file_path) { upload.retrieve_uploader.file.path }

      it_behaves_like 'removes'

      context 'migrated to object storage' do
        before do
          stub_uploads_object_storage(AvatarUploader)
          upload.update_column(:store, AvatarUploader::Store::REMOTE)
        end

        it_behaves_like 'removes'
      end
    end

    context 'with namespace_file' do
      let_it_be(:group) { create(:group) }
      let(:file) { fixture_file_upload('spec/fixtures/dk.png', 'image/png') }
      let!(:upload) do
        NamespaceFileUploader.new(group).store!(file)
        Upload.find_by(model: group, uploader: NamespaceFileUploader.name)
      end

      let!(:registry) { create(:geo_upload_registry, :namespace_file, file_id: upload.id) }
      let!(:file_path) { upload.retrieve_uploader.file.path }

      it_behaves_like 'removes'

      context 'migrated to object storage' do
        before do
          stub_uploads_object_storage(NamespaceFileUploader)
          upload.update_column(:store, NamespaceFileUploader::Store::REMOTE)
        end

        it_behaves_like 'removes'
      end
    end

    context 'with personal_file' do
      let(:snippet) { create(:personal_snippet) }
      let(:file) { fixture_file_upload('spec/fixtures/dk.png', 'image/png') }
      let!(:upload) do
        PersonalFileUploader.new(snippet).store!(file)
        Upload.find_by(model: snippet, uploader: PersonalFileUploader.name)
      end
      let!(:registry) { create(:geo_upload_registry, :personal_file, file_id: upload.id) }
      let!(:file_path) { upload.retrieve_uploader.file.path }

      it_behaves_like 'removes'

      context 'migrated to object storage' do
        before do
          stub_uploads_object_storage(PersonalFileUploader)
          upload.update_column(:store, PersonalFileUploader::Store::REMOTE)
        end

        it_behaves_like 'removes'
      end
    end

    context 'with favicon' do
      let(:appearance) { create(:appearance) }
      let(:file) { fixture_file_upload('spec/fixtures/dk.png', 'image/png') }
      let!(:upload) do
        FaviconUploader.new(appearance).store!(file)
        Upload.find_by(model: appearance, uploader: FaviconUploader.name)
      end
      let!(:registry) { create(:geo_upload_registry, :favicon, file_id: upload.id) }
      let!(:file_path) { upload.retrieve_uploader.file.path }

      it_behaves_like 'removes'

      context 'migrated to object storage' do
        before do
          stub_uploads_object_storage(FaviconUploader)
          upload.update_column(:store, PersonalFileUploader::Store::REMOTE)
        end

        it_behaves_like 'removes'
      end
    end
  end
end
