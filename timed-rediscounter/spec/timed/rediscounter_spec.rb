require "spec_helper"

class TestObject
  include Timed::Rediscounter

  #class neeeds an id or another id field => see below
  def id 
    1
  end

  timed_rediscounter(:standard)


  master_host = "localhost"
  redis_db = 2
  master_port = 6379
  timed_rediscounter(:with_other_redis, redis: Redis.new(:host => master_host, :port => master_port, :db => redis_db))

end


class Array
  def sum
    inject(0){|s,elem| s += elem.to_i}
  end
end


RSpec.describe Timed::Rediscounter do

  let (:standard_counter) { TestObject.new.standard }


  it "has redis instances" do 
    expect(TestObject.new.standard.redis).to be_kind_of(Redis)
    expect(TestObject.new.with_other_redis.redis).to be_kind_of(Redis)
    #expect(TestObject.new.standard.redis.client.db).to eq(1)
    #expect(TestObject.new.with_other_redis.redis.client.db).to eq(2)
  end


  describe "as a standard_counter" do 


    it "has standard periods" do 
      expect(standard_counter.periods).to eq(Timed::Rediscounter::Counter::Periods)
    end

    it "should count correctly" do

      incr_result = standard_counter.incr
      expect(incr_result).not_to be_empty
      expect(incr_result).not_to be nil
       
      hashes_to_check = {
        minute: standard_counter.history(1.minute.ago..Time.current),
        hour: standard_counter.history(1.hour.ago..Time.current),
        day:  standard_counter.history(1.day.ago..Time.current),
        month: standard_counter.history(1.month.ago..Time.current),
        year: standard_counter.history(13.month.ago..Time.current),
      }
      
      hashes_to_check.each do |k,h| 
        case k
        when :minute
          expect(h.keys.length).to eq(2)
          expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
        when :hour
          expect(h.keys.length).to eq(61)
          expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
        when :day
          expect(h.keys.length).to eq(25)
          expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
        when :month
          expect(h.keys.length).to be >= 30
          expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
        when :year
          expect(h.keys.length).to eq(2)
          expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
        end
        #expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
      end

      standard_counter.incr()

      r = 1.minute.ago..Time.current
      expect(standard_counter.sum(r)).to eq(2)

      expect(standard_counter.history(r).values.sum).to eq(2)


      expect(standard_counter.summed_up_history(r).values.last).to eq(2) #ist ja aufsummiert




    end


    it "should delete keys correctly" do 
      incr_result = standard_counter.incr
      expect(incr_result).not_to be_empty
      expect(incr_result).not_to be nil

      Timed::Rediscounter::Counter::Periods.each do |period|
        expect(standard_counter.sum(1.send(period).ago)).to eq(1)
      end

      standard_counter.delete_keys

      Timed::Rediscounter::Counter::Periods.each do |period|
        expect(standard_counter.sum(1.send(period).ago)).to eq(0)
      end
      
    end
  end


  Timed::Rediscounter::Counter::Periods.each do |period|
    describe "as #{period} counter" do 

      counter = Timed::Rediscounter::Counter.new("#{period}",periods: [period])
      it "has only #{period} keys" do 
         expect(counter.periods).to eq([period])
      end

      it "counts only #{period}" do 
        expect(counter.incr).to eq([1])
      end

      it "has only two keys if range goes from 1 #{period} ago" do 
        expect(counter.incr).to eq([1])
        r = counter.history(1.send(period).ago)
        expect(r.keys.length).to eq(2)
        expect(r.values.inject(0) { |sum, p| sum + p }).to eq(1)
      end

    end
  end








  it "has a version number" do
    expect(Timed::Rediscounter::VERSION).not_to be nil
  end

end
