# coding: utf-8

require 'fig/command/package_loader'
require 'fig/package'
require 'fig/statement/configuration'
require 'fig/user_input_error'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::Publish
  def descriptor_requirement()
    return :required
  end

  def allow_both_descriptor_and_file?()
    # Actually, publishing requires a descriptor and another source of the base
    # package.
    return true
  end

  def cares_about_asset_options?()
    return true
  end

  def modifies_repository?()
    return true
  end

  def load_base_package?()
    return true
  end

  def base_package_can_come_from_descriptor?()
    return false
  end

  def register_base_package?()
    return false
  end

  def apply_config?()
    return true
  end

  def apply_base_config?()
    return nil # don't care
  end

  # Is this a publish action?
  def publish?()
    return true
  end

  def configure(options)
    @descriptor             = options.descriptor
    @environment_statements = options.environment_statements
    @asset_statements       = options.asset_statements
    @force                  = options.force?

    return
  end

  def publish_preflight()
    if @descriptor.name.nil? || @descriptor.version.nil?
      raise Fig::UserInputError.new(
        'Please specify a package name and a version name.'
      )
    end
    if @descriptor.name == '_meta'
      raise Fig::UserInputError.new(
        %q<Due to implementation issues, cannot create a package named "_meta".>
      )
    end

    if not @environment_statements.empty?
      derive_publish_statements_from_environment_statements
    elsif not @asset_statements.empty?
      raise Fig::UserInputError.new(
        '--resource/--archive options were specified, but no --set/--append option was given. Will not publish.'
      )
    else
      if not @execution_context.base_package.statements.empty?
        @publish_statements = @execution_context.base_package.statements
      else
        raise Fig::UserInputError.new('Nothing to publish.')
      end
    end

    return
  end

  def derive_publish_statements_from_environment_statements
    if @execution_context.package_loaded_from_path
      message = 'Cannot publish based upon both a package definition file ('
      message << @execution_context.package_loaded_from_path
      message << ') and --set/--append options.'

      if @execution_context.package_source_description ==
        Fig::Command::PackageLoader::DEFAULT_PACKAGE_FILE ||
        @execution_context.package_source_description ==
        Fig::Command::PackageLoader::DEFAULT_APPLICATION_FILE ||

        message << "\n\n"
        message << 'You can avoid loading '
        message << @execution_context.package_source_description
        message << ' by using the --no-file option.'
      end

      raise Fig::UserInputError.new(message)
    end

    @publish_statements =
      @asset_statements +
      [
        Fig::Statement::Configuration.new(
          nil,
          nil,
          Fig::Package::DEFAULT_CONFIG,
          @environment_statements
        )
      ]

    return
  end
end
