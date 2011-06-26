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
# -a, --avahi
#   Load Avahi services over D-BUS
# -A DIRECTORY, --avahi-services DIRECTORY
#   Load Avahi service definitions from DIRECTORY
#   If DIRECTORY is not provided, defaults to /etc/avahi/services
#   If the -A flag is omitted altogether, static records will not be added.
# -c FILE, --config FILE:
#   Get configuration data from FILE
# -i, --ip-addreses (or --no-ip-addresses)
#   Enable/Disable Publishing A and AAAA records
# -h, --help:
#   Show this help
# -v, --verbose
#   Be verbose

# Update the include path
$:.push(File.dirname(__FILE__))

require "rubygems"
require "avahi_model"
require "avahi_service"
require "avahi_service_file"
require "dns_avahi_controller"
require "dns_ip_controller"

require "getoptlong"
require "optparse"
require "singleton"
require "timeout"

$verbose = false

# Wamupd is a module that is used to namespace all of the wamupd code.
module Wamupd
    Options = Struct.new(:config, :ip_addresses, :avahi, :verbose, :avahi_services_dir, :avahi_services)
#    $options = Options.new(:config => "/etc/wamupd.yaml", :ip_addresses => false, :avahi => false, :verbose => false, :avahi_services_dir => "/etc/avahi/services/")
    $options = Options.new
    $options.config = "/etc/wamupd.yaml"
    $options.ip_addresses = false
    $options.avahi = false
    $options.avahi_services = false
    $options.verbose = false
    
    OptionParser.new do |opts|
      opts.banner = "Usage: wamupd [options] service-file"

      opts.on("-c", "--config FILE", "Get configuration data from FILE") do |cfg|
        $options.config = cfg
      end

      opts.on("-A", "--avahi-services [DIRECTORY]", 
        "Load Avahi service definitions from DIRECTORY",
        "  If DIRECTORY is not provided, defaults to /etc/avahi/services",
        "  If the -A flag is omitted altogether, static records will not be added.") do |services|
        $options.avahi_services_dir = services || "/etc/avahi/services"
        $options.avahi_services = true
      end

      opts.on("-i", "--[no-]ip-addresses", "Enable/Disable Publishing A and AAAA records") do |ips|
        $options.ip_addresses = ips
      end

      opts.on("-a", "--avahi", "Load Avahi services over D-BUS") do |avahi|
        $options.avahi = true
      end 

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.on("-v", "--verbose", "Be verbose") do
        $options.verbose = true
      end
    end.parse!

# wamupd service-file
#
# -a, --avahi
#   Load Avahi services over D-BUS
# -A DIRECTORY, --avahi-services DIRECTORY
#   Load Avahi service definitions from DIRECTORY
#   If DIRECTORY is not provided, defaults to /etc/avahi/services
#   If the -A flag is omitted altogether, static records will not be added.
# -c FILE, --config FILE:
#   Get configuration data from FILE
# -i, --ip-addreses (or --no-ip-addresses)
#   Enable/Disable Publishing A and AAAA records
# -h, --help:
#   Show this help
# -v, --verbose
#   Be verbose
#    OPTS = GetoptLong.new(
#        ["--help", "-h", GetoptLong::NO_ARGUMENT],
#        ["--config", "-c", GetoptLong::REQUIRED_ARGUMENT],
#        ["--avahi-services", "-A", GetoptLong::OPTIONAL_ARGUMENT],
#        ["--avahi", "-a", GetoptLong::NO_ARGUMENT],
#        ["--ip-addresses", "-i", GetoptLong::NO_ARGUMENT],
#        ["--no-ip-addresses", GetoptLong::NO_ARGUMENT],
#        ["--verbose", "-v", GetoptLong::NO_ARGUMENT]
#    ) # :nodoc:

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
                "--avahi" => :avahi,
                "--avahi-services" => :avahi_services,
                "--ip-addresses" => :ip
            }

            @config_file = $options.config
            @avahi_dir = $options.avahi_services_dir
            @bools[:ip] = $options.ip_addresses
            $verbose = $options.verbose
            @bools[:avahi] = $options.avahi
            @bools[:avahi_services] = $options.avahi_services

