# Common configuration for SimpleCov for both RSpec and bin/fig.

SimpleCov.merge_timeout 2 * 60 * 60 # 2 hours

class FigFileFilter < SimpleCov::Filter
  def matches?(source_file)
    return source_file.filename =~ %r<\bspec\b>
  end
end
SimpleCov.add_filter(FigFileFilter.new(nil))
