# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20191022113635_nullify_feature_flag_plaintext_tokens.rb')

describe NullifyFeatureFlagPlaintextTokens do
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:feature_flags_clients) { table(:operations_feature_flags_clients) }

  let!(:namespace) { namespaces.create!(id: 11, name: 'gitlab', path: 'gitlab-org') }
  let!(:project1) { projects.create!(namespace_id: namespace.id, name: 'Project 1') }
  let!(:project2) { projects.create!(namespace_id: namespace.id, name: 'Project 2') }

  let(:secret1_encrypted) { Gitlab::CryptoHelper.aes256_gcm_encrypt('secret1') }
  let(:secret2_encrypted) { Gitlab::CryptoHelper.aes256_gcm_encrypt('secret2') }

  before do
    feature_flags_clients.create!(token: 'secret1', token_encrypted: secret1_encrypted, project_id: project1.id)
    feature_flags_clients.create!(token: nil, token_encrypted: secret2_encrypted, project_id: project2.id)
  end

  it 'correctly migrates up and down' do
    feature_flag1 = feature_flags_clients.find_by_project_id(project1.id)
    feature_flag2 = feature_flags_clients.find_by_project_id(project2.id)

    reversible_migration do |migration|
      migration.before -> {
        feature_flag1.reload
        expect(feature_flag1.token).to eq('secret1')
        expect(feature_flag1.token_encrypted).to eq(secret1_encrypted)

        feature_flag2.reload
        expect(feature_flag2.token_encrypted).to eq(secret2_encrypted)
      }

      migration.after -> {
        expect(feature_flags_clients.where('token IS NOT NULL').count).to eq(0)

        feature_flag1.reload
        expect(feature_flag1.token).to be_nil
        expect(feature_flag1.token_encrypted).to eq(secret1_encrypted)

        feature_flag2.reload
        expect(feature_flag2.token).to be_nil
        expect(feature_flag2.token_encrypted).to eq(secret2_encrypted)
      }
    end
  end
end
