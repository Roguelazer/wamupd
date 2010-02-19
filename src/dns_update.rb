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

module Wamupd
    # Class to help with constructing DNS UPDATEs. Probably not useful except to
    # me.
    class DNSUpdate
        @@queue = nil
        @@outstanding = []

        # Set the queue
        def self.queue=(v)
            @@queue=v
        end

        # How many requests are outstanding?
        def self.outstanding
            return @@outstanding
        end

        # Is this update going to be asynchronous?
        def self.async?
            return (not @@queue.nil?)
        end
    
        # Publish a batch of DNS records
        #
        # Arguments:
        # An array of records to publish. Each record is either a Hash
        # containing the keys :target, :type, :ttl, and :value, or an array of
        # items which could be args to Dnsruby::Update::add
        def self.publish_all(args)
            sa = MainSettings.instance()
            resolver = sa.resolver
            update = Dnsruby::Update.new(sa.zone, "IN")
            shortest_ttl=86400
            args.each { |arg|
                if (arg.kind_of?(Hash))
                    update.add(arg[:target], arg[:type], arg[:ttl], arg[:value])
                    if (arg[:ttl] < shortest_ttl)
                        shortest_ttl = arg[:ttl]
                    end
                elsif (arg.kind_of?(Array))
                    if (arg[2] < shortest_ttl)
                        shortest_ttl = arg[2]
                    end
                    update.add(*arg)
                else
                    raise ArgumentError.new("Could not parse arguments")
                end
            }
            opt = Dnsruby::RR::OPT.new
            lease_time = Dnsruby::RR::OPT::Option.new(2, [shortest_ttl].pack("N"))
            opt.klass="IN"
            opt.options=[lease_time]
            opt.ttl = 0
            update.add_additional(opt)
            update.header.rd = false
            begin
#                if (async?)
#                    puts "Sending asynchronous request"
#                    resolver.send_async(update, @@queue)
#                    @@outstanding += 1
#                else
                    resolver.send_message(update)
#                end
            rescue Dnsruby::TsigNotSignedResponseError => e
                # Not really an error for UPDATE; we don't care if the reply is
                # signed!
                nil
            rescue Exception => e
                $stderr.puts "Registration failed: #{e.to_s}"
            end
        end

        # Publish a single DNS record
        #
        # Arguments:
        # Same as Dnsruby::Update::add
        def self.publish(*args)
            self.publish_all([args])
        end

        # Unpublish a batch of DNS records
        #
        # Arguments:
        # An array of records to unpublish. Each record is either a Hash
        # containing keys :target, :type, and :value, or an array of items which
        # could be args to Dnsruby::Update::delete
        def self.unpublish_all(*args)
            sa = MainSettings.instance()
            resolver = sa.resolver
            update = Dnsruby::Update.new(sa.zone, "IN")
            args.each { |arg|
                if (arg.kind_of?(Hash))
                    if (arg.has_key?(:value))
                        update.delete(arg[:target], arg[:type], arg[:value])
                    else
                        update.delete(arg[:target], arg[:type])
                    end
                elsif (arg.kind_of?(Array))
                    update.delete(*arg)
                else
                    raise ArgumentError.new("Could not parse arguments")
                end
            }
            begin
                if (async?)
                    queue_id = resolver.send_async(update, @@queue)
                    puts "ID = #{queue_id}"
                    puts update
                    @@outstanding << queue_id
                else
                    resolver.send_message(update)
                end
            rescue Dnsruby::NXRRSet => e
                $stderr.puts "Could not remove record because it doesn't exist!"
            rescue Dnsruby::TsigNotSignedResponseError => e
                # Not really an error for UPDATE; we don't care if the reply is
                # signed!
                nil
            rescue Exception => e
                $stderr.puts "Unregistration failed: #{e.to_s}"
            end

        end

        # Unpublish a single DNS record
        #
        # Arguments:
        # Same as Dnsruby::Update::delete
        def self.unpublish(*args)
            self.unpublish_all(args)
        end
    end
end
