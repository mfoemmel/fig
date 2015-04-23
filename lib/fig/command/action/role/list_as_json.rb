# coding: utf-8

require 'json'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

# Requires a #set_up_object_to_be_serialized method.
module Fig::Command::Action::Role::ListAsJSON
  def execute()
    set_up_object_to_be_serialized

    puts JSON.pretty_generate @object_to_be_serialized

    return Fig::Command::Action::EXIT_SUCCESS
  end
end
