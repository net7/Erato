# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Base authentication module for Talia3
#
# Authentication in Talia3 is delegated to the Devise plugin.
module Talia3::Auth

  ##
  # Defines database table prefixes for classes inside this module.
  #
  # Used by ActiveRecord to assemble the table name associated to a class. 
  # @private
  def self.table_name_prefix
    'talia3_auth_'
  end
end # module Auth::Talia3
