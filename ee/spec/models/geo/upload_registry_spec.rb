# frozen_string_literal: true

require 'spec_helper'

describe Geo::UploadRegistry, :geo, :geo_fdw do
  let!(:failed) { create(:geo_upload_registry, :failed) }
  let!(:synced) { create(:geo_upload_registry) }

  it 'finds associated Upload record' do
    registry = create(:geo_upload_registry, :attachment, :with_file)

    expect(described_class.find(registry.id).upload).to be_an_instance_of(Upload)
  end

  describe '.failed' do
    it 'returns registries in the failed state' do
      expect(described_class.failed).to match_ids(failed)
    end
  end

  describe '.synced' do
    it 'returns registries in the synced state' do
      expect(described_class.synced).to match_ids(synced)
    end
  end

  describe '.retry_due' do
    it 'returns registries in the synced state' do
      retry_yesterday = create(:geo_upload_registry, retry_at: Date.yesterday)
      create(:geo_upload_registry, retry_at: Date.tomorrow)

      expect(described_class.retry_due).to match_ids([failed, synced, retry_yesterday])
    end
  end

  describe '.never' do
    it 'returns registries that are never synced' do
      never = create(:geo_upload_registry, retry_count: nil, success: false)

      expect(described_class.never).to match_ids([never])
    end
  end

  describe '.with_status' do
    it 'finds the registries with status "synced"' do
      expect(described_class).to receive(:synced)

      described_class.with_status('synced')
    end

    it 'finds the registries with status "never"' do
      expect(described_class).to receive(:never)

      described_class.with_status('never')
    end
    it 'finds the registries with status "failed"' do
      expect(described_class).to receive(:failed)

      described_class.with_status('failed')
    end
  end

  describe '.with_search' do
    it 'searches registries on path' do
      upload = create(:upload, path: 'uploads/-/system/project/avatar/my-awesome-avatar.png')
      upload_registry = create(:geo_upload_registry, file_id: upload.id, file_type: :avatar)

      expect(described_class.with_search('awesome-avatar')).to match_ids(upload_registry)
    end
  end

  describe '#file' do
    it 'returns the path of the upload of a registry' do
      upload = create(:upload, :with_file)
      registry = create(:geo_upload_registry, :file, file_id: upload.id)

      expect(registry.file).to eq(upload.path)
    end

    it 'return "removed" message when the upload no longer exists' do
      registry = create(:geo_upload_registry, :avatar)

      expect(registry.file).to match(/^Removed avatar with id/)
    end
  end

  describe '#synchronization_state' do
    it 'returns :synced for a successful synced registry' do
      expect(synced.synchronization_state).to eq(:synced)
    end

    it 'returns :never for a successful registry never synced' do
      never = build(:geo_upload_registry, success: false, retry_count: nil)

      expect(never.synchronization_state).to eq(:never)
    end

    it 'returns :failed for a failed registry' do
      expect(failed.synchronization_state).to eq(:failed)
    end
  end
end
