require Rails.root.join('lib/maintenance', 'item_merger.rb')
require Rails.root.join('lib/maintenance', 'tags.rb')
require Rails.root.join('lib', 'association_manager.rb')
module RailsAdmin

  class MainController < RailsAdmin::ApplicationController

    include ActionView::Helpers::TextHelper
    include RailsAdmin::MainHelper
    include RailsAdmin::ApplicationHelper
    include Maintenance::ItemMerger
    include Maintenance::Tags


    layout :get_layout

    before_filter :get_model, :except => RailsAdmin::Config::Actions.all(:root).map(&:action_name)
    before_filter :get_object, :only => RailsAdmin::Config::Actions.all(:member).map(&:action_name)
    before_filter :check_for_cancel
    before_filter :persist_objects

    RailsAdmin::Config::Actions.all.each do |action|
      class_eval %{
        def #{action.action_name}
          action = RailsAdmin::Config::Actions.find('#{action.action_name}'.to_sym)
          @authorization_adapter.try(:authorize, action.authorization_key, @abstract_model, @object)
          @action = action.with({:controller => self, :abstract_model => @abstract_model, :object => @object})
          @page_name = "Dashboard!"
          instance_eval &@action.controller
        end
      }
    end

    def replace_and_merge tagname1, tagname2
      Maintenance::Tags.replace_and_merge(tagname1, tagname2)
    end
    def bulk_moderate items
      items.each do |item|
        item.moderate= true
      end 
    end

    def bulk_action
      self.send(params[:bulk_action]) if params[:bulk_action].in?(RailsAdmin::Config::Actions.all(:controller => self, :abstract_model => @abstract_model).select(&:bulkable?).map(&:route_fragment))
    end

  
    def persist_objects
      @filtered_objs = @objects
      if params.has_key?(:f)
        @filters = params[:f]
      end
    end

    def list_entries(is_edit, model_config = @model_config, auth_scope_key = :index, additional_scope = get_association_scope_from_params, pagination = !(params[:associated_collection] || params[:all]))
      scope = model_config.abstract_model.scoped
      if auth_scope = @authorization_adapter && @authorization_adapter.query(auth_scope_key, model_config.abstract_model)
        scope = scope.merge(auth_scope)
      end
      scope = scope.instance_eval(&additional_scope) if additional_scope
      @entries = get_collection(is_edit, model_config, scope, pagination)
      @entries
    end
    

    private
    
    def get_layout
      "rails_admin/#{request.headers['X-PJAX'] ? 'pjax' : 'application'}"
    end

    def back_or_index
      params[:return_to].presence && params[:return_to].include?(request.host) && (params[:return_to] != request.fullpath) ? params[:return_to] : index_path
    end


    def get_sort_hash(model_config)
      abstract_model = model_config.abstract_model
      params[:sort] = params[:sort_reverse] = nil unless model_config.list.fields.map {|f| f.name.to_s}.include? params[:sort]

      params[:sort] ||= model_config.list.sort_by.to_s
      params[:sort_reverse] ||= 'false'

      field = model_config.list.fields.find{ |f| f.name.to_s == params[:sort] }

      column = if field.nil? || field.sortable == true # use params[:sort] on the base table
        "#{abstract_model.table_name}.#{params[:sort]}"
      elsif field.sortable == false # use default sort, asked field is not sortable
        "#{abstract_model.table_name}.#{model_config.list.sort_by}"
      elsif field.sortable.is_a?(String) && field.sortable.include?('.') # just provide sortable, don't do anything smart
        field.sortable
      elsif field.sortable.is_a?(Hash) # just join sortable hash, don't do anything smart
        "#{field.sortable.keys.first}.#{field.sortable.values.first}"
      elsif field.association? # use column on target table
        "#{field.associated_model_config.abstract_model.table_name}.#{field.sortable}"
      else # use described column in the field conf.
        "#{abstract_model.table_name}.#{field.sortable}"
      end

      reversed_sort = (field ? field.sort_reverse? : model_config.list.sort_reverse?)
      {:sort => column, :sort_reverse => (params[:sort_reverse] == reversed_sort.to_s)}
    end

    def redirect_to_on_success
      notice = t("admin.flash.successful", :name => @model_config.label, :action => t("admin.actions.#{@action.key}.done"))
      if params[:_add_another]
        redirect_to new_path(:return_to => params[:return_to]), :flash => { :success => notice }
      elsif params[:_add_edit]
        redirect_to edit_path(:id => @object.id, :return_to => params[:return_to]), :flash => { :success => notice }
      elsif params[:_moderate_another]
         @objects ||= list_entries(true)
        obj = @objects[session["index"]]
        @object.moderate= true 
        redirect_to edit_path(:id => obj.id, :return_to => params[:return_to]), :flash => { :success => notice }
      else
        redirect_to back_or_index, :flash => { :success => notice }
      end
    end
    def get_object_index my_objects, object, model_config
      i = 0
      index = -1
      my_objects.each do |obj|
        puts obj.name
        if obj.id.to_s.eql? object.id.to_s
          index = i + 1
        end
        i = i + 1
      end
      index
    end

    def sanitize_params_for!(action, model_config = @model_config, _params = params[@abstract_model.param_key])
      return unless _params.present?
      fields = model_config.send(action).fields
      fields.select{ |f| f.respond_to?(:parse_input) }.each {|f| f.parse_input(_params) }

      fields.select(&:nested_form).each do |association|
        children_params = association.multiple? ? _params[association.method_name].try(:values) : [_params[association.method_name]].compact
        (children_params || []).each do |children_param|
          sanitize_params_for!(:nested, association.associated_model_config, children_param)
        end
      end
    end

    def handle_save_error whereto = :new
      action = params[:action]

      flash.now[:error] = t("admin.flash.error", :name => @model_config.label, :action => t("admin.actions.#{@action.key}.done"))
      flash.now[:error] += ". #{@object.errors[:base].to_sentence}" unless @object.errors[:base].blank?

      respond_to do |format|
        format.html { render whereto, :status => :not_acceptable }
        format.js   { render whereto, :layout => false, :status => :not_acceptable  }
      end
    end

    def check_for_cancel
      if params[:_continue]
        redirect_to(back_or_index, :flash => { :info => t("admin.flash.noaction") })
      end
    end

    def get_collection(is_edit, model_config, scope, pagination)
      if params.has_key?(:f)
        session[:filters] = params[:f]
      end
      if params.has_key?(:sort)
        session[:sort_hash] = params[:sort]
      end
      if params.has_key?(:page)
        session[:selected_page] = params[:page]
      end
      if is_edit
        params[:f] = session[:filters]
        params[:sort] = session[:sort_hash]
        params[:page] = session[:selected_page]
      end
      puts "ee" * 100
      puts "page " + params[:page] if params[:page]
      associations = model_config.list.fields.select {|f| f.type == :belongs_to_association && !f.polymorphic? }.map {|f| f.association[:name] }
      options = {}
      #pagination = !is_edit
      options = options.merge(:page => (params[:page] || 1).to_i, :per => (params[:per] || model_config.list.items_per_page)) if pagination
      options = options.merge(:include => associations) unless associations.blank?
      options = options.merge(get_sort_hash(model_config))
      options = options.merge(:query => params[:query]) if params[:query].present?
      puts " filter params"
      puts "*" * 30
      puts params[:f]
      options = options.merge(:filters => params[:f]) if params[:f].present?
      options = options.merge(:bulk_ids => params[:bulk_ids]) if params[:bulk_ids]
      objects = model_config.abstract_model.all(options, scope)
      return objects
    end

  


    def get_association_scope_from_params
      return nil unless params[:associated_collection].present?
      source_abstract_model = RailsAdmin::AbstractModel.new(to_model_name(params[:source_abstract_model]))
      source_model_config = source_abstract_model.config
      source_object = source_abstract_model.get(params[:source_object_id])
      action = params[:current_action].in?(['create', 'update']) ? params[:current_action] : 'edit'
      @association = source_model_config.send(action).fields.find{|f| f.name == params[:associated_collection].to_sym }.with(:controller => self, :object => source_object)
      @association.associated_collection_scope
    end

    def associations_hash
      associations = {}
      @abstract_model.associations.each do |association|
        if [:has_many, :has_and_belongs_to_many].include?(association[:type])
          records = Array(@object.send(association[:name]))
          associations[association[:name]] = records.collect(&:id)
        end
      end
      associations
    end
  end
end
