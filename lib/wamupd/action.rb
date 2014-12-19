# Copyright (C) 2010 James Brown <roguelazer@roguelazer.com>.
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

module Wamupd
    # Possible actions in the system. Essentially, an enum
    class ActionType
        ADD=1
        DELETE=2
        QUIT=4
    end

    # A command wrapper
    class Action
        # The action to be performed. A Wamupd::ActionType
        attr_reader :action

        # The associated record (might be an AvahiService, or whatever else
        # is appropriate). Might be nil
        attr_reader :record

        def initialize(action, record=nil)
            @action=action
            @record=record
        end
    end
end
