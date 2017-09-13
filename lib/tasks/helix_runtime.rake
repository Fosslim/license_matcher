
require 'helix_runtime/build_task'

HelixRuntime::BuildTask.new("license_matcher")

task :default => :build
