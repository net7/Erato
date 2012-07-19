# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require "rails"

##
# Talia3 Engine
#
# Autoloads configuration from config/talia3.yml.
# Registers Talia3 tasks.
#
class Talia3::Engine < ::Rails::Engine
  # Get configuration from <app>/config/talia3.yml configuration file
  config.talia3 = Talia3.load_config
  rake_tasks {load File.join "talia3", "railties", "tasks.rake"}

  # Activate Devise. We want to do this here because we want 
  # it working as soon as the Talia3 plugin is installed.
  require 'devise'
  # Devise configuration file. The authentication plugin 
  # is configured according to Talia3 settings.
  require File.join(root, 'config', 'devise.rb')

  # Activate "gettext_i18n_rails". Initialization is once again
  # embedded in Talia3 own.
  require 'gettext_i18n_rails'
  require File.join(root, 'config', 'fast_gettext.rb')
  
  # Required by some of Devise's features.
  unless config.talia3[:application_url].blank?
    config.action_mailer.default_url_options[:host] = config.talia3[:application_url]
  end

  initializer "static assets" do |app|
    # Alternative?
    # app.middleware.insert_before(::ActionDispatch::Static, ::ActionDispatch::Static, "#{root}/public")
    app.middleware.use ::ActionDispatch::Static, "#{root}/public"
  end
end # Talia3::Engine

