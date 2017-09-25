require 'active_support'
require 'active_support/time'

require 'active_support/core_ext/date/conversions'
require 'active_support/core_ext/hash'

require "redis"

require "timed/rediscounter/version"
require "timed/counter"



module Timed
  module Rediscounter
    extend ActiveSupport::Concern

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


  end
end
