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
          expect(h.keys.length).to eq(2)
          expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
        when :year
          expect(h.keys.length).to eq(2)
          expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
        end
        #expect(h.values.inject(0) { |sum, p| sum + p }).to eq(1)
      end

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
