require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'
require 'fig/command/action/role/publish'
require 'fig/logging'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::PublishLocal
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction
  include Fig::Command::Action::Role::Publish

  def options()
    return %w<--publish-local>
  end

  def execute()
    publish_preflight()

    Fig::Logging.info "Publishing #{@descriptor.to_string()}."
    @execution_context.repository.publish_package(
      @publish_statements, @descriptor, :publish_local
    )

    return EXIT_SUCCESS
  end
end
