# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


module Talia3::Metal
  ##
  # HTTP API controller for Talia3::Record REST requests.
  #
  class HTTPRecord < Talia3::Metal::Base
    def self.call(env)
      # "action_dispatch.request.path_parameters"=>{:type=>"foaf__Person", :id=>"local__rik"}
      super(env)
      authenticated do
        @user.admin? ? do_rest(env) : [401, text_plain, ["Admin user required."]]
      end
    end

    def self.do_rest(env)
      @env = env
      @path_params = env['action_dispatch.request.path_parameters']
      method = @env['REQUEST_METHOD']
      case method
        when 'GET'    then show
        when 'POST'   then create_or_update
        when 'DELETE' then destroy
      end
    end

    def self.index_or_show
      @path_params[:id].nil? ? [404, text_plain, ["Not Found"]] : show
    end

    def self.index
      [501, text_plain, ["Not implemented."]]
    end

    def self.show
      [501, text_plain, ["Not implemented."]]
    end

    def self.create_or_update
      @path_params[:id].nil? ? create : update
    end

    def self.create
      [501, text_plain, ["Not implemented."]]
    end

    def self.update
      [501, text_plain, ["Not implemented."]]
    end

    def destroy
      [501, text_plain, ["Not implemented."]]
    end
  end
end
