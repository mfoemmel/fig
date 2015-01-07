# coding: utf-8

require 'rspec/core/formatters/documentation_formatter'

class SeedSpitter < RSpec::Core::Formatters::DocumentationFormatter

  def start(*)
    super
    output.puts "\nSeed: #{RSpec.configuration.seed}"
  end

end
