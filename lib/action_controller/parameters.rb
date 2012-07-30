require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'action_controller'

module ActionController
  class ParameterMissing < IndexError
    attr_reader :param

    def initialize(param)
      @param = param
      super("key not found: #{param}")
    end
  end

  class ParameterForbidden < IndexError
    attr_reader :param

    def initialize(param)
      @param = param
      super("key forbidden: #{param}")
    end
  end

  class Parameters < ActiveSupport::HashWithIndifferentAccess
    attr_accessor :permitted
    alias :permitted? :permitted

    def initialize(attributes = nil)
      super(attributes)
      @permitted = false
      @strict = false
    end

    def permit!
      @permitted = true
      self
    end

    def require(key)
      self[key].presence || raise(ActionController::ParameterMissing.new(key))
    end

    alias :required :require

    def strict!
      @strict = true
      self
    end

    def permit(*filters)
      check_parameters(*filters) if @strict
      permit_parameters(*filters)
    end

    def [](key)
      convert_hashes_to_parameters(key, super)
    end

    def fetch(key, *args)
      convert_hashes_to_parameters(key, super)
    rescue KeyError
      raise ActionController::ParameterMissing.new(key)
    end

    def slice(*keys)
      self.class.new(super)
    end

    def dup
      super.tap do |duplicate|
        duplicate.instance_variable_set :@permitted, @permitted
      end
    end

    protected
      def check_parameters(*filters)
        param_keys = filters.map { |filter| filter.is_a?(Hash) ? filter.keys : filter }
        param_keys = param_keys.flatten.map(&:to_s)
        diff = self.keys - param_keys

        # exit on first mismatch
        raise(ActionController::ParameterForbidden.new(diff)) unless diff.empty?

        filters.each do |filter|
          if filter.is_a?(Hash)
            filter.each do |key,value|
              params = self.class.new(self[key])
              params.check_parameters(*Array.wrap(filter[key]))
            end
          end
        end

      end

      def permit_parameters(*filters)
        params = self.class.new

        filters.each do |filter|
          case filter
          when Symbol, String then
            params[filter] = self[filter] if has_key?(filter)
          when Hash then
            self.slice(*filter.keys).each do |key, value|
              return unless value

              key = key.to_sym

              params[key] = each_element(value) do |value|
                # filters are a Hash, so we expect value to be a Hash too
                next if filter.is_a?(Hash) && !value.is_a?(Hash)

                value = self.class.new(value) if !value.respond_to?(:permit)

                value.permit_parameters(*Array.wrap(filter[key]))
              end
            end
          end
        end

        params.permit!
      end

    private
      def convert_hashes_to_parameters(key, value)
        if value.is_a?(Parameters) || !value.is_a?(Hash)
          value
        else
          # Convert to Parameters on first access
          self[key] = self.class.new(value)
        end
      end

      def each_element(object)
        if object.is_a?(Array)
          object.map { |el| yield el }.compact
        else
          yield object
        end
      end
  end

  module StrongParameters
    extend ActiveSupport::Concern

    included do
      rescue_from(ActionController::ParameterMissing) do |parameter_missing_exception|
        render :text => "Required parameter missing: #{parameter_missing_exception.param}", :status => :bad_request
      end

      rescue_from(ActionController::ParameterForbidden) do |parameter_forbidden_exception|
        render :text => "Parameters forbidden: #{parameter_forbidden_exception.param.join(' ')}", :status => :bad_request
      end
    end

    def params
      @_params ||= Parameters.new(request.parameters)
    end

    def params=(val)
      @_params = val.is_a?(Hash) ? Parameters.new(val) : val
    end
  end
end

ActionController::Base.send :include, ActionController::StrongParameters
