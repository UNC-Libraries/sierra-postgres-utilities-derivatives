lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sierra_postgres_utilities/derivatives/version'

Gem::Specification.new do |spec|
  spec.name          = 'sierra_postgres_utilities-derivatives'
  spec.version       = Sierra::Derivatives::VERSION
  spec.authors       = ['ldss-jm']
  spec.email         = ['ldss-jm@users.noreply.github.com']

  spec.summary       = 'Transform Sierra bib into MARC for another system'
  spec.homepage      = 'https://github.com/UNC-Libraries/sierra-postgres-utilities-derivatives'

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'factory_bot', '~> 5.0.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spec.add_runtime_dependency 'sierra_postgres_utilities', '~> 0.3.0'
end
