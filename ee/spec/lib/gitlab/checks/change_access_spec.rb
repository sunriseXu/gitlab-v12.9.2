# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Checks::ChangeAccess do
  describe '#exec' do
    include_context 'push rules checks context'

    let(:push_rule) { create(:push_rule, deny_delete_tag: true) }

    subject { change_access }

    it_behaves_like 'check ignored when push rule unlicensed'

    it 'calls push rules validators' do
      expect_next_instance_of(EE::Gitlab::Checks::PushRuleCheck) do |instance|
        expect(instance).to receive(:validate!)
      end

      subject.exec
    end
  end
end
