
require 'bundler/setup'
require 'rspec/core/rake_task'
import 'lib/tasks/helix_runtime.rake'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.verbose = false
end

task :spec => :build
task :default => :spec