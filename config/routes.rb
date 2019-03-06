Rails.application.routes.draw do

   devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

    resources :clients do
      resources :items
      resources :events
      resources :orders, except: [:destroy]
    end
    resources :events do
      resources :locations do
        resources :orders, except: [:create, :index, :destroy]
        resources :transactions, except: [:destroy]
      end
    end


# Custom Routes
 # Home Routes
  get 'home' => 'home_pages#home'

  get 'about' => 'home_pages#about'

  get 'faqs' => 'home_pages#faqs'

# Order Routes
# route to view details from a specific order
get '/locations/:location_id/orders/:order_id' => 'order#show', as: 'order'


# Location Routes
post '/events/:event_id/locations' => 'locations#create', as: 'create_location'
get 'api/events/:event_id/locations' => 'locations#index_as_json', as: 'locations_api_index'
get 'api/events/:event_id/locations/:id' => 'locations#location_json', as: 'location_api'

# Inventory Routes
# route to get all current items in a bin in a specific location
get '/locations/:location_id/bins' => 'bins#inventory', as: 'location_inventory'
get '/locations/:location_id/bins/new' => 'bins#new', as: 'new_location_item'
post '/locations/:location_id/bins' => 'bins#create', as: 'create_location_item'
patch '/locations/:location_id/bins/:id' => 'bins#update_item', as: 'inventory_item_edit'

# Transaction Routes 
get '/bins/:bin_id/transactions' => 'transactions#index', as: 'bin_transactions'
post '/bins/:bin_id/transactions' => 'transactions#create', as: 'new_transaction'
patch '/bins/:bin_id/transactions/:id' => 'transactions#edit', as: 'transaction_edit'
delete '/bins/:bin_id/transactions/:id' => 'transactions#destroy', as: 'transaction_destroy'

# Order Routes
post '/locations/:location_id/orders' => 'orders#create', as: 'new_location_order'
get '/events/:event_id/locations/:location_id/orders' => 'orders#orders_by_location', as: 'location_orders'
get '/events/:event_id/orders' => 'orders#orders_by_event', as: 'event_orders'
# get '/events/:event_id/locations/map_edit' => 'locations#map_edit', as: 'locations_map_edit'

  root to: 'clients#dashboard'
get '*path', to: 'clients#dashboard'


end
