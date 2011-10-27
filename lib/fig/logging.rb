require 'log4r'

module Fig; end

module Fig::Logging
  def self.initialize_logging
    logger = Log4r::Logger.new('fig')

    outputter = Log4r::Outputter.stdout
    logger.add outputter
    outputter.formatter = Log4r::PatternFormatter.new :pattern => '%M'

    return
  end
end
