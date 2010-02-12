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

require 'xml'

$service_dtd_path = "/usr/share/avahi/avahi-service.dtd";

class AvahiService
    include Enumerable

    # Has this service been XML-validated?
    attr_reader :valid

    # A single <service> entry from a service record. A given service (i.e.,
    # SSH) might have many service entries corresponding to all of the
    # different ports it is available on
    class AvahiServiceEntry
        attr_reader :type
        attr_reader :subtype
        attr_reader :hostname
        attr_reader :port
        attr_reader :txt

        # Get the subtype as Apple displays it
        def subtype_display
            "#{@type},#{@subtype}"
        end

        # Initialize from an XML node
        def initialize(node)
            node.children.each { |c|
                case c.name
                when "type"
                    @type = c.content
                when "subtype"
                    @subtype = c.content
                when "host-name"
                    @hostname = c.content
                when "port"
                    @port = c.content.to_i
                when "txt-record"
                    @txt = c.content
                end
            }
        end
    end

    # Get the name of this service
    def name
        if (@replace_wildcards)
            return AvahiService.replace_wildcards(@name)
        end
        return @name
    end

    # Access each service in turn
    def each(&block)
        @services.each { |c|
            yield c
        }
    end

    # The number of services in this definition
    def size
        return @services.count
    end

    # The first service defined
    def first
        if (self.size > 0)
            return @services[0]
        else
            return nil
        end
    end

    # Replace the wildcards in a string using the Avahi
    # rules
    def self.replace_wildcards(string)
        return string.sub("%h", MainSettings.instance.hostname)
    end

    # Initialize the service from a service file
    def initialize(filename)
        @valid = false
        @services = []
        d = XML::Document.file(filename)
        if (not File.exists?($service_dtd_path))
            $stderr.puts "Could not find service DTD at #{$service_dtd_path}"
            exit(1)
        end
        dtd = File.open($service_dtd_path, "r") { |f|
            lines = f.readlines().join("")
        }
        validator = XML::Dtd.new(dtd)
        @valid = d.validate(validator)
        if (not valid)
            $stderr.puts "Service file #{filename} failed validation"
            exit(1)
        end
        sg = d.root
        sg.children.each { |c|
            case c.name
            when "name"
                @name = c.content
                if ((not c["replace-wildcards"].nil?) and (c["replace-wildcards"] == "yes"))
                    @replace_wildcards = true
                end
            when "service"
                @services.push(AvahiServiceEntry.new(c))
            end
        }
    end

    # Load all of the service definitions in a directory 
    #
    # Returns:
    # an array of AvahiService objects
    def self.load_from_directory(dir)
        retval = []
        Dir.glob(File.join(dir, "*.service")).each { |f|
            retval.push(AvahiService.new(f))
        }
        return retval
    end
end