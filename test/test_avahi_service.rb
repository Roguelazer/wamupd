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

require 'test/unit'
require 'main_settings'
require 'avahi_service'

class Test::AvahiService < Test::Unit::TestCase
    def test_hash_construct
        a = Wamupd::AvahiService.new("test", {
            :type=>"t",
            :subtype=>"s",
            :hostname=>"h",
            :domainname=>"d",
            :port=>10,
            :txt=>"txt"
        })
        assert_equal("test", a.name)
        assert_equal("t", a.type)
        assert_equal("s", a.subtype)
        assert_equal("h", a.hostname)
        assert_equal("d", a.domainname)
        assert_equal(10, a.port)
        assert_equal("txt", a.txt)

        a = Wamupd::AvahiService.new("", {})
        assert_equal("", a.name)
        assert_nil(a.type)
        assert_nil(a.subtype)
        assert_nil(a.hostname)
        assert_nil(a.domainname)
        assert_nil(a.port)
        assert_equal("\0", a.txt)
    end
end
