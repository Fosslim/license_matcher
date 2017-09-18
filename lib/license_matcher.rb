require "helix_runtime"

begin
    require "license_matcher/native"
rescue LoadError
    warn "Unable to load license_matcher/native. Please run `rake build`"
end

require 'license_matcher/preprocess'
require 'license_matcher/url_matcher'
require 'license_matcher/rule_matcher'
require 'license_matcher/tf_ruby_matcher'

module LicenseMatcher

  # if class is missing from the module,
  # then look from global ns
  def self.const_missing(c)
    Object.const_get(c)
  end
end
