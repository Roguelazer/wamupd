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

module Wamupd
    # Coordinate between a set of Avahi Services and DNS records
    class DNSAvahiController
        # Initialize the controller.
        def initialize()
            @sa = MainSettings.instance
            # Services stored as a hash from 
            @services = {}
            @resolver = @sa.resolver
            @added = []
        end

        # Add an array of services to the controller
        def add_services(services)
            services.each { |s| add_service(s) }
        end

        # Add a single service record to the controller
        def add_service(service)
            if service.kind_of?(AvahiService)
                @services[service.identifier] = service
            elsif (service.kind_of?(AvahiServiceFile))
                service.each { |service_entry|
                    self.add_service(service_entry)
                }
            else
                raise ArgumentError.new("Not an AvahiService")
            end
        end

        # Return the number of elements in the controller
        def size
            return @services.size
        end

        # Keys
        def keys
            return @services.keys
        end

        def publish_all
            to_update = []
            @services.each { |key,service|
                to_update << {:target=>service.type_in_zone,
                    :type=>Dnsruby::Types.PTR, :ttl=>@sa.ttl,
                    :value=>service.type_in_zone_with_name}
                to_update << {:target=>service.type_in_zone_with_name,
                    :type=>Dnsruby::Types.SRV, :ttl=>@sa.ttl,
                    :value=> "#{@sa.priority} #{@sa.weight} #{service.port} #{service.target}"}
                to_update << {:target => service.type_in_zone_with_name,
                    :type=>Dnsruby::Types.TXT, :ttl=>@sa.ttl,
                    :value=>service.txt}
            }
            DNSUpdate.publish_all(to_update)
        end

        def unpublish_all
            todo = []
            @services.each { |key,service|
                todo << [service.type_in_zone_with_name, Dnsruby::Types.SRV]
                todo << [service.type_in_zone, Dnsruby, Dnsruby::Types.PTR,
                    service.type_in_zone_with_name]
                todo << [service.type_in_zone_with_name, Dnsruby::Types.TXT]
            }
            DNSUpdate.unpublish_all(todo)
        end
    end
end
