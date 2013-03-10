require 'rails_admin/config/sections/base'
require 'rails_admin/config/fields'

module RailsAdmin
  module Config
    module Sections
      # Configuration of the list view
      class List < RailsAdmin::Config::Sections::Base
        include RailsAdmin::Config::Fields
        register_instance_option :filters do
          puts "-=1" * 100
          field = get_field
          puts field
          @my_custom_field = field

          []
        end

        # Number of items listed per page
        register_instance_option :items_per_page do
          RailsAdmin::Config.default_items_per_page
        end

        register_instance_option :sort_by do
          parent.abstract_model.primary_key
        end

        register_instance_option :sort_reverse? do
          true # By default show latest first
        end
      end
    end
  end
end
