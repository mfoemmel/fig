require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/environment'
require 'fig/package'
require 'fig/packagedescriptor'
require 'fig/statement/configuration'
require 'fig/statement/set'

DEPENDED_UPON_PACKAGE_NAME = 'depended-upon'

def standard_package_version(name)
  return "#{name}-version"
end

def new_example_package(environment, name, extra_statements, variable_value)
  statements = extra_statements +
      [
        Fig::Statement::Configuration.new(
          Fig::Package::DEFAULT_CONFIG, []
        )
      ]

  package =
    Fig::Package.new(
      name, standard_package_version(name), "#{name}-directory", statements
    )

  environment.register_package(package)

  set_statement = Fig::Statement::Set.new(
    "WHATEVER_#{name.upcase}", variable_value
  )
  environment.apply_config_statement(package, set_statement, nil)

  return package
end

def new_example_environment(variable_value = 'whatever', retrieve_vars = {})
  retriever_double = double('retriever')
  retriever_double.stub(:with_package_version)
  environment =
    Fig::Environment.new(nil, Fig::EnvironmentVariables.new(false, {'FOO' => 'bar'}), retriever_double)

  if retrieve_vars
    retrieve_vars.each do |name, path|
      environment.add_retrieve( name, path )
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
        Fig::PackageDescriptor.parse(
          "#{DEPENDED_UPON_PACKAGE_NAME}/#{depended_upon_package_version}"
        ),
        [],
        package_name
      )
    ]
    new_example_package(
      environment, package_name, extra_statements, variable_value
    )
  end

  environment.register_package(
    Fig::Package.new(
      'has_command', 'version', 'directory',
      [
        Fig::Statement::Configuration.new(
          Fig::Package::DEFAULT_CONFIG,
          [Fig::Statement::Command.new('echo foo')]
        )
      ]
    )
  )

  return environment
end

def substitute_command(command)
  environment = new_example_environment

  substituted_command = nil
  environment.execute_shell(command) {
    |command_line|
    substituted_command = command_line
  }

  return substituted_command
end

def setup_variables
  variable_arguments = %w<WHATEVER_ONE WHATEVER_TWO WHATEVER_THREE>
  return variable_arguments.map do |var_arg| 
    Fig::OperatingSystem.add_shell_variable_expansion(var_arg)
  end
end

def substitute_variable(variable_value, retrieve_vars = {})
  environment = new_example_environment(variable_value, retrieve_vars)

  output = nil
  variables = setup_variables
  environment.execute_shell([]) {
    output =
      %x[echo #{variables[0]}&& echo #{variables[1]}&& echo #{variables[2]}]
  }

  return output
end

describe 'Environment' do
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

    it 'complains about unknown escapes' do
      expect {
        # Grrr, Ruby syntax: that's three backslashes followed by "f"
        substitute_command %w< bar\\\\\\foo >
      }.to raise_error(/unknown escape/i)
    end
  end

  describe 'package name substitution in variables' do
    it 'does basic @ substitution' do
      output = substitute_variable('@/foobie')

      output.should ==
        "one-directory/foobie\ntwo-directory/foobie\nthree-directory/foobie\n"
    end

    it 'does @ escaping' do
      output = substitute_variable('\\@/foobie')

      output.should == "@/foobie\n@/foobie\n@/foobie\n"
    end

    it 'does retrieve variables [package] substitution' do
      retrieve_vars = {'WHATEVER_ONE' => 'foo.[package].bar.[package].baz'}
      output = substitute_variable('blah', retrieve_vars)

      output.should == "foo.one.bar.one.baz/blah\nblah\nblah\n"
    end

    it 'truncates before //' do
      retrieve_vars = {
        'WHATEVER_ONE'   => 'foo.[package].//./bar.[package].baz',
        'WHATEVER_THREE' => 'phoo.//.bhar'
      }
      output = substitute_variable('blah.//.blez', retrieve_vars)

      output.should == "foo.one.//./bar.one.baz/.blez\nblah.//.blez\nphoo.//.bhar/.blez\n"
    end
  end

  describe 'command execution' do
    it 'issues an error when attempting to execute a command from a config which contains no command' do
      environment = new_example_environment('blah')
      expect {
        environment.execute_config(
          nil, Fig::PackageDescriptor.new('one', nil, nil), nil
        )
      }.to raise_error(Fig::UserInputError)
    end

    it 'executes a command successfully' do
      environment = new_example_environment('blah')
      received_command = nil
      environment.execute_config(
        nil, Fig::PackageDescriptor.new('has_command', nil, nil), []
      ) { |command| received_command = command }
      received_command.should == %w<echo foo>
    end
  end
end
