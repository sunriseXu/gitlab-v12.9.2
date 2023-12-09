# frozen_string_literal: true

resources :issues, only: [], constraints: { id: /\d+/ } do
  member do
    get '/descriptions/:version_id/diff', action: :description_diff, as: :description_diff
    delete '/descriptions/:version_id', action: :delete_description_version, as: :delete_description_version
    get '/designs(/*vueroute)', to: 'issues#designs', as: :designs, format: false
  end

  collection do
    post :export_csv
    get :service_desk
  end

  resources :issue_links, only: [:index, :create, :destroy], as: 'links', path: 'links'
end
