require 'fig/userinputerror'

module Fig
  # An issue with a stored package, i.e. not a package.fig in the current
  # directory.
  class PackageError < UserInputError
  end
end
