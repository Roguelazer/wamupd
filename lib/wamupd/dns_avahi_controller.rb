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

require "wamupd/action"
require "wamupd/avahi_service"
require "wamupd/dns_update"
require "wamupd/lease_update"
require "wamupd/main_settings"
require "wamupd/signals"

require "algorithms"
require "dnsruby"
require "thread"

# Wamupd is a module that is used to namespace all of the wamupd code.
module Wamupd
    # Duplicate services were registered with the controller.
    # Should almost certainly be treated as non-fatal
    class DuplicateServiceError < StandardError
    end

    # Coordinate between a set of Avahi Services and DNS records
    #
    # == Signals
    #
    # [:added] 
    #    Raised when a new service is added to the controller and
    #    successfully registered.  has two parameters: the AvahiService
    #    added and the queue ID of the DNS request (or <tt>true</tt> if the
    #    request was synchronous)
    #
    # [:deleted]
    #    Raised when a service is deleted from the controller. Contains
    #    the deleted service as its parameter
    #
    # [:renewed] 
    #    Raised when a service's lease is renewed. Contains the renewed
    #    service as its parameter
    #
    # [:quit]
    #    Raised when the controller is quitting
    class DNSAvahiController
        include Wamupd::Signals

        # A queue to put actions into.
        attr_reader :queue

        # Initialize the controller.
        def initialize()
            @sa = MainSettings.instance
            # Services stored as a hash from 
            @services = {}
            @resolver = @sa.resolver
            @added = []
            @queue = Queue.new
            # Make a min priority queue for leases
            @lease_queue = Containers::PriorityQueue.new { |x,y| (x<=>y) == -1 }
        end

        # Add an array of services to the controller
        def add_services(services)
            services.each { |s| add_service(s) }
        end

        # Add a single service record to the controller
        def add_service(service)
            if service.kind_of?(AvahiService)
                if (not @services.has_key?(service.identifier))
                    @services[service.identifier] = service
                else
                    raise DuplicateServiceError.new("Got a duplicate")
                end
            elsif (service.kind_of?(AvahiServiceFile))
                service.each { |service_entry|
                    add_service(service_entry)
                }
            else
                raise ArgumentError.new("Not an AvahiService")
            end
        end

        # Delete a signle service record from the service
        def delete_service(service)
            if service.kind_of?(AvahiService)
                @services.delete(service.identifier)
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

        # Publish all currently stored records
        def publish_all
            ids = []
            @services.each { |key,service|
                ids << publish(service)
            }
            return ids
        end

        # Unpublish all stored records
        def unpublish_all
            todo = []
            @services.each { |key,service|
                todo << { :target=>service.type_in_zone_with_name, 
                    :type=>Dnsruby::Types.SRV,
                    :value=> "#{@sa.priority} #{@sa.weight} #{service.port} #{service.target}"}
                todo << { :target=>service.type_in_zone, 
                    :type=>Dnsruby::Types.PTR,
                    :value=>service.type_in_zone_with_name}
                todo << { :target=>service.type_in_zone_with_name,
                    :type=>Dnsruby::Types.TXT}
            }
            DNSUpdate.unpublish_all(*todo)
        end

        # Publish a single service
        #
        # Returns: the DNS request ID
        def publish(service, ttl=@sa.ttl, lease_time=@sa.lease_time)
            to_update = []
            to_update << {:target=>service.type_in_zone,
                :type=>Dnsruby::Types.PTR, :ttl=>ttl,
                :value=>service.type_in_zone_with_name}
            to_update << {:target=>service.type_in_zone_with_name,
                :type=>Dnsruby::Types.SRV, :ttl=>ttl,
                :value=> "#{@sa.priority} #{@sa.weight} #{service.port} #{service.target}"}
            # why doesn't Ruby have !==
            unless (service.txt === false)
                to_update << {:target => service.type_in_zone_with_name,
                    :type=>Dnsruby::Types.TXT, :ttl=>ttl,
                    :value=>service.txt}
            end
            update_time = Time.now() + lease_time
            @lease_queue.push(Wamupd::LeaseUpdate.new(update_time, service), update_time)
            return DNSUpdate.publish_all(to_update)
        end

        # Unpublish a single service
        def unpublish(service, ttl=@sa.ttl)
            todo = []
            to_update << {:target=>service.type_in_zone,
                :type=>Dnsruby::Types.PTR,
                :value=>service.type_in_zone_with_name}
            to_update << {:target=>service.type_in_zone_with_name, 
                :type=>DnsRuby::Types.SRV}
            to_update << {:target=>service.type_in_zone_with_name,
                :type=>Dnsruby::Types.TXT}
            DNSUpdate.unpublish_all(todo)
        end

        # Process a single Wamupd::Action out of the queue
        def process_action(action)
            case action.action
            when Wamupd::ActionType::ADD
                begin
                    add_service(action.record)
                    id = publish(action.record)
                    signal(:added, action.record, id)
                rescue DuplicateServiceError
                    # Do nothing
                end
            when Wamupd::ActionType::DELETE
                delete_service(action.record)
                unpublish_service(action.record)
                signal(:deleted, action.record)
            when Wamupd::ActionType::QUIT
                # Flush the queue, then signal quit
                until @queue.empty?
                    process_action(@queue.pop(false))
                end
                unpublish_all
                signal(:quit)
            end
        end

        # Exit out of the main loop
        def exit
            @queue << Wamupd::Action.new(Wamupd::ActionType::QUIT)
        end

        # Wait for data to go into the queue, and handle it when it does
        def run
            while true
                process_action(@queue.pop)
            end
        end

        # Takes care of updating leases. Run it in a separate thread from
        # the main "run" function
        def update_leases
            while true
                now = Time.now
                while (not @lease_queue.empty?) and (@lease_queue.next.date < now)
                    item = @lease_queue.pop
                    if @services.has_key?(item.service.identifier)
                        signal(:renewed, item.service)
                        publish(item.service)
                    end
                end
                sleep(@sa.sleep_time)
            end
        end

        private :process_action, :publish
    end
end
