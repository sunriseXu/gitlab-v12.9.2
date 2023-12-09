# frozen_string_literal: true

require 'spec_helper'

describe GitlabSlackApplicationService do
  describe '#chat_responder' do
    it 'returns the chat responder to use' do
      expect(subject.chat_responder).to eq(Gitlab::Chat::Responder::Slack)
    end
  end
end