#            OPTS.each do |opt,arg|
#                case opt
#                when "--help"
#                    RDoc::usage
#                when "--config"
#                    @config_file = arg.to_s
#                when "--avahi-services"
#                    if (not arg.nil? and arg != "")
#                        @avahi_dir=arg
#                    end
#                when "--no-ip-addresses"
#                    @bools[:ip] = false
#                when "--verbose"
#                    $verbose = true
#                end
#                if (boolean_vars.has_key?(opt))
#                    @bools[boolean_vars[opt]] = true
#                end
#            end
        end

        # Construct the object and process all command-line options
        def initialize
            @bools = {
                :publish=>false,
                :unpublish=>false,
                :avahi=>false,
                :avahi_services=>false,
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

            if (@bools[:ip])
                @d = DNSIpController.new()
            end

            if (@bools[:avahi] or @bools[:avahi_services])
                @a = Wamupd::DNSAvahiController.new()
            end

            if (@bools[:avahi_services])
                @avahi_services = AvahiServiceFile.load_from_directory(@avahi_dir)
            end
            :w

            if (@bools[:avahi])
                @am = Wamupd::AvahiModel.new
            end
        end

        # Actually run the program.
        #
        # This call doesn't return until SIGTERM is caught.
        def run
            puts "Starting main function" if $verbose
            publish_static

            update_queue = Queue.new
            DNSUpdate.queue = update_queue

            threads = []
            if (@bools[:avahi] or @bools[:avahi_services])
                # Handle the DNS controller
                threads << Thread.new {
                    @a.on(:quit) {
                        Thread.exit
                    }
                    @a.on(:added) { |item,id|
                        puts "Added #{item.type_in_zone_with_name} (id=\"#{id}\")" if $verbose
                    }
                    @a.on(:deleted) { |item|
                        puts "Deleted #{item.type_in_zone_with_name}" if $verbose
                    }
                    @a.on(:renewed) { |item|
                        puts "Renewed #{item.type_in_zone_with_name}" if $verbose
                    }
                    @a.run
                }

                # Lease maintenance
                threads << Thread.new {
                    @a.update_leases
                }
            end

            if (@bools[:avahi])
                @am.on(:added) { |avahi_service|
                    @a.queue << Wamupd::Action.new(Wamupd::ActionType::ADD, avahi_service)
                }
                # Handle listening to D-BUS
                threads << Thread.new {
                    @am.run
                }
            end
            
            if (@bools[:ip])
                threads << Thread.new{
                    @d.update_leases
                }
            end

            threads << Thread.new {
                while (1)
                    response_id, response, exception = update_queue.pop
                    puts "Got back response #{response_id}" if $verbose
                    if (not exception.nil?)
                        if (exception.kind_of?(Dnsruby::TsigNotSignedResponseError))
                            # Do nothing
                        else
                            $stderr.puts "Error: #{exception}"
                            $stderr.puts response
                        end
                    end
                    if (response.rcode != Dnsruby::RCode::NOERROR)
                        $stderr.puts "Got an unexpected rcode (#{response.rcode})"
                        $stderr.puts response
                    end
                    if DNSUpdate.outstanding.delete(response_id).nil?
                        $stderr.puts "Got back an unexpected response ID"
                        $stderr.puts response
                    end
                end
            }

            trap("INT") {
                puts "Unregistering services, please wait..."
                if (@bools[:avahi] or @bools[:avahi_services])
                    @a.exit
                end
                if (@bools[:avahi])
                    @am.exit
                end
                if (@bools[:ip])
                    @d.unpublish
                end
                sleep($settings.max_dns_response_time)
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
                if ($verbose)
                    @d.on(:added) { |type,address|
                        puts "Added #{type} record for #{address}"
                    }
                    @d.on(:removed) { |type,address|
                        puts "Removed #{type} record for #{address}"
                    }
                end
                @d.publish
            end

            if (@avahi_services)
                @avahi_services.each { |avahi_service_file|
                    avahi_service_file.each { |avahi_service|
                        @a.queue << Wamupd::Action.new(Wamupd::ActionType::ADD, avahi_service)
                    }
                }
            end
        end

        private :process_args, :publish_static
    end
end


if (__FILE__ == $0)
    w = Wamupd::Main.instance
    w.run
end
