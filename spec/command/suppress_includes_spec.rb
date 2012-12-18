require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/operating_system'

describe 'Fig' do
  describe 'include processing' do
    let(:publish_from_directory)  { "#{FIG_SPEC_BASE_DIRECTORY}/publish-home" }

    before(:each) do
      clean_up_test_environment
      FileUtils.mkdir_p CURRENT_DIRECTORY

      FileUtils.rm_rf(publish_from_directory)
      FileUtils.mkdir_p(publish_from_directory)

      fig(
        %w<--publish dependency/1.2.3 --append FOO=dependency>,
        :current_directory => publish_from_directory
      )

      input = <<-END
        config default
          include dependency/1.2.3
          include :level-one
          add FOO=default
        end

        config level-one
          include :level-two
          add FOO=level-one
        end

        config level-two
          add FOO=level-two
        end
      END
      fig(
        %w<--publish dependent/1.2.3>,
        input,
        :current_directory => publish_from_directory
      )
    end

    it 'happens by default' do
      # Really, this is just a test of the test setup...
      out, * = fig %w<dependent/1.2.3 --get FOO>
      out.should ==
        "default#{File::PATH_SEPARATOR}level-one#{File::PATH_SEPARATOR}level-two#{File::PATH_SEPARATOR}dependency"
    end

    it 'is limited by --suppress-cross-package-includes' do
      out, * =
        fig %w<dependent/1.2.3 --suppress-cross-package-includes --get FOO>
      out.should ==
        "default#{File::PATH_SEPARATOR}level-one#{File::PATH_SEPARATOR}level-two"
    end

    it 'is blocked by --suppress-all-includes' do
      out, * = fig %w<dependent/1.2.3 --suppress-all-includes --get FOO>
      out.should == 'default'
    end
  end
end
