# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/grammar_spec_helper')

describe 'Fig' do
  describe %q<uses the correct grammar version in the package definition created for publishing> do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    ENVIRONMENT_VARIABLE_PUBLISHED_QUOTING_EXAMPLES = {
      [%q<VARIABLE='foo\'bar'>, 1] => [
        %q<VARIABLE=foo\'bar>,
        %q<VARIABLE="foo'bar">,
        %q<VARIABLE='foo\'bar'>
      ],
      [%q<VARIABLE='foo"bar'>,  1] => [
        %q<VARIABLE=foo\"bar>,
        %q<VARIABLE="foo\"bar">,
        %q<VARIABLE='foo"bar'>
      ],
      [%q<VARIABLE='foo#bar'>,  1] => [
        %q<VARIABLE="foo#bar">,
        %q<VARIABLE='foo#bar'>
      ],
      [%q<VARIABLE=foo@bar>,    0] => [
        %q<VARIABLE=foo@bar>,
        %q<VARIABLE="foo@bar">,
      ],
      [%q<VARIABLE=foo\@bar>,   0] => [
        %q<VARIABLE=foo\@bar>,
        %q<VARIABLE="foo\@bar">,
        %q<VARIABLE='foo@bar'>
      ],
      [%q<VARIABLE=foo\\\\bar>,   0] => [
        %q<VARIABLE=foo\\\\bar>,
        %q<VARIABLE="foo\\\\bar">,
        %q<VARIABLE='foo\\\\bar'>
      ]
    }

    shared_examples_for 'environment variable option' do
      |assignment_type|

      it 'with simple value' do
        fig(
          [%w<--publish foo/1.2.3>, "--#{assignment_type}", 'VARIABLE=VALUE'],
          :fork => false
        )

        out, * = check_published_grammar_version(0)

        out.should =~ / \b #{assignment_type} \s+ VARIABLE=VALUE \b /x
      end

      {
        'unquoted'        => %q<>,
        'double quoted'   => %q<">,
        'single quoted'   => %q<'>
      }.each do
        |name, quote|

        it "with #{name} whitespace" do
          fig(
            [
              %w<--publish foo/1.2.3>,
              "--#{assignment_type}",
              "VARIABLE=#{quote}foo bar#{quote}"
            ],
            :fork => false
          )

          out, * = check_published_grammar_version(1)

          out.should =~ / \b #{assignment_type} \s+ VARIABLE='foo[ ]bar' /x
        end
      end

      ENVIRONMENT_VARIABLE_PUBLISHED_QUOTING_EXAMPLES.each do
        |expected, inputs|

        result, version = *expected

        inputs.each do
          |value|

          it "with «#{value}»" do
            fig(
              [ %w<--publish foo/1.2.3>, "--#{assignment_type}", value ],
              :fork => false
            )

            out, * = check_published_grammar_version(version)

            out.should =~ / \b #{assignment_type} \s+ #{Regexp.quote result} /x
          end
        end
      end

      it "with «VARIABLE=foo#bar»" do
        fig(
          [
            %w<--publish foo/1.2.3>,
            "--#{assignment_type}",
            %q<VARIABLE=foo#bar>
          ],
          :fork => false
        )

        out, * = check_published_grammar_version(1)

        out.should =~ / \b #{assignment_type} \s+ VARIABLE='foo[#]bar' /x
      end

      {
        'unquoted'        => %q<>,
        'double quoted'   => %q<">
      }.each do
        |name, quote|

        it "with #{name}, unescaped at sign, but forced to v1 grammar" do
          fig(
            [
              %w<--publish foo/1.2.3>,
              "--#{assignment_type}",
              'VARIABLE_WITH_WHITESPACE_TO_FORCE=v1 grammar',
              "--#{assignment_type}",
              "VARIABLE=#{quote}foo@bar#{quote}"
            ],
            :fork => false
          )

          out, * = check_published_grammar_version(1)

          out.should =~ / \b #{assignment_type} \s+ VARIABLE="foo@bar" /x
        end
      end
    end

    ILLEGAL_CHARACTERS_IN_V0_PATH_STATEMENTS = %w< ; : < > | >

    describe 'for --set' do
      it_behaves_like 'environment variable option', 'set'

      ILLEGAL_CHARACTERS_IN_V0_PATH_STATEMENTS.each do
        |character|

        it "for «#{character}»" do
          fig(
            [
              %w<--publish foo/1.2.3 --set>,
              "VARIABLE=#{character}"
            ],
            :fork => false
          )

          out, * = check_published_grammar_version(0)

          out.should =~ / \b set \s+ VARIABLE=#{Regexp.quote character} [^'] /x
        end
      end
    end

    describe 'for --append' do
      it_behaves_like 'environment variable option', 'append'

      ILLEGAL_CHARACTERS_IN_V0_PATH_STATEMENTS.each do
        |character|

        it "for «VARIABLE=#{character}»" do
          fig(
            [
              %w<--publish foo/1.2.3 --append>,
              "VARIABLE=#{character}"
            ],
            :fork => false
          )

          out, * = check_published_grammar_version(1)

          out.should =~ / \b append \s+ VARIABLE='#{Regexp.quote character}' /x
        end
      end
    end

    shared_examples_for 'environment variable statement' do
      |assignment_type|

      it 'with simple value' do
        out, * = check_published_grammar_version(0, <<-"END_INPUT")
          grammar v1
          config default
            #{assignment_type} VARIABLE=VALUE
          end
        END_INPUT

        out.should =~ / \b #{assignment_type} \s+ VARIABLE=VALUE \b /x
      end

      {
        'double quoted'   => %q<">,
        'single quoted'   => %q<'>
      }.each do
        |name, quote|

        it "with #{name} whitespace" do
          out, * = check_published_grammar_version(1, <<-"END_INPUT")
            grammar v1
            config default
              #{assignment_type} VARIABLE=#{quote}foo bar#{quote}
            end
          END_INPUT

          out.should =~ / \b #{assignment_type} \s+ VARIABLE='foo[ ]bar' /x
        end
      end

      ENVIRONMENT_VARIABLE_PUBLISHED_QUOTING_EXAMPLES.each do
        |expected, inputs|

        result, version = *expected

        inputs.each do
          |value|

          it "with «#{value}»" do
            out, * = check_published_grammar_version(version, <<-"END_INPUT")
              grammar v1
              config default
                #{assignment_type} #{value}
              end
            END_INPUT

            out.should =~ / \b #{assignment_type} \s+ #{Regexp.quote result} /x
          end
        end
      end
    end

    describe 'for set statement in v1 grammar' do
      it_behaves_like 'environment variable statement', 'set'

      ILLEGAL_CHARACTERS_IN_V0_PATH_STATEMENTS.each do
        |character|

        it "for «#{character}»" do
          out, * = check_published_grammar_version(0, <<-"END_INPUT")
            grammar v1
            config default
              set VARIABLE=#{character}
            end
          END_INPUT

          out.should =~ / \b set \s+ VARIABLE=#{Regexp.quote character} [^'] /x
        end
      end
    end

    describe 'for append statement in v1 grammar' do
      it_behaves_like 'environment variable statement', 'append'

      ILLEGAL_CHARACTERS_IN_V0_PATH_STATEMENTS.each do
        |character|

        it "for «#{character}»" do
          out, * = check_published_grammar_version(1, <<-"END_INPUT")
            grammar v1
            config default
              append VARIABLE=#{character}
            end
          END_INPUT

          out.should =~ / \b append \s+ VARIABLE='#{Regexp.quote character}' /x
        end
      end
    end
  end
end

# vim: set fileencoding=utf8 :
