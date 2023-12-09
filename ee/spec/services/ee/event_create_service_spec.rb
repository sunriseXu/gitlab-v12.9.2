# frozen_string_literal: true

require 'spec_helper'

describe EventCreateService do
  let(:service) { described_class.new }

  describe 'Epics' do
    let(:epic) { create(:epic) }

    describe '#open_epic' do
      it "creates new event" do
        event = service.open_epic(epic, epic.author)

        expect_event(event, Event::CREATED)
      end
    end

    describe '#close_epic' do
      it "creates new event" do
        event = service.close_epic(epic, epic.author)

        expect_event(event, Event::CLOSED)
      end
    end

    describe '#reopen_epic' do
      it "creates new event" do
        event = service.reopen_epic(epic, epic.author)

        expect_event(event, Event::REOPENED)
      end
    end

    describe '#leave_note' do
      it "creates new event" do
        note = create(:note, noteable: epic)

        event = service.leave_note(note, epic.author)

        expect_event(event, Event::COMMENTED)
      end
    end

    def expect_event(event, action)
      expect(event).to be_persisted
      expect(event.action).to eq action
      expect(event.project_id).to be_nil
      expect(event.group_id).to eq epic.group_id
    end
  end
end
