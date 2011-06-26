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
require "signals"

require "dbus"
require "set"

# Wamupd is a module that is used to namespace all of the wamupd code.
module Wamupd
    # Model for Avahi's registered services. Uses D-BUS to talk to the
    # system Avahi daemon and pull down service information. It's kind of a
    # hack because Avahi has a really (really!) horrible D-BUS interface.
    #
    # ==Signals
    #
    # [:added]
    #    A service was added from the system Avahi. Includes the service as
    #    a parameter.
    #
    # [:removed]
    #    A service was removed from the system Avahi. Includes the service
    #    as a paramter.
    #
    # [:quit]
    #    The model is quitting.
    class AvahiModel
        include Signals

        # Constructor. Boring.
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
            @handlers = Hash.new
        end

        # Actually starts listening.
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
                mr.path = sb
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
                                        name = msg.params[2]
                                        type = msg.params[3]
                                        host = msg.params[5]
                                        address = msg.params[7]
                                        port = msg.params[8]
                                        txt = Wamupd::AvahiModel.pack_txt_param(msg.params[9])
                                        add_service_record(name, type, host, port, txt)
                                    end
                                end
                            end
                        end
                    elsif (item_msg.member == "ItemRemove")
                        if ((item_msg.params[5] & 8) != 0)
                            name = msg.params[2]
                            type = msg.params[3]
                            host = msg.params[5]
                            address = msg.params[7]
                            port = msg.params[8]
                            txt = Wamupd::AvahiModel.pack_txt_param(msg.params[9])
                            remove_service_record(name, type, host, port, txt)
                        end
                    end
                end
            }
        end

        # Pack an array of TXT parameters into a single TXT record
        # appropriately
        #
        # Note: The actual TXT record should consist of name-value pairs,
        # with each pair delimited by its length.
        #
        # As of 2010-04-21, Dnsruby internally converts double-quoted,
        # space-separted strings into the appropriate format. Most
        # annoyingly, if you provide it input already in the right format,
        # it sticks a completely unnecessary byte on the front and screws it
        # up.
        #
        # Aren't you happy you know that now?
        def self.pack_txt_param(strs)
            val = ""
            strs.each { |c|
                # Dnsruby uses multi-byte lengths if any of your records are
                # over 255 characters, though. This makes mDNSResponder get
                # amusingly confused.
                if (c.length > 255)
                    next
                end
                val += "\"#{c.pack("c*")}\" "
            }
            return val.chop
        end

        # Construct an AvahiService from the given parameters
        def add_service_record(name, type, host, port, txt)
            # Replace the .local that Avahi sticks at the end of the host (why
            # doesn't it just use the domain field? who knows?)
            host.sub!(/\.local$/, "")
            a = AvahiService.new(name, {:type=>type, :hostname=>host, :port=>port, :txt=>txt})
            @known_services[a.identifier] = a
            signal(:added, a)
        end

        # Remove an AvahiService using the given parameters.
        def remove_service_record(name, type, host, port, txt)
            a = AvahiService.new(name, {:type=>type, :hostname=>host, :port=>port, :txt=>txt})
            if (@known_services.has_key?(a.identifier))
                @known_services.delete(a.identifier)
            end
            signal(:removed, a)
        end

        # Exit the listener
        def exit
            signal(:quit)
        end

        # Run the listener. This function doesn't return until
        # exit is called.
        def run
            start_listen

            @main_loop = DBus::Main.new
            self.on(:quit) {
                @main_loop.quit
            }
            @main_loop << @bus
            @main_loop.run
        end

        private :add_type_listener
    end
end
