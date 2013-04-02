module Fig; end

# Metadata about a package definition file that hasn't been read yet.
class Fig::NotYetParsedPackage
  attr_accessor :descriptor
  attr_accessor :working_directory
  attr_accessor :include_file_base_directory
  attr_accessor :source_description
  attr_accessor :unparsed_text

  def extended_source_description()
    if source_description
      if source_description.start_with? working_directory
        return source_description
      end

      extended = source_description
      if working_directory != '.'
        extended << " (#{working_directory})"
      end

      return extended
    end

    return working_directory
  end
end
