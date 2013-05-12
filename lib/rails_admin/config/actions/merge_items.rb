require Rails.root.join('lib/maintenance', 'item_merger.rb')
require Rails.root.join('lib', 'association_manager.rb')

module RailsAdmin
  module Config
    module Actions
      class MergeItems < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        include Maintenance::ItemMerger
        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:post, :delete]
        end

        register_instance_option :controller do
          Proc.new do
             @objects = list_entries(false, @model_config, :destroy)
            if request.post? # BULK DELETE
              @merge = true
             

              render @action.template_name

            elsif request.delete? # BULK DESTROY
              puts "##" * 20
              puts "merge"
             
                merge(@objects[0],@objects[1]) if params[:master] == @objects[0].to_s
                merge(@objects[1],@objects[0]) unless params[:master] == @objects[0].to_s
              
                            redirect_to back_or_index


            end
          end
        end

        register_instance_option :authorization_key do
          :destroy
        end

        register_instance_option :bulkable? do
          true
        end
      end
    end
  end
end
