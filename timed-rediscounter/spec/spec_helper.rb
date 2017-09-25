require "bundler/setup"
require "timed/rediscounter"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  master_host = "localhost"
  redis_db = 1
  master_port = 6379
  $redis = Redis.new(:host => master_host, :port => master_port, :db => redis_db)

  config.before(:each) do 
    Timed::Rediscounter.redis.flushdb
  end


  config.after(:each) do
    Timed::Rediscounter.redis.flushdb
  end

end
