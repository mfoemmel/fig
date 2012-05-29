require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'
require 'fig/command/action/role/publish'
require 'fig/logging'
require 'fig/user_input_error'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Publish
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction
  include Fig::Command::Action::Role::Publish

  def options()
    return %w<--publish>
  end

  def remote_operation_necessary?()
    return true
  end

  def execute()
    publish_preflight()

    Fig::Logging.info "Checking status of #{@descriptor.to_string()}..."

    package_description =
      Fig::PackageDescriptor.format(@descriptor.name, @descriptor.version, nil)
    if @execution_context.repository.list_remote_packages.include?(
      package_description
    )
      Fig::Logging.info "#{@descriptor.to_string()} has already been published."

      if not @force
        raise UserInputError.new(
          'Use the --force option if you really want to overwrite.'
        )
      else
        Fig::Logging.info 'Overwriting...'
      end
    end

    Fig::Logging.info "Publishing #{@descriptor.to_string()}."
    @execution_context.repository.publish_package(
      @publish_statements, @descriptor, false
    )

    return 0
  end
end
