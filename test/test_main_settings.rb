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
require "main_settings"
require "socket"

class TestMainSettings < Test::Unit::TestCase
    def test_main
        sa = Wamupd::MainSettings.instance()
        sa.clear
        hostname = Socket.gethostname
        assert_equal(hostname, sa.hostname)
        assert_equal(7200, sa.ttl)
    end

    def test_yaml
        sa = Wamupd::MainSettings.instance()
        sa.clear
        sa.load_from_yaml(File.join($DATA_BASE, "config.yaml"))
        assert_equal("test", sa.hostname)
        assert_equal(5352, sa.dns_port)
        assert_equal("test.example.com", sa.dns_server)
        assert_equal("test.example.com", sa.dnssec_key_name)
        assert_equal("qvdra/qmRNop12eD/1Ez4Dr==", sa.dnssec_key_value)
        assert_equal(8640, sa.ttl)
    end
end
