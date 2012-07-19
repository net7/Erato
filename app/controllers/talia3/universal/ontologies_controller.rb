# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Ontologies administration for Universal Form service.
#
class Talia3::Universal::OntologiesController < Talia3::Universal::BaseController

  def index
    @title = "Ontologies"
    @ontologies = Talia3::Ontology::Cache.all
  end

  def destroy
    begin
      context = Base64.decode64 params[:id]
      Talia3::Ontology::Cache.destroy! Base64.decode64 params[:id]
      flash[:notice] = 'Ontology deleted correctly'
    rescue 
      flash[:alert] = "Unknown error while deleting: #{$!.inspect}"
    ensure
      redirect_to :action => :index
    end
  end

  ##
  # @todo refactor
  def create
    begin
      context  = params[:id].strip.blank? ? nil : params[:id].strip
      location = nil
      options = {:content_type => (params[:format].strip.blank? ? nil : params[:format].strip)}

      unless context.nil?
        unless Talia3::URI.valid? context
          flash[:alert] = 'Please enter a valid namespace URL' 
        else
          flash[:alert] = 'Context name already in use' if Talia3::Ontology::Cache.exists? context
        end
      end

      unless flash[:alert]
        case
          when params[:import_file]
            if file = params.delete(:ontology_file) and file.is_a?(ActionDispatch::Http::UploadedFile)
              options[:original_filename] = file.original_filename
              options[:base_uri] = options[:context] = context.blank? ? "file://#{file.original_filename}" : context
              location = file.path
            else
              flash[:alert] = 'Invalid file uploaded'
            end
          when params[:import_remote]
            url = params[:url].strip
            if not url.blank? and Talia3::URI.valid? url
              options[:base_uri] = options[:context] = context.blank? ? url : context
              location = url
            else
              flash[:alert] = 'Invalid URL for ontology location'
            end
        end
      end # unless flash[:alert]

      unless location.nil?
        Talia3::Ontology::Cache.import(location, options)
        flash[:notice] = 'Ontology added correctly'
      end
    rescue RDF::FormatError
      flash[:alert] = "Invalid format or data"
    rescue Errno::ENOENT
      flash[:alert] = "Location or file not found"
    rescue
      flash[:alert] = "Unknown error while adding: '#{$!}'"
    ensure
      redirect_to :action => :index, :id => params[:context]
    end
  end
end
