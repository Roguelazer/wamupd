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

require "singleton"
require "socket"
require "yaml"

# Simple singleton for storing app-side configuration-type
# things
class MainSettings
    include Singleton

    # The current hostname, or, if present, the 
    # host name desired from the YAML
    attr_reader :hostname

    # DNS server to try and update
    attr_reader :dns_server

    # Port to use when talking to the DNS server
    attr_reader :dns_port

    # DNSSEC key name (if nil, do not use DNSSEC)
    attr_reader :dnssec_key_name

    # DNSSEC key value (usually, a HMAC-MD5 private key)
    attr_reader :dnssec_key_value

    # Constructor. Use the instance() function
    # to actually initialize
    def initialize
        @hostname = Socket.gethostname()
        @dns_port = 53
    end

    # Load some more settings from a YAML file
    def load_from_yaml(yaml_file)
        y = YAML.load_file(yaml_file)
        properties_map = { 
            "hostname" => :@hostname,
            "dns_server" => :@dns_server,
            "dns_port" => :@dns_port,
            "dnssec_key_name" => :@dnssec_key_name,
            "dnssec_key_hmac" => :@dnssec_key_value
        }
        properties_map.each { |k,v|
            if (y.has_key?(k))
                self.instance_variable_set(v, y[k])
            end
        }
    end

    # Reset the MainSettings
    def clear
        initialize
    end
end
