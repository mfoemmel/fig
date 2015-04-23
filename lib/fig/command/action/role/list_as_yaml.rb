# coding: utf-8

require 'yaml'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

# Requires a #set_up_object_to_be_serialized method.
module Fig::Command::Action::Role::ListAsYAML
  def execute()
    set_up_object_to_be_serialized

    YAML.dump @object_to_be_serialized, $stdout

    return Fig::Command::Action::EXIT_SUCCESS
  end
end
