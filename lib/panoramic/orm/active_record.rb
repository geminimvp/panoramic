module Panoramic
  module Orm
    module ActiveRecord
      def store_templates
        class_eval do
          validates :body,    :presence => true
          validates :path,    :presence => true
          validates :format,  :inclusion => Mime::SET.symbols.map(&:to_s)
          validates :locale,  :inclusion => I18n.available_locales.map(&:to_s), :allow_blank => true
          validates :handler, :inclusion => ActionView::Template::Handlers.extensions.map(&:to_s)

          # NOTE See ClassMethods.resolver for details on cache coherence.
          after_save { self.class.resolver.clear_cache }

          extend ClassMethods
        end
      end

      module ClassMethods
        def find_model_templates(conditions = {})
          self.where(conditions)
        end

        # NOTE Use this to create new Panoramic::Resolvers. If you instantiate
        # them yourself, the after_save hook will not be able to invalidate the
        # cache when templates change, so you will be taking responsibility to
        # manage their cache coherency.
        def resolver(options={})
          @resolver ||= Panoramic::Resolver.new(self, options)
        end
      end
    end
  end
end

ActiveRecord::Base.extend Panoramic::Orm::ActiveRecord
