# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "license_matcher"
  spec.version       = "0.2.0-alpha"
  spec.authors       = ["Timo Sulg", "Versioneye"]
  spec.email         = ["timgluz@gmail.com", "reiz@versioneye.com"]

  spec.summary       = %q{It helps to classify OSS license text and find correct SPDX-ID label for it}
  spec.description   = %q{
    LicenseMatcher is rubygem, which uses Fosslim to match various OSS license
    with correct SPDX-id or EULA label.
  }
  spec.homepage      = "https://www.github.com/fosslim"
  spec.licenses      = [ "MIT" ]

  spec.files        = Dir['{lib/**/*,[A-Z]*}']
  spec.platform     = Gem::Platform::RUBY
  spec.require_path = 'lib'

  spec.add_dependency 'helix_runtime', '~> 0.6.0'
  spec.add_dependency 'narray', '~> 0.6.1.2'
  spec.add_dependency 'tf-idf-similarity', '~> 0.1.6'
  spec.add_dependency 'nokogiri', '~> 1.8.0'

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency 'rspec', '~> 3.4'
  spec.add_development_dependency 'msgpack', '~> 1.1.0'
end
