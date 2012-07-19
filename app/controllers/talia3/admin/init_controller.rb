##
# Talia3 Initialization controller.
#
# Base Talia3 administration include:
# * A page to start the talia3:init rake task via web (TODO).
#
# 
class Talia3::Admin::InitController < Talia3::ApplicationController
  # Make sure the configuration file is present
  # for all steps except the first one.
  before_filter :check_init, :except => [:index]

  # Initialization has its own layput.
  layout 'talia3/init'

  def index
    redirect_to :talia3_admin and return if init_exists? and params[:initialize].blank?
    if params[:initialize]
      system "rake -sq FORCE=1 talia3:init"
      @talia3_init = session[:talia3_init] = true
      redirect_to :controller => 'talia3/admin/init', :action => :admin_password and return
    end
  end

  def admin_password
    @talia3_init = session[:talia3_init]
    if @talia3_init and params[:save]
      unless params[:password] == params[:confirm_password]
        flash[:error] = "Invalid password and/or confirmation"
      else
        user = Talia3::Auth::User.find 1
        user.password = params[:password]
        user.password_confirmation = params[:confirm_password]
        user.valid?
        if user.errors[:password].blank?
          user.save!(:validate => false)
          redirect_to :controller => 'talia3/admin/init', :action => :settings and return
        end
        flash[:error] = "Invalid password"
      end
    end
  end

  def settings
    @talia3_init = session[:talia3_init]
    @talia3_init = true
    if @talia3_init and params[:proceed]
      redirect = {:controller => 'talia3/admin/init', :action => :done}
      talia3_config = Talia3.load_config
      unless params[:type].strip.blank? or params[:location].strip.blank?
        talia3_config["repositories"][Rails.env.to_s]["local"] = {
          'type'     => params[:type].strip,
          'location' => params[:location].strip
        }
        redirect = {:controller => 'talia3/admin/init', :action => :import}
      end

      talia3_config["application_name"] = params[:application_name].strip unless params[:application_name].strip.blank?
      talia3_config["user_emails_enabled"] = !!params[:user_emails_enabled]
      talia3_config["application_url"] = params[:application_url].strip unless params[:application_name].strip.blank?
      talia3_config["base_uri"] = params[:base_uri].strip unless params[:base_uri].strip.blank?
      talia3_config["loose_schema"] = !params[:strict_schema]
      talia3_config["api_enabled"] = !!params[:api_enabled]
      
      Talia3.config = talia3_config
      Talia3.write_config
      redirect_to redirect
    end
  end

  def import
    @talia3_init = session[:talia3_init]
    @talia3_init = true
    @ontology_files = Dir[File.join(Talia3.root, 'config', 'ontologies', '*.rdf')]
    @view_files = Dir[File.join(Talia3.root, 'config', 'views', '*.n3')]

    if @talia3_init and params[:import]
      Talia3.repository.clear if params[:clear_repository]
      if params[:ontologies]
        @ontology_files.each do |file|
          Talia3::Ontology.import file if params[:ontologies][File.basename(file, '.rdf')]
        end
        @view_files.each do |file|
          Talia3::Ontology.import file if params[:ontologies][File.basename(file, '.n3')]
        end
      end

      Talia3::Resource.import params[:data].tempfile.path if params[:data]
      redirect_to :controller => 'talia3/admin/init', :action => :done and return
    end
  end

  def done
    session[:talia3_init] = nil
  end
end
