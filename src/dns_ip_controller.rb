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

require "main_settings"
require "dnsruby"
require "socket"
require "ipaddr"

# Wrap local IP parameters
class LocalIP
    attr_reader :ipv4, :ipv6

    def initialize
        @ipv4 = nil
        @ipv6 = nil
        get_ip_addresses()
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
            s.connect("2001:4860:b006::1", 1)
            if (s.addr[0] == "AF_INET6")
                @ipv6 = IPAddr.new(s.addr.last)
            end
        rescue SocketError => e
            $stderr.puts "Unable to determine IPv6 address: #{e}"
        rescue Errno::ENETUNREACH
            $stderr.puts "Unable to determine IPv6 address: #{e}"
        end
    end
end

# Manage IP information in DNS
class DNSIpController
    # Constructor
    #
    # Arguments:
    # ip:: A LocalIP object (will be constructed if nil)
    def initialize(ip=nil)
        if (ip == nil)
            ip = LocalIP.new
        end
        @ip = ip
        @sa = MainSettings.instance
        @resolver = @sa.resolver
    end

    # Publish A and AAAA records
    def publish
        update = Dnsruby::Update.new(@sa.zone, "IN")
        if (@ip.ipv4)
            update.absent(@sa.target, Dnsruby::Types.A)
            update.add(@sa.target, Dnsruby::Types.A, @sa.ttl, @ip.ipv4)
            begin
                @resolver.send_message(update)
            rescue Dnsruby::YXRRSet => e
                $stderr.puts "Not adding IPv4 address because it already exists!"
            rescue Exception => e
                $stderr.puts "Registration failed: #{e}"
            end
        end
        update = Dnsruby::Update.new(@sa.zone, "IN")
        if (@ip.ipv6)
            update.absent(@sa.target, Dnsruby::Types.AAAA)
            update.add(@sa.target, Dnsruby::Types.AAAA, @sa.ttl, @ip.ipv6)
            begin
                @resolver.send_message(update)
            rescue Dnsruby::YXRRSet => e
                $stderr.puts "Not adding IPv6 address because it already exists!"
            rescue Exception => e
                $stderr.puts "Registration failed: #{e}"
            end
        end
    end

    # Unpublish A and AAAA records
    def unpublish
        update = Dnsruby::Update.new(@sa.zone, "IN")
        if (@ip.ipv4)
            update.present(@sa.target, Dnsruby::Types.A)
            update.delete(@sa.target, Dnsruby::Types.A, @ip.ipv4)
            begin
                @resolver.send_message(update)
            rescue Dnsruby::NXRRSet => e
                $stderr.puts "Not removing IPv4 address because it doesn't exist! (#{e})"
            rescue Exception => e
                $stderr.puts "Registration failed: #{e}"
            end
        end
        update = Dnsruby::Update.new(@sa.zone, "IN")
        if (@ip.ipv6)
            update.present(@sa.target, Dnsruby::Types.AAAA)
            update.delete(@sa.target, Dnsruby::Types.AAAA, @ip.ipv6)
            begin
                @resolver.send_message(update)
            rescue Dnsruby::NXRRSet => e
                $stderr.puts "Not removing IPv6 address because it doesn't exist! (#{e})"
            rescue Exception => e
                $stderr.puts "Registration failed: #{e}"
            end
        end
    end
end
