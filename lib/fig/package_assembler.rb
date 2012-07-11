require 'fig/statement_container'

module Fig; end

# Used for building packages for publishing.
class Fig::PackageAssembler
  include Enumerable
  include Fig::StatementContainer

  attr_reader :statements

  def initialize()
    @statements = []
    @text       = []

    return
  end

  # Argument can either be a single Statement or an array of them.
  def <<(statements)
    @statements << statements
    @statements.flatten!

    return
  end

  # Iterate over the Statements (which means you can enumerate them in any way
  # as well).
  def each(&block)
    return @statements.each(&block)
  end

  # Argument can be a single string or an array of strings
  def add_text(text)
    @text << text
    @text.flatten!

    return
  end

  def assemble_package_definition()
    definition = @text.join("\n")
    definition.gsub!(/\n{3,}/, "\n\n")
    definition.strip!
    definition << "\n"

    return definition
  end
end
