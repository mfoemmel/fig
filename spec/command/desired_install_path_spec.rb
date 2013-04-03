require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Fig' do
  describe 'desired-install-path' do
    let(:test_install_path) { "#{FIG_SPEC_BASE_DIRECTORY}/install-path" }

    before(:each) do
      clean_up_test_environment
      set_up_test_environment

      input = <<-"END_SOURCE_PACKAGE"
        grammar v3

        resource #{FIG_FILE_GUARANTEED_TO_EXIST}

        desired-install-path #{test_install_path}

        config default
          set RUNTIME=@
        end
      END_SOURCE_PACKAGE

      fig %w<--publish wants-absolute-path/1.2.3>, input

      input = <<-"END_CLIENT_PACKAGE"
        grammar v3

        config do-not-use-install-path
          include wants-absolute-path/1.2.3
        end
        config use-install-path
          use-desired-install-paths
          include wants-absolute-path/1.2.3
        end
      END_CLIENT_PACKAGE

      fig %w<--publish client/1.2.3>, input
    end

    it %q<warns, but works, if use-desired-install-paths not in effect> do
      out, err, * =
        fig %w<client/1.2.3:do-not-use-install-path --update --get RUNTIME>

      out.should be_start_with FIG_HOME
      err.should =~ %r<
        \b wants-absolute-path/1[.]2[.]3 \b
        .*
        \b desired-install-path \b
      >xm

      File.exist?(test_install_path).should be_false
    end

    it %q<works if use-desired-install-paths is in effect> do
      # We need to test that, even if we have previously retrieved the package,
      # we install to the absolute path.
      fig %w<client/1.2.3:do-not-use-install-path --update -- echo>
      File.exist?(test_install_path).should be_false

      out, err, * =
        fig %w<client/1.2.3:use-install-path --update --get RUNTIME>

      out.should be_start_with test_install_path
      err.should == ''
      pending 'Need to separate archive downloading from extraction.'
      File.directory?(test_install_path).should be_true
    end
  end
end
