# yardoc info: http://cheat.errtheblog.com/s/yard/

class TTimeTracker
  require 'time'

  # @author Christian Genco (@cgenco)

  # @attribute directory [String] the parent directory that the log files are stored in
  # @attribute subdirectory [String] the subdirectory in which the current task will be stored
  # @attribute filename [String] the full path to the log file of the current task
  # @attribute task [String] the users entered task
  # @attribute at [Time] the time that the task started at
  # @attribute from [Time] when setting a range, the starting DateTime
  # @attribute to [Time] when setting a range, the ending DateTime
  attr_accessor :directory, :subdirectory, :filename, :task, :at, :from, :to

  # A new instance of TTimeTracker.
  # @param [Hash] params Options hash
  # @option params [Symbol] :now the date to consider when deciding which log file to use
  # @option params [Symbol] :directory the parent directory that the log files are stored in
  # @option params [Symbol] :subdirectory the subdirectory in which the current task will be stored
  # @option params [Symbol] :filename the full path to the log file of the current task
  def initialize(params = {})
    now = params[:now] || Time.now
    @directory    = params[:directory] || File.join(Dir.home, '.ttimetracker')
    @subdirectory = params[:subdirectory] || File.join(@directory, now.year.to_s, now.strftime("%m_%b"), '')
    @filename     = params[:filename] || File.join(@subdirectory, now.strftime('%Y-%m-%d') + '.csv')

    mkdir @subdirectory
  end

  def at=(time_in_words)
    require 'chronic'
    @at = Chronic.parse(time_in_words, :context => :past)
  end

  private

  # Create directory if it doesn't exist, creating intermediate 
  # directories as required. Equivalent to `mkdir -p`.
  # 
  # @param dir [String] a directory name
  def mkdir(dir)
    mkdir(File.dirname dir) unless File.dirname(dir) == dir
    Dir.mkdir(dir) unless dir.empty? || File.directory?(dir)
  end

  # Converts an integer of minutes into a more human readable format.
  # 
  # @example
  #   "format_minutes(95)" #=> "1:15"
  #   "format_minutes(5)"  #=> "0:05"
  # 
  # @param minutes [Integer] a number of minutes
  # @return [String] the formatted minutes
  def format_minutes(minutes)
    "#{minutes.to_i / 60}:#{'%02d' % (minutes % 60)}"
  end
end