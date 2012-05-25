module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListDependenciesFlat
  # TODO: Delete this.
  def implemented?
    return true
  end

  def execute()
    packages = gather_package_dependency_configurations()

    if packages.empty? and $stdout.tty?
      puts '<no dependencies>'
    else
      strings = derive_package_strings(packages)

      puts strings.uniq.sort.join("\n")
    end

    return 0
  end
end
