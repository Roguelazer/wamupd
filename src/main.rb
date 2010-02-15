#!/usr/bin/ruby
# Copyright (C) 2009-2010 James Brown <roguelazer@roguelazer.com>.
#
# This file is part of wamupd.
#
# wamupd is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# wamupd is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with wamupd.  If not, see <http://www.gnu.org/licenses/>.
#
# == Synopsis
# 
# wamupd: Read avahi service descriptions and current IP information, then
# use that information to generate Wide-Area mDNS Updates
#
# == Usage
#
# wamupd service-file
#
# -A DIRECTORY, --avahi-services DIRECTORY
#   Load Avahi service definitions from DIRECTORY
#   If DIRECTORY is not provided, defaults to /etc/avahi/services
# -c FILE, --config FILE:
#   Get configuration data from FILE
# -h, --help:
#   Show this help

# Update the include path
$:.push(File.dirname(__FILE__))

require "avahi_service"
require "dns_avahi_controller"

require "getoptlong"
require "rdoc/usage"

config_file=nil
avahi_dir="/etc/avahi/services/"
bools = {
    :publish=>false,
    :unpublish=>false,
    :avahi=>false
}

opts = GetoptLong.new(
    ["--help", "-h", GetoptLong::NO_ARGUMENT],
    ["--config", "-c", GetoptLong::REQUIRED_ARGUMENT],
    ["--publish", "-p", GetoptLong::NO_ARGUMENT],
    ["--unpublish", "-u", GetoptLong::NO_ARGUMENT],
    ["--avahi-services", "-A", GetoptLong::OPTIONAL_ARGUMENT]
)

boolean_vars = {
    "--publish" => :publish,
    "--unpublish" => :unpublish,
    "--avahi-services" => :avahi
}

opts.each do |opt,arg|
    case opt
    when "--help"
        RDoc::usage
    when "--config"
        config_file = arg.to_s
    when "--avahi-services"
        if (not arg.nil? and arg != "")
            avahi_dir=arg
        end
    end
    if (boolean_vars.has_key?(opt))
        bools[boolean_vars[opt]] = true
    end
end

if (ARGV.length != 1)
    puts "Incorrect arguments"
    RDoc::usage
end

$settings = MainSettings.instance()
if (not config_file.nil?)
    $settings.load_from_yaml(config_file)
end

if (bools[:avahi])
    s = AvahiService.load_from_directory(avahi_dir)
    d = DNSAvahiController.new(s)
    if (bools[:publish])
        d.publish_all
    end
    if (bools[:unpublish])
        d.unpublish_all
    end
end
