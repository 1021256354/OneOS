--[[
		Bedrock is the core program framework used by all OneOS and OneCode programs.
							Inspired by Apple'a Cocoa framework.
									   (c) oeed 2014

		  For documentation see the OneOS wiki, github.com/oeed/OneOS/wiki/Bedrock/
]]

AllowTerminate = true

View = nil

EventHandlers = {
	
}

ObjectClickHandlers = {
	
}

function Initialise(self)
	--first, check that the barebones APIs are available
	local requiredApis = {
		'Drawing',
		'View'
	}
	local env = getfenv()
	for i,v in ipairs(requiredApis) do
		if not env[v] then
			error('The API: '..v..' is not loaded. Please make sure you load it to use Bedrock.')
		end
	end

	local copy = { }
	for k, v in pairs(self) do
		if k ~= 'Initialise' then
			copy[k] = v
		end
	end
	return setmetatable(copy, getmetatable(self))
end

function HandleClick(self, event, side, x, y)
	if self.View then
		if self.View:Click(event, side, x, y) then
			self:Draw()
		end		
	end
end

function ObjectClick(self, name, func)
	self.ObjectClickHandlers[name] = func
end

function ClickObject(self, object, event, side, x, y)
	self.ObjectClickHandlers[object.Name](object, event, side, x, y)
end

function GetAbsolutePosition(obj)
	if not obj.Parent then
		return {X = obj.X, Y = obj.Y}
	else
		local pos = GetAbsolutePosition(obj.Parent)
		local x = pos.X + obj.X - 1
		local y = pos.Y + obj.Y - 1
		return {X = x, Y = y}
	end
end
_G.GetAbsolutePosition = GetAbsolutePosition
_G.RegisterClick = function()end --TODO: remove this from all programs

function LoadView(self, name)
	if self.OnViewClose then
		self:OnViewClose(self.View.Name)
	end
	local success = false

	local h = fs.open('views/'..name..'.view', 'r')
	if h then
		local view = textutils.unserialize(h.readAll())
		if view then
			self.View = View:InitialiseFile(self, view, name)
			self:ReorderObjects()

			if view.ToolBarColour then
				OneOS.ToolBarColour = view.ToolBarColour
			end
			if view.ToolBarTextColour then
				OneOS.ToolBarTextColour = view.ToolBarTextColour
			end
			success = true
		end
	end

	if success and self.OnViewOpen then
		self:OnViewOpen(name, success)
	end
end

local function findObjectNamed(view, name)
	if view and view.Children then
		for i, child in ipairs(view.Children) do
			if child.Name == name then
				return child, i, view
			elseif child.Children then
				local found, index, foundView = findObjectNamed(child, name)
				if found then
					return found, index, foundView
				end
			end
		end
	end
end

function ObjectFromFile(self, file, view)
	local env = getfenv()
	if env[file.Type] then
		local object = env[file.Type]:Initialise()
		for k, v in pairs(file) do
			if k == 'Width' or k == 'X' or k == 'Height' or k == 'Y' then
				local parentSize = view.Width
				if k == 'Height' or k == 'Y' then
					parentSize = view.Height
				end
				local parts = {v}
				if type(v) == 'string' and string.find(v, ',') then
					parts = {}
					for word in string.gmatch(v, '([^,]+)') do
					    table.insert(parts, word)
					end
				end

				v = 0
				for i2, part in ipairs(parts) do
					if type(part) == 'string' and part:sub(#part) == '%' then
						v = v + math.ceil(parentSize * (tonumber(part:sub(1, #part-1)) / 100))
					else
						v = v + tonumber(part)
					end
				end
			end

			if k == 'Width' then
				if object.AutoWidth then
					object.AutoWidth = false
				end
			end
			object[k] = v
		end

		object._Click = function(...) self:ClickObject(...) end
		if object.UpdateEvokers then
			object:UpdateEvokers()
		end
		return object
	else
		error('No Object: '..file.Type..'. The API probably isn\'t loaded')
	end
end

function ReorderObjects(self)
	table.sort(self.View.Children, function(a,b)
		return a.Z < b.Z 
	end)
end

function AddObject(self, info, viewName)
	local parent = self.View
	if viewName then
		parent = findObjectNamed(self.View, name)
	end

	if parent and parent.Children then
		local view = self:ObjectFromFile(info, parent)
		if not view.Z then
			view.Z = #parent.Children + 1
		end

		table.insert(parent.Children, view)
		self:ReorderObjects()
	end
end

function GetObject(self, name)
	local object = findObjectNamed(self.View, name)
	return object
end

function RemoveObject(self, name)
	local object, index, view = findObjectNamed(self.View, name)
	table.remove(view.Children, index)
end

function RegisterEvent(self, event, func, passSelf)
	if not self.EventHandlers[event] then
		self.EventHandlers[event] = {}
	end

	table.insert(self.EventHandlers[event], {func, passSelf})
end

OnTimer = nil
OnClick = nil
OnKeyChar = nil
OnDrag = nil
OnScroll = nil
OnViewOpen = nil
OnViewClose = nil

local eventFuncs = {
	OnTimer = {{'timer'}},
	OnClick = {{'mouse_click'}},
	OnKeyChar = {{'key', 'char'}},
	OnDrag = {{'mouse_drag'}},
	OnScroll = {{'mouse_scroll'}},
	HandleClick = {{'mouse_click'}, true},
}

function Draw(self)
	if self.View then
		self.View:Draw()
	else
		print('No view loaded (LoadView was not called or loading failed.)')
	end
	Drawing.DrawBuffer()
end

function Run(self, ready)

	for name, events in pairs(eventFuncs) do
		if self[name] then
			for i, event in ipairs(events[1]) do
				self:RegisterEvent(event, self[name], events[2])
			end
		end
	end

	if self.AllowTerminate then
		--TODO: maybe quit here instead
		self:RegisterEvent('terminate', function()error('Program terminated: terminate', 0) end)
	end

	if ready then
		ready()
	end
	self:Draw()

	while true do
		local event = { os.pullEventRaw() }

		if self.EventHandlers[event[1]] then
			for i, e in ipairs(self.EventHandlers[event[1]]) do
				if e[2] then
					e[1](self, unpack(event))
				else
					e[1](unpack(event))
				end
			end
		end
	end
end