require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/environment_variables/case_sensitive'
require 'fig/package'
require 'fig/package_descriptor'
require 'fig/runtime_environment'
require 'fig/statement/command'
require 'fig/statement/configuration'
require 'fig/statement/retrieve'
require 'fig/statement/set'

DEPENDED_UPON_PACKAGE_NAME = 'depended_upon'

def standard_package_version(name)
  return "#{name}-version"
end

def new_example_package(environment, name, extra_statements, variable_value)
  statements = extra_statements +
      [
        Fig::Statement::Configuration.new(
          nil, nil, Fig::Package::DEFAULT_CONFIG, []
        )
      ]

  package =
    Fig::Package.new(
      name, standard_package_version(name), "#{name}-directory", statements
    )

  environment.register_package(package)

  # Kind of a cheat: we're creating a "set" statement that isn't in a "config"
  # block and then shoving it through the RuntimeEnvironment directly.
  set_statement = new_example_set_statement(name, variable_value)
  environment.apply_config_statement(package, set_statement, nil)

  return package
end

def new_example_environment(variable_value = 'whatever', retrieve_vars = {})
  maintainer_double = double('working directory maintainer')
  maintainer_double.stub(:switch_to_package_version)
  maintainer_double.stub(:retrieve)
  environment =
    Fig::RuntimeEnvironment.new(
      nil,
      Fig::EnvironmentVariables::CaseSensitive.new({'FOO' => 'bar'}),
      maintainer_double
    )

  if retrieve_vars
    retrieve_vars.each do |name, path|
      tokenized_path = Fig::Statement::Retrieve.tokenize_path path
      environment.add_retrieve(
        Fig::Statement::Retrieve.new(nil, nil, name, tokenized_path)
      )
    end
  end

  depended_upon_package_version =
    standard_package_version(DEPENDED_UPON_PACKAGE_NAME)
  new_example_package(
    environment, DEPENDED_UPON_PACKAGE_NAME, [], variable_value
  )

  %w< one two three >.each do
    |package_name|

    extra_statements = [
      Fig::Statement::Include.new(
        nil,
        nil,
        Fig::PackageDescriptor.parse(
          "#{DEPENDED_UPON_PACKAGE_NAME}/#{depended_upon_package_version}"
        ),
        package_name
      )
    ]
    new_example_package(
      environment, package_name, extra_statements, variable_value
    )
  end

  command = Fig::Statement::Command.new(
    nil,
    nil,
    [
      Fig::Statement::Command.validate_and_process_escapes_in_argument(
        'echo foo'
      )
    ]
  )
  environment.register_package(
    Fig::Package.new(
      'has_command', 'version', 'directory',
      [
        Fig::Statement::Configuration.new(
          nil,
          nil,
          Fig::Package::DEFAULT_CONFIG,
          [command]
        )
      ]
    )
  )

  return environment
end

def new_example_set_statement(name, value)
  parsed_name, parsed_value =
    Fig::Statement::Set.parse_name_value("WHATEVER_#{name.upcase}=#{value}") do
      |description|

      raise StandardError.new(
        %Q<Never should have gotten here.  Description: "#{description}">
      )
    end

  return Fig::Statement::Set.new(nil, nil, parsed_name, parsed_value)
end

def substitute_command(command)
  environment = new_example_environment
  base_package =
    Fig::Package.new('test-package', 'test-version', 'test-directory', [])

  tokenized_command = command.map {
    |argument|

    Fig::Statement::Command.validate_and_process_escapes_in_argument(argument) {
      |error_description| raise error_description
    }
  }

  substituted_command = nil
  environment.expand_command_line(base_package, nil, nil, tokenized_command) {
    |command_line|
    substituted_command = command_line
  }

  return substituted_command
end

def generate_shell_variable_expansions
  variable_arguments = %w<WHATEVER_ONE WHATEVER_TWO WHATEVER_THREE>
  return variable_arguments.map do |var_arg|
    Fig::OperatingSystem.wrap_variable_name_with_shell_expansion(var_arg)
  end
end

