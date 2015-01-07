# coding: utf-8

module Fig
  # Bad user!  Bad!  (Indicates we should exit with an error, but because it's
  # a user caused issue, it's not a bug and should not produce a stack trace.)
  class UserInputError < StandardError
  end
end
