##
# Talia3 Records backend panel controller.
#
class Talia3::Admin::Backend::RecordsController < Talia3::Admin::BackendController
  before_filter :fetch_type, :except => [:destroy]

  def index
    @records = Talia3::Record.from_type(@type).all
    render template("index")
  end

  def new
    @record = Talia3::Record.from_type(@type).new
    render template("new", @record.strict_schema?)
  end

  def create
    values = params[:record].dup
    params[:record].each_key do |name|
      parts = name.to_s.partition /_extra$/
      unless parts[0].blank? or parts[1].blank?
        value_type = values.delete("#{name}_type").try(:to_sym)
        value = values.delete(name.to_sym)
        value = (value_type == :uri) ? value.to_sym : value.to_s
        values[parts[0].to_sym] = [] if values[parts[0].to_sym].blank?
        values[parts[0].to_sym] << value
      end
    end

    unless params[:attribute_name].blank?
      value = params[:attribute_value]
      value = (params[:attribute_value_type] == "uri") ? value.to_sym : value.to_s
      values[params[:attribute_name]] = value
    end

    @record = Talia3::Record.from_type(@type).new(values)
    if @record.save
      flash[:success] = "Record saved correctly"
      redirect_to "/talia3/admin/backend"
    else
      render template("new", @record.strict_schema?)
    end
  end

  def edit
    @record = Talia3::Record.from_type(@type).for(params.delete(:id).to_sym)
    render template("edit", @record.strict_schema?)
  end

  def update
    begin
      values = params[:record].dup
      params[:record].each_key do |name|
        parts = name.to_s.partition /_extra$/
        unless parts[0].blank? or parts[1].blank?
          value_type = values.delete("#{name}_type").try(:to_sym)
          value = values.delete(name.to_sym)
          value = (value_type == :uri) ? value.to_sym : value.to_s
          values[parts[0].to_sym] = [] if values[parts[0].to_sym].blank?
          values[parts[0].to_sym] << value
        end
        parts = name.to_s.partition /_others$/
        unless parts[0].blank? or parts[1].blank?
          values[parts[0].to_sym] = [] if values[parts[0].to_sym].blank?
          values[parts[0].to_sym] |= values.delete(name.to_sym)
        end
      end

      unless params[:attribute_name].blank?
        value = params[:attribute_value]
        value = (params[:attribute_value_type] == "uri") ? value.to_sym : value.to_s
        values[params[:attribute_name]] = value
      end

      @record = Talia3::Record.from_type(@type).new(params.delete(:id).to_sym)
      if @record.update_attributes values
        flash[:success] = "Record Updated correctly"
        redirect_to talia3_records_url(:talia3_record => {:type => @type})
      else
        render template("edit", @record.strict_schema?)
      end
    rescue Exception => e
      flash[:error] = e.message
      render template("edit", @record.strict_schema?)
    end
  end

  def destroy
    @record = Talia3::Record.for(params.delete(:id).to_sym).delete
    redirect_to :back
  end

  private
    def fetch_type
      begin
        @type = Talia3::URI.new params.delete(:type)
      rescue
        flash.now[:error] = "No type provided or invalid type."
        redirect_to talia3_admin_backend_url and return
      end
    end
  # end private
end # class Talia3::Admin::Backend::RecordsController
