module Panoramic
  class Resolver < ActionView::Resolver
    # model - Either an ActiveRecord::Relation defining the scope of templates
    #         to be searched, or a callable object accepting a hash of details and
    #         returning a Relation. The callable can return nil or throw the
    #         symbol :skip_panoramic to bypass Panoramic and defer to the next
    #         resolver.
    #
    # options - An optional hash of:
    #   :only - If provided, only operate on the given prefix.
    #
    def initialize(model, options={})
      super()
      @model = model
      @resolver_options = options
    end

    # this method is mandatory to implement a Resolver
    def find_templates(name, prefix, partial, details, key=nil, locals=[])
      return [] if @resolver_options[:only] && !@resolver_options[:only].include?(prefix)

      request_model = resolve_model(details)
      return [] if request_model.nil?

      path = build_path(name, prefix)
      conditions = {
        :path    => path,
        :locale  => [normalize_array(details[:locale]).first, nil],
        :format  => normalize_array(details[:formats]),
        :handler => normalize_array(details[:handlers]),
        :partial => partial || false
      }.merge(details[:additional_criteria].presence || {})

      request_model.find_model_templates(conditions).map do |record|
        Rails.logger.debug "Rendering template from database: #{path} (#{record.format})"
        initialize_template(record)
      end
    end

    private

    def request_specific_options?
      @model.respond_to?(:call)
    end

    def resolve_model(details)
      if request_specific_options?
        # If the block throws :skip_panoramic, we immediately quit and fall
        # through to the next resolver.
        catch(:skip_panoramic) do
          @model.call(details)
        end
      else
        @model
      end
    end

    # Initialize an ActionView::Template object based on the record found.
    def initialize_template(record)
      source = record.body
      identifier = "#{record.class} - #{record.id} - #{record.path.inspect}"
      handler = ActionView::Template.registered_template_handler(record.handler)

      details = {
        :format => Mime[record.format],
        :updated_at => record.updated_at,
        :virtual_path => virtual_path(record.path, record.partial)
      }

      ActionView::Template.new(source, identifier, handler, details)
    end

    # Build path with eventual prefix
    def build_path(name, prefix)
      prefix.present? ? "#{prefix}/#{name}" : name
    end

    # Normalize array by converting all symbols to strings.
    def normalize_array(array)
      array.map(&:to_s)
    end

    # returns a path depending if its a partial or template
    def virtual_path(path, partial)
      return path unless partial
      if index = path.rindex("/")
        path.insert(index + 1, "_")
      else
        "_#{path}"
      end
    end
  end
end
