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

require "xml"

require "avahi_service"

# Wamupd is a module that is used to namespace all of the wamupd code.
module Wamupd
    # AvahiServiceFile is a class to abstract Avahi's .service files. It is
    # capable of loading, parsing, and validating these files into a group
    # of AvahiService objects.
    class AvahiServiceFile
        include Enumerable

        SERVICE_DTD_PATH = "/usr/local/share/avahi/avahi-service.dtd";

        # Get the name of this service
        def name
            if (@replace_wildcards)
                return AvahiServiceFile.replace_wildcards(@name)
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

        # Has this service file entry been validated against the DTD?
        def valid?
            return @valid
        end

        # Initialize the service from a service file
        def initialize(filename)
            @valid = false
            @services = []
            @replace_wildcards = false
            load_from_file(filename)
        end

        # Load this AvahiService entry from a .service defintion file
        #
        # Arguments:
        # filename:: The file to load
        def load_from_file(filename)
            d = XML::Document.file(filename)
            if (not File.exists?(SERVICE_DTD_PATH))
                $stderr.puts "Could not find service DTD at #{SERVICE_DTD_PATH}"
                exit(1)
            end
            dtd = File.open(SERVICE_DTD_PATH, "r") { |f|
                lines = f.readlines().join("")
            }
            validator = XML::Dtd.new(dtd)
            @valid = d.validate(validator)
            if (not @valid)
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
                    node = c
                    params = {}
                    node.children.each { |c|
                        case c.name
                        when "type"
                            params[:type] = c.content
                        when "subtype"
                            params[:subtype] = c.content
                        when "host-name"
                            params[:hostname] = c.content
                        when "port"
                            params[:port] = c.content.to_i
                        when "txt-record"
                            params[:txt] = c.content
                        when "domain-name"
                            params[:domainname] = c.content
                        end
                    }
                    @services.push(AvahiService.new(self.name, params))
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
                retval.push(AvahiServiceFile.new(f))
            }
            return retval
        end
    end
end

