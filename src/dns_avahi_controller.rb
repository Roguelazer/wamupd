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
require "dns_update"

# Coordinate between a set of Avahi Services and DNS records
class DNSAvahiController
    attr_reader :resolver

    # Initialize the controller. Takes an array of services
    def initialize(services)
        @sa = MainSettings.instance
        @services = services
        @resolver = @sa.resolver
        @added = []
    end

    def publish_all
        to_update = []
        @services.each { |service|
            service.each { |service_entry|
                to_update << {:target=>service_entry.type_in_zone,
                    :type=>Dnsruby::Types.PTR, :ttl=>@sa.ttl,
                    :value=>service_entry.type_in_zone_with_name}
                to_update << {:target=>service_entry.type_in_zone_with_name,
                    :type=>Dnsruby::Types.SRV, :ttl=>@sa.ttl,
                    :value=> "#{@sa.priority} #{@sa.weight} #{service_entry.port} #{service_entry.target}"}
                to_update << {:target => service_entry.type_in_zone_with_name,
                    :type=>Dnsruby::Types.TXT, :ttl=>@sa.ttl,
                    :value=>service_entry.txt}
            }
        }
        DnsUpdate.publish_all(to_update)
    end

    def unpublish_all
        todo = []
        @services.each { |service|
            service.each { |service_entry|
                todo << [service_entry.type_in_zone_with_name, Dnsruby::Types.SRV]
                todo << [service_entry.type_in_zone, Dnsruby, Dnsruby::Types.PTR,
                    service_entry.type_in_zone_with_name]
                todo << [service_entry.type_in_zone_with_name, Dnsruby::Types.TXT]
            }
        }
        DnsUpdate.unpublish_all(todo)
    end
end
