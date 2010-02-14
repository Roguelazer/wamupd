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

require "avahi_service"
require "main_settings"
require "dnsruby"

# Coordinate between a set of Avahi Services and DNS records
class DNSAvahiController
    attr_reader :resolver

    # Initialize the controller. Takes an array of services
    def initialize(services)
        @sa = MainSettings.instance
        @services = services
        @resolver = @sa.resolver
    end

    def publish_all
        update = Dnsruby::Update.new(@sa.zone, "IN")
        @services.each { |service|
            service.each { |service_entry|
                puts update.add(service_entry.type_in_zone,
                                Dnsruby::Types.SRV, @sa.ttl,
                                "#{@sa.priority} #{@sa.weight} #{service_entry.port} #{service_entry.target}")
            }
        }
        begin
            @resolver.send_message(update)
        rescue Exception => e
            puts "Registration failed: #{e}"
        end
    end

    def unpublish_all
        update = Dnsruby::Update.new(@sa.zone, "IN")
        @services.each { |service|
            service.each { |service_entry|
                puts update.delete(service_entry.type_in_zone,
                                Dnsruby::Types.SRV,
                                "#{@sa.priority} #{@sa.weight} #{service_entry.port} #{service_entry.target}")
            }
        }
        begin
            @resolver.send_message(update)
        rescue Exception => e
            puts "Deletion failed: #{e}"
        end
    end
end
