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

require "test/unit"
require "avahi_service_file"
require "dns_avahi_controller"

class TestDNSAvahiStaticController < Test::Unit::TestCase
    def test_1
        service = nil
        dc = nil
        assert_nothing_raised() {
            service = Wamupd::AvahiServiceFile.new(File.join($DATA_BASE, "ssh.service"))
            dc = Wamupd::DNSAvahiStaticController.new()
            dc.add_services(service)
        }
        assert_not_nil(service)
        assert_not_nil(dc)
        assert_equal(1, dc.size)
        assert_equal("_ssh._tcp-22", dc.keys[0])
    end
end
