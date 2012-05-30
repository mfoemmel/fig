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

  def configure(options)
    @descriptor                   = options.descriptor
    @environment_statements       = options.environment_statements
    @package_contents_statements  = options.package_contents_statements
    @force                        = options.force?

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

    # TODO: fail on environment statements && --file because the --file will
    # get ignored as far as statements are concerned.
    publish_statements = nil
    if not @environment_statements.empty?
      @publish_statements =
        @package_contents_statements +
        [
          Fig::Statement::Configuration.new(
            nil,
            nil,
            Fig::Package::DEFAULT_CONFIG,
            @environment_statements
          )
        ]
    elsif not @package_contents_statements.empty?
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
end
