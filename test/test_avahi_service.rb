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

class TestAvahiService < Test::Unit::TestCase
    def setup
        @settings = MainSettings.instance()
        @ssh = AvahiService.new(File.join($DATA_BASE, "ssh.service"))
        @simple = AvahiService.new(File.join($DATA_BASE, "simple.service"))
    end

    def test_ssh
        assert(@ssh.valid)
        assert_equal("Terminal Service", @ssh.name)
        assert_equal(1, @ssh.count)
        assert_equal(1, @ssh.size)
        @ssh.each { |s|
            assert_equal("_ssh._tcp", s.type)
            assert_equal(22, s.port)
            assert_nil(s.subtype)
            assert_nil(s.hostname)
            assert_nil(s.txt)
        }
    end

    def test_substution
        assert(@simple.valid)
        assert_equal(@settings.hostname, @simple.name)
    end
    
    def test_subtype_formatting
        assert_equal("_simple,_complex", @simple.first.subtype_display)
    end

    def test_dir
        d = AvahiService.load_from_directory($DATA_BASE)
        assert_equal(2, d.size)
        assert_equal(1, (d.find_all { |c| c.name == "Terminal Service"}).count)
        assert_equal(1, (d.find_all { |c| c.name == @settings.hostname}).count)
    end
end