require 'Forwardable'

module Appium
  module Device
    extend Forwardable

    NoArgMethods = {
      post: {
        shake: 'session/:session_id/appium/device/shake',
        launch: 'session/:session_id/appium/app/launch',
        closeApp: 'session/:session_id/appium/app/close',
        reset: 'session/:session_id/appium/app/reset'
      },
      get: {
        current_activity: 'session/:session_id/appium/device/current_activity',
        current_context: 'session/:session_id/context',
        app_strings: 'session/:session_id/appium/app/strings',
        available_contexts: 'session/:session_id/contexts',
      }
    }

    # @!method app_strings
    #   Return the hash of all localization strings.
    #   ```ruby
    #   app_strings #=> "TransitionsTitle"=>"Transitions", "WebTitle"=>"Web"
    #   ```

    # @!method background_app
    #  Backgrounds the app for a set number of seconds.
    #  This is a blocking application
    # @param seconds (int) How many seconds to background the app for.

    # @!method current_activity

    # @!method launch
    #   Start the simulator and applicaton configured with desired capabilities  

    # @!method reset
    #   Reset the device, relaunching the application.

    # @!method shake
    #   Cause the device to shake

    class << self
      def extended(mod)
        extend_webdriver_with_forwardable
        
        NoArgMethods.each_pair do |verb, pair|
          pair.each_pair { |command, path| add_endpoint_method command, path, verb }
        end

        add_endpoint_method(:lock, 'session/:session_id/appium/device/lock') do
          def lock(duration)
            execute :lock, {}, :seconds => duration
          end
        end

        add_endpoint_method(:install, 'session/:session_id/appium/device/install_app') do
          def install(path)
            execute :install, {}, :appPath => path
          end
        end

        add_endpoint_method(:remove, 'session/:session_id/appium/device/remove_app') do
          def remove(id)
            execute :remove, {}, :appId => id
          end
        end

        add_endpoint_method(:is_installed?, 'session/:session_id?/appium/device/app_installed') do
          def is_installed?(app_id)
            execute :is_installed?, {}, :bundleId => app_id
          end
        end

        add_endpoint_method(:background_app, 'session/:session_id/appium/app/background') do
          def background_app(duration)
            execute :background_app, {}, :seconds => duration
          end
        end
        
        add_endpoint_method(:current_context=, 'session/:session_id/context') do
          def current_context=(context=null)
            execute :current_context=, {}, :context => context
          end
        end
      end 

      def add_endpoint_method(method, path, verb=:post)
        if block_given?
          # &Proc.new with no args passes the passed_in block
          # Because creating Procs from blocks is slow
          create_bridge_command method, verb, path, &Proc.new
        else
          create_bridge_command method, verb, path
        end

        delegate_driver_method method
        delegate_appium_driver_method method
      end 

      def extend_webdriver_with_forwardable
        return if Selenium::WebDriver::Driver.kind_of? Forwardable
        Selenium::WebDriver::Driver.class_eval do
          extend Forwardable
        end
      end

      def delegate_driver_method(method)
        return if Selenium::WebDriver::Driver.method_defined? method
        Selenium::WebDriver::Driver.class_eval { def_delegator :@bridge, method}
      end

      def delegate_appium_driver_method(method)
        def_delegator :@driver, method
      end

      def create_bridge_command(method, verb, path)
        # Don't clobber methods that are moved into Selenium
        log_reimplemented_warning(method, path) if selenium_has method

        Selenium::WebDriver::Remote::Bridge.class_eval do
          command method, verb, path
          if block_given?
            class_eval &Proc.new
          else
            define_method(method) {execute method}
          end
        end
      end

      def selenium_has(method)
        Selenium::WebDriver::Remote::Bridge.method_defined? method
      end

      def log_reimplemented_warning(method, path)
        msg = "Selenium::WebDriver has now implemented the `#{method}` method."
        if Selenium::WebDriver::Remote::COMMANDS[method][1] == path
          msg << " It may no longer function as expected"
        else
          msg << " It no longer uses the same endpoint,"
          msg << " so it probably won't do what you expect anymore."
        end
        msg << " Raise an issue at http://www.github.com/appium/ruby_lib if so."
        Appium::Logger.warn msg
      end
    end

    def within_context(context)
      existing_context = current_context
      yield if block_given?
      current_context = existing_context
    end

    def switch_to_default_context
      current_context = nil
    end
  end
end