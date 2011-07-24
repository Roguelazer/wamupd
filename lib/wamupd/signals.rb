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

# Wamupd is a module that is used to namespace all of the wamupd code.
module Wamupd
    # Mixin for basic event-driven processing. Listeners register using the
    # on function. Classes which include Signals can raise a signal with the
    # signal function.
    module Signals
        # Add a handler for the specified signal
        #
        # *Args:*
        # [name] An atom of the signal name
        def on(name, &action) # :yields: parameters
            if (not @handlers)
                @handlers = Hash.new
            end
            if (not @handlers.has_key?(name))
                @handlers[name] = []
            end
            @handlers[name] << action
        end

        # Raise a signal. Any additional args will be passed to the handler
        def signal(name, *args) #:doc:
            if (not @handlers)
                @handlers = Hash.new
            end
            if (@handlers.has_key?(name))
                @handlers[name].each { |handler|
                    handler.call(*args)
                }
            end
        end

        private :signal
    end
end
