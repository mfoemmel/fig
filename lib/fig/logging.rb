require 'log4r'

module Fig; end

module Fig::Logging
  def self.initialize_logging(
    config_file = nil,
    log_level = nil,
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

    if not log_level.nil?
      assign_log_level(logger, log_level)
    end

    return
  end

  private

  def self.assign_log_level(logger, level)
    string_to_level_mapping = {
      'off'   => Log4r::OFF,
      'fatal' => Log4r::FATAL,
      'error' => Log4r::ERROR,
      'warn'  => Log4r::WARN,
      'info'  => Log4r::INFO,
      'debug' => Log4r::DEBUG,
      'all'   => Log4r::ALL
    }
    logger.level = string_to_level_mapping[level]
    return nil
  end

end
