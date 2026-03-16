Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

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

      resources :network_maps do
        resources :map_pops
        resources :map_nodes do
          resources :map_node_items, only: %i[index create destroy]
        end
        resources :network_cables do
          resources :events, controller: "network_cable_events", only: :index
        end
        resource :editor_state, controller: "network_map_editor_states", only: %i[show update]
        resource :metrics, controller: "network_map_metrics", only: :show
        get "metrics/events", to: "network_map_metrics#events"
      end

      resources :sites
      resources :devices

      resources :zabbix_connections do
        resources :zabbix_hosts, only: :index do
          collection do
            get :dropdown
          end
        end
        resources :zabbix_items, only: :index do
          collection do
            get :dropdown
          end
        end
      end
    end
  end
end
