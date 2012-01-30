require 'colorize'
require 'log4r/outputter/iooutputter'

module Fig; end
module Fig::Log4r; end

class Fig::Log4r::Outputter < Log4r::IOOutputter
  def initialize(name, file_handle, hash = {})
    @colors = hash.delete(:colors)
    @colors ||= {
      :debug => :white,
      :info  => :light_white,
      :warn  => :yellow,
      :error => :red,
      :fatal => {:color => :light_yellow, :background => :red}
    }
    @colorize = file_handle.tty?

    super(name, file_handle, hash)

    initialize_colors_by_level()
  end

  private

  def initialize_colors_by_level()
    @colors_by_level = {}

    Log4r::LNAMES.each_index do
      |index|

      name_symbol = Log4r::LNAMES[index].downcase.to_sym
      color = @colors[name_symbol]
      if color
        @colors_by_level[index] = color
      end
    end

    return
  end

  def canonical_log(logevent)
    synch { write( format(logevent), logevent ) }
  end

  def write(data, logevent)
    begin
      if not @colorize
        @out.print data
      else
        color = @colors_by_level[logevent.level]
        if color
          @out.print data.colorize(color)
          @out.print ''.uncolorize
        else
          @out.print data
        end
      end

      @out.flush
    rescue IOError => error # recover from this instead of crash
      Logger.log_internal {"IOError in Outputter '#{@name}'!"}
      Logger.log_internal {error}
      close
    rescue NameError => error
      Logger.log_internal {"Outputter '#{@name}' IO is #{@out.class}!"}
      Logger.log_internal {error}
      close
    end

    return
  end
end
