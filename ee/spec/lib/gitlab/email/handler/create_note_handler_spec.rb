# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Email::Handler::CreateNoteHandler do
  include_context :email_shared_context

  before do
    stub_incoming_email_setting(enabled: true, address: "reply+%{key}@appmail.adventuretime.ooo")
    stub_config_setting(host: 'localhost')
    stub_licensed_features(epics: true)
  end

  let(:email_raw) { fixture_file('emails/valid_reply.eml') }
  let(:group) { create(:group_with_members) }
  let(:user) { group.users.first }
  let(:noteable) { create(:epic, group: group) }
  let(:note) { create(:note, project: nil, noteable: noteable)}

  let!(:sent_notification) do
    SentNotification.record_note(note, user.id, mail_key)
  end

  context "when the note could not be saved" do
    before do
      allow_next_instance_of(Note) do |instance|
        allow(instance).to receive(:persisted?).and_return(false)
      end
    end

    it "raises an InvalidNoteError" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::InvalidNoteError)
    end
  end

  context 'when the note contains quick actions' do
    let!(:email_raw) { fixture_file("emails/commands_in_reply.eml") }

    context 'and current user cannot update the noteable' do
      it 'only executes the commands that the user can perform' do
        expect { receiver.execute }
          .to change { noteable.notes.user.count }.by(1)
      end
    end

    context 'and current user can update noteable' do
      before do
        group.add_developer(user)
      end

      it 'posts a note and updates the noteable' do
        expect(TodoService.new.todo_exist?(noteable, user)).to be_falsy

        expect { receiver.execute }
          .to change { noteable.notes.user.count }.by(1)
      end
    end
  end

  context "when the reply is blank" do
    let!(:email_raw) { fixture_file("emails/no_content_reply.eml") }

    it "raises an EmptyEmailError" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::EmptyEmailError)
    end
  end

  context "when everything is fine" do
    before do
      setup_attachment
    end

    it "creates a comment" do
      expect { receiver.execute }.to change { noteable.notes.count }.by(1)
      new_note = noteable.notes.last

      expect(new_note.author).to eq(sent_notification.recipient)
      expect(new_note.position).to eq(note.position)
      expect(new_note.note).to include("I could not disagree more.")
      expect(new_note.in_reply_to?(note)).to be_truthy
    end

    it "adds all attachments" do
      expect_next_instance_of(Gitlab::Email::AttachmentUploader) do |uploader|
        expect(uploader).to receive(:execute).with(upload_parent: group, uploader_class: NamespaceFileUploader).and_return(
          [
            {
              url: "uploads/image.png",
              alt: "image",
              markdown: markdown
            }
          ]
        )
      end

      receiver.execute

      note = noteable.notes.last
      expect(note.note).to include(markdown)
    end

    context 'when sub-addressing is not supported' do
      before do
        stub_incoming_email_setting(enabled: true, address: nil)
      end

      shared_examples 'an email that contains a mail key' do |header|
        it "fetches the mail key from the #{header} header and creates a comment" do
          expect { receiver.execute }.to change { noteable.notes.count }.by(1)
          new_note = noteable.notes.last

          expect(new_note.author).to eq(sent_notification.recipient)
          expect(new_note.position).to eq(note.position)
          expect(new_note.note).to include('I could not disagree more.')
        end
      end

      context 'mail key is in the References header' do
        let(:email_raw) { fixture_file('emails/reply_without_subaddressing_and_key_inside_references.eml') }

        it_behaves_like 'an email that contains a mail key', 'References'
      end

      context 'mail key is in the References header with a comma' do
        let(:email_raw) { fixture_file('emails/reply_without_subaddressing_and_key_inside_references_with_a_comma.eml') }

        it_behaves_like 'an email that contains a mail key', 'References'
      end
    end
  end

  context 'when the service desk' do
    let(:project) { create(:project, :public, service_desk_enabled: true) }
    let(:support_bot) { User.support_bot }
    let(:noteable) { create(:issue, project: project, author: support_bot, title: 'service desk issue') }
    let(:note) { create(:note, project: project, noteable: noteable) }
    let(:email_raw) { fixture_file('emails/valid_reply_with_quick_actions.eml', dir: 'ee') }

    let!(:sent_notification) do
      SentNotification.record_note(note, support_bot.id, mail_key)
    end

    context 'is enabled' do
      before do
        allow(::EE::Gitlab::ServiceDesk).to receive(:enabled?).and_return(true)
        allow(::EE::Gitlab::ServiceDesk).to receive(:enabled?).with(project: project).and_return(true)
        project.project_feature.update!(issues_access_level: issues_access_level)
      end

      context 'when issues are enabled for everyone' do
        let(:issues_access_level) { ProjectFeature::ENABLED }

        it 'creates a comment' do
          expect { receiver.execute }.to change { noteable.notes.count }.by(1)
        end

        context 'when quick actions are present' do
          it 'encloses quick actions with code span markdown' do
            receiver.execute
            noteable.reload

            note = Note.last
            expect(note.note).to include("Jake out\n\n`/close`\n`/title test`")
            expect(noteable.title).to eq('service desk issue')
            expect(noteable).to be_opened
          end
        end
      end

      context 'when issues are protected members only' do
        let(:issues_access_level) { ProjectFeature::PRIVATE }

        it 'creates a comment' do
          expect { receiver.execute }.to change { noteable.notes.count }.by(1)
        end
      end

      context 'when issues are disabled' do
        let(:issues_access_level) { ProjectFeature::DISABLED }

        it 'does not create a comment' do
          expect { receiver.execute }.to raise_error(::Gitlab::Email::UserNotAuthorizedError)
        end
      end
    end

    context 'is disabled' do
      before do
        allow(::EE::Gitlab::ServiceDesk).to receive(:enabled?).and_return(false)
        allow(::EE::Gitlab::ServiceDesk).to receive(:enabled?).with(project: project).and_return(false)
      end

      it 'does not create a comment' do
        expect { receiver.execute }.to raise_error(::Gitlab::Email::ProjectNotFound)
      end
    end
  end
end
