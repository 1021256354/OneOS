	Process = nil
	EventQueue = {}
	Timers = {}
	AppRedirect = nil
	Running = true
	local _args = {}
	Initialise = function(self, shell, path, title, args, appRedirY)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		_args = args
		new.Title = title or path
		new.Path = path
		appRedirY = appRedirY or 2
		new.AppRedirect = AppRedirect:Initialise(1, appRedirY, Drawing.Screen.Width, Drawing.Screen.Height-1, new)
		new.Environment = Environment:Initialise(new, shell, path)
		new.Running = true
		
		local executable = function()
			local _, err = pcall(function()
				--os.run(new.Environment, path, unpack(args))

				local fnFile, err = OneOS.LoadFile( path)
		        local tEnv = new.Environment
				setmetatable( tEnv, { __index = _G } )
				setfenv( fnFile, tEnv )

				if not fnFile or err then
					term.setTextColour(colours.red)
					term.setBackgroundColour(colours.black)
					print(err)
					if err == 'File not found' then
						term.clear()
						term.setTextColour(colours.white)
						term.setCursorPos(1,2)
						print('The program could not be found or is corrupt.')
						print()
						print('Try running the program again or reinstalling it.')
						print()
						print()
					end
					return false
				end

				local ok, err = pcall( function()
		        	fnFile( unpack( args ) )
		        end )
		        if not ok then
		        	if err and err ~= "" then
						term.setTextColour(colours.red)
						term.setBackgroundColour(colours.black)
						print(err)
			        end
		        end
			end)

        	if not _ and err and err ~= "" then
				term.setTextColour(colours.red)
				term.setBackgroundColour(colours.black)
				print(err)
			end
		end

		table.insert(Current.Programs, new)
		Current.Program = new

		if executable then
			setfenv(executable, new.Environment)
			new.Process = coroutine.create(executable)
			new:Resume()
		else
			printError('Failed to load program: '..path)
		end
		Overlay.UpdateButtons()
		MainDraw()

		return new
	end

	Restart = function(self)
		local path = self.Path
		local title = self.Title
		self:Close()
		LaunchProgram(path, {}, title)
	end

	QueueEvent = function(self, ...)
		table.insert(self.EventQueue, {...})
	end

	Click = function(self, event, button, x, y)
		if self.Running and self.Process and coroutine.status(self.Process) ~= "dead" then
			self:QueueEvent(event, button, x, y)
		else
			self:Close()
		end
	end

	_Resume = function(self, ...)
		if not self.Process or coroutine.status(self.Process) == "dead" then
			return false
		end

		local event = {...}
		term.redirect(self.AppRedirect.Term)
		local response = {coroutine.resume(self.Process, unpack(event))}
		if not response[1] and response[2] then
			print()
	    	term.setTextColour(colours.red)
	    	print('The program has crashed.')
	    	print(response[2])
	    	self:Kill(1)
		elseif coroutine.status(self.Process) == "dead" then
	    	print()
	    	term.setTextColour(colours.red)
	    	print('The program has finished.')
	    	self:Kill(0)
	    end
	    term.restore()
	    Drawing.DrawBuffer()
	    term.setCursorPos(Current.CursorPos[1], Current.CursorPos[2])
		term.setCursorBlink(self.AppRedirect.CursorBlink)
		term.setTextColour(Current.CursorColour)
	    return unpack(response)
	end

	Resume = function(self, ...)
		local event = {...}
		local result = false
		xpcall(function()
				if not self.Process or coroutine.status(self.Process) == "dead" then
					return false
				end

				term.redirect(self.AppRedirect.Term)
				local response = {coroutine.resume(self.Process, unpack(event))}
				if not response[1] and response[2] then
					print()
			    	term.setTextColour(colours.red)
			    	print('The program has crashed.')
			    	print(response[2])
			    	self:Kill(1)
				elseif coroutine.status(self.Process) == "dead" then
			    	print()
			    	term.setTextColour(colours.red)
			    	print('The program has finished.')
			    	self:Kill(0)
			    end
			    term.restore()
			    Drawing.DrawBuffer()
			    term.setCursorPos(Current.CursorPos[1], Current.CursorPos[2])
				term.setCursorBlink(self.AppRedirect.CursorBlink)
				term.setTextColour(Current.CursorColour)
			    result = unpack(response)
			end, function(err)
				if string.find(err, "Too long without yielding") then
			    	term.redirect(self.AppRedirect.Term)
			    	print()
			    	term.setTextColour(colours.red)
			    	print('Too long without yielding')
			    	self:Kill(0)
			    	term.restore()
			    else
			    	error(err)
				end
			end)
		if result then
			return result
		end
	end

	Kill = function(self, code)
		term.setBackgroundColour(colours.black)
		term.setTextColour(colours.white)
		Current.CursorPos[1] = 1
		Current.CursorPos[2] = 1
		term.setCursorBlink(false)
		print('Click anywhere to close this program.')
		for i, program in ipairs(Current.Programs) do
			if program == self then
				Current.Programs[i].Running = false
				if code ~= 0 then
					coroutine.yield(Current.Programs[i].Process)
				end
				Current.Programs[i].Process = nil
			end
		end
	end

	Close = function(self, force)
		if force or not self.Environment.OneOS.CanClose or self.Environment.OneOS.CanClose() ~= false then
			if self == Current.Program then
				Current.Program = nil
			end

			for i, program in ipairs(Current.Programs) do
				if program == self then
					table.remove(Current.Programs, i)

					if Current.Programs[i] then
						Current.Program = Current.Programs[i]
					elseif Current.Programs[i-1] then
						Current.Program = Current.Programs[i-1]
					end
					break
				end
			end

			if Desktop then
				Desktop:RefreshFiles()
			end
			Overlay.UpdateButtons()
			if Current.Program then
				Drawing.Clear(colours.black)
				Drawing.DrawBuffer()
				sleep(0)
				os.queueEvent('oneos_draw')
			else
				if Desktop then
					Desktop:Draw()
				end
			end
			return true
		else
			return false
		end
	end