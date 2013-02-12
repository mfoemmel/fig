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
        set SUB_PACKAGE=@/default
        set SHOULD_BE_OVERRIDDEN='not overridden'
      end

      config non-default
        set SUB_PACKAGE=@/non-default
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
    write_file "#{CURRENT_DIRECTORY}/test.fig", <<-END_PACKAGE
      grammar v2
      retrieve SUB_PACKAGE->somewhere
      config default
        include-file 'included/base.fig'
      end
    END_PACKAGE

    return
  end

  it 'handles include-file' do
    set_up_include_files

    out, err, * = fig(
      [
        '--file', "#{CURRENT_DIRECTORY}/test.fig",
        '--update',
        '--list-variables',
      ],
      :fork => false,
    )
    out.should =~ /^PEER=was set$/
    out.should =~ %r<^SUB_PACKAGE=.*subdirectory/non-default$>
    out.should =~ /^SHOULD_BE_OVERRIDDEN=overridden$/
    out.should_not =~ /^SHOULD_NOT_BE_SET=/
    err.should =~ /[Rr]etrieve.*SUB_PACKAGE.*ignored/
  end
end
