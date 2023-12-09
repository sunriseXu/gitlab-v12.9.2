# frozen_string_literal: true

require 'spec_helper'

describe SessionsController, :geo do
  include DeviseHelpers
  include EE::GeoHelpers

  before do
    set_devise_mapping(context: @request)
  end

  describe '#new' do
    context 'on a Geo secondary node' do
      let_it_be(:primary_node) { create(:geo_node, :primary) }
      let_it_be(:secondary_node) { create(:geo_node) }

      before do
        stub_current_geo_node(secondary_node)
      end

      shared_examples 'a valid oauth authentication redirect' do
        it 'redirects to the correct oauth_geo_auth_url' do
          get(:new)

          redirect_uri = URI.parse(response.location)
          redirect_params = CGI.parse(redirect_uri.query)

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to %r(\A#{Gitlab.config.gitlab.url}/oauth/geo/auth)
          expect(redirect_params['state'].first).to end_with(':')
        end
      end

      context 'with a tampered HOST header' do
        before do
          request.headers['HOST'] = 'http://this.is.not.my.host'
        end

        it_behaves_like 'a valid oauth authentication redirect'
      end

      context 'with a tampered X-Forwarded-Host header' do
        before do
          request.headers['X-Forwarded-Host'] = 'http://this.is.not.my.host'
        end

        it_behaves_like 'a valid oauth authentication redirect'
      end

      context 'without a tampered header' do
        it_behaves_like 'a valid oauth authentication redirect'
      end
    end
  end

  describe '#create' do
    before do
      allow(::Gitlab).to receive(:com?).and_return(true)
    end

    context 'with wrong credentials' do
      context 'when is a trial form' do
        it 'redirects to new trial sign in page' do
          post :create, params: { trial: true, user: { login: 'foo@bar.com', password: '11111' } }

          expect(response).to render_template("trial_registrations/new")
        end
      end

      context 'when is a regular form' do
        it 'redirects to the regular sign in page' do
          post :create, params: { user: { login: 'foo@bar.com', password: '11111' } }

          expect(response).to render_template("devise/sessions/new")
        end
      end
    end
  end
end
