require 'active_support'
require 'active_support/time'

require 'active_support/core_ext/date/conversions'
require 'active_support/core_ext/hash'

require "redis"

require "timed/rediscounter/version"




module Timed
  module Rediscounter
    def self.included(mod)
      mod.extend(ClassMethods)
    end

    def self.redis=(r)
      @redis = r if r.is_a?(Redis)
    end

    def self.redis
      @redis || $redis
    end


    module ClassMethods
      #examples
      # Define like: 
      #
      # timed_rediscounter(:test1)
      # timed_rediscounter(:test2,periods: [:hour,:day])
      # timed_rediscounter(:test3,steps: [1.day,1.month,1.year])
      # timed_rediscounter(:test4,periods: [:hour,:day,:year], steps: [1.day,1.month,1.year])
      # 
      # Steps are for defining limits when to output which timehash for a given range
      #
      # EXAMPLES
      # steps: : [1.day,1.month,1.year]
      # periods: [:hour,:day,:year]
      #
      #   counter.hash_for_range(1.hour.ago..Time.now) will return daty by hour:
      # 
      #   {2017-09-21 16:00:00 +0200=>0, 2017-09-21 17:00:00 +0200=>0, 2017-09-21 18:00:00 +0200=>0, 2017-09-21 19:00:00 +0200=>0, ... .. 
      #
      #
      # 
      #   counter.hash_for_range(27.days.ago..Time.now) will return dates by day:
      #
      #   {2017-08-26 02:00:00 +0200=>0, 2017-08-27 02:00:00 +0200=>0, 2017-08-28 02:00:00 +0200=>0, 2017-08-29 02:00:00 +0200=>0, 2
      def timed_rediscounter(key_name,options={})
        obj_v_string = "@#{key_name}_instance_variable"

        id_field = (options.delete(:id_field) || :id)
        define_method(key_name) do 
          if instance_variable_get(obj_v_string)
            instance_variable_get(obj_v_string)
          else
            o = Timed::Rediscounter::Counter.new([key_name,send(id_field)].join("::"),options)
            instance_variable_set(obj_v_string, o)
          end
        end
      end
    end


    class Counter

      Periods = [:minute, :hour,   :day,     :month,  :year].freeze

      attr_reader :periods,:key
      def initialize(key,default_options={})
        @key = key
        @periods = (default_options.delete(:periods) || Periods)
        @redis = (default_options.delete(:redis) || Timed::Rediscounter.redis)
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
      # history(1.hour.ago..Time.now) or history(1.hour.ago)
      #
      #
      # result:
      # {2017-09-22 15:00:00 +0200=>0, 2017-09-22 16:00:00 +0200=>0} 
      # 
      # optional Parameter period: 
      # [:minute, :hour,   :day,     :month,  :year]
      def history(range_arg,period=nil)
        redis_key, hash_keys =  build_redishash_arguments(range_arg,period)
        return Hash.new if hash_keys.empty?

        redis.mapped_hmget(redis_key, *hash_keys).inject({}) do |h,(k,v)| 
          h[Time.at(k)] = v.to_i
          h
        end
      end

      def sum(range_arg,period=nil)
        redis_key, hash_keys =  build_redishash_arguments(range_arg,period)
        return 0 if hash_keys.empty?
        redis.hmget(redis_key, *hash_keys).inject(0){|sum,i| sum += i.to_i}
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
        @redis
      end

      private

      #builds the 
      def build_redishash_arguments(range_arg,period=nil)
        case range_arg 
        when Time,Date
          range = (range_arg..Time.current)
        when String
          range = (Time.parse(range_arg)..Time.current)
        when Range
          range = range_arg
        else
          ArgumentError.new 
        end
        period ||= period_by_range(range)
        raise_if_not_valid_periods(period) 

        off_set = 1.send(period)
        hash_keys = Set.new

        start_time = range.first.send("beginning_of_#{period}")
        end_time = range.last.send("beginning_of_#{period}")

        hash_keys << start_time
        while (end_time - start_time) >= off_set
          start_time += off_set
          hash_keys << start_time
        end

        return period_key(period), hash_keys.collect(&:to_i)
      end

      Steps   = [1.hour,  1.day,   1.month,  1.year,  2.year].freeze
      # Calculate a a valid period by a given range
      def period_by_range(range)
        diff = (range.last - range.first).round
        period = nil
        Steps.each_with_index do |step,i|
          if diff <= step
            period = @periods[i] 
            break
          end
        end
        #if not found => fallback
        period ||= ( @periods[Steps.length] || @periods.last ) 
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
