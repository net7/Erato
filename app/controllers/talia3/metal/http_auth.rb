# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


module Talia3::Metal
  ##
  # HTTP API controller for authentication requests.
  #
  class HTTPAuth < Talia3::Metal::Base
    ##
    # Services authorization token requests.
    #
    # @param [Hash] env The request environment, with some
    #   information added or parsed by Rails.
    # 
    # @return [Array] An HTTP response. Its body will contain the new
    #   authentication token if there were no errors. 401 or 402 statuses 
    #   will be returned for invalid authentications and invalid requests 
    #   respectively.
    def self.call(env)
      super(env)
      authenticated do
        @user.reset_authentication_token!
        [200, text_plain, [@user.authentication_token]]
      end
    end
  end
end
