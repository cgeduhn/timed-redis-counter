require "timed/rediscounter/time_helper"

module Timed
  module Rediscounter
    class Counter
      attr_reader :steps,:periods,:key
      def initialize(key,default_options={})
        @key = key
        @periods = (default_options.delete(:periods) || DefaultPeriods)
        @steps = (default_options.delete(:steps) || Steps).collect(&:to_i).sort
        raise_if_not_valid_periods(@periods)
        @default_options = default_options.to_h
      end

      # Increments all given periodkeys by a given offset
      # offset is normally 1
      # 
      def incr(options={})
        opt = @default_options.merge(options).with_indifferent_access
        offset = opt.fetch(:offset,1).to_i
        time = opt.fetch(:time,Time.current)
        periods = opt[:periods]
        raise_if_not_valid_periods(periods)

        if offset > 0
          return redis.multi do
            periods.each do  |period| 
              redis.hincrby( period_key(period), convert_time_to_period_hash_key(time,period),  offset)
            end
          end
        end

        return nil
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

        ts_array = hash_keys_for_range(period,range)
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
      def hash_keys_for_range(period,range)
        raise_if_not_valid_periods([period]) 
        ts_array = Set.new
        Timed::Rediscounter::TimeHelper.for_each(period,s..e).each do |t|
          ts_array << convert_time_to_period_hash_key(t,period)  
        end
        ts_array.to_a
      end

      # Calculate a a valid period by a given range
      def period_by_range(range)
        diff = (range.last - range.first).round
        #finding the first step thats less or equal the range difference
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
          return (!a.any?{|it| !Periods.include?(it.to_sym)})
        when Symbol,String
          return Periods.include?(a.to_sym)
        else
          false
        end
        raise ArgumentError.new("Not valid periods: #{a} Must contain one or more of #{Periods}") unless r
      end


      Steps   = [1.hour,  1.day,   4.weeks,  1.year,  2.year].freeze
      Periods = [:minute, :hour,   :day,     :month,  :year].freeze
      DefaultPeriods = Periods


      def period_key(period)
        "#{self.class.name}::#{@key}::#{period}"
      end

      def convert_to_time(time)
        case time
        when Time
          time = time.utc
        when Date
          time = time.to_time.utc
        when String
          time = Time.parse(time).utc
        when Fixnum,Float
          time = Time.at(time).utc
        else 
          raise ArgumentError.new("Not valid Time")
        end
      end

      def convert_time_to_period_hash_key(time,period)
        convert_to_time(time).send("beginning_of_#{period}").to_i
      end



    end
  end
end