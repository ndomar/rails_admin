require Rails.root.join('lib/maintenance', 'item_merger.rb')
require Rails.root.join('lib', 'association_manager.rb')

module RailsAdmin
  module Config
    module Actions
      class Moderate < RailsAdmin::Config::Actions::Base
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

            if request.post? # BULK DELETE

              @objects = list_entries(@model_config, :destroy)
              puts "===================== OBJECT size IS ===================="
              puts @objects.size

              render @action.template_name

            elsif request.delete? # BULK DESTROY

              puts "-=-=-=-=-=-=-=-=-=  CALLED MERGE ITEMS -=-=-=-=-=-==-=-=-=-="
@objects = list_entries(@model_config, :destroy)
        bulk_moderate(@objects)

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