def substitute_variable(variable_value, retrieve_vars = {})
  environment = new_example_environment(variable_value, retrieve_vars)
  base_package =
    Fig::Package.new('test-package', 'test-version', 'test-directory', [])

  output = nil
  variables = generate_shell_variable_expansions
  environment.expand_command_line(base_package, nil, nil, []) {
    # No space between the closing curly of an interpolation and the double
    # ampersand due to the way that echo works on MS Windows.
    output =
      %x[echo #{variables[0]}&& echo #{variables[1]}&& echo #{variables[2]}]
  }

  return output
end

describe 'RuntimeEnvironment' do
  before(:all) do
    set_up_test_environment()
  end

  it 'can hand back a variable' do
    environment = new_example_environment

    environment['FOO'].should == 'bar'
  end

  describe 'package name substitution in commands' do
    it 'can replace bare names' do
      substituted_command = substitute_command %w< @one >

      substituted_command.should == %w< one-directory >
    end

    it 'can replace prefixed names' do
      substituted_command = substitute_command %w< something@one >

      substituted_command.should == %w< somethingone-directory >
    end

    it 'can replace multiple names in a single argument' do
      substituted_command = substitute_command %w< @one@two@three >

      substituted_command.should == %w< one-directorytwo-directorythree-directory >
    end

    it 'can replace names in multiple arguments' do
      substituted_command = substitute_command %w< @one @two >

      substituted_command.should == %w< one-directory two-directory >
    end

    it 'can handle simple escaped names' do
      substituted_command = substitute_command %w< \@one\@two >

      substituted_command.should == %w< @one@two >
    end

    it 'can replace name after an escaped name' do
      substituted_command = substitute_command %w< \@one@two >

      substituted_command.should == %w< @onetwo-directory >
    end

    it 'can handle escaped backslash' do
      substituted_command = substitute_command %w< bar\\\\foo >

      substituted_command.should == %w< bar\\foo >
    end

    it 'can handle escaped backslash in front of @' do
      substituted_command = substitute_command %w< bar\\\\@one >

      substituted_command.should == %w< bar\\one-directory >
    end

    it 'can handle escaped backslash in front of escaped @' do
      substituted_command = substitute_command %w< bar\\\\\\@one >

      substituted_command.should == %w< bar\\@one >
    end

    it 'complains about bad escapes' do
      expect {
        # Grrr, Ruby syntax: that's three backslashes followed by "f"
        substitute_command %w< bar\\\\\\foo >
      }.to raise_error(/bad escape/i)
    end
  end

  describe 'package name substitution in variables' do
    it 'does basic @ substitution' do
      output = substitute_variable('@/foobie')

      output.should ==
        "one-directory/foobie\ntwo-directory/foobie\nthree-directory/foobie\n"
    end

    it 'does @ escaping' do
      output = substitute_variable('\\@@/foobie')

      output.should ==
        "@one-directory/foobie\n@two-directory/foobie\n@three-directory/foobie\n"
    end

    it 'does retrieve variables [package] substitution' do
      retrieve_vars = {
        'WHATEVER_ONE' => 'foo.[package].bar.[package].baz',
        'WHATEVER_TWO' => 'foo.[package].bar.[package].baz',
        'WHATEVER_THREE' => 'foo.[package].bar.[package].baz'
      }
      output = substitute_variable(FIG_FILE_GUARANTEED_TO_EXIST, retrieve_vars)

      destination = File.basename(FIG_FILE_GUARANTEED_TO_EXIST)
      output.should ==
        "foo.one.bar.one.baz/#{destination}\nfoo.two.bar.two.baz/#{destination}\nfoo.three.bar.three.baz/#{destination}\n"
    end

    it 'truncates before //' do
      if FIG_FILE_GUARANTEED_TO_EXIST !~
          %r<
            \A
            (.+ [^/]) # Maximally at least two charcters not ending in a slash.
            (
              (?: / [^/]+ ){2} # Slash followed by maximally non-slash, twice.
            )
            \z
          >x
        fail "Test assumes that FIG_FILE_GUARANTEED_TO_EXIST (#{FIG_FILE_GUARANTEED_TO_EXIST}) has at least two parent directories."
      end
      base_path = $1
      to_be_preserved = $2 # Note that this will have a leading slash...

      # ... which means that this will have two slashes in it.
      mangled_path = "#{base_path}/#{to_be_preserved}"

      retrieve_vars = {
        # Just checking that double slashes aren't mangled in the retrieves.
        'WHATEVER_ONE'   => 'foo.[package].//./bar.[package].baz',
        # No WHATEVER_TWO here means that the value should pass through
        # unmolested.
        'WHATEVER_THREE' => 'phoo.//.bhar'
      }
      output = substitute_variable(mangled_path, retrieve_vars)

      output.should == \
        "foo.one.//./bar.one.baz#{to_be_preserved}\n" + # WHATEVER_ONE
        "#{mangled_path}\n"                           + # WHATEVER_TWO
        "phoo.//.bhar#{to_be_preserved}\n"              # WHATEVER_THREE
    end
  end

  describe 'command expansion' do
    it 'issues an error when attempting to expand a command statement from a config which contains no command' do
      environment = new_example_environment(FIG_FILE_GUARANTEED_TO_EXIST)
      expect {
        environment.expand_command_statement_from_config(
          nil, nil, Fig::PackageDescriptor.new('one', nil, nil), nil
        )
      }.to raise_error(Fig::UserInputError)
    end

    it 'expands a command statement successfully' do
      environment = new_example_environment(FIG_FILE_GUARANTEED_TO_EXIST)
      received_command = nil
      environment.expand_command_statement_from_config(
        nil, nil, Fig::PackageDescriptor.new('has_command', nil, nil), []
      ) { |command| received_command = command }
      received_command.should == ['echo foo']
    end
  end
end
