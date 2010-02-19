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
#
# == Signals

require 'xml'

module Wamupd
    # A single <service> entry from a service record. A given service (i.e.,
    # SSH) might have many service entries corresponding to all of the
    # different ports it is available on
    class AvahiService
        attr_reader :type
        attr_reader :subtype
        attr_reader :hostname
        attr_reader :port
        attr_reader :domainname
        attr_reader :name

        # Get the subtype as Apple displays it
        def subtype_display
            "#{@type},#{@subtype}"
        end

        def type_in_zone_with_name
            sa = MainSettings.instance
            return sa.hostname + "." + @type + "."+ sa.zone
        end

        def type_in_zone
            sa = MainSettings.instance
            return @type + "." + sa.zone
        end

        # A key that can be used to identify this service.
        # Is the subtype-type followed by a - followed by the port
        def identifier
            retval = ""
            if (@subtype)
                retval += @subtype
                retval += "."
            end
            if (@type)
                retval += @type
                retval += "-"
            end
            retval += @port.to_s
            return retval
        end

        def target
            t = ""
            sa = MainSettings.instance
            if (@hostname.nil?)
                t += sa.hostname
            else
                t += @hostname
            end
            t += "."
            if (@domainname.nil?)
                t += sa.zone
            else
                t += @domainname
            end
        end

        # TXT record
        def txt
            return @txt.nil? ? "\0" : @txt
        end

        # Initialize
        #
        # Argument:
        # Either an XML node or a hash with some useful subset of the
        # parameters :type, :subtype, :hostname, :port, :txt, and
        # :domainname
        def initialize(name, param)
            @name = name
            mapping = {:type=>:@type,
                :subtype=>:@subtype,
                :hostname=>:@hostname,
                :port=>:@port,
                :txt=>:@txt,
                :domainname=>:@domainname
            }
            mapping.each {|k,v|
                if (param.has_key?(k))
                    self.instance_variable_set(v, param[k])
                end
            }
        end

        # String coercer
        def to_s
            "<AvahiService name='#{@name}' type=#{@type} txt=#{self.txt}>"
        end
    end
end
