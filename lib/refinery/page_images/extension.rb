module Refinery
  module PageImages
    module Extension
      def has_many_page_images
        has_many :image_pages, :as => :page, :class_name => 'Refinery::ImagePage', :order => 'position ASC'
        has_many :images, :through => :image_pages, :class_name => 'Refinery::Image', :order => 'position ASC'
        # accepts_nested_attributes_for MUST come before def images_attributes=
        # this is because images_attributes= overrides accepts_nested_attributes_for.

        accepts_nested_attributes_for :images, :allow_destroy => false

        attr_accessor :image_pages_marked_for_deletion

        after_save :delete_image_pages_as_necessary
        # need to do it this way because of the way accepts_nested_attributes_for
        # deletes an already defined images_attributes
        module_eval do
          def delete_image_pages_as_necessary
            if @image_pages_marked_for_deletion
              @image_pages_marked_for_deletion.each do |image_page|
                image_page.destroy
              end
            end
          end


          def images_attributes=(data)
            ids_to_keep = data.map{|i, d| d['id']}.compact

            image_pages_to_delete = if ids_to_keep.empty?
              @image_pages_marked_for_deletion = self.image_pages.all
              self.image_pages.delete_if {true}
            else
              @image_pages_marked_for_deletion = self.image_pages.where(Refinery::ImagePage.arel_table[:image_id].not_in(ids_to_keep)).all
              self.image_pages.delete_if { |ip| !ids_to_keep.include?(ip.image_id.to_s)}
            end

            data.each do |i, image_data|
              image_page_id, image_id, caption =
                image_data.values_at('image_page_id', 'id', 'caption')

              next if image_id.blank?

              image_page = (self.image_pages.detect {|ip| ip.image_id.to_s == image_id.to_s } || self.image_pages.build(:image_id => image_id))

              image_page.position = i
              image_page.caption = caption if Refinery::PageImages.captions
            end
          end
        end

        include Refinery::PageImages::Extension::InstanceMethods

        attr_accessible :images_attributes
      end

      module InstanceMethods

        def caption_for_image_index(index)
          self.image_pages[index].try(:caption).presence || ""
        end

        def image_page_id_for_image_index(index)
          self.image_pages[index].try(:id)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:extend, Refinery::PageImages::Extension)
