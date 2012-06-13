require 'log4r'
require 'log4r/configurator'
require 'log4r/yamlconfigurator'

require 'fig/config_file_error'
require 'fig/log4r_config_error'
require 'fig/log4r/outputter'

module Fig; end

# Logging facility that handles the fact that we may wish to do logging prior
# to Log4r being properly configured.
module Fig::Logging
  if not Log4r::Logger['initial']
    @@logger = Log4r::Logger.new('initial')
  end

  STRING_TO_LEVEL_MAPPING = {
    'off'   => Log4r::OFF,
    'fatal' => Log4r::FATAL,
    'error' => Log4r::ERROR,
    'warn'  => Log4r::WARN,
    'info'  => Log4r::INFO,
    'debug' => Log4r::DEBUG,
    'all'   => Log4r::ALL
  }

  def self.initialize_pre_configuration(log_level = nil)
    log_level ||= 'info'

    assign_log_level(@@logger, log_level)
    setup_default_outputter(@@logger)
  end

  def self.initialize_post_configuration(
    config_file = nil,
    log_level = nil,
    suppress_default_configuration = false
  )
    if config_file
      begin
        case config_file
          when / [.] xml \z /x
            Log4r::Configurator.load_xml_file(config_file)
          when / [.] ya?ml \z /x
            Log4r::YamlConfigurator.load_yaml_file(config_file)
          else
            raise Fig::ConfigFileError, %Q<Don't know what format #{config_file} is in.>, config_file
        end

        if Log4r::Logger['fig'].nil?
          $stderr.puts %q<A value was provided for --log-config but no "fig" logger was defined.>
        end
      rescue Log4r::ConfigError, ArgumentError => exception
        raise Fig::Log4rConfigError.new(config_file, exception)
      end
    end

    if Log4r::Logger['fig'].nil?
      @@logger = Log4r::Logger.new('fig')
    else
      @@logger = Log4r::Logger['fig']
    end

    if not config_file and not suppress_default_configuration
      assign_log_level(@@logger, 'info')
      setup_default_outputter(@@logger)
    end

    assign_log_level(@@logger, log_level)

    return
  end

  def self.fatal(data = nil, propagated = nil)
    @@logger.fatal data, propagated
  end

  def self.fatal?()
    return @@logger.fatal?
  end

  def self.error(data = nil, propagated = nil)
    @@logger.error data, propagated
  end

  def self.error?()
    return @@logger.error?
  end

  def self.warn(data = nil, propagated = nil)
    @@logger.warn data, propagated
  end

  def self.warn?()
    return @@logger.warn?
  end

  def self.info(data = nil, propagated = nil)
    @@logger.info data, propagated
  end

  def self.info?()
    return @@logger.info?
  end

  def self.debug(data = nil, propagated = nil)
    @@logger.debug data, propagated
  end

  def self.debug?()
    return @@logger.debug?
  end

  private

  def self.assign_log_level(logger, string_level)
    return if string_level.nil?

    level = STRING_TO_LEVEL_MAPPING[string_level.downcase]
    logger.level = level
    logger.outputters.each { | outputter | outputter.level = level }

    return
  end

  def self.setup_default_outputter(logger)
    outputter = Fig::Log4r::Outputter.new('fig stderr', $stderr)
    logger.add outputter
    outputter.formatter = Log4r::PatternFormatter.new :pattern => '%M'

    return
  end
end
