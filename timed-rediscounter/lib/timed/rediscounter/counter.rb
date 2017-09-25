module Timed
  module Rediscounter
    class Counter

      Steps   = [1.hour,  1.day,   1.month,  1.year,  2.year].freeze
      Periods = [:minute, :hour,   :day,     :month,  :year].freeze
      DefaultPeriods = Periods

      attr_reader :steps,:periods,:key
      def initialize(key,default_options={})
        @key = key
        @periods = (default_options.delete(:periods) || DefaultPeriods)
        @steps = (default_options.delete(:steps) || Steps).collect(&:to_i).sort
        raise_if_not_valid_periods(@periods)
        @default_options = default_options.to_h
      end

      # Increments all given period keys by a given offset
      # offset is normally 1
      # 
      def incr(options={})
        opt = @default_options.merge(options).with_indifferent_access
        offset = opt.fetch(:offset,1).to_i
        time = opt.fetch(:time,Time.current)
        periods = (opt[:periods] || @periods)
        raise_if_not_valid_periods(periods)

        if offset > 0
          return redis.multi do
            periods.each do  |period| 
              redis.hincrby( period_key(period), convert_time_to_period_hash_key(time,period),  offset)
            end
          end
        end

        return []
      end

      # Returns a Hash by a given range or a period
      #
      # example:
      # hash_for_range(1.hour.ago..Time.now)
      #
      # result:
      # {2017-09-22 15:00:00 +0200=>0, 2017-09-22 16:00:00 +0200=>0} 
      # 
      # optional Parameter period: 
      # [:minute, :hour,   :day,     :month,  :year]
      def timehash(range,period=nil)

        period ||= period_by_range(range)
        ts_array = hash_keys_by_range(period,range)
        return Hash.new if ts_array.empty?

        redis.mapped_hmget(period_key(period), *ts_array).inject({}) do |h,(k,v)| 
          h[Time.at(k)] = v.to_i
          h
        end
      end

      #Expiring all period Keys
      #
      #expire_in in seconds
      def expire_keys(expire_in=nil)
        expire_in ||= @default_options.fetch(:expire_in, 1.year).to_i
        redis.multi do 
          Periods.each { |period| redis.expire period_key(period), expire_in }
        end
      end

      #deleting all period keys
      def delete_keys
        redis.multi do 
          Periods.each { |period| redis.del period_key(period) }
        end
      end

      #helper to access redis
      def redis
        Timed::Rediscounter.redis
      end

      private

      #build the hash keys for a period and a range
      def hash_keys_by_range(period,range)
        raise_if_not_valid_periods(period) 

        off_set = 1.send(period)
        ts_array = Set.new

        start_time = range.first.send("beginning_of_#{period}")
        end_time = range.last.send("beginning_of_#{period}")

        ts_array << start_time
        while (end_time - start_time) >= off_set
          start_time += off_set
          ts_array << start_time
        end
        return ts_array.collect(&:to_i)
      end

      # Calculate a a valid period by a given range
      def period_by_range(range)
        diff = (range.last - range.first).round
        period = nil
        @steps.each_with_index do |step,i|
          if diff <= step
            period = @periods[i] 
            break
          end
        end
        #if not found => fallback
        period ||= ( @periods[@steps.length] || @periods.last ) 
      end

      def raise_if_not_valid_periods(a)
        r = case a 
        when Array
          return !a.any?{|it| !Periods.include?(it.to_sym)}
        when Symbol,String
          return Periods.include?(a.to_sym)
        else
          false
        end
        raise ArgumentError.new("Not valid periods: #{a} Must contain one or more of #{Periods}") unless r
      end


      def period_key(period)
        "#{self.class.name}::#{@key}::#{period}"
      end

      def convert_time_to_period_hash_key(time,period)
        case time
        when Time
          t = time
        when Date
          t = time.to_time
        when String
          t = Time.parse(time)
        when Fixnum,Float
          t = Time.at(time)
        else 
          raise ArgumentError.new("Not valid Time")
        end
        t.send("beginning_of_#{period}").to_i
      end



    end
  end
end