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

require "dnsruby"
require "singleton"
require "socket"
require "yaml"

# Wamupd is a module that is used to namespace all of the wamupd code.
module Wamupd
    # Simple singleton for storing app-side configuration-type
    # things
    class MainSettings
        include Singleton

        # The current hostname, or, if present, the 
        # host name desired from the YAML
        attr_reader :hostname

        # DNS server to try and update
        attr_reader :dns_server

        # Port to use when talking to the DNS server
        attr_reader :dns_port

        # DNSSEC key name (if nil, do not use DNSSEC)
        attr_reader :dnssec_key_name

        # DNSSEC key value (usually, a HMAC-MD5 private key)
        attr_reader :dnssec_key_value

        # Zone
        attr_reader :zone

        # Default TTL of records
        attr_reader :ttl

        # Default priority of SRV records
        attr_reader :priority

        # Default weight of SRV records
        attr_reader :weight

        # Current IPv4 address
        attr_reader :ipv4

        # Current IPv6 address
        attr_reader :ipv6

        # Minimum time to sleep between lease renewal checks
        attr_reader :sleep_time

        # Maximum time to wait for DNS
        attr_reader :max_dns_response_time

        # The lease renewal time. By default, ttl * (2/3)
        def lease_time
            return (0.667 * @ttl).to_i
        end

        # Constructor. Use the instance() function
        # to actually initialize
        def initialize
            @hostname = Socket.gethostname()
            @dns_port = 53
            @ttl = 7200
            @priority = 1
            @weight = 5
            @resolver = nil
            @ipv4 = nil
            @ipv6 = nil
            @sleep_time = 60
            @max_dns_response_time=10
        end

        # Are we using DNSSEC?
        def using_dnssec?
            return (not @dnssec_key_name.nil?)
        end

        # Target for ops
        def target
            t = ""
            t += @hostname
            t += "."
            t += @zone
            return t
        end

        # Load some more settings from a YAML file
        def load_from_yaml(yaml_file)
            y = YAML.load_file(yaml_file)
            properties_map = { 
                "hostname" => :@hostname,
                "dns_server" => :@dns_server,
                "dns_port" => :@dns_port,
                "dnssec_key_name" => :@dnssec_key_name,
                "dnssec_key_hmac" => :@dnssec_key_value,
                "zone" => :@zone,
                "ttl" => :@ttl,
                "srv_priority" => :@priority,
                "srv_weight" => :@weight,
                "sleep_time" => :@sleep_time
            }
            properties_map.each { |k,v|
                if (y.has_key?(k))
                    self.instance_variable_set(v, y[k])
                end
            }
        end

        # Reset the MainSettings
        def clear
            initialize
        end

        # Get a Dnsruby::Resolver
        def resolver
            if (@resolver.nil?)
                make_resolver
            end
            return @resolver
        end

        def make_resolver
            if self.using_dnssec?
                ts = Dnsruby::RR.new_from_hash({
                    :type=>Dnsruby::Types.TSIG,
                    :klass=>Dnsruby::Classes.ANY,
                    :name=>self.dnssec_key_name,
                    :key=>self.dnssec_key_value,
                    :algorithm=>Dnsruby::RR::TSIG::HMAC_MD5
                })
            end
            @resolver = Dnsruby::Resolver.new({
                :nameserver => self.dns_server,
                :port => self.dns_port,
                :tsig => ts,
                :dnssec => false
            })
            
        end

        # Get IPv4 and IPv6 addresses
        def get_ip_addresses
            sa = MainSettings.instance
            begin
                s = UDPSocket.new(Socket::AF_INET)
                s.connect("8.8.8.8", 1)
                if (s.addr[0] == "AF_INET")
                    @ipv4 = IPAddr.new(s.addr.last)
                end
            rescue SocketError => e
                $stderr.puts "Unable to determine IPv4 address: #{e}"
            rescue Errno::ENETUNREACH => e
                $stderr.puts "Unable to determine IPv4 address: #{e}"
            end

            begin
                s = UDPSocket.new(Socket::AF_INET6)
                s.connect("2001:4860:b006::2", 1)
                if (s.addr[0] == "AF_INET6")
                    @ipv6 = IPAddr.new(s.addr.last)
                end
            rescue SocketError => e
                $stderr.puts "Unable to determine IPv6 address: #{e}"
            rescue Errno::ENETUNREACH => e
                $stderr.puts "Unable to determine IPv6 address: #{e}"
            end
        end

        private :make_resolver
    end
end
