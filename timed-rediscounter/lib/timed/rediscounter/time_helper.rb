module Timed
  module Rediscounter

    class TimeHelper
      def self.for_each(step,range)
        start_time = range.first
        end_time = range.last
        
        case step
        when Symbol,String
          off_set = 1.send(step)
        when ActiveSupport::Duration
          off_set = step
        else
          raise ArgumentError.new
        end

        start_time = Time.at( (start_time.to_i/off_set.to_i).round * off_set.to_i )
        end_time = Time.at( ( (end_time.to_i) /off_set.to_i).round * off_set.to_i )

        diff = end_time - start_time
        i = 1
        arr = [start_time]
        yield start_time if block_given?
        
        while diff > 0
          t = (start_time + (i*off_set))
          i += 1
          arr << t
          yield t if block_given?
          diff = end_time - t
        end
        return arr
      end
    end

    
  end
end