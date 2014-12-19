# coding: UTF-8

Gem::Specification.new do |s|
  s.name              = "wamupd"
  s.version           = "1.0"
  s.platform          = Gem::Platform::RUBY
  s.authors           = ["Jonathan Walker", "roguelazer"]
  s.email             = ["kallous@gmail.com"]
  s.homepage          = "http://github.com/johnnywalker/wamupd"
  s.summary           = "A Ruby program to update DNS-SD using Avahi & D-Bus"
  s.description       = "Wamupd -- A Ruby program to update DNS-SD using Avahi & D-Bus"
  s.rubyforge_project = s.name

  s.required_rubygems_version = ">= 1.3.6"

  s.required_ruby_version = '>= 1.9.0'
  
  s.add_dependency "daemons"
  s.add_dependency "algorithms"
  s.add_dependency "dnsruby"
  s.add_dependency "logger"
  s.add_dependency "ruby-dbus", ">= 0.6.1"
  
  # The list of files to be contained in the gem
  s.files         = `git ls-files`.split("\n")
  s.executables   = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  
  s.require_path = 'lib'
end
