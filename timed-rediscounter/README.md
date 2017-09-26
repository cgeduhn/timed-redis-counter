# Timed::Rediscounter


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'timed-rediscounter'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install timed-rediscounter

## Usage

```ruby
class TestObject
  include Timed::Rediscounter

  #class neeeds an id or another id field => see below
  def id 
    1
  end

  # Define a counter like: 
  timed_rediscounter(:test1)
  # only a counter for hours and days
  # valid periods are [:minute, :hour,   :day,     :month,  :year]
  timed_rediscounter(:test2,periods: [:hour,:day])

  # you can pass a other id field
  timed_rediscounter(:test2,id_field: :special_id_field)

end

##Incrementation
obj.test1.incr()
#if you want to incrment by a value bigger than 1
obj.test1.incr(offset: 10)
#if you want to increment for a specific timestamp
obj.test1.incr(time: 10.years.ago)
#if you only want to increment for specific periods
obj.test1.incr(periods: [:year])


##Results

#return a timestamp hash with timestamp as key and count as value
obj.test1.history(1.minute.ago)


#optional with step as second argument. 
#normally the step will be calculated by given range
obj.test1.history(1.year.ago,:minute) 


#returns the sum in the given range
obj.test1.sum(1.minute.ago..Time.now) #or obj.sum(1.minute.ago)


```

## Deleting and expiring

```ruby
obj.test1.delete_keys
obj.test1.expire_keys(10) #in seconds
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/cgeduhn/timed-rediscounter. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the Timed::Rediscounter project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/timed-rediscounter/blob/master/CODE_OF_CONDUCT.md).
