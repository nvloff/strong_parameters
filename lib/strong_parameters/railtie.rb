require 'rails/railtie'

module StrongParameters
  class Railtie < ::Rails::Railtie
    config.strong_parameters = ActiveSupport::OrderedOptions.new

    if config.respond_to?(:app_generators)
      config.app_generators.scaffold_controller = :strong_parameters_controller
    else
      config.generators.scaffold_controller = :strong_parameters_controller
    end

    initializer "strong_parameters.strict", :group => :all do |app|
      app.config.strong_parameters.strict ||= false
    end

    initializer "strong_parameters.set_config" do |app|
      ActionController::Parameters.strict_config = app.config.strong_parameters.strict
    end

  end
end
