# frozen_string_literal: true

require 'spec_helper'

describe RepositoryImportWorker do
  let(:project) { create(:project, :import_scheduled) }

  it 'updates the error on custom project template Import/Export' do
    stub_licensed_features(custom_project_templates: true)
    error = %q{remote: Not Found fatal: repository 'https://user:pass@test.com/root/repoC.git/' not found }

    project.update(import_type: 'gitlab_custom_project_template')
    project.import_state.update(jid: '123')
    expect_any_instance_of(Projects::ImportService).to receive(:execute).and_return({ status: :error, message: error })

    expect do
      subject.perform(project.id)
    end.to raise_error(RuntimeError, error)

    expect(project.import_state.reload.last_error).not_to be_nil
  end

  context 'when project is a mirror' do
    let(:project) { create(:project, :mirror, :import_scheduled) }

    it 'adds mirror in front of the mirror scheduler queue' do
      expect_any_instance_of(Projects::ImportService).to receive(:execute)
        .and_return({ status: :ok })

      expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!)

      subject.perform(project.id)
    end
  end
end
