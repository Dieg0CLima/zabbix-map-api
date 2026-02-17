Rails.application.routes.draw do
  namespace :api, as: nil do
    namespace :v1, as: nil do
      devise_for :users, controllers: {
        registrations: "api/v1/users/registrations",
        sessions: "api/v1/users/sessions"
      }

      get "me", to: "me#show"

      resources :network_maps do
        resources :map_nodes
        resources :network_cables
      end

      resources :zabbix_connections do
        resources :zabbix_hosts, only: :index
        resources :zabbix_items, only: :index
      end
    end
  end
end
