require "helix_runtime"

begin
  require "license_matcher/native"
rescue LoadError
  warn "Unable to load license_matcher/native. Please run `rake build`"
end
