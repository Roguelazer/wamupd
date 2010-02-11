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

# Update load path to include main src directory
$:.push(File.join(File.dirname(__FILE__), "..", "src"))
$DATA_BASE=File.join(File.dirname(__FILE__), "data")


if (ARGV.size == 0)
    # Require all of the test_*'s
    Dir.glob("test_*.rb") { |f|
        require f
    }
else
    ARGV.each { |arg|
        require "test_#{arg}.rb"
    }
end
