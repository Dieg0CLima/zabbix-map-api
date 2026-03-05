Rails.application.routes.draw do
  namespace :api, as: nil do
    namespace :v1, as: nil do
      devise_for :users, controllers: {
        registrations: "api/v1/users/registrations",
        sessions: "api/v1/users/sessions"
      }

      get "me", to: "me#show"

      resources :projects, controller: "network_projects" do
        member do
          put :save
        end
      end

      resources :sites
      resources :devices
      resources :network_links

      resources :network_maps do
        resources :map_pops
        resources :map_nodes
        resources :network_cables do
          resources :events, controller: "network_cable_events", only: :index
        end
        resource :editor_state, controller: "network_map_editor_states", only: %i[show update]
        resource :monitoring, controller: "network_map_monitoring", only: :show
      end

      resources :zabbix_connections do
        resources :zabbix_hosts, only: :index
        resources :zabbix_items, only: :index
      end
    end
  end
end
