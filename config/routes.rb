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

      resources :sites do
        collection do
          get :dropdown
        end
      end
      get "devices/catalogs", to: "device_catalogs#index"
      resources :devices do
        collection do
          get :dropdown
        end
        member do
          get :dashboard
          patch :site_link
        end
        resources :interfaces, controller: "device_interfaces", only: %i[index create update destroy]
        resources :zabbix_links, controller: "zabbix_links", only: %i[index create]
        namespace :monitoring, module: "devices/monitoring" do
          resource :host_link, only: %i[show update], path: "host-link"
          get "available-items", to: "available_items#index"
          resources :items, only: %i[index create update destroy]
          get "summary", to: "summary#show"
        end
      end
      get "device_interfaces/:interface_id/zabbix_links", to: "zabbix_links#index"
      post "device_interfaces/:interface_id/zabbix_links", to: "zabbix_links#create"
      resources :zabbix_links, only: :destroy

      resources :network_maps, controller: "network_maps_v2", only: %i[index create show update destroy] do
        member do
          get :editor_state
          get :available_sites
          get :available_devices
          get :health
          get :metrics
          get :events
          get :cable_metrics
        end

        resources :nodes, controller: "map_nodes_v2", only: %i[index create update destroy] do
          resources :monitoring_bindings, controller: "map_monitoring_bindings", only: %i[index create update destroy]
          resources :node_items, controller: "map_node_items_v2", only: %i[index create destroy] do
            collection do
              get :metrics
            end
          end
        end

        member do
          post "nodes/from-site", to: "map_nodes_v2#from_site"
          post "nodes/from-device", to: "map_nodes_v2#from_device"
        end

        resources :network_cables do
          member do
            get :available_device_items
            patch :geometry
          end
          resources :events, controller: "network_cable_events", only: :index
          resources :network_cable_items, only: %i[index create destroy]
        end

        resources :map_pops, controller: "map_pops"
        resources :edges, controller: "map_edges", param: :id, only: %i[index create update destroy]
        resources :site_markers, controller: "site_markers", only: %i[create update destroy] do
          collection do
            post :bulk_create
            patch :bulk_update
            delete :bulk_destroy
          end
        end
        resources :device_markers, controller: "device_markers", only: %i[create update destroy] do
          collection do
            post :bulk_create
            patch :bulk_update
            delete :bulk_destroy
          end
        end

        resources :sites, only: [] do
          namespace :monitoring, module: "sites/monitoring" do
            resource :ping_link, only: %i[show create destroy], path: "ping-link"
          end
        end
      end

      post "network_maps/imports/preview", to: "network_map_imports#preview"
      post "network_maps/imports/apply", to: "network_map_imports#apply"
      get "network_maps/imports/:import_id/status", to: "network_map_imports#status"

      resources :legacy_network_maps, controller: "network_maps", path: "legacy/network_maps" do
        resources :map_pops
        resources :map_nodes do
          resources :map_node_items, only: %i[index create destroy]
        end
        resources :network_cables do
          member do
            get :available_device_items
            patch :geometry
          end
          resources :events, controller: "network_cable_events", only: :index
          resources :network_cable_items, only: %i[index create destroy]
        end
        resource :editor_state, controller: "network_map_editor_states", only: %i[show update]
        resource :metrics, controller: "network_map_metrics", only: :show
        get "metrics/events", to: "network_map_metrics#events"
      end

      resources :zabbix_connections do
        resources :zabbix_hosts, only: %i[index show] do
          collection do
            get :dropdown
          end
          member do
            get :items
          end
        end
        resources :zabbix_items, only: :index do
          collection do
            get :dropdown
            get :history
          end
        end
        member do
          get "hosts/dropdown", to: "zabbix_connection_dropdowns#hosts"
          get "items/dropdown", to: "zabbix_connection_dropdowns#items"
        end
      end

      resource :ldap_settings, controller: "ldap_settings", only: %i[show update] do
        post :test_connection
      end
    end
  end
end
