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
require "thread"
require "avahi_service_file"
require "dns_avahi_controller"

class TestDNSAvahiStaticController < Test::Unit::TestCase
    def test_1
        service = nil
        dc = nil
        assert_nothing_raised() {
            service = Wamupd::AvahiServiceFile.new(File.join($DATA_BASE, "ssh.service"))
            dc = Wamupd::DNSAvahiController.new()
            dc.add_services(service)
        }
        assert_not_nil(service)
        assert_not_nil(dc)
        assert_equal(1, dc.size)
        assert_equal("_ssh._tcp-22", dc.keys[0])
    end

    def test_parallel
        d = Wamupd::DNSAvahiController.new()
        i = 0
        dt = Thread.new {
            d.on(:added) {
                i += 1
            }
            d.on(:quit) {
                Thread.exit
            }
            d.run
        }
        ct = Thread.new {
            d.queue.push(Wamupd::Action.new(Wamupd::ActionType::ADD, ""))
            d.queue.push(Wamupd::Action.new(Wamupd::ActionType::QUIT))
        }
        dt.join
        ct.join
        assert_equal(1, i)
    end

    def test_parallel_2
        d = Wamupd::DNSAvahiController.new()
        i = 0
        dt = Thread.new {
            d.on(:added) {
                i += 1
            }
            d.on(:quit) {
                Thread.exit
            }
            d.run
        }
        ct = Thread.new {
            d.queue.push(Wamupd::Action.new(Wamupd::ActionType::ADD, ""))
            d.queue.push(Wamupd::Action.new(Wamupd::ActionType::ADD, ""))
            d.queue.push(Wamupd::Action.new(Wamupd::ActionType::ADD, ""))
        }
        c2t = Thread.new {
            d.queue.push(Wamupd::Action.new(Wamupd::ActionType::ADD, ""))
            d.queue.push(Wamupd::Action.new(Wamupd::ActionType::ADD, ""))
            d.queue.push(Wamupd::Action.new(Wamupd::ActionType::ADD, ""))
            d.queue.push(Wamupd::Action.new(Wamupd::ActionType::QUIT, ""))
        }
        dt.join
        ct.join
        c2t.join
        assert_equal(6, i)
    end

    def test_raise
        d = Wamupd::DNSAvahiController.new
        service = Wamupd::AvahiServiceFile.new(File.join($DATA_BASE, "ssh.service"))
        service2 = Wamupd::AvahiService.new("NOT SSH", {:type=>"_ssh._tcp", :port=>22})
        assert_nothing_raised { d.add_service(service) }
        assert_raise(Wamupd::DuplicateServiceError) { d.add_service(service) }
        assert_raise(Wamupd::DuplicateServiceError) { d.add_service(service2) }
    end
end
