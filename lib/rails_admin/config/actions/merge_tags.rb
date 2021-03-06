require Rails.root.join('lib/maintenance', 'tags.rb')


module RailsAdmin
  module Config
    module Actions
      class MergeTags < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        include Maintenance::Tags
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
              render @action.template_name
            elsif request.delete? # BULK DESTROY

        replace_and_merge(@objects[0].tagname,@objects[1].tagname)

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
