# coding: utf-8

module Fig
  # A (possibly remote) file that was looked for was not found.  This may or
  # may not actually be a problem; i.e. this may be the result of an existence
  # test.
  class FileNotFoundError < StandardError
    attr_reader :path

    def initialize(message, path)
      super(message)

      @path = path
    end
  end
end
