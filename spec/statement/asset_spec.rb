require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/statement/archive'
require 'fig/statement/resource'

[Fig::Statement::Archive, Fig::Statement::Resource].each do
  |statement_type|

  describe statement_type do
    TEST_KEYWORDS =
      %w<
        add      append    archive  command   end
        include  override  path     resource  retrieve  set
      >.freeze
    TEST_KEYWORDS.each {|keyword| keyword.freeze}

    describe '.validate_and_process_escapes_in_url!()' do
      def test_should_equal_and_should_glob(statement_type, original_url, url)
        block_message = nil

        should_be_globbed =
          statement_type.validate_and_process_escapes_in_url!(url) do
            |message| block_message = message
          end

        url.should                == original_url
        should_be_globbed.should  be_true
        block_message.should      be_nil

        return
      end

      def test_should_equal_and_should_not_glob(statement_type, original_url, url)
        block_message = nil

        should_be_globbed =
          statement_type.validate_and_process_escapes_in_url!(url) do
            |message| block_message = message
          end

        url.should                == original_url
        should_be_globbed.should  be_false
        block_message.should      be_nil

        return
      end

      # "foo * bar": whitespace and glob character
      # "config":    the one keyword we allow to be used everywhere
      [%q<foo * bar>, 'config'].each do
        |original_url|

        it %Q<does not modify [#{original_url}] and says that it should be globbed> do
          test_should_equal_and_should_glob(
            statement_type, original_url, original_url.clone
          )
        end
        it %Q<strips quotes from ["#{original_url}"] and says that it should be globbed> do
          test_should_equal_and_should_glob(
            statement_type, original_url, %Q<"#{original_url}">
          )
        end

        it %Q<strips quotes from ['#{original_url}'] and says that it should not be globbed> do
          test_should_equal_and_should_not_glob(
            statement_type, original_url, %Q<'#{original_url}'>
          )
        end
      end

      it %q<strips quotes from ['foo\bar'] (no escaping in single quoted values) and says that it should not be globbed> do
        test_should_equal_and_should_not_glob(
          statement_type, 'foo\bar', %q<'foo\bar'>
        )
      end

      def test_got_error_message(statement_type, url, error_regex)
        block_message = nil

        statement_type.validate_and_process_escapes_in_url!(url.dup) do
          |message| block_message = message
        end

        block_message.should =~ error_regex

        return
      end

      def test_shouldnt_be_permitted(statement_type, url)
        test_got_error_message(statement_type, url, /isn't permitted/i)

        return
      end

      %w< @ \\' \\" < > | >.each do
        |character|

        it %Q<says [foo #{character} bar] isn't allowed> do
          test_shouldnt_be_permitted(statement_type, %Q<foo #{character} bar>)
        end
        it %Q<says ["foo #{character} bar"] isn't allowed> do
          test_shouldnt_be_permitted(statement_type, %Q<"foo #{character} bar">)
        end
        it %Q<says ['foo #{character} bar'] isn't allowed> do
          test_shouldnt_be_permitted(statement_type, %Q<'foo #{character} bar'>)
        end
      end

      def test_is_a_keyword(statement_type, url)
        test_got_error_message(statement_type, url, /is a keyword/i)

        return
      end

      TEST_KEYWORDS.each do
        |keyword|

        it %Q<says [#{keyword}] is a keyword> do
          test_is_a_keyword(statement_type, keyword)
        end
        it %Q<says ["#{keyword}"] is a keyword> do
          test_is_a_keyword(statement_type, %Q<"#{keyword}">)
        end
        it %Q<says ['#{keyword}'] is a keyword> do
          test_is_a_keyword(statement_type, %Q<'#{keyword}'>)
        end
      end

      %w< " "xxx xxx" "\" "\\ >.each do
        |url|

        it %Q<says [#{url}] has unbalanced quotes> do
          test_got_error_message(
            statement_type, url, /has unbalanced double quotes/i
          )
        end
      end

      %w< ' 'xxx xxx' >.each do
        |url|

        it %Q<says [#{url}] has unbalanced quotes> do
          test_got_error_message(
            statement_type, url, /has unbalanced single quotes/i
          )
        end
      end

      %w< xxx'xxx xxx"xxx >.each do
        |url|

        it %Q<says [#{url}] has unescaped quote> do
          test_got_error_message(statement_type, url, /unescaped .* quote/i)
        end
      end

      %w< \\ xxx\\ >.each do
        |url|

        it %Q<says [#{url}] has incomplete escape> do
          test_got_error_message(statement_type, url, /incomplete escape/i)
        end
      end

      %w< \\n "\\n" >.each do
        |url|

        it %Q<says [#{url}] has bad escape> do
          test_got_error_message(statement_type, url, /bad escape/i)
        end
      end

      %w< foo\\\\\\\\bar\\\\baz "foo\\\\\\\\bar\\\\baz" >.each do
        |original_url|

        it %Q<collapses the backslashes in [#{original_url}]> do
          url           = original_url.clone
          block_message = nil

          should_be_globbed =
            statement_type.validate_and_process_escapes_in_url!(url) do
              |message| block_message = message
            end

          url.should                == 'foo\\\\bar\\baz'
          should_be_globbed.should  be_true
          block_message.should      be_nil
        end
      end
    end
  end
end
