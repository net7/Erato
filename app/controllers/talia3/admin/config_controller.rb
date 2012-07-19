##
# Talia3 configuration panel controller.
#
class Talia3::Admin::ConfigController < Talia3::AdminController
  def index
  end

  def views
    @views = Talia3::Schema::View.all
  end

  def delete_view
    Talia3::Schema::View.destroy params.delete(:uri).to_sym
    Talia3::Schema.reset
    redirect_to :back
  end

  def import_view
    begin 
      if (file = params.delete :view_file) and file.is_a? ActionDispatch::Http::UploadedFile
        Talia3::Ontology.import(file.path, :n3)
        Talia3::Schema.reset
      end
    rescue Exception => e
      flash[:error] = e.message      
    end
    redirect_to :back
  end

  def ontologies
  end

  def import_ontologies
    begin 
      if (file = params.delete :ontology_file) and file.is_a? ActionDispatch::Http::UploadedFile
        Talia3::Ontology.import(file.path, :rdfxml)
      end
    rescue Exception => e
      flash[:error] = e.message      
    end
    redirect_to :back
  end

  def data
  end

  def import_data
    begin 
      if (file = params.delete :data_file) and file.is_a? ActionDispatch::Http::UploadedFile
        Talia3::Resource.import(file.path, :rdfxml)
      end
    rescue Exception => e
      flash[:error] = e.message      
    end
    redirect_to :back
  end
end
