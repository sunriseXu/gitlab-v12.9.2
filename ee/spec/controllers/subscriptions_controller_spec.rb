# frozen_string_literal: true

require 'spec_helper'

describe SubscriptionsController do
  let_it_be(:user) { create(:user) }

  describe 'GET #new' do
    subject { get :new, params: { plan_id: 'bronze_id' } }

    context 'with experiment enabled' do
      before do
        stub_experiment(paid_signup_flow: true)
        stub_experiment_for_user(paid_signup_flow: true)
      end

      context 'with unauthenticated user' do
        it { is_expected.to have_gitlab_http_status(:redirect) }
        it { is_expected.to redirect_to new_user_registration_path(redirect_from: 'checkout') }

        it 'stores subscription URL for later' do
          subject

          expected_subscription_path = new_subscriptions_path(experiment_started: true, plan_id: 'bronze_id')

          expect(controller.stored_location_for(:user)).to eq(expected_subscription_path)
        end

        it 'tracks the event when experiment starts' do
          expect(Gitlab::Tracking).to receive(:event).with('Growth::Acquisition::Experiment::PaidSignUpFlow', 'start_experiment', label: nil, value: nil)

          subject
        end

        it 'does not track event when user got redirected to the subscription page again' do
          get :new, params: { plan_id: 'bronze_id', experiment_started: 'true' }

          expect(Gitlab::Tracking).not_to receive(:event).with('Growth::Acquisition::Experiment::PaidSignUpFlow', 'start_experiment', label: nil, value: nil)
        end
      end

      context 'with authenticated user' do
        before do
          sign_in(user)
        end

        it { is_expected.to render_template 'layouts/checkout' }
        it { is_expected.to render_template :new }

        it 'tracks the event with the right parameters' do
          expect(Gitlab::Tracking).to receive(:event).with('Growth::Acquisition::Experiment::PaidSignUpFlow', 'start_experiment', label: nil, value: nil)
          expect(Gitlab::Tracking).to receive(:event).with('Growth::Acquisition::Experiment::PaidSignUpFlow', 'start', label: nil, value: nil)

          subject
        end
      end
    end

    context 'with experiment disabled' do
      before do
        stub_experiment(paid_signup_flow: false)
        stub_experiment_for_user(paid_signup_flow: false)
      end

      it { is_expected.to redirect_to "#{EE::SUBSCRIPTIONS_URL}/subscriptions/new?plan_id=bronze_id&transaction=create_subscription" }
    end
  end

  describe 'GET #payment_form' do
    subject { get :payment_form, params: { id: 'cc' } }

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to new_user_session_path }
    end

    context 'with authorized user' do
      before do
        sign_in(user)
        client_response = { success: true, data: { signature: 'x', token: 'y' } }
        allow(Gitlab::SubscriptionPortal::Client).to receive(:payment_form_params).with('cc').and_return(client_response)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'returns the data attribute of the client response in JSON format' do
        subject
        expect(response.body).to eq('{"signature":"x","token":"y"}')
      end
    end
  end

  describe 'GET #payment_method' do
    subject { get :payment_method, params: { id: 'xx' } }

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to new_user_session_path }
    end

    context 'with authorized user' do
      before do
        sign_in(user)
        client_response = { success: true, data: { credit_card_type: 'Visa' } }
        allow(Gitlab::SubscriptionPortal::Client).to receive(:payment_method).with('xx').and_return(client_response)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'returns the data attribute of the client response in JSON format' do
        subject
        expect(response.body).to eq('{"credit_card_type":"Visa"}')
      end
    end
  end

  describe 'POST #create' do
    subject do
      post :create,
        params: params,
        as: :json
    end

    let(:params) do
      {
        setup_for_company: setup_for_company,
        customer: { company: 'My company', country: 'NL' },
        subscription: { plan_id: 'x', quantity: 2 }
      }
    end

    let(:setup_for_company) { true }

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:unauthorized) }
    end

    context 'with authorized user' do
      let_it_be(:service_response) { { success: true, data: 'foo' } }
      let_it_be(:group) { create(:group) }

      before do
        sign_in(user)
        allow_any_instance_of(Subscriptions::CreateService).to receive(:execute).and_return(service_response)
        allow_any_instance_of(EE::Groups::CreateService).to receive(:execute).and_return(group)
      end

      context 'when setting up for a company' do
        it 'updates the setup_for_company attribute of the current user' do
          expect { subject }.to change { user.reload.setup_for_company }.from(nil).to(true)
        end

        it 'tracks the event with the right parameters' do
          expect(Gitlab::Tracking).to receive(:event).with(
            'Growth::Acquisition::Experiment::PaidSignUpFlow',
            'end',
            label: 'x',
            value: 2
          )

          subject
        end
      end

      context 'when not setting up for a company' do
        let(:params) do
          {
            setup_for_company: setup_for_company,
            customer: { country: 'NL' },
            subscription: { plan_id: 'x', quantity: 1 }
          }
        end

        let(:setup_for_company) { false }

        it 'does not update the setup_for_company attribute of the current user' do
          expect { subject }.not_to change { user.reload.setup_for_company }
        end

        it 'tracks the event with the right parameters' do
          expect(Gitlab::Tracking).to receive(:event).with(
            'Growth::Acquisition::Experiment::PaidSignUpFlow',
            'end',
            label: 'x',
            value: 1
          )

          subject
        end
      end

      it 'creates a group' do
        expect_any_instance_of(EE::Groups::CreateService).to receive(:execute)

        subject
      end

      context 'when an error occurs creating a group' do
        let(:group) { Group.new(path: 'foo') }

        it 'returns the errors in json format' do
          group.save
          subject

          expect(response.body).to include({ name: ["can't be blank", Gitlab::Regex.group_name_regex_message] }.to_json)
        end
      end

      context 'on successful creation of a subscription' do
        it { is_expected.to have_gitlab_http_status(:ok) }

        it 'returns the group edit location in JSON format' do
          subject

          expected_response = {
            location: "/-/subscriptions/groups/#{group.path}/edit?plan_id=x&quantity=2",
            plan_id: 'x',
            quantity: 2
          }

          expect(response.body).to eq(expected_response.to_json)
        end
      end

      context 'on unsuccessful creation of a subscription' do
        let(:service_response) { { success: false, data: { errors: 'error message' } } }

        it { is_expected.to have_gitlab_http_status(:ok) }

        it 'returns the error message in JSON format' do
          subject

          expect(response.body).to eq('{"errors":"error message"}')
        end
      end

      context 'when selecting an existing group' do
        let_it_be(:selected_group) { create(:group) }
        let(:params) do
          {
            selected_group: selected_group.id,
            customer: { country: 'NL' },
            subscription: { plan_id: 'x', quantity: 1 }
          }
        end

        before do
          selected_group.add_owner(user)
        end

        it 'does not create a group' do
          expect { subject }.to not_change { Group.count }
        end

        it 'returns the selected group location in JSON format' do
          subject

          expected_response = {
            location: "/#{selected_group.path}",
            plan_id: 'x',
            quantity: 1
          }

          expect(response.body).to eq(expected_response.to_json)
        end
      end

      context 'when selecting a non existing group' do
        let(:params) do
          {
            selected_group: 999,
            customer: { country: 'NL' },
            subscription: { plan_id: 'x', quantity: 1 }
          }
        end

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end
    end
  end
end
