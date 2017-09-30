require 'os'
require "helix_runtime"


if OS.mac?
  begin
    require "license_matcher/native"
  rescue LoadError
    warn "Failed to load native extensions for OSx. Please run `rake build`"
  end
elsif OS.posix?
  begin
    require "license_matcher/native.so"
  rescue LoadError
    warn "Failed to load native extensions for Posix. Please run `rake build`"
  end
else
  warn "Unsupported platform - you are not able to use some models;"
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
