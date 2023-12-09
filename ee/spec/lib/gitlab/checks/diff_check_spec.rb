# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Checks::DiffCheck do
  include FakeBlobHelpers

  include_context 'push rules checks context'

  describe '#validate!' do
    context 'no push rules active' do
      let_it_be(:push_rule) { create(:push_rule) }

      it "does not attempt to check commits" do
        expect(subject).not_to receive(:process_commits)

        subject.validate!
      end
    end

    describe "#validate_code_owners" do
      let!(:code_owner) { create(:user, username: "owner-1") }
      let(:project) { create(:project, :repository) }
      let(:codeowner_content) { "*.rb @#{code_owner.username}\ndocs/CODEOWNERS @owner-1" }
      let(:codeowner_blob) { fake_blob(path: "CODEOWNERS", data: codeowner_content) }
      let(:codeowner_blob_ref) { fake_blob(path: "CODEOWNERS", data: codeowner_content) }
      let(:codeowner_lookup_ref) { merge_request.target_branch }
      let(:merge_request) do
        build(
          :merge_request,
          source_project: project,
          source_branch: 'feature',
          target_project: project,
          target_branch: 'master'
        )
      end

      before do
        allow(project.repository).to receive(:code_owners_blob)
          .with(ref: codeowner_lookup_ref)
          .and_return(codeowner_blob)
      end

      context "the MR contains a matching file path" do
        let(:validation_result) do
          subject.send(:validate_code_owners).call(["docs/CODEOWNERS", "README"])
        end

        context "and the user is not listed as a code owner" do
          it "returns an error message" do
            expect(validation_result).to include("Pushes to protected branches")
          end
        end

        context "and the user is listed as a code owner" do
          # `user` is set as the owner of the incoming change by the shared
          #   context found in 'push rules checks context'
          let(:codeowner_content) { "* @#{user.username}" }

          it "returns nil" do
            expect(validation_result).to be_nil
          end
        end
      end

      context "the MR doesn't contain a matching file path" do
        it "returns nil" do
          expect(subject.send(:validate_code_owners)
            .call(["docs/SAFE_FILE_NAME", "README"])).to be_nil
        end
      end
    end

    describe "#path_validations" do
      include_context 'change access checks context'

      context "when the feature isn't enabled on the project" do
        before do
          expect(project).to receive(:branch_requires_code_owner_approval?)
            .once.and_return(false)
        end

        it "returns an empty array" do
          expect(subject.send(:path_validations)).to eq([])
        end
      end

      context "when the feature is enabled on the project" do
        context "updated_from_web? == false" do
          before do
            expect(subject).to receive(:updated_from_web?).and_return(false)
            expect(project).to receive(:branch_requires_code_owner_approval?)
              .once.and_return(true)
          end

          it "returns an array of Proc(s)" do
            validations = subject.send(:path_validations)

            expect(validations.any?).to be_truthy
            expect(validations.any? { |v| !v.is_a? Proc }).to be_falsy
          end
        end

        context "updated_from_web? == true" do
          before do
            expect(subject).to receive(:updated_from_web?).and_return(true)
            expect(project).not_to receive(:branch_requires_code_owner_approval?)
          end

          it "returns an empty array" do
            expect(subject.send(:path_validations)).to eq([])
          end
        end
      end
    end

    context 'file name rules' do
      # Notice that the commit used creates a file named 'README'
      context 'file name regex check' do
        let!(:push_rule) { create(:push_rule, file_name_regex: 'READ*') }

        it_behaves_like 'check ignored when push rule unlicensed'

        it "returns an error if a new or renamed filed doesn't match the file name regex" do
          expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "File name README was blacklisted by the pattern READ*.")
        end

        it 'returns an error if the regex is invalid' do
          push_rule.file_name_regex = '+'

          expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, /\ARegular expression '\+' is invalid/)
        end
      end

      context 'blacklisted files check' do
        let(:push_rule) { create(:push_rule, prevent_secrets: true) }

        it_behaves_like 'check ignored when push rule unlicensed'

        it "returns true if there is no blacklisted files" do
          new_rev = nil

          white_listed =
            [
              'readme.txt', 'any/ida_rsa.pub', 'any/id_dsa.pub', 'any_2/id_ed25519.pub',
              'random_file.pdf', 'folder/id_ecdsa.pub', 'docs/aws/credentials.md', 'ending_withhistory'
            ]

          white_listed.each do |file_path|
            old_rev = 'be93687618e4b132087f430a4d8fc3a609c9b77c'
            old_rev = new_rev if new_rev
            new_rev = project.repository.create_file(user, file_path, "commit #{file_path}", message: "commit #{file_path}", branch_name: "master")

            allow(project.repository).to receive(:new_commits).and_return(
              project.repository.commits_between(old_rev, new_rev)
            )

            expect(subject.validate!).to be_truthy
          end
        end

        it "returns an error if a new or renamed filed doesn't match the file name regex" do
          new_rev = nil

          black_listed =
            [
              'aws/credentials', '.ssh/personal_rsa', 'config/server_rsa', '.ssh/id_rsa', '.ssh/id_dsa',
              '.ssh/personal_dsa', 'config/server_ed25519', 'any/id_ed25519', '.ssh/personal_ecdsa', 'config/server_ecdsa',
              'any_place/id_ecdsa', 'some_pLace/file.key', 'other_PlAcE/other_file.pem', 'bye_bug.history', 'pg_sql_history'
            ]

          black_listed.each do |file_path|
            old_rev = 'be93687618e4b132087f430a4d8fc3a609c9b77c'
            old_rev = new_rev if new_rev
            new_rev = project.repository.create_file(user, file_path, "commit #{file_path}", message: "commit #{file_path}", branch_name: "master")

            allow(subject).to receive(:commits).and_return(
              project.repository.commits_between(old_rev, new_rev)
            )

            expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, /File name #{file_path} was blacklisted by the pattern/)
          end
        end
      end
    end

    context 'file lock rules' do
      let(:project) { create(:project, :repository) }
      let(:path_lock) { create(:path_lock, path: 'README', project: project) }

      it 'returns an error if the changes update a path locked by another user' do
        path_lock

        expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "The path 'README' is locked by #{path_lock.user.name}")
      end

      it 'memoizes the validate_path_locks? call' do
        expect(project).to receive(:any_path_locks?).once.and_call_original

        2.times { subject.validate! }
      end

      context 'when the branch is being deleted' do
        let(:newrev) { Gitlab::Git::BLANK_SHA }

        it 'does not run' do
          path_lock

          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'when there is no valid change' do
        let(:changes) { { oldrev: '_any', newrev: nil, ref: nil } }

        it 'does not run' do
          path_lock

          expect { subject.validate! }.not_to raise_error
        end
      end
    end
  end
end
