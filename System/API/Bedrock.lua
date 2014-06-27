--[[
		Bedrock is the core program framework used by all OneOS and OneCode programs.
							Inspired by Apple's Cocoa framework.
									   (c) oeed 2014

		  For documentation see the OneOS wiki, github.com/oeed/OneOS/wiki/Bedrock/
]]

--adds a few debugging things (a draw call counter)
local isDebug = true

local load = os.loadAPI
local viewPath = '/System/Views/'
if OneOS then
	load = OneOS.LoadAPI
	viewPath = 'Views/'
end

local apis = {
	'Drawing',
	'Object',
	'View',
	'Button',
	'Label',
	'Separator',
	'TextInput',
	'TextBox',
	'ImageView'
}

local env = getfenv()
if not isStartup then
	for i, v in ipairs(apis) do
		load('/System/API/'..v..'.lua', false)
		if not env[v] then
			error('Could not find API: '..v)
		elseif v == 'Separator' or v == 'Label' or v == 'ImageView'  or v == 'Button' then--v ~= 'Object' and v ~= 'Drawing' then
			env[v].__index = Object
			if env[v].Inheirt then
				env[v].__index = env[v].Inheirt
			end
			setmetatable(env[v], env[v])
		end
	end
end

CanDraw = true

AllowTerminate = true

View = nil

ActiveObject = nil

EventHandlers = {
	
}

ObjectClickHandlers = {
	
}

ObjectUpdateHandlers = {
	
}

Timers = {
	
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
		if self.View:Click(event, side, x, y) ~= false then
			--self:Draw()
		end		
	end
end

function HandleKeyChar(self, event, keychar)
	if self:GetActiveObject() then
		local activeObject = self:GetActiveObject()
		if activeObject.OnKeyChar then
			if activeObject:OnKeyChar(event, keychar) ~= false then
				--self:Draw()
			end
		end
--[[
	elseif keychar == keys.up then
		Scroll('mouse_scroll', -1)
	elseif keychar == keys.down then
		Scroll('mouse_scroll', 1)
]]--
	end
end

function ObjectClick(self, name, func)
	self.ObjectClickHandlers[name] = func
end

function ClickObject(self, object, event, side, x, y)
	if self.ObjectClickHandlers[object.Name] then
		self.ObjectClickHandlers[object.Name](object, event, side, x, y)
	end
end

function ObjectUpdate(self, name, func)
	self.ObjectUpdateHandlers[name] = func
end

function UpdateObject(self, object, ...)
	if self.ObjectUpdateHandlers[object.Name] then
		self.ObjectUpdateHandlers[object.Name](object, ...)
		--self:Draw()
	end
end

function GetAbsolutePosition(self, obj)
	if not obj.Parent then
		return {X = obj.X, Y = obj.Y}
	else
		local pos = self:GetAbsolutePosition(obj.Parent)
		local x = pos.X + obj.X - 1
		local y = pos.Y + obj.Y - 1
		return {X = x, Y = y}
	end
end
_G.RegisterClick = function()end --TODO: remove this from all programs

function LoadView(self, name)
	if self.View and self.OnViewClose then
		self.OnViewClose(self.View.Name)
	end
	local success = false

	local h = fs.open(viewPath..name..'.view', 'r')
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
			self:SetActiveObject()
			success = true
		end
	end

	if success and self.OnViewLoad then
		self.OnViewLoad(name, success)
	end
	self:Draw()
	return success
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

function InheritFile(self, file, name)
	local h = fs.open(viewPath..name..'.view', 'r')
	if h then
		local super = textutils.unserialize(h.readAll())
		if super then
			for k, v in pairs(super) do
				if not file[k] then
					file[k] = v
				end
			end
			return file
		end
	end
	return file
end

function ObjectFromFile(self, file, view)
	local env = getfenv()
	if env[file.Type] then
		if not env[file.Type].Initialise then
			error('Malformed Object: '..file.Type)
		end
		local object = env[file.Type]:Initialise()

		if file.InheritView then
			file = self:InheritFile(file, file.InheritView)
		end
		
		object.AutoWidth = true
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
				object.AutoWidth = false
			end
			if k ~= 'Children' then
				object[k] = v
			end
		end

		if file.Children then
			for i, obj in ipairs(file.Children) do
				local view = self:ObjectFromFile(obj, object)
				if not view.Z then
					view.Z = i
				end
				view.Parent = object
				table.insert(object.Children, view)
			end
		end

		object.Bedrock = self

		object._Click = function(...) self:ClickObject(...) end
		object._Update = function(...) self:UpdateObject(...) end
		if object.OnLoad then
			object:OnLoad()
		end
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

function StartRepeatingTimer(self, func, interval)
	local timer = os.startTimer(interval)
	self.Timers[timer] = {func, interval}
end

function HandleTimer(self, event, timer)
	if self.Timers[timer] then
		local oldTimer = self.Timers[timer]
		self.Timers[timer] = nil
		oldTimer[1]()
		self:StartRepeatingTimer(oldTimer[1], oldTimer[2])
	elseif self.OnTimer then
		self.OnTimer(event, timer)
	end
end

function SetActiveObject(self, object)
	if object then
		if object ~= self.ActiveObject then
			self.ActiveObject = object
		end
	else
		self.CursorPos = {}
	end
	self:Draw()
end

function GetActiveObject(self)
	return self.ActiveObject
end

OnTimer = nil
OnClick = nil
OnKeyChar = nil
OnDrag = nil
OnScroll = nil
OnViewLoad = nil
OnViewClose = nil

local eventFuncs = {
	OnClick = {{'mouse_click'}},
	OnKeyChar = {{'key', 'char'}},
	OnDrag = {{'mouse_drag'}},
	OnScroll = {{'mouse_scroll'}},
	HandleClick = {{'mouse_click'}, true},
	HandleKeyChar = {{'key', 'char'}, true},
	HandleTimer = {{'timer'}, true}
}

local drawCalls = 0
local ignored = 0
function Draw(self)
	if not self.CanDraw then
		return
	end

	if self.View and self.View:NeedsDraw() then
		self.View:Draw()
		Drawing.DrawBuffer()
		if isDebug then
			drawCalls = drawCalls + 1
		end
	elseif not self.View then
		print('No loaded view.')
	elseif isDebug then
		ignored = ignored + 1
	end

	if isDebug then
		term.setCursorPos(1, Drawing.Screen.Height-1)
		term.setBackgroundColour(colours.black)
		term.setTextColour(colours.white)
		term.write(drawCalls.. ":" .. ignored)
	end

	if self:GetActiveObject() and self.CursorPos and type(self.CursorPos[1]) == 'number' and type(self.CursorPos[2]) == 'number' then
		term.setCursorPos(self.CursorPos[1], self.CursorPos[2])
		term.setTextColour(self.CursorColour)
		term.setCursorBlink(true)
	else
		term.setCursorBlink(false)
	end
end

function EventHandler(self)
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
		self:RegisterEvent('terminate', function()error('Terminated', 0) end)
	end

	if ready then
		ready()
	end

	while true do
		self:EventHandler()
	end
end