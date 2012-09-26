# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/grammar_spec_helper')

describe 'Fig' do
  describe %q<uses the correct grammar version in the package definition created for publishing> do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    shared_examples_for 'environment variable option' do
      |assignment_type|

      it 'with simple value' do
        fig(
          [%w< --publish foo/1.2.3>, "--#{assignment_type}", 'VARIABLE=VALUE'],
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
              %w< --publish foo/1.2.3>,
              "--#{assignment_type}",
              "VARIABLE=#{quote}foo bar#{quote}"
            ],
            :fork => false
          )

          out, * = check_published_grammar_version(1)

          out.should =~ / \b #{assignment_type} \s+ VARIABLE='foo[ ]bar' /x
        end
      end

      {
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
          %q<VARIABLE=foo#bar>,
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
      }.each do
        |expected, inputs|

        result, version = *expected

        inputs.each do
          |value|

          it "with «#{value}»" do
            fig(
              [ %w< --publish foo/1.2.3>, "--#{assignment_type}", value ],
              :fork => false
            )

            out, * = check_published_grammar_version(version)

            out.should =~ / \b #{assignment_type} \s+ #{Regexp.quote result} /x
          end
        end
      end

      {
        'unquoted'        => %q<>,
        'double quoted'   => %q<">
      }.each do
        |name, quote|

        it "with #{name}, unescaped at sign, but forced to v1 grammar" do
          fig(
            [
              %w< --publish foo/1.2.3>,
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

    describe 'for --set' do
      it_behaves_like 'environment variable option', 'set'
    end

    describe 'for --append' do
      it_behaves_like 'environment variable option', 'append'
    end
  end
end

# vim: set fileencoding=utf8 :
