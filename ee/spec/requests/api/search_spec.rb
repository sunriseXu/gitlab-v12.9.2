# frozen_string_literal: true

require 'spec_helper'

describe API::Search do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let(:project) { create(:project, :public, :repository, :wiki_repo, name: 'awesome project', group: group) }

  shared_examples 'response is correct' do |schema:, size: 1|
    it { expect(response).to have_gitlab_http_status(:ok) }
    it { expect(response).to match_response_schema(schema) }
    it { expect(response).to include_limited_pagination_headers }
    it { expect(json_response.size).to eq(size) }
  end

  shared_examples 'elasticsearch disabled' do
    it 'returns 400 error for wiki_blobs scope' do
      get api(endpoint, user), params: { scope: 'wiki_blobs', search: 'awesome' }

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    it 'returns 400 error for blobs scope' do
      get api(endpoint, user), params: { scope: 'blobs', search: 'monitors' }

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    it 'returns 400 error for commits scope' do
      get api(endpoint, user), params: { scope: 'commits', search: 'folder' }

      expect(response).to have_gitlab_http_status(:bad_request)
    end
  end

  shared_examples 'elasticsearch enabled' do
    context 'for wiki_blobs scope', :sidekiq_might_not_need_inline do
      before do
        wiki = create(:project_wiki, project: project)
        create(:wiki_page, wiki: wiki, attrs: { title: 'home', content: "Awesome page" })

        project.wiki.index_wiki_blobs
        ensure_elasticsearch_index!

        get api(endpoint, user), params: { scope: 'wiki_blobs', search: 'awesome' }
      end

      it_behaves_like 'response is correct', schema: 'public_api/v4/blobs'
    end

    context 'for commits scope', :sidekiq_might_not_need_inline do
      before do
        project.repository.index_commits_and_blobs
        ensure_elasticsearch_index!

        get api(endpoint, user), params: { scope: 'commits', search: 'folder' }
      end

      it_behaves_like 'response is correct', schema: 'public_api/v4/commits_details', size: 2
    end

    context 'for blobs scope', :sidekiq_might_not_need_inline do
      before do
        project.repository.index_commits_and_blobs
        ensure_elasticsearch_index!

        get api(endpoint, user), params: { scope: 'blobs', search: 'monitors' }
      end

      it_behaves_like 'response is correct', schema: 'public_api/v4/blobs'

      context 'filters' do
        it 'by filename' do
          get api("/projects/#{project.id}/search", user), params: { scope: 'blobs', search: 'mon filename:PROCESS.md' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(1)
          expect(json_response.first['path']).to eq('PROCESS.md')
        end

        it 'by path' do
          get api("/projects/#{project.id}/search", user), params: { scope: 'blobs', search: 'mon path:markdown' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(1)
          json_response.each do |file|
            expect(file['path']).to match(%r[/markdown/])
          end
        end

        it 'by extension' do
          get api("/projects/#{project.id}/search", user), params: { scope: 'blobs', search: 'mon extension:md' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(3)
          json_response.each do |file|
            expect(file['path']).to match(/\A.+\.md\z/)
          end
        end
      end
    end
  end

  describe 'GET /search' do
    let(:endpoint) { '/search' }

    context 'with correct params' do
      context 'when elasticsearch is disabled' do
        it_behaves_like 'elasticsearch disabled'
      end

      context 'when elasticsearch is enabled', :elastic do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        end

        context 'when elasticsearch_limit_indexing is on' do
          before do
            stub_ee_application_setting(elasticsearch_limit_indexing: true)
          end

          it_behaves_like 'elasticsearch disabled'
        end

        context 'when elasticsearch_limit_indexing off' do
          before do
            stub_ee_application_setting(elasticsearch_limit_indexing: false)
          end

          it_behaves_like 'elasticsearch enabled'
        end
      end
    end
  end

  describe "GET /groups/:id/-/search" do
    let(:endpoint) { "/groups/#{group.id}/-/search" }

    context 'with correct params' do
      context 'when elasticsearch is disabled' do
        it_behaves_like 'elasticsearch disabled'
      end

      context 'when elasticsearch is enabled', :elastic do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        end

        context 'when elasticsearch_limit_indexing is on' do
          before do
            stub_ee_application_setting(elasticsearch_limit_indexing: true)
          end

          context 'when the namespace is indexed' do
            before do
              create :elasticsearch_indexed_namespace, namespace: group
            end

            it_behaves_like 'elasticsearch enabled'
          end

          context 'when the namespace is not indexed' do
            it_behaves_like 'elasticsearch disabled'
          end
        end

        context 'when elasticsearch_limit_indexing off' do
          before do
            stub_ee_application_setting(elasticsearch_limit_indexing: false)
          end

          it_behaves_like 'elasticsearch enabled'
        end
      end
    end
  end

  describe "GET /projects/:id/-/search" do
    let(:endpoint) { "/projects/#{project.id}/-/search" }

    shared_examples_for 'search enabled' do
      context 'for wiki_blobs scope' do
        before do
          wiki = create(:project_wiki, project: project)
          create(:wiki_page, wiki: wiki, attrs: { title: 'home', content: "Awesome page" })

          get api(endpoint, user), params: { scope: 'wiki_blobs', search: 'awesome' }
        end

        it_behaves_like 'response is correct', schema: 'public_api/v4/blobs'
      end

      context 'for commits scope' do
        before do
          get api(endpoint, user), params: { scope: 'commits', search: 'folder' }
        end

        it_behaves_like 'response is correct', schema: 'public_api/v4/commits_details', size: 2
      end

      context 'for blobs scope' do
        before do
          get api(endpoint, user), params: { scope: 'blobs', search: 'monitors' }
        end

        it_behaves_like 'response is correct', schema: 'public_api/v4/blobs', size: 2

        context 'filters' do
          it 'by filename' do
            get api(endpoint, user), params: { scope: 'blobs', search: 'mon filename:PROCESS.md' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(2)
            expect(json_response.first['path']).to eq('PROCESS.md')
            expect(json_response.first['filename']).to eq('PROCESS.md')
          end

          it 'by path' do
            get api(endpoint, user), params: { scope: 'blobs', search: 'mon path:markdown' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(8)
          end

          it 'by extension' do
            get api(endpoint, user), params: { scope: 'blobs', search: 'mon extension:md' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(11)
          end

          it 'by ref' do
            get api(endpoint, user), params: { scope: 'blobs', search: 'This file is used in tests for ci_environments_status', ref: 'pages-deploy' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(1)
          end
        end
      end
    end

    context 'with correct params' do
      context 'when elasticsearch is disabled' do
        it_behaves_like 'search enabled'
      end

      context 'when elasticsearch is enabled', :elastic do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        end

        context 'when elasticsearch_limit_indexing is on' do
          before do
            stub_ee_application_setting(elasticsearch_limit_indexing: true)
          end

          context 'when the project is indexed' do
            before do
              create :elasticsearch_indexed_project, project: project
            end

            it_behaves_like 'elasticsearch enabled'
          end

          context 'when the project is not indexed' do
            it_behaves_like 'search enabled'
          end
        end

        context 'when elasticsearch_limit_indexing off' do
          before do
            stub_ee_application_setting(elasticsearch_limit_indexing: false)
          end

          it_behaves_like 'elasticsearch enabled'
        end
      end
    end
  end
end
