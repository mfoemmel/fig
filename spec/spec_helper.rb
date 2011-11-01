$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'log4r'
require 'stringio'
require 'fileutils'

require 'fig'
require 'fig/logging'

STRING_IO = StringIO.new
Fig::Logging.initialize_logging(nil, true)
Log4r::Logger['fig'].add( Log4r::IOOutputter.new('fig', STRING_IO) )

def setup_repository()
  return if self.class.const_defined? :FIG_HOME
  self.class.const_set(:FIG_HOME, File.expand_path(File.dirname(__FILE__) + '/../tmp/fighome'))
  FileUtils.mkdir_p(FIG_HOME)
  ENV['FIG_HOME'] = FIG_HOME

  self.class.const_set(:FIG_REMOTE_DIR, File.expand_path(File.dirname(__FILE__) + '/../tmp/remote'))
  FileUtils.mkdir_p(FIG_REMOTE_DIR)
  FileUtils.mkdir_p(File.join(FIG_REMOTE_DIR,'_meta'))
  ENV['FIG_REMOTE_URL'] = %Q<ssh://#{ENV['USER']}@localhost#{FIG_REMOTE_DIR}>

  self.class.const_set(:FIG_BIN, File.expand_path(File.dirname(__FILE__) + '/../bin'))
  ENV['PATH'] = FIG_BIN + ':' + ENV['PATH']  # To find the correct fig-download
  self.class.const_set(:FIG_EXE, %Q<#{FIG_BIN}/fig>)
end
