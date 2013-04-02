module Fig; end
module Fig::Deparser; end

# Handles serializing of statements in the v2 grammar.
module Fig::Deparser::V2Base
  def include_file(statement)
    path = statement.path
    quote = (path.include?(%q<'>) && ! path.include?(%q<">)) ? %q<"> : %q<'>

    add_indent

    @text << 'include-file '
    @text << quote
    @text << path.gsub('\\', ('\\' * 4)).gsub(quote, "\\\\#{quote}")
    @text << quote
    if ! statement.config_name.nil?
      @text << ':'
      @text << statement.config_name
    end
    @text << "\n"

    return
  end
end
