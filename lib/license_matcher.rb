require "helix_runtime"

begin
  require "license_matcher/native"
rescue LoadError
  warn "Unable to load license_matcher/native. Please run `rake build`"
end

require 'license_matcher/preprocess'
require 'license_matcher/tf_ruby_matcher'
require 'license_matcher/url_matcher'
require 'license_matcher/rule_matcher'