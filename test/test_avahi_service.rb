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
    def setup
        @settings = Wamupd::MainSettings.instance()
        @ssh = Wamupd::AvahiService.new_from_file(File.join($DATA_BASE, "ssh.service"))
        @simple = Wamupd::AvahiService.new_from_file(File.join($DATA_BASE, "simple.service"))
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
            assert_equal("\0", s.txt)
        }
    end

    def test_substution
        assert(@simple.valid)
        assert_equal(@settings.hostname, @simple.name)
    end

    def test_txt
        assert_equal("Simple Service", @simple.first.txt)
    end
    
    def test_subtype_formatting
        assert_equal("_simple,_complex", @simple.first.subtype_display)
    end

    def test_dir
        d = Wamupd::AvahiService.load_from_directory($DATA_BASE)
        assert_equal(2, d.size)
        assert_equal(1, (d.find_all { |c| c.name == "Terminal Service"}).count)
        assert_equal(1, (d.find_all { |c| c.name == @settings.hostname}).count)
    end

    def test_in_zone
        @settings.clear
        @settings.load_from_yaml(File.join($DATA_BASE, "config.yaml"))
        assert_equal("_ssh._tcp.browse.test.example.com", @ssh.first.type_in_zone)
    end

    def test_target
        @settings.clear
        @settings.load_from_yaml(File.join($DATA_BASE, "config.yaml"))
        assert_equal("test.browse.test.example.com", @ssh.first.target)
        assert_equal("localhost.localdomain", @simple.first.target)
    end

    def test_hash_construct
        a = Wamupd::AvahiService::AvahiServiceEntry.new({
            :type=>"t",
            :subtype=>"s",
            :hostname=>"h",
            :domainname=>"d",
            :port=>10,
            :txt=>"txt"
        })
        assert_equal("t", a.type)
        assert_equal("s", a.subtype)
        assert_equal("h", a.hostname)
        assert_equal("d", a.domainname)
        assert_equal(10, a.port)
        assert_equal("txt", a.txt)

        a = Wamupd::AvahiService::AvahiServiceEntry.new({})
        assert_nil(a.type)
        assert_nil(a.subtype)
        assert_nil(a.hostname)
        assert_nil(a.domainname)
        assert_nil(a.port)
        assert_equal("\0", a.txt)
    end

    def test_main_construct
        a = Wamupd::AvahiService.new("test")
        assert_equal("test", a.name)
        assert_equal(0, a.size)

        a = Wamupd::AvahiService.new("test", {})
        assert_equal("test", a.name)
        assert_equal(1, a.size)
    end
end
