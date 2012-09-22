# yardoc info: http://cheat.errtheblog.com/s/yard/

class TTimeTracker
  require 'time'

  # @author Christian Genco (@cgenco)

  # @attribute directory [String] the parent directory that the log files are stored in
  # @attribute subdirectory [String] the subdirectory in which the current task will be stored
  # @attribute filename [String] the full path to the log file of the current task
  # @attribute task [String] the users entered task
  # @attribute at [Time] the time that the task (or range) starts at
  # @attribute to [Time] the time that the task (or range) ends at
  attr_accessor :directory, :subdirectory, :filename, :task, :now #, :at, :to, :now

  # A new instance of TTimeTracker.
  # @param [Hash] params Options hash
  # @option params [Symbol] :now the date to consider when deciding which log file to use
  # @option params [Symbol] :directory the parent directory that the log files are stored in
  # @option params [Symbol] :subdirectory the subdirectory in which the current task will be stored
  # @option params [Symbol] :filename the full path to the log file of the current task
  def initialize(params = {})
    # puts "INITIALIZINGGGG!!!"
    @now          = params[:now]          || Time.now
    @directory    = params[:directory]    || File.join(Dir.home, '.ttimetracker')
    @subdirectory = params[:subdirectory] || File.join(@directory, now.year.to_s, now.strftime("%m_%b"), '')
    @filename     = params[:filename]     || File.join(@subdirectory, now.strftime('%Y-%m-%d') + '.csv')
    self.class.mkdir @subdirectory
  end

  # Returns information about the specified task.
  # 
  # @param task_name [Symbol] the stored task to return, `:current` or `:last`
  def task(task_name)
    task_filename = File.join(@directory, task_name.to_s)
    return nil unless File.exists?(task_filename)
    File.open(task_filename,'r') do |f|
      line = f.gets
      return if line.nil?
      parse_task(line)
    end
  end

  # equivalent to task(:current)
  def current_task; task(:current); end

  # equivalent to task(:last)
  def last_task; task(:last); end

  # returns an array of hashed tasks between the specified times. Defaults to today.
  # @todo figure out how to make this work with an arbitrary directory structure
  # @param [Hash] params Options hash
  # @option params [Symbol] :from the starting time; includes any task that starts after it (inclusive)
  # @option params [Symbol] :to the ending time; includes any task that starts before it (inclusive)
  def tasks(params = {})
    require 'active_support/core_ext/time/calculations'
    require 'active_support/core_ext/date/calculations'

    # Time.parse(Time.new.strftime("%F 0:00:00 %z"))
    from = params[:from] || Time.new.beginning_of_day
    # Time.parse(Time.new.strftime("%F 23:59:59 %z"))
    to   = params[:to]   || Time.new.end_of_day
    # ensure from < to
    from, to = [from, to].sort 

    tasks = []

    # first, get every task for the correct days
    now = from
    while now <= to
      # TODO: make this work for arbitrary folder organisation structures
      subdirectory = File.join(@directory, now.year.to_s, now.strftime("%m_%b"), '')
      filename     = File.join(subdirectory, now.strftime('%Y-%m-%d') + '.csv')
      File.open(filename, 'r').each do |line|
        tasks << parse_task(line, :day => now)
      end if File.exists?(filename)
      now = now.tomorrow
    end

    # now filter out tasks that don't fall within the requested timespan
    tasks.delete_if{|t|
      t[:start] < from || t[:start] > to
    }

    tasks
  end

  # warning: this will overwrite the current task. You need to save the current task before saving a new one.
  def save(task = {})
    # forget the last task
    last = File.join(@directory, "last")
    File.unlink(last) if File.exists?(last)

    task[:start] ||= @now

    # save this as the current task if it doesn't have an ending time
    if !task[:finish]
      File.open(File.join(@directory, "current"),'w') do |f|
        f.puts [format_time(task[:start]), task[:description].strip].join(", ")
      end
    else
      # task has start and finish time, so append it to today's log...
      File.open(@filename,'a') do |f|
        f.puts [format_time(task[:start]), format_time(task[:finish]), task[:description].strip].join(", ")
      end

      # ...and save it as "last" in case you want to resume it
      # bugfix: unless it doesn't exist (like during `t reddit --from "10:10am" --to "noon"`)
      File.rename(File.join(@directory, 'current'), File.join(@directory, 'last')) if File.exists?(File.join(@directory, 'current'))
    end

    task[:duration] = ((task[:finish] - task[:start]).to_f / 60).ceil if task[:finish]

    task
  end

  # Converts an integer of minutes into a more human readable format.
  # 
  # @example
  #   format_minutes(95) #=> "1:15"
  #   format_minutes(5)  #=> "0:05"
  # 
  # @param minutes [Integer] a number of minutes
  # @return [String] the formatted minutes
  def self.format_minutes(minutes)
    "#{minutes.to_i / 60}:#{'%02d' % (minutes % 60)}"
  end

  # Parses a comma separated stored task in csv form
  # 
  # @example
  #   parse_task("12:56, 13:10, did the dishes") 
  #   #=> {:start=>2012-05-16 12:56:00, :finish=>2012-05-16 13:10:00, :description=>"did the dishes", :duration=>14}
  #   parse_task("14:32, homework")
  #   #=> {:start=>2012-05-16 14:32:00, :finish=>Time.now, :description=>"homework", :duration=>36}
  # 
  # @param line [String] the CSV stored task
  # @param [Hash] params Options hash
  # @option params [Symbol] :day the default day to assign to times parsed. Defaults to @now.
  # @return [{:start=>Time, :finish=>Time, :description=>String, :duration=>Integer}] the parsed data in the line
  def parse_task(line, params = {})
    def parse_time(time_string, day)
      # if the time already has a date, parse that time
      # else assign a date
      if time_string =~ /\d{4}-\d{2}-\d{2}/
        Time.parse(time_string)
      else
        Time.parse(day.strftime("%F ") + time_string)
      end
    end

    day   = params[:day] || @now
    data  = line.split(",").map(&:strip)
    start = parse_time(data.shift, day)

    if data.length == 2
      # if there are two more values, they are the finished time and the description
      finish = parse_time(data.shift, day)
    else 
      # otherwise the last value is the description; get finish elsewhere
      finish = @now
    end

    description = data.shift
    duration = ((finish - start).to_f / 60).ceil

    return {:start => start, :finish => finish, :description => description, :duration => duration}
  end

  # Create directory if it doesn't exist, creating intermediate 
  # directories as required. Equivalent to `mkdir -p`.
  # 
  # @param dir [String] a directory name
  def self.mkdir(dir)
    mkdir(File.dirname dir) unless File.dirname(dir) == dir
    Dir.mkdir(dir) unless dir.empty? || File.directory?(dir)
  end

  # Converts a Time object into a human readable condensed string.
  # Options for strftime may be found here: 
  # http://www.ruby-doc.org/core-1.9.3/Time.html#method-i-strftime
  # 
  # @example
  #   time = Time.new   #=> 2012-05-16 00:32:31 +0800
  #   format_time(time) #=> "2012-05-16 00:32:31"
  # 
  # @param time [Time] a time
  # @return [String] the formatted time
  def format_time(time)
    time.strftime("%F %T")
  end
end