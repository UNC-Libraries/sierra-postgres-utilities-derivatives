require "bundler/setup"
require 'sierra_postgres_utilities'
require "sierra_postgres_utilities/derivatives"

require 'rspec'
require 'factory_bot'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include FactoryBot::Syntax::Methods
  FactoryBot.definition_file_paths << Sierra::SpecSupport::FACTORY_PATH
  FactoryBot.find_definitions
end

module Sierra::SpecUtils
  module Records
    def values=(hsh)
      @values = hsh
    end

    def set_data(field, data)
      define_singleton_method(field) { data }
      self
    end
  end
end

def newrec(type, metadata = {}, data = {})
  rec = type.new
  rec.extend(Sierra::SpecUtils::Records)
  rec.values=(metadata.to_hash.merge(data.to_hash))
  rec
end

