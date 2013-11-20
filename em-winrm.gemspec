# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "em-winrm/version"

Gem::Specification.new do |s|
  s.name        = "em-winrm"
  s.version     = EventMachine::WinRM::VERSION
  s.platform    = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "LICENSE" ]
  s.authors     = ["Seth Chisamore"]
  s.email       = ["schisamo@opscode.com"]
  s.homepage    = "http://github.com/schisamo/em-winrm"
  s.summary     = %q{EventMachine based, asynchronous parallel WinRM client}
  s.description = s.summary

  s.required_ruby_version	= '>= 1.9.1'
  s.add_dependency "eventmachine", "= 1.0.3"
  s.add_dependency "winrm", "~> 1.1.0"
  s.add_dependency "mixlib-log", ">= 1.3.0"
  s.add_dependency "uuidtools", "~> 2.1.1"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
