require 'log4r'

module Fig; end

module Fig::Logging

  @@logger = Log4r::Logger.new('initial')

  STRING_TO_LEVEL_MAPPING = {
    'off'   => Log4r::OFF,
    'fatal' => Log4r::FATAL,
    'error' => Log4r::ERROR,
    'warn'  => Log4r::WARN,
    'info'  => Log4r::INFO,
    'debug' => Log4r::DEBUG,
    'all'   => Log4r::ALL
  }

  def self.initialize_pre_configuration(log_level=nil)
    assign_log_level(@@logger, log_level)
    setup_default_outputter(@@logger)
  end

  def self.initialize_post_configuration(
    config_file = nil,
    log_level = nil,
    suppress_default_configuration = false
  )
    @@logger = Log4r::Logger.new('fig')

    if config_file
      raise NotImplementedError, %q<Haven't handled config files yet.>
    elsif not suppress_default_configuration
      setup_default_outputter(@@logger)
    end

    assign_log_level(@@logger, log_level)

    return
  end

  def self.fatal(*message)
    @@logger.fatal message
  end

  def self.fatal?()
    return @@logger.fatal?
  end

  def self.error(*message)
    @@logger.error message
  end

  def self.error?()
    return @@logger.error?
  end

  def self.warn(*message)
    @@logger.warn message
  end

  def self.warn?()
    return @@logger.warn?
  end

  def self.info(*message)
    @@logger.info message
  end

  def self.info?()
    return @@logger.info?
  end

  def self.debug(*message)
    @@logger.debug message
  end

  def self.debug?()
    return @@logger.debug?
  end

  private

  def self.assign_log_level(logger, level)
    return if level.nil?
    logger.level = STRING_TO_LEVEL_MAPPING[level]
    return
  end

  def self.setup_default_outputter(logger)
    outputter = Log4r::Outputter.stdout
    logger.add outputter
    outputter.formatter = Log4r::PatternFormatter.new :pattern => '%M'
  end
end
