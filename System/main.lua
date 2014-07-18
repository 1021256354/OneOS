local bedrock = Bedrock:Initialise()

bedrock.AllowTerminate = false

if type(term.native) == 'function' then
	local cur = term.current()
	restoreTerm = function()term.redirect(cur)end
else
	restoreTerm = function()term.restore()end
end

Current = {
	ProgramView = nil,
	Overlay = nil,
	Programs = {},
	Program = nil,
	Desktop = nil,
	Bedrock = bedrock,
	SearchActive = true
}

function UpdateOverlay()
	bedrock:GetObject('Overlay'):UpdateButtons()
end

bedrock.OnKeyChar = function(self, event, keychar)
	if keychar == '\\' then --TODO: remove
		--Restart()
		AnimateShutdown(true)
	end
end

bedrock.OnTimer = function(self, event, timer)
	for i, program in ipairs(Current.Programs) do
		for i2, _timer in ipairs(program.Timers) do
			if _timer == timer then
				program:QueueEvent('timer', timer)
			end
		end
	end
end

bedrock:RegisterEvent('modem_message', function(self, event, side, channel, replyChannel, message, distance)
	if pocket and channel == Wireless.Channels.UltimateDoorlockPing then
		message = textutils.unserialize(message)
		if message then
			message.content = textutils.unserialize(message.content)
			if message.content then
				Wireless.SendMessage(Wireless.Channels.UltimateDoorlockRequest, fingerprint, Wireless.Channels.UltimateDoorlockRequestReply, nil, message.senderID)
				return true
			end
		end
	end
	Current.Program:QueueEvent(event, side, channel, replyChannel, message, distance)
end)

bedrock.EventHandler = function(self)
	for i, program in ipairs(Current.Programs) do
		for i, event in ipairs(program.EventQueue) do
			program:Resume(unpack(event))
		end
		program.EventQueue = {}
	end
	local event = { os.pullEventRaw() }
	-- Log.i('Event: '..table.concat(event, ', ')) --TODO: enable at release

	if self.EventHandlers[event[1]] then
		for i, e in ipairs(self.EventHandlers[event[1]]) do
			e(self, unpack(event))
		end
	else
		Current.Program:QueueEvent(unpack(event))
	end
end

function Shutdown(force, restart)
	Log.i('Trying to shutdown/restart. Restart: '..tostring(restart))
	local success = true
	if not force then
		for i, program in ipairs(Current.Programs) do
			if not program.Hidden and not program:Close() then
				success = false
			end
		end
	end

	if success then
		AnimateShutdown(restart)
	else
		Log.w('Shutdown/restart aborted')
		Current.Desktop:SwitchTo()
		local shutdownLabel = (restart and 'restart' or 'shutdown')
		local shutdownLabelCaptital = (restart and 'Restart' or 'Shutdown')

		bedrock:DisplayAlertWindow("Programs Still Open", "You have unsaved work. Save your work and close the program or click 'Force "..shutdownLabelCaptital.."'.", {'Force '..shutdownLabelCaptital, 'Cancel'}, function(value)
			if value ~= 'Cancel' then
				AnimateShutdown(restart)
			end
		end)
	end
end

function AnimateShutdown(restart)
	Log.w('System safely stopping.')
	if Settings:GetValues()['UseAnimations'] then
		Drawing.Clear(colours.white)
		Drawing.DrawBuffer()
		sleep(0)
		local x = 0
		local y = 0
		local w = 0
		local h = 0
		for i = 1, 8 do
			local percent = (i * 0.05)
			Drawing.Clear(colours.black)
			x = Drawing.Screen.Width * (i * 0.01)
			y = math.floor(Drawing.Screen.Height * (i * 0.05)) + 3
			w = Drawing.Screen.Width - (2 * x) + 1
			h = Drawing.Screen.Height - (2 * y) + 1

			if h < 1 then
				h = 1
			end

			Drawing.DrawBlankArea(x + 1, y, w, h, colours.white)
			Drawing.DrawBuffer()
			sleep(0)
		end

		Drawing.DrawBlankArea(x + 1, y, w, h, colours.lightGrey)
		Drawing.DrawBuffer()
		sleep(0)

		Drawing.DrawBlankArea(x + 1, y, w, h, colours.grey)
		Drawing.DrawBuffer()
		sleep(0)
	end

	term.setBackgroundColour(colours.black)
	term.clear()
	if restart then
		sleep(0.2)
		Log.i('Rebooting now.')
		os.reboot()
	else
		Log.i('Shutting down now.')
		os.shutdown()
	end
end

function Restart(force)
	Shutdown(force, true)
end

function StartDoorWireless()
	if pocket and Wireless.Present() then
		Wireless.Open(Wireless.Channels.UltimateDoorlockPing)
		Wireless.Open(Wireless.Channels.UltimateDoorlockRequest)
		if fs.exists('/System/.fingerprint') then
			local h = fs.open('/System/.fingerprint', 'r')
			if h then
				fingerprint = h.readAll()
				h.close()
			end
		else
			local function GenerateFingerprint()
			    local str = ""
			    for _ = 1, 256 do
			        local char = math.random(32, 126)
			        str = str .. string.char(char)
			    end
			    return str
			end
			fingerprint = GenerateFingerprint()
			local h = fs.open('/System/.fingerprint', 'w')
			if h then
				h.write(fingerprint)
				h.close()
			end
		end
	end
end

function FirstSetup()
	bedrock:Run(function()
		Log.i('Reached First Setup GUI')
		bedrock:LoadView('firstsetup', false)
		Log.i('First Setup GUI Loaded')
		
		Current.ProgramView = bedrock:GetObject('ProgramView')
		Helpers.OpenFile('System/Programs/First Setup.program', {isHidden = true})
	end)
end

--TODO: auto updating
function Initialise()
	bedrock:Run(function()
		Log.i('Reached GUI')
		bedrock:LoadView('main', false)
		Log.i('GUI Loaded')

		Current.ProgramView = bedrock:GetObject('ProgramView')
		Current.Overlay = bedrock:GetObject('Overlay')
		Indexer.RefreshIndex()

		bedrock:GetObject('ClickCatcherView').OnClick = function()
			if Current.SearchActive then
				Search.Close()
			end
		end

		Current.Desktop = Helpers.OpenFile('System/Programs/Desktop.program', {isHidden = true})

		if Settings:GetValues()['StartupProgram'] then
			Helpers.OpenFile('Programs/'..Settings:GetValues()['StartupProgram'])
			UpdateOverlay()
		end

		--Helpers.OpenFile('System/Programs/Files.program')

		-- Helpers.OpenFile('Programs/Test2.program')
		-- Helpers.OpenFile('Programs/App Store.program')
		--Helpers.OpenFile('Programs/Transmit.program')--, {'r'})
		UpdateOverlay()
		--Search.Open()
		StartDoorWireless()
	end)
end