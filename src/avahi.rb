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

require "dbus"
require "set"

class AvahiModel
    def initialize
        @bus = DBus::SystemBus.instance
        @service = @bus.service("org.freedesktop.Avahi")
        @service.introspect
        @server = @service.object("/")
        @server.introspect
        @server = @server["org.freedesktop.Avahi.Server"]

        @service_types = Set.new
        @count = 0

        @known_services = Hash.new
    end

    def start_listen
        stb = @server.ServiceTypeBrowserNew(-1,-1,"",0)
        mr = DBus::MatchRule.new
        mr.type = "signal"
        mr.interface = "org.freedesktop.Avahi.ServiceTypeBrowser"
        mr.path = stb.first
        mr.member = "ItemNew"
        @bus.add_match(mr) do |msg, first_param|
            type = msg.params[2]
            if (not @service_types.member?(type))
                @service_types.add(msg.params[2])
                add_type_listener(msg.params[2])
            end
        end
    end

    # Add a D-BUS listener for an individual service type
    def add_type_listener(service_type)
        @server.ServiceBrowserNew(-1,-1,service_type,"",0) { |sb, first_param|
            sb=sb.params.first
            mr = DBus::MatchRule.new
            mr.type = "signal"
            mr.interface = "org.freedesktop.Avahi.ServiceBrowser"
            mr.path = sb.first
            @bus.add_match(mr) do |item_msg, first_param|
                if (item_msg.member == "ItemNew")
                    # From avahi-common/defs.h:
                    #
                    # typedef enum {
                    # AVAHI_LOOKUP_RESULT_CACHED = 1,         This response originates from the cache 
                    # AVAHI_LOOKUP_RESULT_WIDE_AREA = 2,      This response originates from wide area DNS 
                    # AVAHI_LOOKUP_RESULT_MULTICAST = 4,      This response originates from multicast DNS 
                    # AVAHI_LOOKUP_RESULT_LOCAL = 8,          This record/service resides on and was announced by the local host. Only available in service and record browsers and only on AVAHI_BROWSER_NEW. 
                    # AVAHI_LOOKUP_RESULT_OUR_OWN = 16,       This service belongs to the same local client as the browser object. Only available in avahi-client, and only for service browsers and only on AVAHI_BROWSER_NEW. 
                    # AVAHI_LOOKUP_RESULT_STATIC = 32         The returned data has been defined statically by some configuration option *
                    # } AvahiLookupResultFlags;
                    #
                    # AND the flags result (param 5) to limit ourselves to
                    # local services
                    if ((item_msg.params[5] & 8) != 0)
                        # Then use an async serviceresolver to look up the
                        # service. Has to be async, because otherwise
                        # there's a recursive call that causes us to run out
                        # of stack space. Woo broken libraries.
                        @server.ServiceResolverNew(-1,-1,item_msg.params[2],
                                                   item_msg.params[3],
                                                   item_msg.params[4],
                                                   -1,0) do |srb,fp|
                            srb = srb.params.first
                            mrs = DBus::MatchRule.new
                            mrs.type = "signal"
                            mrs.interface = "org.freedesktop.Avahi.ServiceResolver"
                            mrs.path = srb.first
                            @bus.add_match(mrs) do |msg,fp|
                                if (msg.member == "Found")
                                    name = item_msg.params[2]
                                    type = msg.params[3]
                                    host = msg.params[5]
                                    address = msg.params[7]
                                    port = msg.params[8]
                                    txt = msg.params[9]
                                    add_service_record(name, type, host, port, txt)
                                end
                                @count -= 1
                            end
                        end
                    end
                elsif (item_msg.member == "ItemRemove")
                    puts "Removing item #{item_msg.params[2]}"
                end
            end
        }
    end

    def add_service_record(name, type, host, port, txt)
        puts "Name=#{name}, Type=#{type}, Host=#{host}, Port=#{port}, Txt=#{txt}"
    end

    def main
        main = DBus::Main.new
        main << @bus
        main.run
    end
end

a = AvahiModel.new
a.start_listen
a.main
