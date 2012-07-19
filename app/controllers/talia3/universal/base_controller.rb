# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Base controller for Universal form services.
#
class Talia3::Universal::BaseController < Talia3::ApplicationController
  layout 'talia3/universal'

  ##
  # Exception handling.
  #
  rescue_from Exception do |e|
    case e
      when Errno::ECONNREFUSED then render :status => 500, :text => 'Local repository not available'
      when SocketError then render :status => 400, :text => 'Invalid repository URL'
      when RDF::ReaderError then render :status => 400, :text => 'Invalid response from SPARQL endpoint'

      when RDF::SPARQL::Client::ClientError
        ignoreme, status, message = /<title>([0-9]+)+ ([^<]+)<\/title>/.match($!.message).to_a
        unless status.present?
          status  = 400
          # Try to avoid returning a whole HTML page.
          message = ($!.message.size < 40) ? $!.message : "Client error"
        end
        render :status => status, :text => "Sparql endpoint responded with status #{status}: #{message.to_s}"

      else
        Rails.logger.info $!.inspect
        render :status => 500, :text => "Unknown error"
    end
  end # rescue_from Exception
end # class Talia3::Universal::BaseController
