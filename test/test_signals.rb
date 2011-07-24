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
require "signals"


class TestSignals < Test::Unit::TestCase

    class Tester
        include Wamupd::Signals

        def signal2(*args)
            signal(*args)
        end
    end

    def setup
        @tester = Tester.new
    end

    def test_basic
        assert_respond_to(@tester, :on)
    end

    def test_func
        i = 0
        @tester.on(:hello) {
            i += 1
        }
        @tester.signal2(:hello)
        assert_equal(1, i)
    end

    def test_data
        data = nil
        @tester.on(:data) { |d|
            data = d
        }
        @tester.signal2(:data, :result)
        assert_not_nil(data)
        assert_equal(:result, data)
    end
end
