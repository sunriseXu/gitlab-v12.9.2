# frozen_string_literal: true

require 'spec_helper'

describe Groups::ClustersController do
  include AccessMatchersForController

  let_it_be(:group) { create(:group) }

  let(:user) { create(:user) }

  before do
    group.add_maintainer(user)
    sign_in(user)
  end

  it_behaves_like 'cluster metrics' do
    let(:user) { create(:user) }
    let(:clusterable) { group }

    let(:cluster) do
      create(:cluster, :group, :provided_by_gcp, groups: [group])
    end

    let(:metrics_params) do
      {
        group_id: group,
        id: cluster
      }
    end

    before do
      clusterable.add_maintainer(user)
    end

    context 'with inappropriate requests' do
      context 'with anoymous user' do
        before do
          sign_out(user)
        end

        it 'renders not found' do
          get :prometheus_proxy, params: prometheus_proxy_params

          expect(response).to have_gitlab_http_status(:not_found)
        end

        context 'with invalid clusterable id' do
          before do
            sign_in(user)
          end

          let(:other_clusterable) { create(:group) }

          it 'returns 404' do
            get :prometheus_proxy, params: prometheus_proxy_params(id: other_clusterable.id)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end

    describe 'security' do
      let(:prometheus_adapter) { double(:prometheus_adapter, can_query?: true, query: nil) }

      before do
        sign_in(user)
        allow(controller).to receive(:prometheus_adapter).and_return(prometheus_adapter)
      end

      it { expect { go }.to be_allowed_for(:admin) }
      it { expect { go }.to be_allowed_for(:owner).of(clusterable) }
      it { expect { go }.to be_allowed_for(:maintainer).of(clusterable) }
      it { expect { go }.to be_denied_for(:developer).of(clusterable) }
      it { expect { go }.to be_denied_for(:reporter).of(clusterable) }
      it { expect { go }.to be_denied_for(:guest).of(clusterable) }
      it { expect { go }.to be_denied_for(:user) }
      it { expect { go }.to be_denied_for(:external) }
    end

    describe 'GET #metrics_dashboard' do
      let(:user) { create(:user) }

      before do
        clusterable.add_maintainer(user)
        sign_in(user)
      end

      context 'with license' do
        before do
          stub_licensed_features(cluster_health: true)
        end

        it_behaves_like 'the default dashboard'
      end

      context 'without license' do
        before do
          stub_licensed_features(cluster_health: false)
        end

        it 'has status not found' do
          get :metrics_dashboard, params: metrics_params, format: :json

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  private

  def prometheus_proxy_params(params = {})
    {
      id: cluster.id.to_s,
      group_id: group.name,
      proxy_path: 'query',
      query: '1'
    }.merge(params)
  end

  describe 'GET environments' do
    let(:cluster) { create(:cluster_for_group, groups: [group]) }

    before do
      create(:deployment, :success, cluster: cluster)
    end

    def get_cluster_environments
      get :environments,
        params: {
          group_id: group.to_param,
          id: cluster
        },
        format: :json
    end

    describe 'functionality' do
      it 'responds successfully' do
        get_cluster_environments

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Poll-Interval']).to eq("5000")
      end
    end

    describe 'security' do
      it { expect { get_cluster_environments }.to be_allowed_for(:admin) }
      it { expect { get_cluster_environments }.to be_allowed_for(:owner).of(group) }
      it { expect { get_cluster_environments }.to be_allowed_for(:maintainer).of(group) }
      it { expect { get_cluster_environments }.to be_denied_for(:developer).of(group) }
      it { expect { get_cluster_environments }.to be_denied_for(:reporter).of(group) }
      it { expect { get_cluster_environments }.to be_denied_for(:guest).of(group) }
      it { expect { get_cluster_environments }.to be_denied_for(:user) }
      it { expect { get_cluster_environments }.to be_denied_for(:external) }
    end
  end

  describe 'GET show' do
    let(:cluster) { create(:cluster_for_group, groups: [group]) }

    def get_cluster
      get :show,
        params: {
          group_id: group,
          id: cluster
        }
    end

    it 'expires etag cache to force reload environments list' do
      stub_licensed_features(cluster_deployments: true)
      expect_next_instance_of(Gitlab::EtagCaching::Store) do |store|
        expect(store).to receive(:touch)
          .with(environments_group_cluster_path(cluster.group, cluster))
          .and_call_original
      end

      get_cluster
    end
  end
end
