lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq_manager/version'

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq_manager'
  spec.version       = SidekiqManager::VERSION
  spec.authors       = ['Saurabh Maurya']
  spec.email         = ['saurabh.maurya999@gmail.com']

  spec.summary       = 'Intelligent sidekiq management tool'
  spec.description   = 'Intelligently manages sidekiq processes (restart, deployment, monitoring)'
  spec.homepage      = ""

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = ['sidekiq_manager']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_dependency('capistrano', ['>= 3.0'])
  spec.add_dependency('sidekiq', ['>= 3.4'])
end
