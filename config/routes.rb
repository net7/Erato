# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

Rails.application.routes.draw do
  # FIXME currently needed by Devise.
  root :to => 'talia3/admin#index'

  namespace :talia3 do

    ##################
    # Talia3 front-end
    #
    # FIXME: this is only a placeholder, we need a default frontend.
    resources :records, :module => 'admin/backend', :path => 'admin/backend/records'

    ################
    # Universal form
    #
    # FIXME: refactor routes with #resources if possible
    namespace :universal do
      match 'types',            :to => 'service#types'
      match 'instances',        :to => 'service#instances'
      match 'new',              :to => 'service#new'
      match 'create',           :to => 'service#create'
      match '(edit)',           :to => 'service#edit'
      match 'update',           :to => 'service#update'
      match 'destroy',          :to => 'service#destroy'
      match 'label',            :to => 'service#label'
      match 'bnodes',           :to => 'service#bnodes'
      match 'bnodes_transform', :to => 'service#bnode_transform'

      resources :ontologies, :only => [:index, :create, :destroy]
    end

    ############################################
    # Talia3 configuration, settings and backend
    #
    # FIXME: the backend is now obsolete, use the 
    #        universal form tools to redo.
    # TODO: a lot of stuff missing or insufficient, make it better!
    match 'admin', :to => 'admin#index'
    namespace :admin do
      # Talia3 initialization
      match "init(/:action)", :to => 'init'
      # Talia3 user authentication
      match 'logout', :to => 'sessions#destroy'
      # Talia3 configuration and settings
      namespace :config do
        match ':action'
      end
      # Talia3 backend (obsolete)
      namespace :backend do
        match '/', :to => "backend#index"
        match 'new_record', :to => "backend#new_record"
      end
    end
  end

  #################
  # Talia3 authentication
  #
  # Note: Talia3 uses Devise, defined here are Default devise mappings
  devise_for :talia3_users, :class_name => 'Talia3::Auth::User', :path => '/talia3/admin/'

  #################
  # Talia3 HTTP API
  #
  # TODO: redo or remove considering Devise.
  # TODO: moar APIs!
  if Talia3.api_enabled?
    match '/talia3/api/auth' => Talia3::Metal::HTTPAuth
    match '/talia3/api/records/:type/(:id)' => Talia3::Metal::HTTPRecord
  end
  match '/talia3/api/:whatever' => Talia3::Metal::HTTP404
end
