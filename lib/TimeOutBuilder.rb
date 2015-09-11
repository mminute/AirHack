require 'timeout'

class TimeOutTester
  attr_reader :seconds_to_timeout, :sleeper_seconds

  def initialize(seconds_to_timeout, sleeper_seconds)
    @seconds_to_timeout = seconds_to_timeout
    @sleeper_seconds = sleeper_seconds
  end

  def test
    begin  
     Timeout.timeout( seconds_to_timeout ) do
      sleeper( sleeper_seconds )
     end
    rescue Timeout::Error
      puts 'Rescued from the long sleep!  Whew, that could have been boring'
    end
  end

  def sleeper(secs)
    sleep(secs)
    puts 'Awakened!!!'
  end

end

# should_awaken = TimeOutTester.new(30,10)
# should_rescue = TimeOutTester.new(2,10)

# puts "This should not be rescued.  You should see 'Awakened!!!'"
# p should_awaken.test
# puts "This should be rescued.  You should see 'Rescued from the long sleep!...'"
# p should_rescue.test

# [1,2,3,4,5].each do |number|
#   if number < 5
#     next
#   else
#     puts number
#   end
# end