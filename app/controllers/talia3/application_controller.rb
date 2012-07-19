# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Base Talia3 controller.
#
# @todo Documentation and examples!
class Talia3::ApplicationController < ActionController::Base
  # Activates gettext_i18n_rails i18n support.
  before_filter :set_gettext_locale

  # Devise's autoinclude for helpers does not seem to work.
  include Devise::Controllers::Helpers
  # Rails default added-security method.
  protect_from_forgery

  private
    ##
    # Redirects the user to the initialization page if there is no
    # configuration file yet.
    #
    def check_init
      redirect_to :controller => 'talia3/admin/init' unless init_exists?
    end

    ##
    # Checks whether the initialization file is present.
    #
    # @return [Boolean]
    def init_exists?
      File.exist? File.join('config', 'talia3.yml')
    end

    ##
    # Authenticates ad administrator user
    #
    def authenticate_admin!
      authenticate_talia3_user!
      redirect_to new_talia3_user_session_url, :notice => 'Admin required' unless current_talia3_user.admin?
    end
  #end private
end
