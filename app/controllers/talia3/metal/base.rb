# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Metal controllers for Talia3 APIs.
#
#    __Note__: Please note that there is a metal class for every API route,
#    this is to avoid having to chech PATH_INFO inside call, leaving
#    routing logic inside the routes.rb file. Including
#    ActiveController::Rendering would do this for us, but we are
#    trying to include the less possible.
#
module Talia3::Metal
  ##
  # Base controller for API calls.
  #
  # Provides an abstract {Base.env} method: a template for controllers 
  # inheriting it.
  #
  class Base < ActionController::Metal
    ##
    # Default behaviour for children classes
    #
    # Every #call method in children classes should start with
    # super(env).
    # Prepares some handy shortcuts and values:
    #
    # * @params: POST or GET parameters;
    # * @ip: remote request IP;
    # * @user: authenticated Talia3::Auth::User; can also be _nil_ if authentication failed or 
    #   false if no authentication data was provided.
    #
    # @abstract
    # @param [Hash] env The request environment, with some
    #   information added or parsed by Rails.
    # 
    # @return [Array] an anonymous server error response, as this
    #   method should __never__ be called by itself.
    def self.call(env)
      abstract!
      # Should we ever need to filter sensitive information from the logs.
      env["action_dispatch.parameter_filter"] = env["action_dispatch.parameter_filter"] + [:token]
      make_params env
      @ip = env['REMOTE_ADDR']
      # Note: @user is *false* if invalid parameters where given, *nil* if the **values** where invalid.
      @user = if @params[:token]
                Talia3::Auth::User.find_for_token_authentication :token => @params.delete(:token)
              elsif @params[:email] and @params[:password]
                user = Talia3::Auth::User.find_for_database_authentication :email => @params.delete(:email)
                user.try(:valid_password?, @params.delete(:password)) ? user : nil
              else
                false
              end
      [501, {}, '']
    end

    ##
    # Checks for any authentication and executes block.
    #
    # Executes the block if user authentication (but not authorization!) is valid.
    # Returns the proper status and string error if authentication is not valid.
    #
    # @return [Array] returns an error HTTP response on invalid authentication, block's own response otherwise
    def self.authenticated(&block)
      if(@user)
        block.call
      elsif @user.nil?
        [401, text_plain, ["User authentication failed."]]
      else
        [400, text_plain, ["User authentication required, please provide email and password or a valid token."]]
      end
    end #self.authenticated

    def self.make_params(env)
      post = env["rack.request.form_hash"].try(:to_options!) || {}
      get  = env['QUERY_STRING'].empty? ? {} : CGI.parse(env['QUERY_STRING']).to_options!

      token    = post.delete(:token)    || get.delete(:token).try(:first)
      email    = post.delete(:email)    || get.delete(:email).try(:first)
      password = post.delete(:password) || get.delete(:password).try(:first)

      @params = post.empty? ? post : get
      @params[:token] = token
      @params[:email] = email
      @params[:password] = password
      true
    end

    def self.text_plain
      {'Content-Type' => 'plain/text'}
    end # self.text_plain

  end # class Base
end # module Talia3::Metal
