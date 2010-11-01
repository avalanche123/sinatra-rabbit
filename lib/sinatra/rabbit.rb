require 'sinatra/base'
require 'sinatra/rabbit/url_for'
require 'sinatra/rabbit/respond_to'
require 'sinatra/rabbit/validation'

module Sinatra

  module Rabbit

    class RabbitDuplicateParamException < Exception; end
    class RabbitDuplicateOperationException < Exception; end
    class RabbitDuplicateCollectionException < Exception; end

    def self.registered(app)
      app.helpers Rabbit::Helpers
    end

    class Operation
      attr_reader :name, :method

      include Rabbit::Validation

      STANDARD = {
        :index => { :method => :get, :member => false },
        :show =>  { :method => :get, :member => true },
        :create => { :method => :post, :member => false },
        :update => { :method => :put, :member => true },
        :destroy => { :method => :delete, :member => true }
      }

      def initialize(coll, name, opts, &block)
        @name = name.to_sym
        opts = STANDARD[@name].merge(opts) if standard?
        @collection = coll
        raise "No method for operation #{name}" unless opts[:method]
        @method = opts[:method].to_sym
        @member = opts[:member]
        @description = ""
        instance_eval(&block) if block_given?
        generate_documentation
      end

      def standard?
        STANDARD.keys.include?(name)
      end

      def description(text="")
        return @description if text.blank?
        @description = text
      end

      def generate_documentation
        coll, oper = @collection, self
        ::Sinatra::Application.get("/api/docs/#{@collection.name}/#{@name}") do
          @collection, @operation = coll, oper
          respond_to do |format|
            format.html { haml :'docs/operation' }
            format.xml { haml :'docs/operation' }
          end
        end
      end

      def control(&block)
        op = self
        @control = Proc.new do
          op.validate(params)
          instance_eval(&block)
        end
      end

      def prefix
        # FIXME: Make the /api prefix configurable
        "/api"
      end

      def path(args = {})
        l_prefix = args[:prefix] ? args[:prefix] : prefix
        if @member
          if standard?
            "#{l_prefix}/#{@collection.name}/:id"
          else
            "#{l_prefix}/#{@collection.name}/:id/#{name}"
          end
        else
          "#{l_prefix}/#{@collection.name}"
        end
      end

      def generate
        ::Sinatra::Application.send(@method, path, {}, &@control)
        # Set up some Rails-like URL helpers
        if name == :index
          gen_route "#{@collection.name}_url"
        elsif name == :show
          gen_route "#{@collection.name.to_s.singularize}_url"
        else
          gen_route "#{name}_#{@collection.name.to_s.singularize}_url"
        end
      end

      private
      def gen_route(name)
        route_url = path
        if @member
          ::Sinatra::Application.send(:define_method, name) do |id, *args|
            url = query_url(route_url, args[0])
            url_for url.gsub(/:id/, id.to_s), :full
          end
        else
          ::Sinatra::Application.send(:define_method, name) do |*args|
            url = query_url(route_url, args[0])
            url_for url, :full
          end
        end
      end
    end

    class Collection
      attr_reader :name, :operations

      def initialize(name, &block)
        @name = name
        @description = ""
        @operations = {}
        instance_eval(&block) if block_given?
        generate_documentation
      end

      # Set/Return description for collection
      # If first parameter is not present, full description will be
      # returned.
      def description(text='')
        return @description if text.blank?
        @description = text
      end

      def generate_documentation
        coll, oper, features = self, @operations, features(name)
        ::Sinatra::Application.get("/api/docs/#{@name}") do
          @collection, @operations, @features = coll, oper, features
          respond_to do |format|
            format.html { haml :'docs/collection' }
            format.xml { haml :'docs/collection' }
          end
        end
      end

      # Add a new operation for this collection. For the standard REST
      # operations :index, :show, :update, and :destroy, we already know
      # what method to use and whether this is an operation on the URL for
      # individual elements or for the whole collection.
      #
      # For non-standard operations, options must be passed:
      #  :method : one of the HTTP methods
      #  :member : whether this is an operation on the collection or an
      #            individual element (FIXME: custom operations on the
      #            collection will use a nonsensical URL) The URL for the
      #            operation is the element URL with the name of the operation
      #            appended
      #
      # This also defines a helper method like show_instance_url that returns
      # the URL to this operation (in request context)
      def operation(name, opts = {}, &block)
        raise DuplicateOperationException if @operations[name]
        @operations[name] = Operation.new(self, name, opts, &block)
      end

      def generate
        operations.values.each { |op| op.generate }
        app = ::Sinatra::Application
        collname = name # Work around Ruby's weird scoping/capture
        app.send(:define_method, "#{name.to_s.singularize}_url") do |id|
            url_for "/api/#{collname}/#{id}", :full
        end

        if index_op = operations[:index]
          app.send(:define_method, "#{name}_url") do
            url_for index_op.path.gsub(/\/\?$/,''), :full
          end
        end
      end

      def add_feature_params(features)
        features.each do |f|
          f.operations.each do |fop|
            if cop = operations[fop.name]
              fop.params.each_key do |k|
                if cop.params.has_key?(k)
                  raise DuplicateParamException, "Parameter '#{k}' for operation #{fop.name} defined by collection #{@name} and by feature #{f.name}"
                else
                  cop.params[k] = fop.params[k]
                end
              end
            end
          end
        end
      end
    end

    def collections
      @collections ||= {}
    end

    # Create a new collection. NAME should be the pluralized name of the
    # collection.
    #
    # Adds a helper method #{name}_url which returns the URL to the :index
    # operation on this collection.
    def collection(name, &block)
      raise DuplicateCollectionException if collections[name]
      return if collection_excluded?(name.to_sym)
      collections[name] = Collection.new(name, &block)
      collections[name].add_feature_params(features(name))
      collections[name].generate
    end

    def collection_excluded?(name)
      false
    end

    def features(collection_name)
      []
    end

    # Generate a root route for API docs
    get '/api/docs\/?' do
      respond_to do |format|
        format.html { haml :'docs/index' }
        format.xml { haml :'docs/index' }
      end
    end

    module Helpers
      def query_url(url, params)
        return url if params.nil? || params.empty?
        url + "?#{URI.escape(params.collect{|k,v| "#{k}=#{v}"}.join('&'))}"
      end

      def entry_points
        collections.values.inject([]) do |m, coll|
          url = url_for coll.operations[:index].path, :full
          m << [ coll.name, url ]
        end
      end
    end
  end
end

class String
  # Rails defines this for a number of other classes, including Object
  # see activesupport/lib/active_support/core_ext/object/blank.rb
  def blank?
      self !~ /\S/
  end

  # Title case.
  #
  #   "this is a string".titlecase
  #   => "This Is A String"
  #
  # CREDIT: Eliazar Parra
  # Copied from facets
  def titlecase
    gsub(/\b\w/){ $`[-1,1] == "'" ? $& : $&.upcase }
  end

  def pluralize
    self + "s"
  end

  def singularize
    self.gsub(/s$/, '')
  end

  def underscore
      gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr("-", "_").
          downcase
  end
end
