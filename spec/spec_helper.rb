$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'log4r'
require 'stringio'

require 'fig'
require 'fig/logging'

STRING_IO = StringIO.new
Fig::Logging.initialize_logging(nil, true)
Log4r::Logger['fig'].add( Log4r::IOOutputter.new('fig', STRING_IO) )
