##
# Talia3 backend panel controller.
#
class Talia3::Admin::BackendController < Talia3::AdminController
  def index
    @types = Talia3::Schema.classes
    render template("index")
  end

  def new_record
    @type = params[:type]
    @types = @type.nil? ? Talia3::Schema.all_classes : nil
    render template("new_record")
  end

  private
    def template(action, strict=nil)
      strict ||= !Talia3.config(:loose_schema) 
      action.to_s + (strict ? "_strict" : "_loose")
    end
  # end private
end
