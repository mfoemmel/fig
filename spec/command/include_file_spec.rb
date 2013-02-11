require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Fig' do
  def set_up_include_files()
    cleanup_home_and_remote
    base_included = "#{CURRENT_DIRECTORY}/included"
    sub_included = "#{base_included}/subdirectory"

    FileUtils.mkdir_p sub_included

    write_file "#{sub_included}/leaf.fig", <<-END_PACKAGE
      grammar v2
      config default
        set SUB_PACKAGE=default
        set SHOULD_BE_OVERRIDDEN='not overridden'
      end

      config non-default
        set SUB_PACKAGE=non-default
      end

      config not-used
        set SHOULD_NOT_BE_SET='was set'
      end
    END_PACKAGE
    write_file "#{base_included}/peer.fig", <<-END_PACKAGE
      grammar v2
      config default
        set PEER='was set'
        # Note path relative to this file and not to CURRENT_DIRECTORY.
        include-file "subdirectory/leaf.fig":non-default
      end
    END_PACKAGE
    write_file "#{base_included}/base.fig", <<-END_PACKAGE
      grammar v2
      config default
        include-file subdirectory/leaf.fig
        include-file 'peer.fig'

        set SHOULD_BE_OVERRIDDEN=overridden
      end
    END_PACKAGE

    return
  end

  it 'handles include-file' do
    set_up_include_files

    out, * = fig(
      [
        '--include-file', "#{CURRENT_DIRECTORY}/included/base.fig",
        '--list-variables',
      ],
      :fork => false,
    )
    out.should =~ /^PEER=was set$/
    out.should =~ /^SUB_PACKAGE=non-default$/
    out.should =~ /^SHOULD_BE_OVERRIDDEN=overridden$/
    out.should_not =~ /^SHOULD_NOT_BE_SET=/
  end
end
