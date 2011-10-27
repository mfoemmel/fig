require 'log4r'

module Fig; end

module Fig::Logging
  def self.initialize_logging(
    config_file = nil,
    suppress_default_configuration = false
  )
    logger = Log4r::Logger.new('fig')

    if config_file
      raise NotImplementedError, %q<Haven't handled config files yet.>
    elsif not suppress_default_configuration
      outputter = Log4r::Outputter.stdout
      logger.add outputter
      outputter.formatter = Log4r::PatternFormatter.new :pattern => '%M'
    end

    return
  end
end
