require "spec_helper"


RSpec.describe Timed::Rediscounter do

  let (:standard_counter) { Timed::Rediscounter::Counter.new("standard") }


  it "has a redis" do 
     expect(Timed::Rediscounter.redis).to be_kind_of(Redis)
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
        minute: standard_counter.timehash(1.minute.ago..Time.current),
        hour: standard_counter.timehash(1.hour.ago..Time.current),
        day:  standard_counter.timehash(1.day.ago..Time.current),
        month: standard_counter.timehash(1.month.ago..Time.current),
        year: standard_counter.timehash(13.month.ago..Time.current),
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
          expect(h.keys.length).to eq(2)
          expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
        when :year
          expect(h.keys.length).to eq(2)
          expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
        end
        #expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
      end

    end
  end

  it "has a version number" do
    expect(Timed::Rediscounter::VERSION).not_to be nil
  end

end
