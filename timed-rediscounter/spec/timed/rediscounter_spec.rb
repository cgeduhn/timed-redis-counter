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
       

      minute_hash = standard_counter.timehash(1.minute.ago..Time.now)

      expect(minute_hash.keys.length).to eq(2)

      expect(minute_hash.values.inject(0) { |sum, p| sum + p }).to eq(1)

    end
  end

  it "has a version number" do
    expect(Timed::Rediscounter::VERSION).not_to be nil
  end

end
