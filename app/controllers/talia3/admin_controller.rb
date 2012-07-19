# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Base Talia3 administration panel controller.
#
# @todo Documentation and examples!
class Talia3::AdminController < Talia3::ApplicationController
  layout 'talia3/application'
  # Always make sure this application has been initialized.
  before_filter :check_init

  # Always require an administrator user.
  before_filter :authenticate_admin!

  def index
  end
end
