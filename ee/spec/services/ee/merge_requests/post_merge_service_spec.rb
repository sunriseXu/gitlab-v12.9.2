# frozen_string_literal: true

require 'spec_helper'

describe MergeRequests::PostMergeService do
  let(:project) { merge_request.target_project }
  let(:merge_request) { create(:merge_request) }
  let(:current_user) { merge_request.author }
  let(:service) { described_class.new(project, current_user) }

  describe '#execute' do
    context 'finalize approvals' do
      let(:finalize_service) { double(:finalize_service) }

      it 'executes ApprovalRules::FinalizeService' do
        expect(ApprovalRules::FinalizeService).to receive(:new).and_return(finalize_service)
        expect(finalize_service).to receive(:execute)

        service.execute(merge_request)
      end
    end
  end
end
