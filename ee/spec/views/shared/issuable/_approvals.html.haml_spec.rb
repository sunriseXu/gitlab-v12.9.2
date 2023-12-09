# frozen_string_literal: true

require 'spec_helper'

describe 'shared/issuable/_approvals.html.haml' do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository) }
  let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let(:presenter) { merge_request.present(current_user: user) }
  let(:approver_presenter) { double(any?: false, show_code_owner_tips?: true) }
  let(:form) { double('form') }

  before do
    allow(view).to receive(:can?).and_return(true)
    allow(view).to receive(:current_user).and_return(user)
    allow(form).to receive(:label)
    allow(form).to receive(:number_field)
    allow(MergeRequestApproverPresenter).to receive(:new).and_return(approver_presenter)
    assign(:project, project)
    assign(:target_project, project)
    assign(:mr_presenter, merge_request.present(current_user: user))
  end

  context 'has no approvers' do
    context 'can override approvers' do
      before do
        render 'shared/issuable/approvals', form: form, issuable: merge_request, presenter: presenter
      end

      it 'shows suggested approvers' do
        expect(rendered).to have_css('.suggested-approvers')
      end
    end

    context 'can not override approvers' do
      before do
        allow(view).to receive(:can?).with(user, :update_approvers, merge_request).and_return(false)
        render 'shared/issuable/approvals', form: form, issuable: merge_request, presenter: presenter
      end

      it 'hides suggested approvers' do
        expect(rendered).not_to have_css('.suggested-approvers')
      end

      it 'hides select approvers field' do
        expect(rendered).not_to have_css('#merge_request_approver_ids')
      end

      it 'hides select approver groups field' do
        expect(rendered).not_to have_css('#merge_request_approver_group_ids')
      end
    end
  end

  context 'has approvers' do
    let(:user) { create(:user) }
    let(:approver) { create(:approver, user: user, target: merge_request) }
    let(:approver_group) { create(:approver_group, target: merge_request) }

    before do
      assign(:approver, approver)
      assign(:approver_group, approver_group)
      assign(:presenter, merge_request.present(current_user: user))
    end

    it 'shows approver in table' do
      render 'shared/issuable/approvals', form: form, issuable: merge_request, project: project, presenter: presenter

      expect(rendered).to have_text(approver[:name])
      expect(rendered).to have_text(approver_group[:name])
    end

    context 'can not override approvers' do
      it 'hides remove button' do
        allow(view).to receive(:can?).with(user, :update_approvers, merge_request).and_return(false)

        render 'shared/issuable/approvals', form: form, issuable: merge_request, presenter: presenter

        expect(rendered).not_to have_css('.btn-remove')
      end
    end
  end
end
