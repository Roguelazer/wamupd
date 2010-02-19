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
# -i, --ip-addreses (or --no-ip-addresses)
#   Enable/Disable Publishing A and AAAA records
# -h, --help:
#   Show this help
# -p, --publish
#   Publish records
# -u, --unpublish
#   Unpublish records

# Update the include path
$:.push(File.dirname(__FILE__))

require "avahi_model"
require "avahi_service"
require "avahi_service_file"
require "dns_avahi_controller"
require "dns_ip_controller"

require "getoptlong"
require "rdoc/usage"
require "singleton"

# Wamupd is a module that is used to namespace all of the wamupd code.
module Wamupd

    OPTS = GetoptLong.new(
        ["--help", "-h", GetoptLong::NO_ARGUMENT],
        ["--config", "-c", GetoptLong::REQUIRED_ARGUMENT],
        ["--publish", "-p", GetoptLong::NO_ARGUMENT],
        ["--unpublish", "-u", GetoptLong::NO_ARGUMENT],
        ["--avahi-services", "-A", GetoptLong::OPTIONAL_ARGUMENT],
        ["--ip-addresses", "-i", GetoptLong::NO_ARGUMENT],
        ["--no-ip-addresses", GetoptLong::NO_ARGUMENT]
    )

    DEFAULT_CONFIG_FILE = "/etc/wamupd.yaml"
    DEFAULT_AVAHI_DIR   = "/etc/avahi/services/"

    # Main wamupd object
    class Main
        include Singleton

        # Process command-line objects
        def process_args
            @config_file = DEFAULT_CONFIG_FILE
            @avahi_dir = DEFAULT_AVAHI_DIR

            boolean_vars = {
                "--publish" => :publish,
                "--unpublish" => :unpublish,
                "--avahi-services" => :avahi,
                "--ip-addresses" => :ip
            }

            OPTS.each do |opt,arg|
                case opt
                when "--help"
                    RDoc::usage
                when "--config"
                    @config_file = arg.to_s
                when "--avahi-services"
                    if (not arg.nil? and arg != "")
                        @avahi_dir=arg
                    end
                when "--no-ip-addresses"
                    @bools[:ip] = false
                end
                if (boolean_vars.has_key?(opt))
                    @bools[boolean_vars[opt]] = true
                end
            end
        end

        # Construct the object and process all command-line options
        def initialize
            @bools = {
                :publish=>false,
                :unpublish=>false,
                :avahi=>false,
                :ip=>false
            }

            $settings = MainSettings.instance()

            process_args()

            # Load settings
            if (not File.exists?(@config_file))
                $stderr.puts "Could not find configuration file #{@config_file}"
                $stderr.puts "Try running with --help?"
                exit
            end
            $settings.load_from_yaml(@config_file)

            if (not (@bools[:avahi] or @bools[:ip]))
                $stderr.puts "No action specified!"
                $stderr.puts "Try running with --help (or adding a -i or -A)"
                exit
            end

            if (@bools[:ip])
                @d = DNSIpController.new()
            end

            if (@bools[:avahi])
                @avahi_services = AvahiServiceFile.load_from_directory(@avahi_dir)
                @a = Wamupd::DNSAvahiController.new()
                @a.add_services(@avahi_services)

                @am = Wamupd::AvahiModel.new
            end
        end

        # Actually run the program
        def run
            # Publish/unpublish static records
            if (@bools[:publish])
                publish_static
            end
            if (@bools[:unpublish])
                unpublish_static
            end

            threads = []
            # Handle the DNS controller
            threads << Thread.new {
                @a.on(:quit) {
                    Thread.exit
                }
                @a.on(:added) { |record|
                    puts "Got a record through the Queue"
                }
                @a.run
            }
            @am.on(:added) { |avahi_service|
                puts "Found a new service with D-BUS"
                puts avahi_service
                @a.queue << Wamupd::Action.new(Wamupd::ActionType::ADD, avahi_service)
            }
            # Handle listening to D-BUS
            threads << Thread.new {
                @am.run
            }

            trap(2) {
                puts "Quitting"
                threads.each { |t|
                    t.exit
                }
            }

            threads.each { |t|
                t.join
            }
        end

        def publish_static
            if (@d)
                @d.publish
            end

            if (@a)
                @a.publish_all
            end
        end
        
        def unpublish_static
            if (@d)
                @d.unpublish
            end

            if (@a)
                @a.unpublish_all
            end
        end

        private :process_args
    end
end


if (__FILE__ == $0)
    w = Wamupd::Main.instance
    w.run
end
