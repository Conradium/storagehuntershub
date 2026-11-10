-- Storage Hunters Hub 4.9.3 (Storage Hunters: Open World)
-- Made by conradium, commissioned by rsl.
-- Auto bid, auto open auctions and airdrops, take/open/repair won items, favorites,
-- shelf listing, lost items, mining, event timers, teleports and movement. Settings are saved per account.
-- Show or hide the window with Insert. Stop: getgenv().SHHub.stop()

local env = getgenv()
if env.SHHub and type(env.SHHub.stop) == "function" then pcall(env.SHHub.stop) end
local Hub = { alive = true, version = "4.9.3" }
env.SHHub = Hub
local Kit = (function()
---------------------------------------------------------------------------
-- Compact UI kit (custom, requested for this hub)
---------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Kit = {}
Kit.__index = Kit

local C = {
	bg = Color3.fromRGB(16, 16, 20),
	panel = Color3.fromRGB(24, 24, 30),
	row = Color3.fromRGB(30, 30, 37),
	rowHover = Color3.fromRGB(36, 36, 44),
	line = Color3.fromRGB(44, 44, 54),
	text = Color3.fromRGB(236, 236, 240),
	sub = Color3.fromRGB(150, 150, 162),
	faint = Color3.fromRGB(96, 96, 108),
	accent = Color3.fromRGB(255, 122, 92),
	good = Color3.fromRGB(96, 214, 140),
	off = Color3.fromRGB(58, 58, 70),
}
-- Themes. Every colour in the kit comes from one of these roles; switching
-- theme repaints existing elements by swapping each role's old colour for the new.
local ROLES = { "bg", "panel", "row", "rowHover", "line", "text", "sub", "faint", "accent", "good", "off" }
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
Kit.Themes = {
	Original = {
		bg = rgb(16, 16, 20), panel = rgb(24, 24, 30), row = rgb(30, 30, 37), rowHover = rgb(36, 36, 44),
		line = rgb(44, 44, 54), text = rgb(236, 236, 240), sub = rgb(150, 150, 162), faint = rgb(96, 96, 108),
		accent = rgb(255, 122, 92), good = rgb(96, 214, 140), off = rgb(58, 58, 70),
	},
	["Black Teal"] = { -- near-black base, cool greys, teal accent
		bg = rgb(13, 15, 17), panel = rgb(20, 23, 26), row = rgb(27, 31, 35), rowHover = rgb(34, 39, 44),
		line = rgb(43, 49, 55), text = rgb(229, 236, 239), sub = rgb(145, 158, 165), faint = rgb(92, 104, 111),
		accent = rgb(32, 196, 180), good = rgb(110, 214, 160), off = rgb(55, 62, 69),
	},
	Noir = { -- pure black and white, no hue at all
		bg = rgb(4, 4, 4), panel = rgb(11, 11, 11), row = rgb(18, 18, 18), rowHover = rgb(27, 27, 27),
		line = rgb(38, 38, 38), text = rgb(244, 244, 244), sub = rgb(158, 158, 158), faint = rgb(96, 96, 96),
		accent = rgb(255, 255, 255), good = rgb(196, 196, 196), off = rgb(52, 52, 52),
	},
}

local function colorKey(c)
	return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- Roles must all differ so a later theme switch can tell them apart.
local function distinct(theme)
	local seen = {}
	for _, role in ipairs(ROLES) do
		local c = theme[role]
		while seen[colorKey(c)] do
			c = Color3.new(math.clamp(c.R + 1 / 255, 0, 1), math.clamp(c.G + 1 / 255, 0, 1), math.clamp(c.B + 2 / 255, 0, 1))
		end
		theme[role] = c
		seen[colorKey(c)] = true
	end
	return theme
end

-- A full theme from three colours: background, accent and text.
function Kit.CustomTheme(bg, accent, text)
	local function mix(t) return bg:Lerp(text, t) end
	return distinct({
		bg = bg, panel = mix(0.035), row = mix(0.065), rowHover = mix(0.1), line = mix(0.14),
		text = text, sub = text:Lerp(bg, 0.38), faint = text:Lerp(bg, 0.6),
		accent = accent, good = accent:Lerp(rgb(96, 214, 140), 0.6), off = mix(0.2),
	})
end

function Kit.HexToColor(hex)
	local r, g, b = tostring(hex or ""):match("^#?(%x%x)(%x%x)(%x%x)$")
	if not r then return nil end
	return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

function Kit.ColorToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local FONT = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
local FONT_MED = Enum.Font.GothamMedium

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end
local function corner(parent, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent) end
local function stroke(parent, color, t)
	return new("UIStroke", { Color = color or C.line, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end
local function tween(inst, props, t)
	TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function label(parent, text, size, color, font, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 13, TextColor3 = color or C.text,
		Font = font or FONT, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 1, 0),
	}, parent)
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

-- opts: Title, Width, Height, ToggleKey, OnClose
function Kit.Window(opts)
	local self = setmetatable({ tabs = {}, conns = {}, alive = true, values = {}, onChange = nil, setters = {}, title = opts.Title }, Kit)
	local gui = new("ScreenGui", {
		Name = "SHHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
	self.gui = gui

	local width, height = opts.Width or 360, opts.Height or 470
	local main = new("Frame", {
		Name = "Main", BackgroundColor3 = C.bg, Size = UDim2.fromOffset(width, height),
		Position = UDim2.new(0, 24, 0.5, -height / 2), BorderSizePixel = 0, ClipsDescendants = true,
	}, gui)
	corner(main, 12)
	stroke(main, C.line)
	self.main = main

	-- header
	local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44) }, main)
	new("Frame", { BackgroundColor3 = C.accent, Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 16, 0.5, -4) }, header)
	corner(header:FindFirstChildOfClass("Frame"), 4)
	if opts.Credit then
		label(header, opts.Title or "Hub", 15, C.text, FONT_BOLD, { Position = UDim2.fromOffset(32, 6), Size = UDim2.new(1, -110, 0, 18) })
		label(header, opts.Credit, 10, C.faint, FONT, { Position = UDim2.fromOffset(32, 24), Size = UDim2.new(1, -110, 0, 13) })
	else
		label(header, opts.Title or "Hub", 15, C.text, FONT_BOLD, { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -110, 1, 0) })
	end
	local function headerButton(text, x)
		local b = new("TextButton", {
			BackgroundColor3 = C.panel, BackgroundTransparency = 1, Text = text, TextSize = 16, Font = FONT_BOLD,
			TextColor3 = C.sub, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, x, 0.5, -14), AutoButtonColor = false,
		}, header)
		corner(b, 6)
		b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0, TextColor3 = C.text }) end)
		b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1, TextColor3 = C.sub }) end)
		return b
	end
	local minimize = headerButton("-", -72)
	local close = headerButton("x", -40)

	-- tab bar
	local tabBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 44) }, main)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
	self.tabBar = tabBar
	new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 79) }, main)

	-- body + status
	local body = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -112), Position = UDim2.fromOffset(0, 80) }, main)
	self.body = body
	local status = new("Frame", { BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 1, -32) }, main)
	self.statusDot = new("Frame", { BackgroundColor3 = C.faint, Size = UDim2.fromOffset(6, 6), Position = UDim2.new(0, 16, 0.5, -3) }, status)
	corner(self.statusDot, 3)
	self.statusText = label(status, "Ready", 12, C.sub, FONT, { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -44, 1, 0) })

	-- drag (header) for mouse and touch
	local dragging, dragStart, startPos
	table.insert(self.conns, header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, main.Position
		end
	end))
	table.insert(self.conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	table.insert(self.conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))

	-- Minimized: a small draggable pill with the live status; click to restore.
	local pill = new("TextButton", {
		Name = "Pill", Text = "", AutoButtonColor = false, Visible = false,
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.04, Size = UDim2.fromOffset(250, 40),
		Position = main.Position, BorderSizePixel = 0,
	}, gui)
	corner(pill, 20)
	stroke(pill, C.line)
	self.pillDot = new("Frame", { BackgroundColor3 = C.faint, Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 16, 0.5, -4) }, pill)
	corner(self.pillDot, 4)
	label(pill, opts.Title or "Hub", 13, C.text, FONT_BOLD, { Position = UDim2.fromOffset(32, 4), Size = UDim2.new(1, -44, 0, 17) })
	self.pillText = label(pill, "Ready", 11, C.sub, FONT, { Position = UDim2.fromOffset(32, 20), Size = UDim2.new(1, -44, 0, 15) })
	self.pill = pill
	local pillDrag, pillStart, pillPos, pillMoved
	pill.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pillDrag, pillStart, pillPos, pillMoved = true, input.Position, pill.Position, false
		end
	end)
	table.insert(self.conns, UserInputService.InputChanged:Connect(function(input)
		if pillDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - pillStart
			if d.Magnitude > 4 then pillMoved = true end
			pill.Position = UDim2.new(pillPos.X.Scale, pillPos.X.Offset + d.X, pillPos.Y.Scale, pillPos.Y.Offset + d.Y)
		end
	end))
	table.insert(self.conns, UserInputService.InputEnded:Connect(function(input)
		if pillDrag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			pillDrag = false
			if not pillMoved then self:Restore() end -- a click, not a drag
		end
	end))
	minimize.MouseButton1Click:Connect(function() self:Minimize() end)
	close.MouseButton1Click:Connect(function() self:Hide(true) end)
	local key = opts.ToggleKey or Enum.KeyCode.Insert
	self.toggleKey = key
	self.toggleKeyName = key.Name
	self.switches, self.chips = {}, {}
	table.insert(self.conns, UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if self.capturing then self:_capture(input.KeyCode); return end
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == key then
			if main.Visible then self:Hide(false) else self:Restore() end
			return
		end
		local ids = self:_idsFor(input.KeyCode.Name)
		local notify = self.values.keybindNotify ~= false
		if #ids == 1 then
			local id, sw = ids[1], self.switches[ids[1]]
			local msg = sw.flip()
			local state = self.values[id] and "ON" or "OFF"
			self:SetStatus(type(msg) == "string" and msg or (sw.text .. ": " .. state), "ok")
			if notify then self:Notify(sw.text .. ": " .. state, type(msg) == "string" and msg or ("Key " .. input.KeyCode.Name), 3) end
		elseif #ids > 1 then
			-- a shared key moves its switches together: all on if any is off, else all off
			local anyOff = false
			for _, id in ipairs(ids) do if self.values[id] ~= true then anyOff = true end end
			local names = {}
			for _, id in ipairs(ids) do
				local set = self.setters[id]
				if set then set(anyOff, true) end
				names[#names + 1] = self.switches[id].text
			end
			local state = anyOff and "ON" or "OFF"
			self:SetStatus(string.format("%s: %d switches %s", input.KeyCode.Name, #ids, state), "ok")
			if notify then self:Notify(input.KeyCode.Name .. ": " .. state, table.concat(names, ", "), 4) end
		end
	end))
	self.onClose = opts.OnClose
	return self
end

-- A slim text-only bar at the top centre of the screen.
-- items: { { Label = "text", Callback = fn }, ... }; the first ones are
-- shown in the accent colour when Accent = true.
function Kit:Bar(items)
	local bar = new("Frame", {
		Name = "QuickBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0,
	}, self.gui)
	corner(bar, 18)
	stroke(bar, C.line)
	new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, bar)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, bar)
	for i, item in ipairs(items) do
		local b = new("TextButton", {
			Text = item.Label or "", AutoButtonColor = false, BackgroundColor3 = C.row, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i,
			Font = FONT_MED, TextSize = 12, TextColor3 = item.Accent and C.accent or C.sub,
		}, bar)
		corner(b, 13)
		new("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11) }, b)
		local rest = b.TextColor3
		b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0, TextColor3 = C.text }) end)
		b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1, TextColor3 = rest }) end)
		b.MouseButton1Click:Connect(function()
			task.spawn(function()
				local ok, err = pcall(item.Callback)
				if not ok then self:SetStatus("Error: " .. tostring(err)) end
			end)
		end)
	end
	return bar
end

-- A small list pinned to the screen edge (event timers and the like). It
-- stays up when the window is hidden, sits under the window, and can be
-- dragged. opts: Title, Empty (text when there are no rows), Position (UDim2),
-- Width, OnMoved(position). Returns a panel:
--   panel:SetRows({ { Text = "name", Value = "1:23", State = "live" | "soon" | nil }, ... })
--   panel:SetVisible(on)
function Kit:SidePanel(opts)
	local frame = new("Frame", {
		Name = "SidePanel", Position = opts.Position or UDim2.fromOffset(12, 96), Active = true,
		Size = UDim2.fromOffset(opts.Width or 214, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 0,
	}, self.gui)
	corner(frame, 10)
	stroke(frame, C.line)
	new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11) }, frame)
	new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
	label(frame, opts.Title or "", 11, C.faint, FONT_BOLD, { Size = UDim2.new(1, 0, 0, 17), LayoutOrder = 0 })
	local empty = label(frame, opts.Empty or "-", 12, C.sub, FONT, { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1 })
	local rows = {}
	local panel = { frame = frame }
	function panel:SetRows(list)
		empty.Visible = #list == 0
		for i, item in ipairs(list) do
			local r = rows[i]
			if not r then
				local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = i + 1 }, frame)
				r = {
					frame = f,
					name = label(f, "", 12, C.text, FONT_MED, { Size = UDim2.new(1, -80, 1, 0) }),
					value = label(f, "", 12, C.sub, FONT_MED, { Position = UDim2.new(1, -78, 0, 0), Size = UDim2.new(0, 78, 1, 0),
						TextXAlignment = Enum.TextXAlignment.Right }),
				}
				rows[i] = r
			end
			r.frame.Visible = true
			r.name.Text = item.Text or ""
			r.value.Text = item.Value or ""
			r.name.TextColor3 = item.State == "live" and C.text or C.sub
			r.value.TextColor3 = (item.State == "live" and C.good) or (item.State == "soon" and C.accent) or C.sub
		end
		for i = #list + 1, #rows do rows[i].frame.Visible = false end
	end
	function panel:SetVisible(on) frame.Visible = on and true or false end

	-- drag anywhere on the panel; OnMoved gets the new position to save
	local dragging, startPos, startAt = false, nil, nil
	table.insert(self.conns, frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, startAt = true, frame.Position, input.Position
		end
	end))
	table.insert(self.conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startAt
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	table.insert(self.conns, UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if opts.OnMoved then pcall(opts.OnMoved, frame.Position) end
		end
	end))
	return panel
end

-- Repaints everything already on screen, then makes the new colours current.
function Kit:SetTheme(theme)
	local map = {}
	for _, role in ipairs(ROLES) do map[colorKey(C[role])] = theme[role] end
	local function swap(inst, prop)
		local ok, value = pcall(function() return inst[prop] end)
		if ok and typeof(value) == "Color3" then
			local new = map[colorKey(value)]
			if new then inst[prop] = new end
		end
	end
	for _, d in ipairs(self.gui:GetDescendants()) do
		if d:IsA("GuiObject") then swap(d, "BackgroundColor3") end
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then swap(d, "TextColor3") end
		if d:IsA("TextBox") then swap(d, "PlaceholderColor3") end
		if d:IsA("UIStroke") then swap(d, "Color") end
		if d:IsA("ScrollingFrame") then swap(d, "ScrollBarImageColor3") end
	end
	for _, role in ipairs(ROLES) do C[role] = theme[role] end
end

-- Window states: open, minimized (pill) or hidden (Insert brings it back).
function Kit:Minimize()
	self.pill.Position = self.main.Position
	self.main.Visible = false
	self.pill.Visible = true
end

function Kit:Restore()
	self.pill.Visible = false
	self.main.Visible = true
end

function Kit:Hide(notify)
	self.main.Visible = false
	self.pill.Visible = false
	if notify then
		self:Notify(self.title or "Hub", "Hidden. Press " .. self.toggleKeyName .. " to open it again.", 6)
	end
end

-- The Roblox corner notification.
function Kit:Notify(title, text, seconds)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = title, Text = text, Duration = seconds or 5 })
	end)
end

-- "Are you sure?" dialog. o = { Title, Text, Confirm = "Yes", Danger = true, Callback }
function Kit:Confirm(o)
	if self.dialog then self.dialog:Destroy() end
	local shade = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1), ZIndex = 50,
	}, self.gui)
	self.dialog = shade
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.bg, ZIndex = 51,
	}, shade)
	corner(card, 12)
	stroke(card, o.Danger and C.accent or C.line)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14) }, card)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	label(card, o.Title or "Are you sure?", 15, C.text, FONT_BOLD, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, ZIndex = 52 })
	label(card, o.Text or "", 12, C.sub, FONT, {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2, ZIndex = 52,
	})
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 3, ZIndex = 52 }, card)
	local function button(text, x, primary, fn)
		local b = new("TextButton", {
			AutoButtonColor = false, Text = text, TextSize = 12, Font = FONT_BOLD, ZIndex = 53,
			BackgroundColor3 = primary and C.accent or C.row, TextColor3 = primary and C.bg or C.text,
			Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(x, x > 0 and 4 or 0, 0, 0),
		}, row)
		corner(b, 8)
		b.MouseButton1Click:Connect(function()
			shade:Destroy()
			if self.dialog == shade then self.dialog = nil end
			if fn then task.spawn(fn) end
		end)
	end
	button("Cancel", 0, false, nil)
	button(o.Confirm or "Yes", 0.5, true, o.Callback)
end

-- A card under the top bar that stays until closed.
-- o = { Title, Text, Buttons = { { Text, Primary, Callback, Keep } } }
-- Returns { SetText = fn, Close = fn }.
function Kit:Alert(o)
	if self.alert then self.alert:Destroy() end
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.bg, BackgroundTransparency = 0.02, ZIndex = 40,
	}, self.gui)
	corner(card, 12)
	stroke(card, C.accent, 1.5)
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, card)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	label(card, o.Title or "", 14, C.accent, FONT_BOLD, { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, ZIndex = 41 })
	local body = label(card, o.Text or "", 12, C.text, FONT, {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2, ZIndex = 41,
	})
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3, ZIndex = 41 }, card)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }, row)
	local api = {}
	function api.SetText(text) if body.Parent then body.Text = text end end
	function api.Close()
		card:Destroy()
		if self.alert == card then self.alert = nil end
	end
	for _, b in ipairs(o.Buttons or {}) do
		local btn = new("TextButton", {
			AutoButtonColor = false, Text = b.Text, TextSize = 12, Font = FONT_BOLD, ZIndex = 42,
			BackgroundColor3 = b.Primary and C.accent or C.row, TextColor3 = b.Primary and C.bg or C.text,
			Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
		}, row)
		corner(btn, 8)
		new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, btn)
		btn.MouseButton1Click:Connect(function()
			if not b.Keep then api.Close() end
			if b.Callback then task.spawn(b.Callback) end
		end)
	end
	self.alert = card
	return api
end

-- A short notice under the top bar; a newer one replaces the older.
function Kit:Toast(text, seconds)
	if not self.alive then return end
	if self.toast then self.toast:Destroy() end
	local t = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.04, BorderSizePixel = 0,
		Text = text, TextSize = 14, Font = FONT_BOLD, TextColor3 = C.text,
	}, self.gui)
	corner(t, 10)
	stroke(t, C.accent)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, t)
	self.toast = t
	task.delay(seconds or 6, function() if t.Parent then t:Destroy() end end)
end

-- Keybinds: values.keybinds maps a KeyCode name to a list of switch Ids.
-- One key can drive several switches (they move together); each switch has
-- at most one key. Older saves stored a single Id per key; those still work.
function Kit:_binds()
	if type(self.values.keybinds) ~= "table" then self.values.keybinds = {} end
	local binds = self.values.keybinds
	for k, v in pairs(binds) do
		if type(v) == "string" then binds[k] = { v } end
	end
	return binds
end

function Kit:_idsFor(keyName)
	local list = self:_binds()[keyName]
	local ids = {}
	for _, id in ipairs(type(list) == "table" and list or {}) do
		if self.switches[id] then ids[#ids + 1] = id end
	end
	return ids
end

function Kit:_paintChips()
	local byId, shared = {}, {}
	for keyName, ids in pairs(self:_binds()) do
		for _, id in ipairs(ids) do byId[id] = keyName end
		shared[keyName] = #ids > 1
	end
	for id, chip in pairs(self.chips) do
		local k = byId[id]
		local short = k and (k:gsub("^Left", "L"):gsub("^Right", "R")) or nil
		chip.Text = short and (shared[k] and (short .. "*") or short) or "+"
		chip.TextColor3 = k and (shared[k] and C.accent or C.text) or C.faint
	end
end

function Kit:_capture(keyCode)
	local id = self.capturing
	self.capturing = nil
	local binds = self:_binds()
	if keyCode ~= Enum.KeyCode.Escape then
		-- a switch has one key: take it off whatever key it had
		for k, ids in pairs(binds) do
			for i = #ids, 1, -1 do if ids[i] == id then table.remove(ids, i) end end
			if #ids == 0 then binds[k] = nil end
		end
		if keyCode ~= Enum.KeyCode.Backspace and keyCode ~= Enum.KeyCode.Delete and keyCode ~= self.toggleKey then
			local ids = binds[keyCode.Name] or {}
			table.insert(ids, id) -- joins any switches already on this key
			binds[keyCode.Name] = ids
		end
		self:_set("keybinds", binds, true)
	end
	self:_paintChips()
end

-- A small key chip on a switch row; click it, then press a key.
function Kit:_bindChip(row, x, id, text, flip, tab, isSwitch)
	self.switches[id] = { text = text, flip = flip, tab = tab, isSwitch = isSwitch ~= false }
	local chip = new("TextButton", {
		AutoButtonColor = false, Text = "+", TextSize = 11, Font = FONT_MED, TextColor3 = C.faint,
		BackgroundColor3 = C.bg, Size = UDim2.fromOffset(34, 22), Position = UDim2.new(1, x, 0.5, -11),
	}, row)
	corner(chip, 6)
	self.chips[id] = chip
	chip.MouseButton1Click:Connect(function()
		if self.capturing then self:_paintChips() end
		self.capturing = id
		chip.Text = "..."
		chip.TextColor3 = C.accent
		self:SetStatus("Press a key for " .. text .. " (Esc cancels, Backspace clears)", "busy")
	end)
	self:_paintChips()
end

function Kit:SetStatus(text, state)
	if not self.alive then return end
	local color = state == "busy" and C.accent or (state == "ok" and C.good or C.faint)
	self.statusText.Text = text
	self.statusDot.BackgroundColor3 = color
	if self.pillText then self.pillText.Text = text; self.pillDot.BackgroundColor3 = color end
end

-- Sets a switch by Id. fire = true counts it as your change (saved, side
-- effects run); otherwise it is a quiet change (used by admin safety).
function Kit:SetSwitch(id, on, fire)
	local set = self.setters[id]
	if set then set(on, fire == true) else self.values[id] = on end
end

function Kit:Destroy()
	if not self.alive then return end
	self.alive = false
	for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
	table.clear(self.conns)
	if self.onClose then pcall(self.onClose) end
	pcall(function() self.gui:Destroy() end)
end

local Tab = {}
Tab.__index = Tab

function Kit:Tab(name)
	local button = new("TextButton", {
		BackgroundColor3 = C.panel, BackgroundTransparency = 1, AutoButtonColor = false, Text = name, TextSize = 12,
		Font = FONT_MED, TextColor3 = C.sub, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = #self.tabs + 1,
	}, self.tabBar)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, button)
	corner(button, 6)
	local page = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), Visible = false,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.line, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, self.body)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12) }, page)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	local tab = setmetatable({ kit = self, page = page, button = button, order = 0 }, Tab)
	table.insert(self.tabs, tab)
	button.MouseButton1Click:Connect(function() self:Select(tab) end)
	if #self.tabs == 1 then self:Select(tab) end
	return tab
end

function Kit:Select(tab)
	for _, t in ipairs(self.tabs) do
		local on = t == tab
		t.page.Visible = on
		tween(t.button, { BackgroundTransparency = on and 0 or 1, TextColor3 = on and C.text or C.sub })
	end
end

-- value store: every control writes kit.values[id] and calls kit.onChange(id, value)
function Kit:_set(id, value, fire)
	self.values[id] = value
	if fire and self.onChange then task.spawn(self.onChange, id, value) end
end

function Tab:_next() self.order += 1; return self.order end

-- Rows created after a collapsible section belong to it and fold with it.
function Tab:_track(frame)
	if self.group then
		table.insert(self.group.items, frame)
		frame.Visible = not self.group.collapsed
	end
	return frame
end

function Tab:_row(height)
	local row = new("Frame", { BackgroundColor3 = C.row, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height or 38), LayoutOrder = self:_next() }, self.page)
	corner(row, 8)
	return self:_track(row)
end

function Tab:_text(row, text, hint)
	local box = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -120, 1, 0) }, row)
	if hint then
		label(box, text, 13, C.text, FONT_MED, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 5) })
		label(box, hint, 11, C.sub, FONT, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 23) })
	else
		label(box, text, 13, C.text, FONT_MED)
	end
	return box
end

-- Section(text) starts a plain group. Section(text, { Collapsible = true,
-- Collapsed = true }) makes a header you click to show/hide the rows below it.
function Tab:Section(text, opts)
	self.group = nil
	if opts and opts.Collapsible then
		local group = { items = {}, collapsed = opts.Collapsed ~= false }
		local head = new("TextButton", {
			BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = self:_next(), Text = "", TextSize = 11, Font = FONT_BOLD, TextColor3 = C.sub,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, self.page)
		new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 6) }, head)
		local function paint() head.Text = (group.collapsed and "+  " or "-  ") .. string.upper(text) end
		head.MouseButton1Click:Connect(function()
			group.collapsed = not group.collapsed
			for _, f in ipairs(group.items) do f.Visible = not group.collapsed end
			paint()
		end)
		paint()
		self.group = group
		return head
	end
	local l = label(self.page, string.upper(text), 11, C.faint, FONT_BOLD, { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = self:_next() })
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 6) }, l)
	return l
end

-- A step of the main loop: status dot, title, live detail line, key chip
-- and on/off switch. api.SetDetail(text), api.SetActive(bool).
function Tab:Step(o)
	local row = self:_row(48)
	local dot = new("Frame", { BackgroundColor3 = C.off, Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 14, 0.5, -4) }, row)
	corner(dot, 4)
	label(row, o.Text, 14, C.text, FONT_BOLD, { Position = UDim2.fromOffset(32, 7), Size = UDim2.new(1, -140, 0, 18) })
	local detail = label(row, "", 11, C.sub, FONT, { Position = UDim2.fromOffset(32, 26), Size = UDim2.new(1, -140, 0, 15) })
	local track = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundColor3 = C.off, Size = UDim2.fromOffset(38, 22),
		Position = UDim2.new(1, -50, 0.5, -11),
	}, row)
	corner(track, 11)
	local knob = new("Frame", { BackgroundColor3 = C.text, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3) }, track)
	corner(knob, 8)
	local kit = self.kit
	local api = { active = false }
	local function paintDot()
		local on = kit.values[o.Id] == true
		dot.BackgroundColor3 = (on and api.active) and C.accent or (on and C.good or C.off)
	end
	function api.Set(value, fire)
		value = value == true
		kit:_set(o.Id, value, fire)
		tween(track, { BackgroundColor3 = value and C.accent or C.off })
		tween(knob, { Position = value and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3) })
		paintDot()
	end
	function api.Get() return kit.values[o.Id] end
	function api.SetDetail(text) if detail.Text ~= text then detail.Text = text end end
	function api.SetActive(on) api.active = on == true; paintDot() end
	track.MouseButton1Click:Connect(function() api.Set(not kit.values[o.Id], true) end)
	api.Set(o.Default == true, false)
	kit.setters[o.Id] = api.Set
	kit:_bindChip(row, -92, o.Id, o.Text, function() api.Set(not kit.values[o.Id], true) end, self.button.Text)
	return api
end

-- A row that runs an action from a key: name, key chip and a Run button.
-- o = { Id, Text, Hint, OnPress } ; OnPress may return a status message.
function Tab:KeyRow(o)
	local row = self:_row(o.Hint and 44 or 38)
	local text = self:_text(row, o.Text, o.Hint)
	text.Size = UDim2.new(1, -150, 1, 0)
	local run = new("TextButton", {
		AutoButtonColor = false, Text = "Run", TextSize = 12, Font = FONT_BOLD, BackgroundColor3 = C.accent,
		TextColor3 = C.bg, Size = UDim2.fromOffset(60, 26), Position = UDim2.new(1, -72, 0.5, -13),
	}, row)
	corner(run, 6)
	run.MouseButton1Click:Connect(function()
		local msg = o.OnPress()
		if type(msg) == "string" then self.kit:SetStatus(msg, "ok") end
	end)
	self.kit:_bindChip(row, -114, o.Id, o.Text, o.OnPress, self.button.Text, false)
end

-- A name on the left, a value on the right; returns set(valueText).
function Tab:Stat(text)
	local row = self:_row(32)
	label(row, text, 12, C.sub, FONT_MED, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.6, -12, 1, 0) })
	local value = label(row, "-", 13, C.text, FONT_BOLD, {
		Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
	})
	return function(v) v = tostring(v); if value.Text ~= v then value.Text = v end end
end

-- A labelled bar; returns set(fraction, valueText).
function Tab:Meter(text)
	local row = self:_row(34)
	label(row, text, 12, C.sub, FONT_MED, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 64, 1, 0) })
	local track = new("Frame", { BackgroundColor3 = C.bg, Size = UDim2.new(1, -184, 0, 8), Position = UDim2.new(0, 80, 0.5, -4) }, row)
	corner(track, 4)
	local fill = new("Frame", { BackgroundColor3 = C.good, Size = UDim2.fromScale(0, 1) }, track)
	corner(fill, 4)
	local value = label(row, "", 12, C.text, FONT_MED, {
		Position = UDim2.new(1, -100, 0, 0), Size = UDim2.new(0, 88, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
	})
	return function(frac, text)
		frac = math.clamp(tonumber(frac) or 0, 0, 1)
		fill.Size = UDim2.fromScale(frac, 1)
		fill.BackgroundColor3 = frac >= 0.85 and C.accent or C.good
		if value.Text ~= text then value.Text = text end
	end
end

-- A row of equal buttons: { { Text = "...", Callback = fn }, ... }
function Tab:Actions(items)
	local row = self:_row(36)
	row.BackgroundTransparency = 1
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local gap = 6 * (#items - 1) / #items
	for i, item in ipairs(items) do
		local b = new("TextButton", {
			AutoButtonColor = false, Text = item.Text, TextSize = 12, Font = FONT_BOLD,
			BackgroundColor3 = i == 1 and C.accent or C.row, TextColor3 = i == 1 and C.bg or C.text,
			Size = UDim2.new(1 / #items, -gap, 1, 0), LayoutOrder = i,
		}, row)
		corner(b, 8)
		local running = false
		b.MouseButton1Click:Connect(function()
			if running then return end
			running = true
			local original = b.Text
			b.Text = "..."
			task.spawn(function()
				local ok, err = pcall(item.Callback)
				if not ok then self.kit:SetStatus("Error: " .. tostring(err)) end
				running = false
				if b.Parent then b.Text = original end
			end)
		end)
	end
	return row
end

-- Toggle({ Id, Text, Hint, Default })
function Tab:Toggle(o)
	local row = self:_row(o.Hint and 44 or 38)
	local text = self:_text(row, o.Text, o.Hint)
	text.Size = UDim2.new(1, -110, 1, 0)
	local track = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundColor3 = C.off, Size = UDim2.fromOffset(38, 22),
		Position = UDim2.new(1, -50, 0.5, -11),
	}, row)
	corner(track, 11)
	local knob = new("Frame", { BackgroundColor3 = C.text, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3) }, track)
	corner(knob, 8)
	local kit = self.kit
	local api = {}
	function api.Set(value, fire)
		value = value == true
		kit:_set(o.Id, value, fire)
		tween(track, { BackgroundColor3 = value and C.accent or C.off })
		tween(knob, { Position = value and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3) })
	end
	function api.Get() return kit.values[o.Id] end
	track.MouseButton1Click:Connect(function() api.Set(not kit.values[o.Id], true) end)
	api.Set(o.Default == true, false)
	kit.setters[o.Id] = api.Set
	if o.Bind ~= false then kit:_bindChip(row, -92, o.Id, o.Text, function() api.Set(not kit.values[o.Id], true) end, self.button.Text) end
	return api
end

local function formatNumber(v, prefix, suffix)
	local s = (math.floor(v) == v) and string.format("%d", v) or string.format("%.2f", v)
	if prefix == "$" then
		local int, frac = s:match("^(%-?%d+)(.*)$")
		int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^(%-?),", "%1")
		s = int .. frac
	end
	return (prefix or "") .. s .. (suffix or "")
end

local function numberBox(row, x)
	local box = new("TextBox", {
		BackgroundColor3 = C.bg, Size = UDim2.fromOffset(96, 26), Position = UDim2.new(1, x, 0.5, -13),
		Font = FONT_MED, TextSize = 13, TextColor3 = C.text, PlaceholderColor3 = C.faint, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	}, row)
	corner(box, 6)
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8) }, box)
	return box
end

-- Number({ Id, Text, Hint, Default, Min, Max, Prefix, Suffix })
function Tab:Number(o)
	local row = self:_row(o.Hint and 44 or 38)
	self:_text(row, o.Text, o.Hint)
	local box = numberBox(row, -106)
	local kit = self.kit
	local api = {}
	local function show(v) box.Text = formatNumber(v, o.Prefix, o.Suffix) end
	function api.Set(value, fire)
		value = tonumber(value) or o.Default or 0
		if o.Min then value = math.max(o.Min, value) end
		if o.Max then value = math.min(o.Max, value) end
		kit:_set(o.Id, value, fire)
		show(value)
	end
	function api.Get() return kit.values[o.Id] end
	box.Focused:Connect(function() box.Text = tostring(kit.values[o.Id]) end)
	box.FocusLost:Connect(function()
		local raw = box.Text:gsub("[^%d%.%-]", "")
		local n = tonumber(raw)
		if n then api.Set(n, true) else show(kit.values[o.Id]) end
	end)
	api.Set(o.Default or 0, false)
	return api
end

-- Rule({ Id, Text, Hint, Default, ValueId, Value, Min, Max, Prefix, Suffix })
-- One row: a switch (Id) and the minimum it applies (ValueId).
function Tab:Rule(o)
	local row = self:_row(o.Hint and 44 or 38)
	local text = self:_text(row, o.Text, o.Hint)
	text.Size = UDim2.new(1, -214, 1, 0)
	local box = numberBox(row, -158)
	local track = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundColor3 = C.off, Size = UDim2.fromOffset(38, 22),
		Position = UDim2.new(1, -50, 0.5, -11),
	}, row)
	corner(track, 11)
	local knob = new("Frame", { BackgroundColor3 = C.text, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3) }, track)
	corner(knob, 8)
	local kit = self.kit
	local api = {}
	local function show(v) box.Text = formatNumber(v, o.Prefix, o.Suffix) end
	function api.SetOn(on, fire)
		on = on == true
		kit:_set(o.Id, on, fire)
		tween(track, { BackgroundColor3 = on and C.accent or C.off })
		tween(knob, { Position = on and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3) })
		box.TextTransparency = on and 0 or 0.55
	end
	function api.SetValue(value, fire)
		value = tonumber(value) or o.Value or 0
		if o.Min then value = math.max(o.Min, value) end
		if o.Max then value = math.min(o.Max, value) end
		kit:_set(o.ValueId, value, fire)
		show(value)
	end
	track.MouseButton1Click:Connect(function() api.SetOn(not kit.values[o.Id], true) end)
	box.Focused:Connect(function() box.Text = tostring(kit.values[o.ValueId]) end)
	box.FocusLost:Connect(function()
		local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
		if n then api.SetValue(n, true) else show(kit.values[o.ValueId]) end
	end)
	api.SetValue(o.Value or 0, false)
	api.SetOn(o.Default == true, false)
	kit.setters[o.Id] = api.SetOn
	kit:_bindChip(row, -198, o.Id, o.Text, function() api.SetOn(not kit.values[o.Id], true) end, self.button.Text)
	return api
end

-- ColorInput({ Id, Text, Hint, Default = "#RRGGBB" }): a hex field with a swatch.
function Tab:ColorInput(o)
	local row = self:_row(o.Hint and 44 or 38)
	local text = self:_text(row, o.Text, o.Hint)
	text.Size = UDim2.new(1, -150, 1, 0)
	local swatch = new("Frame", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -136, 0.5, -11), BackgroundColor3 = C.accent }, row)
	corner(swatch, 6)
	stroke(swatch, C.line)
	local box = numberBox(row, -106)
	box.TextXAlignment = Enum.TextXAlignment.Center
	local kit = self.kit
	local api = { row = row }
	function api.Set(value, fire)
		local c = Kit.HexToColor(value) or Kit.HexToColor(o.Default) or Color3.new(1, 1, 1)
		local hex = Kit.ColorToHex(c)
		kit:_set(o.Id, hex, fire)
		box.Text = hex
		swatch.BackgroundColor3 = c
	end
	function api.Get() return kit.values[o.Id] end
	box.FocusLost:Connect(function()
		if Kit.HexToColor(box.Text) then api.Set(box.Text, true) else box.Text = kit.values[o.Id] end
	end)
	api.Set(o.Default, false)
	return api
end

-- Choice({ Id, Text, Options = {...}, Default }) : single choice, segmented
function Tab:Choice(o)
	local row = self:_row(64)
	label(row, o.Text, 13, C.text, FONT_MED, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 22) })
	local bar = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 26) }, row)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, bar)
	local kit, buttons, api = self.kit, {}, {}
	local w = 1 / #o.Options
	function api.Set(value, fire)
		kit:_set(o.Id, value, fire)
		for opt, b in pairs(buttons) do
			local on = opt == value
			tween(b, { BackgroundColor3 = on and C.accent or C.bg, TextColor3 = on and C.bg or C.sub })
		end
	end
	function api.Get() return kit.values[o.Id] end
	for _, opt in ipairs(o.Options) do
		local b = new("TextButton", {
			AutoButtonColor = false, Text = opt, TextSize = 12, Font = FONT_MED, BackgroundColor3 = C.bg, TextColor3 = C.sub,
			Size = UDim2.new(w, -4 + 4 / #o.Options, 1, 0),
		}, bar)
		corner(b, 6)
		buttons[opt] = b
		b.MouseButton1Click:Connect(function() api.Set(opt, true) end)
	end
	api.Set(o.Default or o.Options[1], false)
	return api
end

-- List({ Id, Text, Hint, Options = {...} | function, Multi = true, Default = {} , Empty = "All"})
-- Expands inline; options are plain strings.
function Tab:List(o)
	local kit = self.kit
	local wrap = new("Frame", { BackgroundColor3 = C.row, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 38), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self:_next() }, self.page)
	corner(wrap, 8)
	self:_track(wrap)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, wrap)
	local head = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, o.Hint and 44 or 38), LayoutOrder = 1 }, wrap)
	self:_text(head, o.Text, o.Hint)
	local summary = label(head, "", 12, C.accent, FONT_MED, {
		Position = UDim2.new(1, -150, 0, 0), Size = UDim2.fromOffset(138, o.Hint and 44 or 38), TextXAlignment = Enum.TextXAlignment.Right,
	})
	local drawer = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, LayoutOrder = 2 }, wrap)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, drawer)
	local search = new("TextBox", {
		BackgroundColor3 = C.bg, Size = UDim2.new(1, 0, 0, 26), Font = FONT, TextSize = 12, TextColor3 = C.text,
		PlaceholderText = "Search", PlaceholderColor3 = C.faint, Text = "", ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1,
	}, drawer)
	corner(search, 6)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, search)
	local grid = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 150), Position = UDim2.fromOffset(0, 32),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.line,
	}, drawer)
	new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 182) }, drawer) -- reserves drawer height

	-- Only a bounded set of rows exists at a time (selected first, then
	-- search matches), so a catalogue of thousands of names stays light.
	local MAX_ROWS = 80
	local api, chips, options = {}, {}, {}
	local selected = {}
	local function refreshSummary()
		local n, first = 0, nil
		for name in pairs(selected) do n += 1; first = first or name end
		if not o.Multi then summary.Text = first or (o.Empty or "None")
		elseif n == 0 then summary.Text = o.Empty or "All"
		elseif n == 1 then summary.Text = first
		else summary.Text = n .. " selected" end
	end
	local publish
	local function paint()
		refreshSummary()
		if not drawer.Visible then return end
		for _, chip in ipairs(chips) do chip:Destroy() end
		table.clear(chips)
		local q = string.lower(search.Text)
		local rows = {}
		for _, name in ipairs(options) do
			if selected[name] then rows[#rows + 1] = name end
		end
		for _, name in ipairs(options) do
			if #rows >= MAX_ROWS then break end
			if not selected[name] and (q == "" or string.find(string.lower(name), q, 1, true)) then rows[#rows + 1] = name end
		end
		for i, name in ipairs(rows) do
			local on = selected[name] == true
			local chip = new("TextButton", {
				AutoButtonColor = false, Text = (on and "[x]  " or "[ ]  ") .. name, TextSize = 12, Font = FONT,
				BackgroundColor3 = on and C.rowHover or C.bg, TextColor3 = on and C.accent or C.sub,
				Size = UDim2.new(1, -6, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i,
			}, grid)
			corner(chip, 5)
			new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, chip)
			chips[#chips + 1] = chip
			chip.MouseButton1Click:Connect(function()
				if o.Multi then
					selected[name] = not selected[name] or nil
				else
					local was = selected[name]
					table.clear(selected)
					if not was then selected[name] = true end
				end
				paint()
				publish(true)
			end)
		end
	end
	publish = function(fire)
		local list = {}
		for name in pairs(selected) do table.insert(list, name) end
		table.sort(list)
		kit:_set(o.Id, o.Multi and list or list[1], fire)
	end
	function api.SetOptions(list)
		options = list
		paint()
	end
	function api.Set(value, fire)
		table.clear(selected)
		if type(value) == "table" then for _, n in ipairs(value) do selected[n] = true end
		elseif value ~= nil then selected[value] = true end
		paint()
		publish(fire)
	end
	function api.Get() return kit.values[o.Id] end
	head.MouseButton1Click:Connect(function()
		drawer.Visible = not drawer.Visible
		if drawer.Visible and type(o.Options) == "function" then options = o.Options() end
		paint()
	end)
	search:GetPropertyChangedSignal("Text"):Connect(paint)
	api.SetOptions(type(o.Options) == "table" and o.Options or {})
	api.Set(o.Default or (o.Multi and {} or nil), false)
	return api
end

-- Button({ Text, Hint, Action = "Run", Callback })
function Tab:Button(o)
	local row = self:_row(o.Hint and 44 or 38)
	self:_text(row, o.Text, o.Hint)
	local b = new("TextButton", {
		AutoButtonColor = false, Text = o.Action or "Run", TextSize = 12, Font = FONT_BOLD, BackgroundColor3 = C.accent,
		TextColor3 = C.bg, Size = UDim2.fromOffset(74, 26), Position = UDim2.new(1, -84, 0.5, -13),
	}, row)
	corner(b, 6)
	local running = false
	b.MouseButton1Click:Connect(function()
		if running then return end
		running = true
		b.Text = "..."
		task.spawn(function()
			local ok, err = pcall(o.Callback)
			if not ok then self.kit:SetStatus("Error: " .. tostring(err)) end
			running = false
			if b.Parent then b.Text = o.Action or "Run" end
		end)
	end)
	return b
end

-- Info({ Text }) : a one-line read-only value; returns setter
function Tab:Info(text)
	local row = self:_row(38)
	local l = label(row, text, 12, C.sub, FONT, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), TextWrapped = true, TextTruncate = Enum.TextTruncate.None })
	return function(t) if l.Parent then l.Text = t end end
end

return Kit
end)()

---------------------------------------------------------------------------
-- Game access
---------------------------------------------------------------------------

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local Modules = RS:WaitForChild("Modules")
local Items = require(Modules.Items)
local Mut = require(Modules.MutatorModule)
local okGC, GameConfig = pcall(require, Modules:FindFirstChild("GameConfig"))
local okGarages, GarageDefs = pcall(require, Modules:FindFirstChild("Garages"))

local Events = RS:WaitForChild("Events")
local function remote(folder, name)
	local f = Events:FindFirstChild(folder)
	return f and f:FindFirstChild(name)
end
local Rm = {
	Bid = remote("Auction", "Bid"),
	ToggleBiddingUI = remote("Auction", "ToggleBiddingUI"),
	UpdateWinning = remote("Auction", "UpdateCurrentWinningBid"),
	ToggleArea = remote("Auction", "ToggleAuctionArea"),
	Paused = remote("Auction", "AuctionPaused"),
	LeaveAuction = remote("Auction", "LeaveAuction"),
	GetInventory = remote("Inventory", "GetPlayerInventory"),
	ToggleFavorite = remote("Inventory", "ToggleFavoriteItem"),
	RepairWonItem = remote("WrenchShop", "RepairWonItem"),
	RepairSlots = remote("Repair", "GetSlotState"),
	GetRepairable = remote("Repair", "GetRepairableItems"),
	StartRepair = remote("Repair", "StartRepair"),
	CollectRepair = remote("Repair", "CollectRepair"),
	ClaimRepair = remote("Repair", "ClaimRepairedItem"),
	ShelfAutoStock = remote("Plot", "ShelfAutoStock"),
	GetMyPlacedItems = remote("Plot", "GetMyPlacedItems"),
	ChangeStockPrice = remote("Plot", "ChangeStockPrice"),
	RequestPlotData = remote("Plot", "RequestPlotData"),
	CashEffect = remote("NPCShopper", "CashEffect"),
	TeleportToPlot = remote("Plot", "TeleportToPlot"),
	RequestSpawn = remote("Vehicles", "RequestSpawn"),
	SpawnResult = remote("Vehicles", "SpawnResult"),
	GetVehicleItems = remote("Vehicles", "GetVehicleItems"),
	Unload = remote("Vehicles", "TransferVehicleItemsToInventory"),
	OfferOverweight = remote("UI", "OfferOverweightAdd"),
	PickSession = remote("Locksmith", "StartPicklockSession"),
	PickInventorySafe = remote("Locksmith", "PicklockInventorySafe"),
	PickFailure = remote("Locksmith", "RegisterInventoryPicklockFailure"),
	LocksmithSlots = remote("Locksmith", "GetSlotState"),
	LocksmithStart = remote("Locksmith", "StartLocksmith"),
	LocksmithOpen = remote("Locksmith", "OpenSafe"),
	LocksmithClaim = remote("Locksmith", "ClaimItem"),
	LockpickState = remote("LockpickShop", "GetState"),
	PickupStart = remote("Auction", "AuctionPickupStart"),
	PickupItem = remote("Auction", "AuctionPickupItem"),
	FeePaid = remote("Auction", "AuctionFeePaid"),
	Notify = remote("UI", "Notify"),
	MiningState = remote("Misc", "MiningState"),
}

local function invoke(rf, ...)
	if not rf then return nil end
	local ok, result = pcall(rf.InvokeServer, rf, ...)
	return ok and result or nil
end

local nameToId = {}
for id, def in pairs(Items) do
	if type(def) == "table" and type(def.Name) == "string" then nameToId[def.Name] = id end
end

-- Value as the game computes it: mutators and condition, then grade.
local function entryValue(entry)
	local def = entry and Items[tostring(entry.ItemId)]
	if not def then return 0 end
	local ok, value = pcall(function()
		local v = Mut:CalculatePriceForEntry(def.BasePrice or 0, entry)
		if okGC and GameConfig.Grading and GameConfig.Grading.GradeCashMultForEntry then
			v *= GameConfig.Grading.GradeCashMultForEntry(entry)
		end
		return v
	end)
	return ok and tonumber(value) or (def.BasePrice or 0)
end

local function modelEntry(model)
	local mutators = {}
	local ok, parsed = pcall(Mut.ParseMutatorsAttr, Mut, model:GetAttribute("Mutators"))
	if ok and type(parsed) == "table" then mutators = parsed end
	local itemId = model:GetAttribute("ItemId")
	local contained = model:GetAttribute("ContainedItem")
	if type(contained) == "string" and nameToId[contained] then itemId = nameToId[contained] end
	return { ItemId = itemId, Condition = model:GetAttribute("Condition"), Mutators = mutators }
end

local function money(n)
	n = math.floor((tonumber(n) or 0) + 0.5)
	local s = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	s = s:gsub("^,", "")
	return (n < 0 and "-$" or "$") .. s
end

local function getChar()
	local c = LP.Character
	return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

---------------------------------------------------------------------------
-- Settings (saved to a file)
---------------------------------------------------------------------------

local DIR = "UAI/files/Storage Hunters Open World (98800969324557)"
-- One file per Roblox account, so switching accounts on this PC never runs
-- (or overwrites) another account's switches. A new account starts with defaults.
local SETTINGS_PATH = DIR .. "/hub_settings_" .. tostring(LP.UserId) .. ".json"
if type(makefolder) == "function" and type(isfolder) == "function" then
	local path = ""
	for part in DIR:gmatch("[^/]+") do
		path = path == "" and part or (path .. "/" .. part)
		if not isfolder(path) then pcall(makefolder, path) end
	end
end

local saved = {}
do
	local ok, raw = pcall(function() return isfile(SETTINGS_PATH) and readfile(SETTINGS_PATH) end)
	if ok and type(raw) == "string" and raw ~= "" then
		local okJ, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if okJ and type(data) == "table" then saved = data end
	end
end
local S = {} -- live settings; the UI writes here
local function D(id, default)
	local v = saved[id]
	if v ~= nil and type(v) == type(default) then return v end
	return default
end
local saveQueued = false
local function queueSave()
	if saveQueued then return end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		pcall(function() writefile(SETTINGS_PATH, HttpService:JSONEncode(S)) end)
	end)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local A = { active = false, garage = nil, winner = nil, amount = 0, nextPrice = nil, paused = false,
	lastBid = 0, wait = 0, bids = 0, status = "Waiting for auction", hasBlue = false }
local Auto = { status = "Idle", busy = false, lastStep = 0, lastAuctionEnd = 0, lastJoin = 0, lastRepair = 0,
	lastFav = 0, lastList = 0, lastDeposit = 0, overweightAt = 0, lastSpawnReq = 0, spawnResult = nil,
	blocked = {}, pickFail = {}, repairTried = {}, veh = nil, plot = nil, plotAt = 0, basePrice = {}, priced = {},
	picked = 0, opened = 0, repaired = 0, favorited = 0, listed = 0, accepted = 0, joined = 0 }
local spotted = setmetatable({}, { __mode = "k" })

-- Numbers for the Stats tab. Saved to a file so they keep counting across
-- reloads and rejoins until you press Reset stats.
local Stats = {
	startedAt = os.clock(), trackedBefore = 0, since = os.date("%d %b %Y, %H:%M"), startNetWorth = nil,
	won = 0, bidsPaid = 0, entryFees = 0, lootValue = 0, mutated = 0, safes = 0, shelfSales = 0, salesCount = 0,
	path = DIR .. "/hub_stats_" .. tostring(LP.UserId) .. ".json",
}
local STAT_FIELDS = { "won", "bidsPaid", "entryFees", "lootValue", "mutated", "safes", "shelfSales", "salesCount" }
local AUTO_FIELDS = { "joined", "picked", "favorited", "listed" }
do
	local ok, raw = pcall(function() return isfile(Stats.path) and readfile(Stats.path) end)
	local okJ, data = false, nil
	if ok and type(raw) == "string" and raw ~= "" then okJ, data = pcall(HttpService.JSONDecode, HttpService, raw) end
	if okJ and type(data) == "table" then
		for _, k in ipairs(STAT_FIELDS) do Stats[k] = tonumber(data[k]) or 0 end
		for _, k in ipairs(AUTO_FIELDS) do Auto[k] = tonumber(data[k]) or 0 end
		Stats.trackedBefore = tonumber(data.tracked) or 0
		Stats.startNetWorth = tonumber(data.startNetWorth)
		Stats.since = type(data.since) == "string" and data.since or Stats.since
	end
end
function Stats.trackedSeconds() return Stats.trackedBefore + (os.clock() - Stats.startedAt) end
function Stats.save()
	local data = { tracked = Stats.trackedSeconds(), since = Stats.since, startNetWorth = Stats.startNetWorth }
	for _, k in ipairs(STAT_FIELDS) do data[k] = Stats[k] end
	for _, k in ipairs(AUTO_FIELDS) do data[k] = Auto[k] end
	pcall(function() writefile(Stats.path, HttpService:JSONEncode(data)) end)
end
function Stats.reset()
	for _, k in ipairs(STAT_FIELDS) do Stats[k] = 0 end
	for _, k in ipairs(AUTO_FIELDS) do Auto[k] = 0 end
	Stats.startedAt, Stats.trackedBefore, Stats.startNetWorth = os.clock(), 0, nil
	Stats.since = os.date("%d %b %Y, %H:%M")
	Stats.save()
end

-- Two locks keep features from racing each other:
--   body  - anything that moves your character or car (auctions, pickup,
--           boxes, unload trips, teleports)
--   items - anything that changes your inventory or shelves (favorite,
--           list, unload into inventory, repair shop)
-- Every automation and every button takes the lock it needs and waits its
-- turn. Work that needs both always takes body first, so it cannot deadlock.
-- Bidding and the reveal touch neither and stay independent.
-- (Luau tasks only switch at yields, so the check-and-take below is atomic.)
local Locks = { body = { name = "body" }, items = { name = "items" } }
local function guarded(lock, who, fn, ...)
	local t0 = os.clock()
	while lock.owner do
		if not Hub.alive then return false, "hub stopped" end
		if os.clock() - t0 > 60 then return false, lock.owner .. " is still running" end
		task.wait(0.05)
	end
	lock.owner = who
	lock.thread = coroutine.running()
	if lock == Locks.body then Auto.busy = true end
	local result = table.pack(pcall(fn, ...))
	lock.owner, lock.thread = nil, nil
	if lock == Locks.body then Auto.busy = false end
	if not result[1] then return false, result[2] end
	return true, table.unpack(result, 2, result.n)
end
local function runBody(who, fn, ...) return guarded(Locks.body, who, fn, ...) end
local function runItems(who, fn, ...) return guarded(Locks.items, who, fn, ...) end

-- Watchdog version for the automation loops: a step that runs past `limit`
-- seconds (a game call that never answered) is stopped and every lock it held
-- is freed, so one frozen call cannot stall the hub while you are away.
local function guardedLimit(lock, who, limit, fn)
	local t0 = os.clock()
	while lock.owner do
		if not Hub.alive then return false, "hub stopped" end
		if os.clock() - t0 > 60 then return false, lock.owner .. " is still running" end
		task.wait(0.05)
	end
	lock.owner = who
	if lock == Locks.body then Auto.busy = true end
	local done, result = false, nil
	local worker
	worker = task.spawn(function()
		lock.thread = coroutine.running()
		result = table.pack(pcall(fn))
		done = true
	end)
	local started = os.clock()
	while not done and Hub.alive and os.clock() - started < limit do task.wait(0.1) end
	if not done then pcall(task.cancel, worker) end
	-- free this lock, and any other lock the stopped step had taken inside
	for _, l in pairs(Locks) do
		if l == lock or (not done and l.thread == worker) then l.owner, l.thread = nil, nil end
	end
	if lock == Locks.body then Auto.busy = false end
	if not done then return false, "stuck", true end
	if not result[1] then return false, result[2] end
	return true, table.unpack(result, 2, result.n)
end

-- Admin safety: while an admin is in the server (and you have not chosen to
-- override), features are switched off and running work stops at its next step.
local Safety = { staff = {}, paused = false, override = false, snapshot = nil }
local function halted()
	return not Hub.alive or Safety.paused
end

-- "Blue" items: the game outlines them for everyone (event bonus) or for
-- you (your bonus item, e.g. a trophy with an aura).
local function isBlue(m)
	if spotted[m] then return true end
	local spot = m:GetAttribute("SpotOutline")
	return spot == true or spot == LP.UserId or m:GetAttribute("IsTrophy") == true or m:GetAttribute("PlayAuraSound") == true
end

---------------------------------------------------------------------------
-- Movement helpers (character and vehicle)
---------------------------------------------------------------------------

-- Presses a prompt, trying three ways in order and stopping as soon as one
-- worked:
--   1. Roblox's own hold methods (exactly what holding the key does)
--   2. a simulated key press through VirtualInputManager
--   3. the executor's fireproximityprompt, as a last resort
-- It runs on its own thread, so nothing here can hold the hub up; callers
-- check the outcome themselves. isDone() says whether it worked; by default,
-- when the prompt is gone or disabled (garage entrances, pickups, boxes).
local firePrompt
do
local VIM = (function()
	local ok, service = pcall(game.GetService, game, "VirtualInputManager")
	return ok and service or nil
end)()
function firePrompt(p, isDone)
	if not (p and p.Parent) then return false end
	if p.HoldDuration > 0 then p.HoldDuration = 0 end
	isDone = isDone or function() return not (p.Parent and p.Enabled) end
	local function settled()
		task.wait(0.6) -- give the server a moment to react
		local ok, done = pcall(isDone)
		return ok and done
	end
	task.spawn(function()
		pcall(function() p:InputHoldBegin(); task.wait(0.05); p:InputHoldEnd() end)
		if settled() then return end
		local key = p.KeyboardKeyCode
		if VIM and key and key ~= Enum.KeyCode.Unknown then
			pcall(function()
				VIM:SendKeyEvent(true, key, false, game)
				task.wait(0.05)
				VIM:SendKeyEvent(false, key, false, game)
			end)
			if settled() then return end
		end
		if type(fireproximityprompt) == "function" then pcall(fireproximityprompt, p) end
	end)
	return true
end
end

-- Asks the game to load the area around pos, but never waits more than ~3.5 s.
local function streamAround(pos)
	local done = false
	task.spawn(function()
		pcall(LP.RequestStreamAroundAsync, LP, pos, 3)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 3.5 do task.wait(0.1) end
end

local function exitVehicle()
	local _, _, hum = getChar()
	if hum and hum.SeatPart then
		hum.Sit = false
		hum.Jump = true
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		local t0 = os.clock()
		repeat task.wait(0.1) until not hum.SeatPart or os.clock() - t0 > 1.5
		task.wait(0.15)
	end
end

local function stillModel(m)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function groundAt(pos, ignore, up)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = {}
	if LP.Character then table.insert(list, LP.Character) end
	if ignore then table.insert(list, ignore) end
	params.FilterDescendantsInstances = list
	up = up or 25
	local hit = workspace:Raycast(pos + Vector3.new(0, up, 0), Vector3.new(0, -(up + 40), 0), params)
	return hit and hit.Position or pos
end

local function tpTo(pos)
	local char, hrp, hum = getChar()
	if not (char and hrp and pos) then return false end
	if hum and hum.SeatPart then hum.Sit = false; task.wait(0.1) end
	streamAround(pos)
	-- Look for floor just above the target, not from high up: indoors a high
	-- ray hits the roof and lands you on top of the building.
	local g = groundAt(pos, nil, 4)
	char:PivotTo(CFrame.new(g + Vector3.new(0, 3.5, 0)) * hrp.CFrame.Rotation)
	hrp.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function placeNear(pos, dist)
	exitVehicle()
	local char, hrp = getChar()
	if not (char and hrp) then return false end
	dist = dist or 3
	local flat = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
	local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
	local spot = pos + dir * dist
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
	local y = hit and (hit.Position.Y + 3) or (pos.Y + 2)
	char:PivotTo(CFrame.new(Vector3.new(spot.X, y, spot.Z), Vector3.new(pos.X, y, pos.Z)))
	hrp.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function myVehicle()
	local guid = LP:GetAttribute("EquippedVehicle")
	if typeof(guid) ~= "string" or guid == "" then return nil end
	local v = Auto.veh
	if v and v.Parent and v:GetAttribute("VehicleGUID") == guid then return v end
	Auto.veh = nil
	local function scan(root)
		for _, m in ipairs(root:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("VehicleGUID") == guid and m:GetAttribute("OwnerUserId") == LP.UserId then return m end
		end
	end
	local found = scan(workspace)
	local deb = workspace:FindFirstChild("_Debris")
	if not found and deb and deb:FindFirstChild("Vehicles") then found = scan(deb.Vehicles) end
	Auto.veh = found
	return found
end

local function cargoOf(veh)
	if not veh then return 0, nil end
	return tonumber(veh:GetAttribute("CargoWeight")) or 0, tonumber(veh:GetAttribute("CargoWeightLimit"))
end

local function seatedIn(veh)
	local _, _, hum = getChar()
	local s = hum and hum.SeatPart
	return s ~= nil and s:IsA("VehicleSeat") and veh ~= nil and s:IsDescendantOf(veh)
end

local function enterVehicle(veh)
	if seatedIn(veh) then return true end
	local seat = veh:FindFirstChild("DriveSeat") or veh:FindFirstChildWhichIsA("VehicleSeat", true)
	local char, hrp, hum = getChar()
	if not (seat and char and hrp and hum) then return false end
	if hum.SeatPart then exitVehicle() end
	char:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.25)
	local prompt = seat:FindFirstChild("VehiclePrompt", true)
	if prompt then firePrompt(prompt, function() return seatedIn(veh) end) end
	for _ = 1, 15 do
		if seatedIn(veh) then return true end
		task.wait(0.1)
	end
	pcall(seat.Sit, seat, hum)
	task.wait(0.4)
	return seatedIn(veh)
end

local function moveVehicle(veh, cf)
	if not enterVehicle(veh) then return false end
	stillModel(veh)
	veh:PivotTo(cf)
	stillModel(veh)
	task.wait(0.3)
	stillModel(veh)
	return true
end

local VEH_RADIUS = 45

-- The game's V key: RequestSpawn(equipped vehicle) puts your car next to you
-- (VehicleHotkey; not allowed while seated, 3 s cooldown). No driving needed.
local function spawnCarHere()
	local guid = LP:GetAttribute("EquippedVehicle")
	if typeof(guid) ~= "string" or guid == "" then return nil, "no vehicle equipped" end
	if not Rm.RequestSpawn then return nil, "spawn remote missing" end
	exitVehicle()
	local cooldown = 3.2 - (os.clock() - Auto.lastSpawnReq)
	if cooldown > 0 then task.wait(cooldown) end
	Auto.lastSpawnReq = os.clock()
	Auto.spawnResult = nil
	Rm.RequestSpawn:FireServer(guid)
	local t0 = os.clock()
	while not Auto.spawnResult and os.clock() - t0 < 3 do task.wait(0.1) end
	if Auto.spawnResult and Auto.spawnResult.ok == false then return nil, Auto.spawnResult.msg end
	local _, hrp = getChar()
	t0 = os.clock()
	repeat
		task.wait(0.2)
		Auto.veh = nil
		local veh = myVehicle()
		if veh and hrp and (veh:GetPivot().Position - hrp.Position).Magnitude <= 40 then return veh end
	until os.clock() - t0 > 2.5
	return myVehicle(), "the car did not appear next to you"
end

-- Brings your vehicle within reach of pos: stand at `spot` (or a few studs
-- from pos) and spawn it there.
local function vehicleNear(pos, spot)
	local veh = myVehicle()
	if veh and (veh:GetPivot().Position - pos).Magnitude <= VEH_RADIUS then return veh end
	if spot then placeNear(spot, 0.5) else placeNear(pos, 8) end
	task.wait(0.2)
	local err
	veh, err = spawnCarHere()
	exitVehicle() -- spawning seats you in the car; hop out and carry on
	if veh and (veh:GetPivot().Position - pos).Magnitude <= VEH_RADIUS + 20 then return veh end
	return nil, err
end

---------------------------------------------------------------------------
-- Auction: bidding
---------------------------------------------------------------------------

-- A gavel in the lot. The game marks it in several ways (its own auction code
-- reads the Gavel* attributes on the garage and items); the outline can be
-- missing while the lot is checked, so look at all of them.
local TROPHY_ID = "376"
do
	local okT, TrophyCfg = pcall(require, Modules:FindFirstChild("TrophyConfig"))
	if okT and type(TrophyCfg) == "table" and TrophyCfg.TrophyItemId then TROPHY_ID = tostring(TrophyCfg.TrophyItemId) end
end
local function isGavelModel(m)
	if m:GetAttribute("IsTrophy") == true or m:GetAttribute("TrophyUid") ~= nil then return true end
	if tostring(m:GetAttribute("ItemId")) == TROPHY_ID then return true end
	if m:GetAttribute("GavelForcedMutator") or m:GetAttribute("GavelAssistMutator") then return true end
	if m.Name:find("Gavel", 1, true) then return true end
	-- the item reveal may already have named a hidden item
	local R = env.UAIAuctionReveal
	local rec = R and type(R.items) == "table" and R.items[m]
	return rec ~= nil and type(rec.guess) == "string" and rec.guess:find("Gavel", 1, true) ~= nil
end

local function scanLotForBlue()
	local g = A.garage
	local floor = g and g:FindFirstChild("Floorspace")
	local found, gavel = false, false
	if g and (g:GetAttribute("GavelForcedMutator") or g:GetAttribute("GavelAssistMutator")) then gavel = true end
	for _, m in ipairs(floor and floor:GetChildren() or {}) do
		if m:IsA("Model") then
			local spot = m:GetAttribute("SpotOutline")
			if spot == true or spot == LP.UserId then spotted[m] = true end
			if spotted[m] or m:GetAttribute("PlayAuraSound") == true then found = true end
			if isGavelModel(m) then gavel = true; spotted[m] = true end
		end
	end
	A.hasGavel = gavel
	-- a gavel counts as an outlined item: always taken, bid on despite lot value
	A.hasBlue = found or (gavel and S.gavelLots ~= false)
end

-- Lot filter: before bidding, require a minimum starting bid and/or at least
-- one item with a chosen mutation. Lots that fail are skipped (and left).
local function lotMutations()
	local found = {}
	local g = A.garage
	local floor = g and g:FindFirstChild("Floorspace")
	for _, m in ipairs(floor and floor:GetChildren() or {}) do
		if m:IsA("Model") then
			local ok, list = pcall(Mut.ParseMutatorsAttr, Mut, m:GetAttribute("Mutators"))
			for _, entry in ipairs(ok and type(list) == "table" and list or {}) do
				if type(entry) == "table" and entry.name then found[entry.name] = true end
			end
		end
	end
	return found
end

-- Leave a rejected lot and move straight on: no waiting for the auctioneer,
-- the countdown or the results pause.
local function failLot(reason)
	A.filter, A.filterWhy = "fail", reason
	if not S.leaveFailed then return end
	local key = A.garage and (A.garage:GetAttribute("GUID") or A.garage:GetFullName())
	if key then Auto.blocked[key] = os.clock() + 300 end
	Auto.leftAt = os.clock()
	Auto.status = "Lot skipped: " .. reason .. "; moving on"
	task.spawn(function()
		invoke(Rm.LeaveAuction)
		A.active, A.garage, A.hasBlue, A.startBid, A.filterGarage = false, nil, false, nil, nil
		Auto.lastAuctionEnd, Auto.lastJoin = 0, 0 -- the next garage can open right away
	end)
end

local function floorItemCount()
	local floor = A.garage and A.garage:FindFirstChild("Floorspace")
	local n = 0
	for _, m in ipairs(floor and floor:GetChildren() or {}) do if m:IsA("Model") then n += 1 end end
	return n
end

-- Decides as early as possible. Starts when you enter the auction zone, so
-- the floor items are judged during the countdown, before bidding opens.
local function checkLot()
	local now = os.clock()
	-- 0. airdrop crates are special drops: always bid
	if A.garage and A.garage:GetAttribute("GarageId") == "Camo Airdrop" then
		A.filter, A.filterWhy = "pass", "airdrop crate"
		return
	end
	-- 1. an outlined item or a gavel: take this lot, skip the other checks
	scanLotForBlue()
	if A.hasBlue then
		A.filter, A.filterWhy = "pass", A.hasGavel and "gavel in the lot" or "outlined item in the lot"
		return
	end
	-- a hidden item could still turn out to be a gavel: while the item reveal
	-- is reading this lot, hold off rejecting it (up to 15 s after it opened)
	local R = env.UAIAuctionReveal
	if R and type(R.garageSummary) == "function" and now - A.openedAt < 15 then
		local okSum, sum = pcall(R.garageSummary, A.garage)
		if okSum and type(sum) == "table" and (sum.pending or 0) > 0 then return end
	end
	-- wait until the floor items have arrived and settled (outlines can follow a moment later)
	local n = floorItemCount()
	if n == 0 then
		if now - A.openedAt < 4 then return end
	elseif n ~= A.floorCount then
		A.floorCount, A.floorSeenAt = n, now
		return
	elseif now - (A.floorSeenAt or now) < 0.8 then
		return
	end
	-- 2. mutations are known as soon as the items are
	local wanted = S.lotMuts or {}
	if #wanted > 0 then
		local found = lotMutations()
		local hit
		for _, name in ipairs(wanted) do if found[name] then hit = name; break end end
		if not hit then return failLot("no wanted mutation in the lot") end
		A.filterWhy = "has " .. hit
	end
	-- 3. the starting bid is only announced when bidding begins
	if S.minStartBid > 0 then
		if not A.startBid then
			if now - A.openedAt < 20 then return end
			return failLot("starting bid never announced")
		end
		if A.startBid < S.minStartBid then
			return failLot(string.format("starting bid %s is under %s", money(A.startBid), money(S.minStartBid)))
		end
	end
	A.filter = "pass"
end

-- Starts a lot check for a garage once, when it is first seen.
local function beginLotCheck(garage)
	if not garage or A.filterGarage == garage then return end
	A.filterGarage = garage
	A.filter = S.lotFilter and "checking" or "off"
	A.filterWhy, A.startBid, A.floorCount, A.floorSeenAt = nil, nil, nil, nil
	A.openedAt = os.clock()
end

local function bidTick(now)
	if not (S.autoBid and A.active) then
		A.status = A.active and "Auction open, auto bid off" or "Waiting for auction"
		return
	end
	if A.filter == "checking" or (S.lotFilter and A.filter == nil) then
		A.status = "Checking the lot before bidding"
		return
	end
	if A.filter == "fail" then A.status = "Lot skipped: " .. tostring(A.filterWhy); return end
	if A.paused then A.status = "Auction paused"; return end
	if A.winner == LP.Name then A.status = "Winning at " .. money(A.amount); return end
	local price = A.nextPrice or A.amount or 0
	local limit
	if A.hasBlue then
		-- an outlined item: bid despite a low lot value; only the outlined max
		-- (or your normal max when that is 0) limits it
		limit = S.blueMaxBid > 0 and S.blueMaxBid or S.maxBid
	else
		limit = S.maxBid
		if S.bidPctOfValue > 0 and A.lotEst then
			local cap = A.lotEst * S.bidPctOfValue / 100
			limit = limit > 0 and math.min(limit, cap) or cap
		end
	end
	if limit > 0 and price > limit then A.status = "Next bid " .. money(price) .. " is over the max"; return end
	local cash = LP:GetAttribute("Cash")
	if type(cash) == "number" and price > cash - S.keepCash then
		A.status = "Not enough cash for " .. money(price)
		A.cashShort = true -- after this auction, wait at the plot for sales
		return
	end
	if now - A.lastBid < A.wait then return end
	A.lastBid = now
	A.wait = S.bidDelay + math.random() * 0.15
	Rm.Bid:FireServer()
	A.bids += 1
	A.status = "Bid sent at " .. money(price)
end

---------------------------------------------------------------------------
-- Auction: finding and starting garages
---------------------------------------------------------------------------

local function netWorth()
	local stats = LP:FindFirstChild("leaderstats")
	local nw = stats and stats:FindFirstChild("Net Worth")
	if not nw then return math.huge end
	return tonumber(nw:GetAttribute("RawValue")) or tonumber((tostring(nw.Value):gsub("[^%d%.]", ""))) or math.huge
end

local function garageCandidates()
	local root = workspace:FindFirstChild("_Debris") and workspace._Debris:FindFirstChild("Garages")
	local out = {}
	if not root then return out end
	local _, hrp = getChar()
	local cash = tonumber(LP:GetAttribute("Cash")) or 0
	local worth = netWorth()
	local allow = {}
	for _, a in ipairs(S.areas or {}) do allow[a] = true end
	local now = os.clock()
	for _, g in ipairs(root:GetChildren()) do
		if g:IsA("Model") and not g:GetAttribute("InAuction") and (g:GetAttribute("EntryCurrency") or "Cash") == "Cash" then
			local area = tostring(g:GetAttribute("AreaName") or "")
			local cost = tonumber(g:GetAttribute("EntryCost")) or 0
			local key = g:GetAttribute("GUID") or g:GetFullName()
			local def = okGarages and type(GarageDefs) == "table" and GarageDefs[g:GetAttribute("GarageId") or ""]
			local minWorth = type(def) == "table" and tonumber(def.MinNetWorth) or 0
			local eventOnly = type(def) == "table" and def.EventOnly == true
			if (next(allow) == nil or allow[area]) and (S.maxEntry <= 0 or cost <= S.maxEntry)
				and cash - cost >= S.keepCash and worth >= minWorth and not eventOnly and (Auto.blocked[key] or 0) < now then
				local pos = g:GetPivot().Position
				out[#out + 1] = { garage = g, cost = cost, area = area, key = key,
					dist = hrp and (pos - hrp.Position).Magnitude or 0 }
			end
		end
	end
	local mode = S.garagePick
	table.sort(out, function(a, b)
		if mode == "Priciest" and a.cost ~= b.cost then return a.cost > b.cost end
		if mode == "Cheapest" and a.cost ~= b.cost then return a.cost < b.cost end
		return a.dist < b.dist
	end)
	return out
end

-- Walks up to a garage's Start Auction prompt and opens it. Shared by normal
-- auctions and airdrops. Returns true once the auction has started.
local function openGarage(g, key, label)
	Auto.lastJoin = os.clock()
	streamAround(g:GetPivot().Position)
	local square = g:FindFirstChild("EntrySquare")
	local part = square and square:FindFirstChild("PromptPart")
	local prompt = part and part:FindFirstChild("EnterAuction")
	if not prompt then
		-- not every garage keeps it under EntrySquare (airdrop crates may not)
		prompt = g:FindFirstChild("EnterAuction", true)
		part = prompt and prompt.Parent
		if part and part:IsA("Attachment") then part = part.Parent end
		if part and not part:IsA("BasePart") then part = nil end
	end
	if not (prompt and part) then
		Auto.blocked[key] = os.clock() + 30
		Auto.status = label .. ": entrance not loaded yet, trying another"
		return false
	end
	if S.bringCar then
		-- park just outside the entrance, on the side away from the garage
		local away = part.Position - g:GetPivot().Position
		away = Vector3.new(away.X, 0, away.Z)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
		Auto.status = "Bringing your car to the garage"
		local veh = vehicleNear(part.Position, part.Position + away * 14)
		if not veh then Auto.status = "Could not bring your car; opening anyway" end
	end
	if halted() then return false end
	placeNear(part.Position, 2.5)
	task.wait(0.4)
	if halted() then return false end
	firePrompt(prompt, function() return A.active or not (prompt.Parent and prompt.Enabled) end)
	local t0 = os.clock()
	while os.clock() - t0 < 10 do
		if A.active then Auto.joined += 1; return true end
		-- rejected by the lot filter during the countdown: it opened, move on
		if (Auto.leftAt or 0) > t0 then Auto.joined += 1; return true end
		task.wait(0.25)
	end
	Auto.blocked[key] = os.clock() + 120
	Auto.status = "Could not open " .. label .. ", skipping it for 2 min"
	return false
end

local function joinAuction()
	local c = garageCandidates()[1]
	if not c then Auto.status = "No garage matches your auction filters"; return false end
	local g = c.garage
	local label = tostring(g:GetAttribute("GarageId") or g.Name)
	Auto.status = string.format("Opening %s (%s, %s)", label, c.area, money(c.cost))
	return openGarage(g, c.key, label)
end

---------------------------------------------------------------------------
-- Airdrops (Military Airdrop event)
---------------------------------------------------------------------------
-- During the event a plane drops "Camo Airdrop" crates onto pads. Each crate
-- is a small auction lot (3 items, $2,000 entry) that needs $80M net worth and
-- disappears 10 minutes after landing. Crates carry the "MilitaryAirdrop"
-- tag and attributes AirdropState ("falling"/"landed") and AirdropExpiresAt.
-- (one table rather than ten locals: the main chunk is near Luau's 200-local limit)
local Air = {}
do
	local ok, cfg = pcall(require, Modules:FindFirstChild("MilitaryAirdropConfig"))
	Air.cfg = ok and type(cfg) == "table" and cfg or {}
	Air.TAG = Air.cfg.Tag or "MilitaryAirdrop"
	Air.GARAGE = Air.cfg.GarageId or "Camo Airdrop"
	local attrs = type(Air.cfg.Attributes) == "table" and Air.cfg.Attributes or {}
	Air.STATE = attrs.State or "AirdropState"
	Air.EXPIRES = attrs.ExpiresAt or "AirdropExpiresAt"
	local def = okGarages and type(GarageDefs) == "table" and GarageDefs[Air.GARAGE] or {}
	Air.MIN_WORTH = tonumber(def.MinNetWorth) or 0
	Air.FEE = type(def.EntryCost) == "table" and tonumber(def.EntryCost.Max or def.EntryCost.Min) or 0
end
local CollectionService = game:GetService("CollectionService")

local function airdropTimeLeft(inst)
	local expires = tonumber(inst:GetAttribute(Air.EXPIRES))
	return expires and (expires - workspace:GetServerTimeNow()) or nil
end

-- The garage you open for a crate: the tagged instance itself when it has a
-- Start Auction prompt, otherwise the nearest Camo Airdrop garage.
local function airdropGarage(inst)
	if inst:FindFirstChild("EnterAuction", true) then return inst end
	local root = workspace:FindFirstChild("_Debris") and workspace._Debris:FindFirstChild("Garages")
	local okPos, pivot = pcall(function() return inst:IsA("BasePart") and inst.CFrame or inst:GetPivot() end)
	local pos = okPos and pivot and pivot.Position
	local best, bestD
	for _, g in ipairs(root and root:GetChildren() or {}) do
		if g:GetAttribute("GarageId") == Air.GARAGE and pos then
			local d = (g:GetPivot().Position - pos).Magnitude
			if d < 80 and (not bestD or d < bestD) then best, bestD = g, d end
		end
	end
	return best
end

local function airdropSummary()
	local falling, landed, nearest = 0, 0, nil
	for _, inst in ipairs(CollectionService:GetTagged(Air.TAG)) do
		local state = inst:GetAttribute(Air.STATE)
		if state == "falling" then falling += 1
		elseif state == "landed" then
			landed += 1
			local left = airdropTimeLeft(inst)
			if left and (not nearest or left < nearest) then nearest = left end
		end
	end
	return falling, landed, nearest
end

local function airdropEligible()
	if netWorth() < Air.MIN_WORTH then
		return false, string.format("needs %s net worth, you have %s", money(Air.MIN_WORTH), money(netWorth()))
	end
	local cash = tonumber(LP:GetAttribute("Cash")) or 0
	if cash - Air.FEE < S.keepCash then return false, "not enough cash for the " .. money(Air.FEE) .. " entry" end
	return true
end

-- Picks the landed crate to open: not in an auction, not about to vanish, nearest first.
local function nextAirdrop()
	local _, hrp = getChar()
	local best, bestD
	for _, inst in ipairs(CollectionService:GetTagged(Air.TAG)) do
		local left = airdropTimeLeft(inst)
		local g = inst:GetAttribute(Air.STATE) == "landed" and (left or 0) > 25 and airdropGarage(inst)
		local key = g and ("airdrop:" .. (g:GetAttribute("GUID") or g:GetFullName()))
		if g and not g:GetAttribute("InAuction") and (Auto.blocked[key] or 0) < os.clock() then
			local d = hrp and (g:GetPivot().Position - hrp.Position).Magnitude or 0
			if not bestD or d < bestD then best, bestD = { garage = g, key = key }, d end
		end
	end
	return best
end

local function openAirdrop()
	local ok, why = airdropEligible()
	if not ok then Auto.status = "Airdrop landed, but opening " .. why; return false end
	local d = nextAirdrop()
	if not d then return false end
	Auto.status = "Opening an airdrop crate"
	return openGarage(d.garage, d.key, "airdrop crate")
end

---------------------------------------------------------------------------
-- After winning: open, repair, take
---------------------------------------------------------------------------

local function myWonModels()
	local folder = workspace:FindFirstChild("_Carryables")
	local list = {}
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		if m:IsA("Model") and m:GetAttribute("Owner") == LP.UserId and m:GetAttribute("ItemsWonGUID") ~= nil
			and m:GetAttribute("VehicleItemGUID") == nil then
			list[#list + 1] = m
		end
	end
	return list
end

local function promptPart(p)
	local part = p.Parent
	if part and part:IsA("Attachment") then part = part.Parent end
	return part and part:IsA("BasePart") and part or nil
end

local function openBoxes()
	local any = false
	for _, m in ipairs(myWonModels()) do
		if halted() then break end
		local prompt = m:FindFirstChild("OpenBoxPrompt", true)
		local part = prompt and prompt.Enabled and promptPart(prompt)
		if part then
			Auto.status = "Opening " .. m.Name
			placeNear(part.Position, 3)
			task.wait(0.2)
			firePrompt(prompt)
			local t0 = os.clock()
			repeat task.wait(0.1) until not prompt.Parent or not m.Parent or os.clock() - t0 > 2
			if not prompt.Parent or not m.Parent then Auto.opened += 1; any = true end
		end
	end
	if any then task.wait(0.6) end -- the contents replace the box
	return any
end

-- Rarity order from the game's own build-menu filter (Junk ... Mythical, Lost);
-- Common sits above Junk and the few Limited items rank highest.
local RARITY_RANK = { Junk = 1, Common = 2, Uncommon = 3, Rare = 4, Epic = 5, Legendary = 6, Mythical = 7, Lost = 8, Limited = 9 }

local function takeable()
	local list = {}
	local now = os.clock()
	for _, m in ipairs(myWonModels()) do
		local prompt = m:FindFirstChild("PickupPrompt", true)
		local part = prompt and prompt.Enabled and promptPart(prompt)
		local fail = prompt and Auto.pickFail[prompt]
		if part and not (fail and fail.untilT > now) then
			local entry = modelEntry(m)
			local value = entryValue(entry)
			local blue = isBlue(m)
			local mutated = false
			if #(S.takeMuts or {}) > 0 then
				local want = {}
				for _, n in ipairs(S.takeMuts) do want[n] = true end
				for _, mu in ipairs(entry.Mutators) do
					if type(mu) == "table" and want[mu.name] then mutated = true; break end
				end
			end
			local def = Items[tostring(entry.ItemId)]
			local named = false
			if def and #(S.takeNames or {}) > 0 then
				for _, n in ipairs(S.takeNames) do if n == def.Name then named = true; break end end
			end
			if (blue and S.takeBlue) or mutated or named or value >= S.minTake then
				list[#list + 1] = { model = m, prompt = prompt, part = part, value = value, blue = blue, entry = entry,
					rank = RARITY_RANK[def and def.Rarity or ""] or 0,
					weight = tonumber(m:GetAttribute("Weight")) or 0 }
			end
		end
	end
	-- highest rarity first, then most valuable, so a full truck keeps the best
	table.sort(list, function(a, b)
		if a.rank ~= b.rank then return a.rank > b.rank end
		return a.value > b.value
	end)
	return list
end

local function vehicleFull(items)
	if os.clock() - Auto.overweightAt < 45 then return true end
	local w, lim = cargoOf(myVehicle())
	if not lim or lim <= 0 then return false end
	if w >= lim - 0.05 then return true end
	if #items == 0 then return false end
	for _, it in ipairs(items) do
		if w + it.weight <= lim then return false end
	end
	return true
end

local function tryWrench(it)
	local def = Items[tostring(it.entry.ItemId)]
	local guid = it.model:GetAttribute("ItemsWonGUID")
	if not (S.autoRepair and Rm.RepairWonItem and guid) or Auto.repairTried[guid] then return end
	if not def or def.Consumable or def.NoRepair then return end
	if (tonumber(it.entry.Condition) or 100) >= 50 then return end
	Auto.repairTried[guid] = true
	local r = invoke(Rm.RepairWonItem, guid)
	if type(r) == "table" and r.success then Auto.repaired += 1 end
end

-- Items go straight into the truck when you take them, as long as the truck
-- is near the auction, so the truck stays put and only you step to each item.
local PICKUP_CAR_RANGE = 80
local function takeItems(items)
	local _, hrp = getChar()
	if not hrp or #items == 0 then return end
	local veh = myVehicle()
	if not (veh and (veh:GetPivot().Position - items[1].part.Position).Magnitude <= PICKUP_CAR_RANGE) then
		Auto.status = "Bringing your vehicle"
		placeNear(items[1].part.Position)
		task.wait(0.3)
		local err
		veh, err = vehicleNear(items[1].part.Position)
		if not veh then Auto.status = "Vehicle unavailable" .. (err and (": " .. tostring(err)) or ""); return end
	end
	for i, it in ipairs(items) do
		if halted() then return end
		if it.prompt.Parent and it.prompt.Enabled then
			local w, lim = cargoOf(veh)
			if not (lim and lim > 0 and w + it.weight > lim + 1e-3) then
				Auto.status = string.format("Taking %s%s (%d/%d)", it.model.Name, it.blue and " [outlined]" or "", i, #items)
				placeNear(it.part.Position)
				task.wait(0.2)
				tryWrench(it)
				firePrompt(it.prompt)
				local t0 = os.clock()
				repeat task.wait(0.1)
				until not it.prompt.Parent or not it.prompt.Enabled or not it.model:IsDescendantOf(workspace) or os.clock() - t0 > 2.5
				if it.prompt.Parent and it.prompt.Enabled and it.model:IsDescendantOf(workspace) then
					local f = Auto.pickFail[it.prompt] or { n = 0, untilT = 0 }
					f.n += 1
					f.untilT = f.n >= 2 and (os.clock() + 60) or 0
					Auto.pickFail[it.prompt] = f
				else
					Auto.picked += 1
					-- count real mutations (not condition flags like Dirty)
					local kinds = type(Mut._kindByName) == "table" and Mut._kindByName or {}
					for _, mu in ipairs(it.entry.Mutators or {}) do
						if type(mu) == "table" and mu.name and kinds[mu.name] ~= "flag" then Stats.mutated += 1; break end
					end
				end
				if os.clock() - Auto.overweightAt < 3 then Auto.status = "Vehicle is full"; break end
			end
		end
	end
end

-- Repair shop slots: start repairs on broken items, collect and claim done ones.
local function repairShopPass()
	local st = invoke(Rm.RepairSlots)
	if type(st) ~= "table" then return end
	local unlocked = tonumber(st.unlockedCount) or 1
	local used = {}
	local now = workspace:GetServerTimeNow()
	for k, s in pairs(type(st.slots) == "table" and st.slots or {}) do
		local i = tonumber(k)
		if i and type(s) == "table" then
			used[i] = true
			local done = s.Repaired == true
			if not done and now >= (tonumber(s.StartTime) or 0) + (tonumber(s.Duration) or 0) then
				local r = invoke(Rm.CollectRepair, i)
				done = type(r) == "table" and r.success == true
			end
			if done then
				local r = invoke(Rm.ClaimRepair, i)
				if type(r) == "table" and r.success then used[i] = nil; Auto.repaired += 1 end
			end
		end
	end
	local free = {}
	for i = 1, unlocked do if not used[i] then free[#free + 1] = i end end
	if #free == 0 then return end
	local rep = invoke(Rm.GetRepairable)
	local list = type(rep) == "table" and rep.items
	for _, it in ipairs(type(list) == "table" and list or {}) do
		local slot = table.remove(free, 1)
		if not slot then break end
		local r = invoke(Rm.StartRepair, slot, it.guid, it.source, it.vehicleGUID)
		if not (type(r) == "table" and r.success) then break end
	end
end

---------------------------------------------------------------------------
-- Favorites
---------------------------------------------------------------------------

-- Gear: wearable/bonus items. The game shows rolled bonus stats for exactly
-- these (UIConfig item tooltip): Accessories (head/back/wrist wearables),
-- car parts, hoverboards, horses, dragons and pickaxes.
local BONUS_INTERACTIVE = { Hoverboard = true, Horse = true, Dragon = true, Pickaxe = true }
local function isGear(def, entry)
	if type(def) ~= "table" then return false end
	if def.Category == "Accessories" or def.CarPart or BONUS_INTERACTIVE[def.Interactive or ""] then return true end
	local rolled = type(entry) == "table" and entry.RolledAttributes
	return type(rolled) == "table" and next(rolled) ~= nil
end

-- Tools and consumables: usable items (rods, pans, watering cans, guns,
-- drinks, cleaning sprays, seeds...).
local TOOL_FIELDS = { "Interactive", "EnergyDrinkId", "MaxCleanUses", "MaxDigUses", "MaxPanUses", "MaxReelUses", "MaxWaterUses", "Consumable" }
local function isTool(def)
	if type(def) ~= "table" then return false end
	for _, field in ipairs(TOOL_FIELDS) do
		if def[field] then return true end
	end
	return false
end

-- Keep rules. An item is kept (favorited) when any of these is true:
--   gear worth at least the gear minimum (0 = price rule off)
--   gear with ANY of the picked gear mutations
--   a Gavel trophy (when on), optionally only with ANY picked gavel mutation
--   a named "always keep" item
local function isGavel(def)
	return type(def.Name) == "string" and def.Name:find("Gavel", 1, true) ~= nil
end

local function keepSets()
	local function set(list)
		local s = {}
		for _, n in ipairs(list or {}) do s[n] = true end
		return s
	end
	return { item = set(S.favItems), gearMut = set(S.favGearMuts), gavelMut = set(S.favGavelMuts) }
end

local function hasAnyMutation(e, wanted)
	if next(wanted) == nil or type(e.Mutators) ~= "table" then return false end
	for _, m in ipairs(e.Mutators) do
		if type(m) == "table" and wanted[m.name] then return true end
	end
	return false
end

local function keepRulesActive()
	return (S.favGearMin or 0) > 0 or #(S.favGearMuts or {}) > 0 or S.favGavel or #(S.favItems or {}) > 0
end

local function matchesKeepRule(def, e, sets)
	-- Gavels follow only the Gavel rule, so its mutation filter cannot be
	-- bypassed by "Always keep" or the gear rules.
	if isGavel(def) then
		if not S.favGavel then return false end
		-- A gavel's mutations carry a luck value (0.35 = the 35% shown on the
		-- gavel). Keep it when one picked mutation (or any, if none are picked)
		-- is at least the minimum %.
		local minPct = tonumber(S.favGavelPct) or 0
		if next(sets.gavelMut) == nil and minPct <= 0 then return true end
		for _, m in ipairs(type(e.Mutators) == "table" and e.Mutators or {}) do
			if type(m) == "table" and m.name and (next(sets.gavelMut) == nil or sets.gavelMut[m.name]) then
				if minPct <= 0 or (tonumber(m.luck) or 0) * 100 >= minPct then return true end
			end
		end
		return false
	end
	if sets.item[def.Name] then return true end
	if isGear(def, e) then
		if S.favGearMin > 0 and entryValue(e) >= S.favGearMin then return true end
		if hasAnyMutation(e, sets.gearMut) then return true end
	end
	if S.favGavel and isGavel(def) then
		if next(sets.gavelMut) == nil or hasAnyMutation(e, sets.gavelMut) then return true end
	end
	return false
end

local function keepRulesText()
	local parts = {}
	if S.favGearMin > 0 then parts[#parts + 1] = "gear worth " .. money(S.favGearMin) .. "+" end
	if #(S.favGearMuts or {}) > 0 then parts[#parts + 1] = "gear with " .. table.concat(S.favGearMuts, " or ") end
	if S.favGavel then
		local pct = tonumber(S.favGavelPct) or 0
		local which = #(S.favGavelMuts or {}) > 0 and table.concat(S.favGavelMuts, " or ") or (pct > 0 and "any mutation" or nil)
		parts[#parts + 1] = which and ("gavels with " .. which .. (pct > 0 and (" at " .. pct .. "%+") or "")) or "all gavels"
	end
	if #(S.favItems or {}) > 0 then parts[#parts + 1] = #S.favItems .. " always-keep item(s)" end
	return #parts > 0 and table.concat(parts, ", ") or "No keep rules set"
end

local function keepSummary()
	if not S.autoFav then return "Auto favorite is off (rules still block selling)" end
	return "Keeps: " .. keepRulesText()
end

-- True when an inventory entry should never leave: already favorited, or it
-- matches a keep rule. Keep rules protect from listing even when auto
-- favorite is off or has not reached the item yet.
local function isKept(e)
	if type(e) ~= "table" then return true end
	if e.Favorited == true then return true end
	-- safes wait for "Open safes" instead of going on a shelf
	local d = Items[tostring(e.ItemId)]
	if S.autoSafe and d and d.SafeId then return true end
	if not keepRulesActive() then return false end
	local def = Items[tostring(e.ItemId)]
	if not def then return false end
	return matchesKeepRule(def, e, keepSets())
end

-- ToggleFavoriteItem is a toggle, so calling it on an item that is already a
-- favorite would REMOVE the favorite. To make that impossible this pass only
-- ever turns favorites on: it re-reads the inventory right before each call,
-- skips anything already favorited (for stacks, if any copy is), checks the
-- result with a fresh read, and never sends a second, corrective toggle.
local favFailUntil = {}
local function favoritePass()
	if not keepRulesActive() then return end
	local inv = invoke(Rm.GetInventory)
	if type(inv) ~= "table" then return end
	local sets = keepSets()
	local now = os.clock()
	local todo, seenStack = {}, {}
	for guid, e in pairs(inv) do
		local def = type(e) == "table" and Items[tostring(e.ItemId)]
		if def and e.Favorited ~= true and (favFailUntil[guid] or 0) < now and matchesKeepRule(def, e, sets) then
			local stackKey = def.Stackable and tostring(e.ItemId) or nil
			if not (stackKey and seenStack[stackKey]) then
				if stackKey then seenStack[stackKey] = true end
				todo[#todo + 1] = { guid = guid, stackKey = stackKey }
			end
		end
	end
	local function safeToFavorite(fresh, job)
		local e = fresh[job.guid]
		if type(e) ~= "table" or e.Favorited == true then return false end
		if job.stackKey then
			for _, other in pairs(fresh) do
				if type(other) == "table" and tostring(other.ItemId) == job.stackKey and other.Favorited == true then return false end
			end
		end
		return true
	end
	for _, job in ipairs(todo) do
		if halted() then return end
		local fresh = invoke(Rm.GetInventory)
		if type(fresh) ~= "table" then return end
		if safeToFavorite(fresh, job) then
			invoke(Rm.ToggleFavorite, job.guid)
			task.wait(0.3)
			local after = invoke(Rm.GetInventory)
			local e = type(after) == "table" and after[job.guid]
			if type(e) == "table" and e.Favorited == true then
				Auto.favorited += 1
			else
				-- not confirmed: leave it alone for a while rather than toggle again
				favFailUntil[job.guid] = os.clock() + 300
				Auto.favNote = "Could not confirm a favorite; will retry in 5 min"
			end
		end
		task.wait(0.15)
	end
end

---------------------------------------------------------------------------
-- Safes and vaults
---------------------------------------------------------------------------
-- Lockpick (fast): StartPicklockSession("Inventory", guid) -> sessionId; the
-- skill check (3 pin hits) only runs on your screen; the hub waits as long as
-- a real attempt takes, then PicklockInventorySafe(guid, sessionId).
-- Locksmith (no minigame, timed): for safes your pick tier cannot open.
local Safe = { note = nil, failUntil = {} }
do
	local okP, Picklock = pcall(require, Modules:FindFirstChild("Picklock"))
	local okS, SafeDefs = pcall(require, Modules:FindFirstChild("Safes"))
	Safe.Picklock = okP and Picklock or nil
	Safe.Defs = okS and type(SafeDefs) == "table" and SafeDefs or {}
end

-- The pick you have equipped (from the Lockpick shop), or nil.
function Safe.tool()
	local st = invoke(Rm.LockpickState)
	return type(st) == "table" and st.equipped or nil
end

function Safe.canPick(toolId, safeDef)
	if not (toolId and Safe.Picklock and safeDef) then return false end
	local ok, can = pcall(Safe.Picklock.CanOpenSafeTier, toolId, tonumber(safeDef.MinPickTier) or 0)
	return ok and can == true
end

-- Collects finished Locksmith slots and returns the free slot numbers.
function Safe.locksmithSlots()
	local st = invoke(Rm.LocksmithSlots)
	if type(st) ~= "table" then return {} end
	local used, free = {}, {}
	local now = workspace:GetServerTimeNow()
	for k, s in pairs(type(st.slots) == "table" and st.slots or {}) do
		local i = tonumber(k)
		if i and type(s) == "table" and s.ItemGUID then
			used[i] = true
			if now >= (tonumber(s.StartTime) or 0) + (tonumber(s.Duration) or 0) then
				local opened = invoke(Rm.LocksmithOpen, i)
				if type(opened) == "table" and opened.success then
					local claimed = invoke(Rm.LocksmithClaim, i)
					if type(claimed) == "table" and claimed.success ~= false then
						used[i] = nil
						Stats.safes += 1
					end
				end
			end
		end
	end
	for i = 1, tonumber(st.unlockedCount) or 1 do if not used[i] then free[#free + 1] = i end end
	return free
end

function Safe.pass()
	if halted() then return end
	local inv = invoke(Rm.GetInventory)
	if type(inv) ~= "table" then return end
	local todo = {}
	for guid, e in pairs(inv) do
		local def = type(e) == "table" and Items[tostring(e.ItemId)]
		if def and def.SafeId and e.Favorited ~= true and (Safe.failUntil[guid] or 0) < os.clock() then
			todo[#todo + 1] = { guid = guid, name = def.Name, safe = Safe.Defs[def.SafeId] or Safe.Defs[tonumber(def.SafeId)] }
		end
	end
	local free = Safe.locksmithSlots()
	if #todo == 0 then Safe.note = "No safes waiting"; return end
	local tool = Safe.tool()
	-- Sends a safe to a free Locksmith slot; true if it was accepted.
	local function toLocksmith(job, why)
		if not S.safeLocksmith then return false end
		if #free == 0 then
			Safe.note = job.name .. ": " .. why .. ", waiting for a free Locksmith slot"
			return false
		end
		local slot = table.remove(free, 1)
		local r = invoke(Rm.LocksmithStart, slot, job.guid, "Inventory", nil)
		if type(r) == "table" and r.success then
			Safe.note = job.name .. " sent to the Locksmith (" .. why .. ")"
			return true
		end
		table.insert(free, 1, slot)
		Safe.note = "Locksmith: " .. tostring(type(r) == "table" and r.error or "refused")
		return false
	end
	for _, job in ipairs(todo) do
		if halted() then return end
		local picked, why = false, nil
		if Safe.canPick(tool, job.safe) then
			Safe.note = "Picking " .. job.name
			local session = invoke(Rm.PickSession, "Inventory", job.guid)
			if type(session) == "table" and session.success and session.sessionId then
				task.wait(4 + math.random() * 3) -- as long as the skill check takes a player
				if halted() then return end
				local result = invoke(Rm.PickInventorySafe, job.guid, session.sessionId)
				if type(result) == "table" and result.success then
					picked = true
					Stats.safes += 1
					if type(result.rewardMutators) == "table" and #result.rewardMutators > 0 then Stats.mutated += 1 end
					Safe.note = "Unlocked " .. job.name
				else
					why = "lockpick failed: " .. tostring(type(result) == "table" and result.error or "not opened")
				end
			else
				why = "lockpick could not start: " .. tostring(type(session) == "table" and session.error or "no reply")
			end
			task.wait(0.5)
		else
			why = "lockpick tier too low"
		end
		-- whatever the lockpick could not do goes to the Locksmith
		if not picked and not toLocksmith(job, why) then
			Safe.failUntil[job.guid] = os.clock() + 120
			if not S.safeLocksmith then Safe.note = job.name .. ": " .. why end
		end
	end
end

---------------------------------------------------------------------------
-- Plot: unload vehicle, fill shelves
---------------------------------------------------------------------------

local function plotData()
	if Auto.plot and os.clock() - Auto.plotAt < 120 then return Auto.plot end
	local d = invoke(Rm.RequestPlotData)
	if not (type(d) == "table" and tonumber(d.OriginX)) then d = nil end
	Auto.plot, Auto.plotAt = d, os.clock()
	return d
end

local function plotBase()
	local d = plotData()
	if not d then return nil end
	return CFrame.new(d.OriginX, d.OriginY, d.OriginZ) * CFrame.Angles(0, math.rad(tonumber(d.RotationY) or 0), 0)
end

local function cargoPct()
	local w, lim = cargoOf(myVehicle())
	if not lim or lim <= 0 then return 0 end
	return w / lim * 100
end

-- The game unloads when you sit in your own vehicle within 14 studs of the
-- plot origin offset by (0, 0, -100) (Screens.UnloadVehicle.isInUnpackZone).
local function unpackPoint()
	local base = plotBase()
	if not base then return nil end
	return base:PointToWorldSpace(Vector3.new(0, 0, -100)), base
end
local function inUnpackZone(pt)
	local _, hrp = getChar()
	if not hrp then return false end
	local dx, dz = hrp.Position.X - pt.X, hrp.Position.Z - pt.Z
	return dx * dx + dz * dz <= 150
end

local function vehicleItemCount()
	local items = invoke(Rm.GetVehicleItems, LP:GetAttribute("EquippedVehicle"))
	local count = 0
	for _ in pairs(type(items) == "table" and items or {}) do count += 1 end
	return count, type(items) == "table" and items or {}
end

-- One unload round. "done" means auctions may resume; "wait" means stay paused.
-- Unloading moves items into the inventory, so it is limited by free slots;
-- shelf sales free more slots over time. force = unload now, ignoring cargo levels.
local function dumpStep(force)
	if halted() then return "done" end
	local veh = myVehicle()
	if not veh then Auto.status = "Unload: no vehicle spawned"; return "done" end
	local count, items = vehicleItemCount()
	local pct = cargoPct()
	if count == 0 then Auto.status = "Unload: vehicle is empty"; return "done" end
	if not force and pct < S.dumpAt - 30 and os.clock() - Auto.overweightAt > 45 then return "done" end
	local free = (tonumber(LP:GetAttribute("InventoryCap")) or math.huge) - (tonumber(LP:GetAttribute("InventoryCount")) or 0)
	if free <= 0 then
		Auto.status = string.format("Unload: inventory full (cargo %d%%), waiting for shelf sales", math.floor(pct))
		return "wait"
	end
	local list = {}
	for g, e in pairs(items) do list[#list + 1] = { guid = g, v = type(e) == "table" and entryValue(e) or 0 } end
	table.sort(list, function(a, b) return a.v > b.v end)
	local guids = {}
	for i = 1, math.min(free, #list) do guids[i] = list[i].guid end

	-- First try unloading where the car is. If the server accepts that, the
	-- car never has to drive to the plot; if not, remember and drive instead.
	if S.unloadAnywhere and Auto.remoteUnload ~= false then
		local ok, after = runItems("unload", function()
			Rm.Unload:FireServer(guids)
			task.wait(1.5)
			return vehicleItemCount()
		end)
		if not ok or type(after) ~= "number" then after = count end
		if after < count then
			Auto.remoteUnload = true
			Auto.overweightAt = 0
			Auto.lastFav, Auto.lastList = 0, 0 -- favorite the new items right away, then list
			Auto.status = string.format("Unloaded %d item(s) without moving; cargo %d%%", count - after, math.floor(cargoPct()))
			return "wait"
		end
		Auto.remoteUnload = false
		Auto.status = "The server wants the car at your plot; driving there"
	end

	local pt, base = unpackPoint()
	if not pt then Auto.status = "Unload: plot not found"; return "done" end
	if not (seatedIn(veh) and inUnpackZone(pt)) then
		-- stand on the unload spot, spawn the car there (V), then sit in it:
		-- the game counts you as in the zone only while seated
		Auto.status = "Bringing your car to the plot's unload spot"
		streamAround(pt)
		placeNear(pt, 0.5)
		task.wait(0.3)
		local spawned, why = spawnCarHere()
		veh = spawned or veh
		if not (spawned and enterVehicle(veh)) then
			Auto.status = "Unload: could not get the car there" .. (why and (" (" .. tostring(why) .. ")") or "")
			return "wait"
		end
		local _, hrp = getChar()
		if hrp then
			-- the zone checks the character, so centre the seat on it
			local delta = Vector3.new(pt.X - hrp.Position.X, 0, pt.Z - hrp.Position.Z)
			if delta.Magnitude > 2 then veh:PivotTo(veh:GetPivot() + delta); stillModel(veh) end
		end
		task.wait(1.2)
	end
	runItems("unload", function()
		Rm.Unload:FireServer(guids)
		task.wait(1.5)
	end)
	Auto.overweightAt = 0
	Auto.lastFav, Auto.lastList = 0, 0 -- favorite the new items right away, then list
	Auto.status = string.format("Unloaded %d item(s) at your plot; cargo %d%%", #guids, math.floor(cargoPct()))
	return "wait"
end

local function listPass()
	if not Rm.ShelfAutoStock or halted() then return end
	local p = invoke(Rm.ShelfAutoStock, "preview")
	if type(p) ~= "table" then return end
	if not p.Ok then Auto.listNote = "Shelves: " .. tostring(p.Error or "unavailable"); return end
	local room = math.min(tonumber(p.FreeSlots) or 0, tonumber(p.SpaceLeft) or 0)
	Auto.listNote = string.format("Shelves: %d free", room)
	if room > 0 then
		local inv = invoke(Rm.GetInventory) or {}
		local list = {}
		for guid in pairs(type(p.Fits) == "table" and p.Fits or {}) do
			local e = inv[guid]
			-- the server lists favorites if asked, so filter here: never list a
			-- favorite or anything a keep rule covers (e.g. a Gavel not yet favorited)
			if type(e) == "table" and not isKept(e) then
				local v = entryValue(e)
				if v >= S.listMin and (S.listMax <= 0 or v <= S.listMax) then list[#list + 1] = { guid = guid, v = v } end
			end
		end
		table.sort(list, function(a, b) return a.v > b.v end)
		local guids = {}
		for i = 1, math.min(room, #list) do guids[i] = list[i].guid end
		if #guids == 0 then
			Auto.listNote = string.format("Shelves: %d free, nothing in your inventory fits or qualifies", room)
		else
			local r = invoke(Rm.ShelfAutoStock, "apply", guids)
			if type(r) == "table" and r.Ok then
				Auto.listed += tonumber(r.Placed) or 0
			elseif type(r) == "table" then
				Auto.listNote = "Shelves: " .. tostring(r.Error or "rejected")
			end
		end
	end
end

---------------------------------------------------------------------------
-- Teleport targets
---------------------------------------------------------------------------

local function posOf(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local ok, cf = pcall(inst.GetPivot, inst)
		if ok then return cf.Position end
	end
	local p = inst:FindFirstChildWhichIsA("BasePart", true)
	return p and p.Position
end

local places = {}
local function addPlace(label, getter) places[label] = getter end
do
	local areas = workspace:FindFirstChild("Areas")
	for _, a in ipairs(areas and areas:GetChildren() or {}) do
		addPlace("Area: " .. a.Name, function()
			for _, c in ipairs(a:GetChildren()) do
				if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then return posOf(c) end
			end
			local box = a:FindFirstChild("Lost and Found Box")
			return box and posOf(box) or posOf(a)
		end)
	end
	local shops = workspace:FindFirstChild("Shops")
	for _, s in ipairs(shops and shops:GetChildren() or {}) do
		addPlace("Shop: " .. s.Name:gsub("%s+$", ""), function() return posOf(s) end)
	end
	addPlace("My plot", function()
		local base = plotBase()
		return base and base:PointToWorldSpace(Vector3.new(0, 0, -20))
	end)
end
local placeNames = {}
for name in pairs(places) do placeNames[#placeNames + 1] = name end
table.sort(placeNames)

-- NPC shops open their screen through the game's UIController; doing the
-- same opens a shop from anywhere without walking to the NPC.
local shopScreens, shopNames = {}, {}
do
	local npcs = workspace:FindFirstChild("Mall - Shop NPCs")
	for _, n in ipairs(npcs and npcs:GetChildren() or {}) do
		local prompt = n:FindFirstChild("ShopPrompt", true)
		local screen = prompt and prompt:GetAttribute("ScreenName")
		if type(screen) == "string" then
			local label = n.Name .. " (" .. prompt.ActionText .. ")"
			shopScreens[label] = { screen = screen, arg = prompt:GetAttribute("ScreenArg") }
			shopNames[#shopNames + 1] = label
		end
	end
	table.sort(shopNames)
end
local function openShop(label)
	local s = shopScreens[label]
	if not s then return false, "pick a shop first" end
	local ok, controller = pcall(require, Modules:FindFirstChild("UIController"))
	if not ok then return false, "UI controller unavailable" end
	local opened, err = pcall(controller.Open, controller, s.screen, s.arg)
	return opened, err
end

local areaNames = {}
do
	local seen = {}
	local root = workspace:FindFirstChild("_Debris") and workspace._Debris:FindFirstChild("Garages")
	for _, g in ipairs(root and root:GetChildren() or {}) do
		local a = g:GetAttribute("AreaName")
		if type(a) == "string" and not seen[a] and (g:GetAttribute("EntryCurrency") or "Cash") == "Cash" then
			seen[a] = true
			areaNames[#areaNames + 1] = a
		end
	end
	table.sort(areaNames)
end

local mutationNames = {}
do
	local kinds = type(Mut._kindByName) == "table" and Mut._kindByName or {}
	for name in pairs(kinds) do mutationNames[#mutationNames + 1] = name end
	table.sort(mutationNames)
end

local itemNames = {}
for name in pairs(nameToId) do itemNames[#itemNames + 1] = name end
table.sort(itemNames)

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

-- Item reveal ESP: runs the Auction Reveal script without its own window.
local REVEAL_PATH = "UAI/scripts/auction_reveal.lua"
local function revealApi()
	local R = env.UAIAuctionReveal
	return (R and type(R.garageSummary) == "function") and R or nil
end
local function applyEsp()
	local R = revealApi()
	if R and R.settings then
		R.settings.distance = S.espDistance
		R.settings.minConf = S.espMinConf
		R.repaint()
	end
end
local function setEsp(on)
	if not on then
		local R = env.UAIAuctionReveal
		if R and R.headless and R.stop then pcall(R.stop) end
		return
	end
	if revealApi() then applyEsp(); return end -- already running
	local ok, src = pcall(readfile, REVEAL_PATH)
	if not ok or type(src) ~= "string" then Auto.status = "Item reveal script not found at " .. REVEAL_PATH; return end
	local fn, err = loadstring(src, "@auction_reveal")
	if not fn then Auto.status = "Item reveal failed to load: " .. tostring(err); return end
	task.spawn(function()
		env.UAIAuctionRevealOptions = { headless = true }
		local okRun, runErr = pcall(fn)
		env.UAIAuctionRevealOptions = nil
		if not okRun then Auto.status = "Item reveal error: " .. tostring(runErr) else applyEsp() end
	end)
end

local ui = Kit.Window({ Title = "Storage Hunters", Credit = "by conradium · commissioned by rsl", Width = 390, Height = 600, OnClose = function() Hub.stop() end })
ui.values = S
S.keybinds = type(saved.keybinds) == "table" and saved.keybinds or {}
ui.onChange = function(id, value)
	queueSave()
	if id == "shopBar" then if Hub.quickBar then Hub.quickBar.Visible = value end
	elseif id == "eventTimers" then if Hub.timers and Hub.timers.panel then Hub.timers.panel:SetVisible(value) end
	elseif id == "instantPrompts" then if not value and Hub.restorePrompts then Hub.restorePrompts() end
	elseif id == "adminGuard" or id == "adminExtra" then if Hub.checkStaff then task.spawn(Hub.checkStaff) end
	elseif id == "theme" or id == "customBg" or id == "customAccent" or id == "customText" then
		if Hub.applyTheme then Hub.applyTheme() end
	elseif id == "esp" then setEsp(value)
	elseif id == "espDistance" or id == "espMinConf" then applyEsp() end
end

---------------------------------------------------------------------------
-- Lost items: glowing items around the map that only you can see
-- (workspace._LostItems, LostOwnerId = you). Each has an "Add to Vehicle"
-- prompt that works only with your car close by (about 30 studs; the server
-- says "Your vehicle is too far away" otherwise). A collected item is renamed
-- TossActor_* while it flies into the car, then removed.
---------------------------------------------------------------------------
local Lost = { running = false, stop = false, note = nil, msg = nil, CAR_RANGE = 26, trace = {}, added = 0 }
function Lost.items()
	local folder = workspace:FindFirstChild("_LostItems")
	local out = {}
	if not folder then return out end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("LostOwnerId") == LP.UserId and not m.Name:find("^TossActor_") then
			local base = m:FindFirstChild("Base")
			local prompt = base and base:FindFirstChild("PickupPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then out[#out + 1] = { model = m, base = base, prompt = prompt } end
		end
	end
	return out
end
function Lost.taken(it)
	local m = it.model
	return m.Parent == nil or m.Name:find("^TossActor_") ~= nil or it.prompt.Parent == nil
end
-- Collects every lost item, nearest first. Runs under the body lock.
-- Returns how many were picked up and why it stopped early (nil if it finished).
function Lost.pass()
	local skip, why = {}, nil
	local startAdded = Lost.added
	local function got() return Lost.added - startAdded end
	while true do
		if halted() then why = "paused"; break end
		if Lost.stop then why = "stopped"; break end
		local _, hrp = getChar()
		if not hrp then why = "no character"; break end
		local best, bestD
		for _, it in ipairs(Lost.items()) do
			if not skip[it.model] then
				local d = (it.base.Position - hrp.Position).Magnitude
				if not bestD or d < bestD then best, bestD = it, d end
			end
		end
		if not best then break end
		local veh = myVehicle()
		local w, lim = cargoOf(veh)
		if lim and lim > 0 and w >= lim - 0.5 then why = "your car is full"; break end
		local pos = best.base.Position
		Lost.note = string.format("Getting %s (%d picked)", best.model.Name, got())
		Auto.status = "Lost items: " .. Lost.note
		if not veh or (veh:GetPivot().Position - pos).Magnitude > Lost.CAR_RANGE then
			tpTo(pos)
			veh = nil
			local err
			-- the server's spawn cooldown is longer than the V key's (~10 s): retry
			local t0 = os.clock()
			repeat
				if halted() or Lost.stop then break end
				placeNear(pos, 7)
				task.wait(0.2)
				local v
				v, err = spawnCarHere()
				exitVehicle() -- spawning seats you in the car
				if v and (v:GetPivot().Position - pos).Magnitude <= Lost.CAR_RANGE + 10 then veh = v; break end
				task.wait(1.5)
			until os.clock() - t0 > 14
			if not veh then
				if halted() or Lost.stop then why = Lost.stop and "stopped" or "paused"; break end
				why = "could not bring your car" .. (err and (": " .. tostring(err)) or ""); break
			end
		end
		if halted() or Lost.stop then why = Lost.stop and "stopped" or "paused"; break end
		placeNear(pos, 3)
		task.wait(0.25)
		Lost.msg = nil
		local before = Lost.added
		local function done() return Lost.taken(best) or Lost.added > before end
		firePrompt(best.prompt, done)
		local t0 = os.clock()
		while not done() and not Lost.msg and os.clock() - t0 < 4 do task.wait(0.1) end
		if not done() and not Lost.msg then
			-- the server's notice can trail the prompt a little
			t0 = os.clock()
			while not done() and os.clock() - t0 < 1.5 do task.wait(0.1) end
		end
		local trace = Lost.trace
		trace[#trace + 1] = string.format("%s: taken=%s added=%d msg=%s", best.model.Name,
			tostring(Lost.taken(best)), Lost.added - before, tostring(Lost.msg))
		if #trace > 40 then table.remove(trace, 1) end
		if done() then
			Auto.picked += 1
		else
			local msg = Lost.msg and Lost.msg:lower() or ""
			if msg:find("full") or msg:find("space") or msg:find("weight") or msg:find("capacity") then
				why = Lost.msg; break
			end
			skip[best.model] = true -- try the others; this one is left for later
		end
	end
	Lost.msg = nil
	return got(), why
end
-- The button: starts collecting, or stops a run in progress.
function Lost.collect()
	if Lost.running then
		Lost.stop = true
		ui:SetStatus("Stopping after this item", "busy")
		return
	end
	if A.active then ui:SetStatus("Finish or leave the auction first", "busy"); return end
	local total = #Lost.items()
	if total == 0 then ui:SetStatus("No lost items on the map right now", "ok"); return end
	if not myVehicle() and not LP:GetAttribute("EquippedVehicle") then ui:SetStatus("Equip a vehicle first", "busy"); return end
	Lost.running, Lost.stop = true, false
	if Locks.body.owner then ui:SetStatus("Lost items queued after " .. Locks.body.owner, "busy") end
	local ok, got, why = runBody("lost items", Lost.pass)
	Lost.running, Lost.stop = false, false
	if not ok then
		Lost.note = "Error: " .. tostring(got)
	else
		local left = #Lost.items()
		Lost.note = string.format("Picked up %d%s", got or 0, left > 0 and string.format(", %d left", left) or ", all done")
		if why then Lost.note = Lost.note .. " (" .. why .. ")" end
	end
	Auto.status = "Lost items: " .. Lost.note
	ui:SetStatus(Auto.status, ok and "ok" or "busy")
end
Hub.lost = Lost -- test hook, like Hub.wouldKeep

---------------------------------------------------------------------------
-- Mining (The Mines). With a pickaxe in hand, the node's Mine prompt starts
-- a session (it then reads "Stop Mining"; pressing again stops). The server
-- pays a jewel every RewardSeconds / (1 + speed/100) while you stay within
-- MineRange, until your inventory is full (MiningState.Stalled = "full").
-- Each node needs a minimum net worth (MiningConfig.Nodes).
---------------------------------------------------------------------------
local Mine = { state = {}, rewards = 0, note = nil, lastTry = 0, starting = false, msg = nil }
do
	local ok, cfg = pcall(require, Modules:FindFirstChild("MiningConfig"))
	Mine.cfg = ok and type(cfg) == "table" and cfg or {}
end
function Mine.nodesFolder()
	local areas = workspace:FindFirstChild("Areas")
	local area = areas and areas:FindFirstChild(Mine.cfg.AreaName or "The Mines")
	return area and area:FindFirstChild(Mine.cfg.NodesFolderName or "RockNodes")
end
function Mine.minWorth(i)
	local n = type(Mine.cfg.Nodes) == "table" and Mine.cfg.Nodes[i]
	return n and tonumber(n.MinNetWorth) or math.huge
end
-- Active when the server said so, or when a node's prompt reads "Stop Mining"
-- (the game relabels it; this also covers a session started before the hub).
function Mine.activeNode()
	if Mine.state.Active then return tonumber(Mine.state.Node) end
	local folder = Mine.nodesFolder()
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		local p = m:FindFirstChild("MinePrompt", true)
		if p and p:IsA("ProximityPrompt") and p.ActionText == "Stop Mining" then return tonumber(m:GetAttribute("NodeIndex") or m.Name) end
	end
	return nil
end
-- The node to mine: the one picked, or the best your net worth allows.
-- The node models (and their positions) are always there; their parts and
-- prompt only stream in near The Mines, so the prompt is looked up on arrival.
function Mine.target()
	local folder = Mine.nodesFolder()
	if not folder then return nil, "The Mines are not loaded; go there first" end
	local worth = netWorth()
	local want = tonumber(tostring(S.mineNode or ""):match("(%d+)"))
	local best
	for _, m in ipairs(folder:GetChildren()) do
		local i = tonumber(m:GetAttribute("NodeIndex") or m.Name)
		if i and m:IsA("Model") then
			if want then
				if i == want then
					if worth < Mine.minWorth(i) then return nil, string.format("Node %d needs %s net worth, you have %s", i, money(Mine.minWorth(i)), money(worth)) end
					return { index = i, model = m }
				end
			elseif worth >= Mine.minWorth(i) and (not best or i > best.index) then
				best = { index = i, model = m }
			end
		end
	end
	if want then return nil, "Node " .. want .. " was not found" end
	if not best then return nil, string.format("Node 1 needs %s net worth, you have %s", money(Mine.minWorth(1)), money(worth)) end
	return best
end
function Mine.promptOf(model)
	local p = model and model:FindFirstChild("MinePrompt", true)
	return p and p:IsA("ProximityPrompt") and p or nil
end
-- Your best pickaxe (by the config's speed range), and whether it is in hand.
function Mine.pickaxe()
	local picks = type(Mine.cfg.Pickaxes) == "table" and Mine.cfg.Pickaxes or {}
	local function score(t)
		if not t:IsA("Tool") then return nil end
		local p = picks[tostring(t:GetAttribute("ItemId") or "")]
		return p and (tonumber(p.MiningSpeed and p.MiningSpeed.max) or 0) or nil
	end
	local char = LP.Character
	local held = char and char:FindFirstChildOfClass("Tool")
	if held and score(held) then return held, true end
	local best, bs
	for _, t in ipairs(LP:FindFirstChildOfClass("Backpack") and LP.Backpack:GetChildren() or {}) do
		local s = score(t)
		if s and (not bs or s > bs) then best, bs = t, s end
	end
	return best, false
end
function Mine.equip()
	local tool, held = Mine.pickaxe()
	if not tool then return false end
	if held then return true end
	local _, _, hum = getChar()
	if not hum then return false end
	pcall(hum.EquipTool, hum, tool)
	local t0 = os.clock()
	repeat task.wait(0.1) until tool.Parent == LP.Character or os.clock() - t0 > 1.5
	return tool.Parent == LP.Character
end
function Mine.anchor(prompt)
	local a = prompt.Parent
	if a and a:IsA("Attachment") then return a.WorldPosition end
	if a and a:IsA("BasePart") then return a.Position end
	return nil
end
-- Starts mining (runs under the body lock). The prompt toggles, so it is
-- pressed once and only pressed again if nothing changed (never twice in a row).
function Mine.start()
	if halted() or Mine.activeNode() then return end
	local t, why = Mine.target()
	if not t then Mine.note = why; return end
	if not Mine.pickaxe() then Mine.note = "No pickaxe in your backpack"; return end
	local _, hrp = getChar()
	if not hrp then return end
	local p = Mine.promptOf(t.model)
	if not p then
		-- far away: go to the node so its prompt streams in
		Mine.note = "Going to Rock Node " .. t.index
		exitVehicle()
		tpTo(t.model:GetPivot().Position)
		local t0 = os.clock()
		repeat task.wait(0.2); p = Mine.promptOf(t.model) until p or os.clock() - t0 > 6
		if not p then Mine.note = "Rock Node " .. t.index .. " did not load"; return end
	end
	local pos = Mine.anchor(p)
	if not pos then Mine.note = "Rock Node " .. t.index .. " has no prompt"; return end
	if (hrp.Position - pos).Magnitude > 6 then
		exitVehicle()
		placeNear(pos, 4)
		task.wait(0.3)
	end
	if halted() then return end
	if not Mine.equip() then Mine.note = "No pickaxe in your backpack"; return end
	Mine.note = "Starting Rock Node " .. t.index
	Mine.starting, Mine.msg = true, nil
	if p.HoldDuration > 0 then p.HoldDuration = 0 end
	pcall(function() p:InputHoldBegin(); task.wait(0.05); p:InputHoldEnd() end)
	local t0 = os.clock()
	while not Mine.activeNode() and not Mine.msg and os.clock() - t0 < 2.5 do task.wait(0.1) end
	if not Mine.activeNode() and not Mine.msg and type(fireproximityprompt) == "function" then
		pcall(fireproximityprompt, p)
		t0 = os.clock()
		while not Mine.activeNode() and not Mine.msg and os.clock() - t0 < 2.5 do task.wait(0.1) end
	end
	Mine.starting = false
	Mine.note = (not Mine.activeNode()) and (Mine.msg or "The node did not start") or nil
end
-- While mining: keep the pickaxe in hand and stay within reach of the node.
function Mine.keep(index)
	local folder = Mine.nodesFolder()
	local node = folder and (folder:FindFirstChild(tostring(index)))
	local prompt = node and node:FindFirstChild("MinePrompt", true)
	local pos = prompt and Mine.anchor(prompt)
	local _, hrp = getChar()
	if pos and hrp and (hrp.Position - pos).Magnitude > (tonumber(Mine.cfg.MineRange) or 10) - 2 then
		runBody("mining", function() exitVehicle(); placeNear(pos, 4) end)
	end
	local _, held = Mine.pickaxe()
	if not held then runBody("mining", Mine.equip) end
end
function Mine.summary()
	local st = Mine.state
	local node = Mine.activeNode()
	local count = Mine.rewards > 0 and string.format("  |  %d jewel%s this session%s", Mine.rewards, Mine.rewards == 1 and "" or "s",
		Mine.last and (", last " .. Mine.last) or "") or ""
	if node then
		local every, progress = tonumber(st.Interval), tonumber(st.Progress)
		local text = "Mining Rock Node " .. node
		if every and every > 0 and progress then
			-- Progress is the share of the interval done (0 to 1), sent about once a second
			local left = math.max(0, every * (1 - progress) - (os.clock() - (Mine.stateAt or os.clock())))
			text = text .. string.format(", next jewel in %d:%02d (every %d:%02d)", math.floor(left / 60), math.floor(left % 60), math.floor(every / 60), math.floor(every % 60))
		end
		if st.Stalled == "full" then text = "Inventory full: mining is paused. Sell or unload to resume." end
		return text .. count
	end
	return (Mine.note or (S.autoMine and "Waiting to start" or "Off")) .. count
end
task.spawn(function()
	while Hub.alive do
		task.wait(2)
		if S.autoMine and not halted() and not A.active and not S.autoAuction then
			local node = Mine.activeNode()
			if node then
				Mine.note = nil
				if not Locks.body.owner then pcall(Mine.keep, node) end
			elseif not Locks.body.owner and os.clock() - Mine.lastTry > 10 then
				Mine.lastTry = os.clock()
				runBody("mining", Mine.start)
			end
		elseif S.autoMine and S.autoAuction then
			Mine.note = "Paused: Find auctions is on"
		end
	end
end)
Hub.mine = Mine -- test hook

-- Actions used by buttons on several tabs. Each takes the lock it needs.
local function goToPlot()
	if not Rm.TeleportToPlot then return end
	runBody("plot teleport", function()
		Rm.TeleportToPlot:FireServer()
		task.wait(1)
	end)
	ui:SetStatus("Teleported to your plot", "ok")
end
local function unloadNow()
	if Locks.body.owner then ui:SetStatus("Unload queued after " .. Locks.body.owner, "busy") end
	local ok, err = runBody("unload", dumpStep, true)
	if not ok then Auto.status = "Unload error: " .. tostring(err) end
end
local function quickOpen()
	if A.active then ui:SetStatus("Already in an auction", "ok"); return end
	local ok, err = runBody("quick open", joinAuction)
	if not ok then Auto.status = "Open failed: " .. tostring(err) end
end
local function fillShelves() runItems("list", listPass) end
local function favoriteNow() runItems("favorite", favoritePass) end
local function leaveAuction() invoke(Rm.LeaveAuction) end

local function unloadScript()
	ui:Confirm({
		Title = "Unload the hub?",
		Text = "Stops every feature and removes the window. Your settings are kept for next time.",
		Confirm = "Unload", Danger = true,
		Callback = function() Hub.stop() end,
	})
end

---------------------------------------------------------------------------
-- Admin safety
---------------------------------------------------------------------------
-- The game marks staff with player attributes; group roles are a fallback.
local STAFF_ATTRS = { "IsAdmin", "HasAbsoluteZeroAdminRole", "HasAbsoluteZeroModeratorRole" }
local EXTRA_ATTRS = { "HasAbsoluteZeroTesterRole", "HasAbsoluteZeroContentCreatorRole" }
local STAFF_WORDS = { "admin", "moderator", "mod ", "developer", "dev", "owner", "staff", "manager", "founder" }
-- everything that acts in the game; the reveal only draws labels for you
local GUARDED = { "autoAuction", "autoBid", "autoTake", "autoUnload", "autoFav", "autoList", "autoOpen",
	"autoRepair", "autoAirdrop", "autoSafe", "noclip", "wsOn", "jpOn", "infJump" }
local GROUP_ID = game.CreatorType == Enum.CreatorType.Group and game.CreatorId or nil
local groupRoles = {}

local function staffReason(p)
	if p == LP then return nil end
	for _, a in ipairs(STAFF_ATTRS) do if p:GetAttribute(a) == true then return "staff" end end
	if S.adminExtra then
		for _, a in ipairs(EXTRA_ATTRS) do if p:GetAttribute(a) == true then return "tester/creator" end end
	end
	local role = groupRoles[p]
	if type(role) == "string" then
		local l = role:lower() .. " "
		for _, w in ipairs(STAFF_WORDS) do if l:find(w, 1, true) then return role end end
	end
	if game.CreatorType == Enum.CreatorType.User and p.UserId == game.CreatorId then return "game owner" end
	return nil
end

local function staffNames(list)
	local names = {}
	for _, s in ipairs(list) do names[#names + 1] = string.format("%s (%s)", s.player.DisplayName, s.why) end
	return table.concat(names, ", ")
end

local function pauseFeatures()
	Safety.snapshot = {}
	for _, k in ipairs(GUARDED) do
		if S[k] then Safety.snapshot[k] = true; ui:SetSwitch(k, false) end
	end
	Safety.paused = true
	local _, _, hum = getChar()
	if hum then
		hum.WalkSpeed = 16
		if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
	end
end

local function restoreFeatures()
	Safety.paused = false
	for k in pairs(Safety.snapshot or {}) do ui:SetSwitch(k, true) end
	Safety.snapshot = nil
end

local safetyAlert
local function askOverride()
	ui:Confirm({
		Title = "Run features with an admin here?",
		Text = "Staff in this server: " .. staffNames(Safety.staff) .. ". Using automation while they watch can get your account banned.",
		Confirm = "Override", Danger = true,
		Callback = function()
			Safety.override = true
			restoreFeatures()
			if safetyAlert then safetyAlert.Close(); safetyAlert = nil end
			ui:Notify("Storage Hunters", "Override on: features run even with an admin here.", 6)
		end,
	})
end

local function pauseAgain()
	Safety.override = false
	if #Safety.staff > 0 and not Safety.paused then pauseFeatures() end
end

local function checkStaff()
	if not Hub.alive then return end
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local why = staffReason(p)
		if why then list[#list + 1] = { player = p, why = why } end
	end
	local before = #Safety.staff
	Safety.staff = list
	if #list > 0 then
		if S.adminGuard and not Safety.paused and not Safety.override then
			pauseFeatures()
			ui:Notify("Storage Hunters", "Admin in server: " .. staffNames(list) .. ". Features paused.", 8)
			safetyAlert = ui:Alert({
				Title = "Admin in this server",
				Text = staffNames(list) .. "\nAll features are paused and anything running was stopped. They switch back on when the admin leaves.",
				Buttons = {
					{ Text = "Keep paused" },
					{ Text = "Override", Primary = true, Callback = askOverride },
				},
			})
		elseif safetyAlert and #list ~= before then
			safetyAlert.SetText(staffNames(list) .. "\nAll features are paused and anything running was stopped. They switch back on when the admin leaves.")
		end
	else
		if Safety.paused then
			restoreFeatures()
			ui:Notify("Storage Hunters", "The admin left. Your features are back on.", 6)
		end
		Safety.override = false
		if safetyAlert then safetyAlert.Close(); safetyAlert = nil end
	end
end

local function watchPlayer(p)
	if p == LP then return end
	for _, a in ipairs(STAFF_ATTRS) do table.insert(ui.conns, p:GetAttributeChangedSignal(a):Connect(checkStaff)) end
	for _, a in ipairs(EXTRA_ATTRS) do table.insert(ui.conns, p:GetAttributeChangedSignal(a):Connect(checkStaff)) end
	if GROUP_ID then
		task.spawn(function()
			local ok, role = pcall(p.GetRoleInGroup, p, GROUP_ID)
			if ok then groupRoles[p] = role; checkStaff() end
		end)
	end
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
table.insert(ui.conns, Players.PlayerAdded:Connect(function(p) watchPlayer(p); checkStaff() end))
table.insert(ui.conns, Players.PlayerRemoving:Connect(function(p)
	groupRoles[p] = nil
	task.defer(checkStaff)
end))

---------------------------------------------------------------------------
-- Home: what runs. Each step of the loop with a live line, plus status.
---------------------------------------------------------------------------
local home = ui:Tab("Home")
home:Section("Your loop")
local steps = {
	find = home:Step({ Id = "autoAuction", Text = "Find auctions", Default = D("autoAuction", false) }),
	bid = home:Step({ Id = "autoBid", Text = "Bid", Default = D("autoBid", false) }),
	take = home:Step({ Id = "autoTake", Text = "Take loot", Default = D("autoTake", false) }),
	unload = home:Step({ Id = "autoUnload", Text = "Unload at plot", Default = D("autoUnload", false) }),
	keep = home:Step({ Id = "autoFav", Text = "Keep favorites", Default = D("autoFav", false) }),
	safe = home:Step({ Id = "autoSafe", Text = "Open safes", Default = D("autoSafe", false) }),
	sell = home:Step({ Id = "autoList", Text = "Sell on shelves", Default = D("autoList", false) }),
}
home:Actions({
	{ Text = "Open auction", Callback = quickOpen },
	{ Text = "Unload", Callback = unloadNow },
	{ Text = "Fill shelves", Callback = fillShelves },
})
home:Actions({
	{ Text = "Go to my plot", Callback = goToPlot },
	{ Text = "Leave auction", Callback = leaveAuction },
	{ Text = "Lost items", Callback = function() Lost.collect() end },
})
home:Section("Right now")
local cargoMeter = home:Meter("Cargo")
local bagMeter = home:Meter("Inventory")
local homeInfo = home:Info("-")

---------------------------------------------------------------------------
-- Auction: how to find, judge and bid on auctions.
---------------------------------------------------------------------------
local auction = ui:Tab("Auction")
auction:Section("Bidding")
local auctionInfo = auction:Info("Waiting for auction")
auction:Number({ Id = "maxBid", Text = "Max bid", Hint = "0 = no limit", Default = D("maxBid", 0), Min = 0, Prefix = "$" })
auction:Number({ Id = "blueMaxBid", Text = "Max bid if outlined item", Hint = "Ignores lot value; 0 = same as max bid", Default = D("blueMaxBid", 0), Min = 0, Prefix = "$" })
auction:Number({ Id = "keepCash", Text = "Always keep cash", Hint = "Never spends below this", Default = D("keepCash", 0), Min = 0, Prefix = "$" })
auction:Section("When cash runs low")
auction:Toggle({ Id = "lowCashPause", Text = "Wait at plot for sales", Hint = "Pauses new auctions until shelf sales come in", Default = D("lowCashPause", true) })
auction:Number({ Id = "lowCashAt", Text = "Low cash below", Hint = "Also kicks in if you could not afford a bid", Default = D("lowCashAt", 1000), Min = 0, Prefix = "$" })
auction:Number({ Id = "lowCashCooldown", Text = "Cooldown", Hint = "Repeats while cash stays low", Default = D("lowCashCooldown", 90), Min = 30, Max = 600, Suffix = "s" })
auction:Section("Where to go")
auction:List({ Id = "areas", Text = "Areas", Hint = "None picked = all areas", Multi = true, Options = areaNames, Default = D("areas", {}), Empty = "All" })
auction:Choice({ Id = "garagePick", Text = "Which garage first", Options = { "Nearest", "Cheapest", "Priciest" }, Default = D("garagePick", "Nearest") })
auction:Number({ Id = "maxEntry", Text = "Max entry fee", Hint = "0 = any", Default = D("maxEntry", 0), Min = 0, Prefix = "$" })
auction:Toggle({ Id = "bringCar", Text = "Bring my car", Hint = "Parks it by the garage so loot loads fast", Default = D("bringCar", false) })
auction:Section("Skip bad lots")
auction:Toggle({ Id = "lotFilter", Text = "Check lots first", Hint = "Outlined items and airdrops always pass", Default = D("lotFilter", false) })
auction:Toggle({ Id = "gavelLots", Text = "Gavel lots always pass", Hint = "Bids on any lot with a gavel, ignoring the checks", Default = D("gavelLots", true) })
auction:List({ Id = "lotMuts", Text = "Must have a mutation", Hint = "Any one of these", Multi = true, Options = mutationNames, Default = D("lotMuts", {}), Empty = "Any" })
auction:Number({ Id = "minStartBid", Text = "Starting bid at least", Hint = "0 = any", Default = D("minStartBid", 0), Min = 0, Prefix = "$" })
auction:Section("See hidden items")
auction:Toggle({ Id = "esp", Text = "Item reveal", Hint = "Labels hidden items and X-rayed boxes", Default = D("esp", false) })
local lotInfo = auction:Info("Lot: -")
auction:Section("Airdrops")
auction:Toggle({ Id = "airdropAlerts", Text = "Alerts", Hint = "Pop-up when crates fall and land", Default = D("airdropAlerts", true) })
auction:Toggle({ Id = "airdropMarkers", Text = "Markers", Hint = "Countdown over each crate", Default = D("airdropMarkers", true) })
auction:Toggle({ Id = "autoAirdrop", Text = "Open airdrops", Hint = "Needs " .. money(Air.MIN_WORTH) .. " net worth", Default = D("autoAirdrop", false) })
local airInfo = auction:Info("Airdrops: none right now")
auction:Section("More options", { Collapsible = true, Collapsed = true })
auction:Number({ Id = "bidDelay", Text = "Bid delay", Default = D("bidDelay", 0.35), Min = 0.05, Max = 3, Suffix = "s" })
auction:Number({ Id = "bidPctOfValue", Text = "Max bid as % of lot value", Hint = "Uses item reveal; 0 = off", Default = D("bidPctOfValue", 0), Min = 0, Max = 1000, Suffix = "%" })
auction:Toggle({ Id = "leaveFailed", Text = "Leave lots that fail", Hint = "Moves on at once; skips that garage 5 min", Default = D("leaveFailed", true) })
auction:Number({ Id = "espDistance", Text = "Reveal label distance", Default = D("espDistance", 150), Min = 50, Max = 500, Suffix = " studs" })
auction:Number({ Id = "espMinConf", Text = "Reveal match confidence", Default = D("espMinConf", 25), Min = 0, Max = 100, Suffix = "%" })

---------------------------------------------------------------------------
-- Loot: what to take after winning and what to keep.
---------------------------------------------------------------------------
local loot = ui:Tab("Loot")
loot:Section("What to take")
loot:Number({ Id = "minTake", Text = "Take items worth at least", Hint = "Cheaper ones stay behind", Default = D("minTake", 0), Min = 0, Prefix = "$" })
loot:Toggle({ Id = "takeBlue", Text = "Always take outlined items", Hint = "Blue or white outline", Default = D("takeBlue", true) })
loot:List({ Id = "takeMuts", Text = "Always take mutations", Hint = "At any value", Multi = true, Options = mutationNames, Default = D("takeMuts", {}), Empty = "None" })
loot:List({ Id = "takeNames", Text = "Always take these items", Hint = "At any value", Multi = true, Options = itemNames, Default = D("takeNames", {}), Empty = "None" })
loot:Section("While taking")
loot:Toggle({ Id = "autoOpen", Text = "Open boxes", Hint = "Crates you won are opened first", Default = D("autoOpen", false) })
loot:Toggle({ Id = "autoRepair", Text = "Repair broken items", Hint = "Wrench on loot, plus repair shop slots", Default = D("autoRepair", false) })
local itemsInfo = loot:Info("-")
loot:Section("What to keep")
local keepInfo = loot:Info("-")
loot:Number({ Id = "favGearMin", Text = "Gear worth at least", Hint = "Wearables, boards, car parts; 0 = off", Default = D("favGearMin", 0), Min = 0, Prefix = "$" })
loot:List({ Id = "favGearMuts", Text = "Gear with a mutation", Hint = "At any price", Multi = true, Options = mutationNames, Default = D("favGearMuts", {}), Empty = "None" })
loot:Toggle({ Id = "favGavel", Text = "Gavel trophies", Default = D("favGavel", false) })
loot:List({ Id = "favGavelMuts", Text = "Gavel mutations", Hint = "None picked = every gavel", Multi = true, Options = mutationNames, Default = D("favGavelMuts", {}), Empty = "Any" })
loot:Number({ Id = "favGavelPct", Text = "Gavel mutation at least", Hint = "The % shown on the gavel; 0 = off", Default = D("favGavelPct", 0), Min = 0, Max = 1000, Suffix = "%" })
do -- gavels are handled only by the Gavel rule above, so they are not offered here
	local keepNames, keepSaved = {}, {}
	for _, name in ipairs(itemNames) do if not name:find("Gavel", 1, true) then keepNames[#keepNames + 1] = name end end
	for _, name in ipairs(D("favItems", {})) do if not name:find("Gavel", 1, true) then keepSaved[#keepSaved + 1] = name end end
	loot:List({ Id = "favItems", Text = "Always keep these items", Hint = "At any value (gavels use the Gavel rule)", Multi = true, Options = keepNames, Default = keepSaved, Empty = "None" })
end
loot:Actions({ { Text = "Favorite matching items now", Callback = favoriteNow } })
loot:Section("Safes and vaults")
loot:Toggle({ Id = "safeLocksmith", Text = "Use the Locksmith too", Hint = "For safes your lockpick is not good enough for", Default = D("safeLocksmith", true) })
local safeInfo = loot:Info("Turn on Open safes on Home")
loot:Actions({ { Text = "Open safes now", Callback = function() runItems("open safes", Safe.pass) end } })
loot:Section("Lost items")
Lost.info = loot:Info("-")
loot:Actions({ { Text = "Collect lost items", Callback = function() Lost.collect() end } })
loot:Section("Mining")
loot:Toggle({ Id = "autoMine", Text = "Auto mine", Hint = "Needs a pickaxe; waits while Find auctions is on", Default = D("autoMine", false) })
do
	local opts = {}
	for i = 1, 10 do opts[i] = string.format("Node %d (%s)", i, money(Mine.minWorth(i))) end
	loot:List({ Id = "mineNode", Text = "Rock node", Hint = "Net worth needed; none = best you can", Multi = false, Options = opts, Empty = "Best I can" })
end
Mine.info = loot:Info("-")

---------------------------------------------------------------------------
-- Stats: what the hub did this session.
---------------------------------------------------------------------------
local statsTab = ui:Tab("Stats")
statsTab:Section("Overview")
local statRows = {
	since = statsTab:Stat("Counting since"),
	time = statsTab:Stat("Time with the hub"),
	worthStart = statsTab:Stat("Net worth at start"),
	worthNow = statsTab:Stat("Net worth now"),
	worthGain = statsTab:Stat("Net worth gained"),
}
statsTab:Section("Auctions")
statRows.opened = statsTab:Stat("Auctions opened")
statRows.won = statsTab:Stat("Auctions won")
statRows.bids = statsTab:Stat("Paid for wins")
statRows.fees = statsTab:Stat("Entry fees")
statRows.loot = statsTab:Stat("Loot value claimed")
statsTab:Section("Items")
statRows.taken = statsTab:Stat("Items taken")
statRows.mutated = statsTab:Stat("Mutated items gained")
statRows.safes = statsTab:Stat("Safes unlocked")
statRows.favorited = statsTab:Stat("Favorited")
statRows.listed = statsTab:Stat("Listed on shelves")
statRows.sales = statsTab:Stat("Shelf sales")
statsTab:Section("Money handled")
statRows.handled = statsTab:Stat("Total moved by the hub")
statsTab:Actions({ { Text = "Reset stats", Callback = function()
	ui:Confirm({
		Title = "Reset all stats?", Text = "Every counter goes back to zero and counting starts again from now.",
		Confirm = "Reset", Danger = true, Callback = Stats.reset,
	})
end } })

---------------------------------------------------------------------------
-- Shop: selling on your plot and unloading.
---------------------------------------------------------------------------
local shop = ui:Tab("Shop")
shop:Section("What to sell")
shop:Number({ Id = "listMin", Text = "Sell items worth at least", Hint = "0 = no minimum", Default = D("listMin", 0), Min = 0, Prefix = "$" })
shop:Number({ Id = "listMax", Text = "Sell items worth at most", Hint = "0 = no maximum", Default = D("listMax", 0), Min = 0, Prefix = "$" })
local plotInfo = shop:Info("-")
shop:Actions({ { Text = "Fill shelves now", Callback = fillShelves }, { Text = "Go to my plot", Callback = goToPlot } })
shop:Section("Unloading")
shop:Number({ Id = "dumpAt", Text = "Unload when cargo reaches", Hint = "Auctions resume 30 points lower", Default = D("dumpAt", 85), Min = 40, Max = 100, Suffix = "%" })
shop:Toggle({ Id = "unloadAnywhere", Text = "Unload without moving", Hint = "Drives to your plot only if refused", Default = D("unloadAnywhere", true) })
shop:Actions({ { Text = "Unload now", Callback = unloadNow } })

-- Top bar: Plot and Unload first, then one button per shop screen.
local SHOP_LABEL = {
	RepairShop = "Repair", LocksmithShop = "Locksmith", WashShop = "Wash", CleaningShop = "Sprays",
	GradingShop = "Grading", VehicleDealership = "Cars", TrailerShop = "Trailers", EnergyShop = "Drinks",
	Clubs = "Clubs", PawnShop = "Pawn", Authentication = "Authenticate",
}
local barItems = {
	{ Label = "Plot", Accent = true, Callback = goToPlot },
	{ Label = "Unload", Accent = true, Callback = unloadNow },
}
for _, name in ipairs(shopNames) do
	local text = SHOP_LABEL[shopScreens[name].screen] or name:match("^(.-) %(") or name
	barItems[#barItems + 1] = { Label = text, Callback = function()
		local ok, err = openShop(name)
		if not ok then ui:SetStatus("Could not open " .. text .. ": " .. tostring(err)) end
	end }
end
local quickBar = ui:Bar(barItems)

---------------------------------------------------------------------------
-- Player: getting around, movement and the hub itself.
---------------------------------------------------------------------------
local playerTab = ui:Tab("Player")
playerTab:Section("Shops")
playerTab:Toggle({ Id = "shopBar", Text = "Shop bar at the top", Hint = "One button per shop screen", Default = D("shopBar", true) })
quickBar.Visible = S.shopBar
playerTab:Section("Teleport")
local placePick = playerTab:List({ Id = "tpPlace", Text = "Place", Multi = false, Options = placeNames, Empty = "Pick one" })
playerTab:Button({ Text = "Go to place", Action = "Go", Callback = function()
	local get = S.tpPlace and places[S.tpPlace]
	if not get then ui:SetStatus("Pick a place first"); return end
	local ok, moved = runBody("teleport", function() return tpTo(get()) end)
	if not (ok and moved) then ui:SetStatus("That place is not loaded") end
end })
local function playerNames()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then list[#list + 1] = p.Name end end
	table.sort(list)
	return list
end
playerTab:List({ Id = "tpPlayer", Text = "Player", Multi = false, Options = playerNames, Empty = "Pick one" })
playerTab:Button({ Text = "Go to player", Action = "Go", Callback = function()
	local p = S.tpPlayer and Players:FindFirstChild(S.tpPlayer)
	local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if hrp then runBody("teleport", tpTo, hrp.Position + Vector3.new(3, 0, 0)) else ui:SetStatus("Player has no character") end
end })
playerTab:Section("Movement")
playerTab:Toggle({ Id = "wsOn", Text = "Walk speed", Default = D("wsOn", false) })
playerTab:Number({ Id = "ws", Text = "Speed", Default = D("ws", 32), Min = 16, Max = 150 })
playerTab:Toggle({ Id = "jpOn", Text = "Jump power", Default = D("jpOn", false) })
playerTab:Number({ Id = "jp", Text = "Power", Default = D("jp", 75), Min = 50, Max = 250 })
playerTab:Toggle({ Id = "infJump", Text = "Infinite jump", Default = D("infJump", false) })
playerTab:Toggle({ Id = "noclip", Text = "Noclip", Default = D("noclip", false) })
playerTab:Toggle({ Id = "antiAfk", Text = "Anti AFK", Default = D("antiAfk", true) })
playerTab:Toggle({ Id = "instantPrompts", Text = "Instant hold E", Hint = "Prompts you would hold fire on a tap", Default = D("instantPrompts", true) })
playerTab:Section("Admin safety")
playerTab:Toggle({ Id = "adminGuard", Text = "Pause when an admin joins", Hint = "Stops everything until they leave", Default = D("adminGuard", true) })
playerTab:Toggle({ Id = "adminExtra", Text = "Count testers and creators", Hint = "Not just admins and moderators", Default = D("adminExtra", false) })
local safetyInfo = playerTab:Info("No staff in this server")
playerTab:Actions({ { Text = "Override", Callback = function()
	if #Safety.staff == 0 then ui:SetStatus("No admin here, nothing to override", "ok") else askOverride() end
end }, { Text = "Pause again", Callback = pauseAgain } })
playerTab:Section("Interface")
local themePick = playerTab:Choice({ Id = "theme", Text = "Theme", Options = { "Black Teal", "Noir", "Original", "Custom" }, Default = D("theme", "Original") })
local customColors = {
	playerTab:ColorInput({ Id = "customBg", Text = "Background", Hint = "Hex colour, like #101214", Default = D("customBg", "#101214") }),
	playerTab:ColorInput({ Id = "customAccent", Text = "Accent", Hint = "Switches, buttons, highlights", Default = D("customAccent", "#2EC4B6") }),
	playerTab:ColorInput({ Id = "customText", Text = "Text", Default = D("customText", "#E8EEF0") }),
}
local function applyTheme()
	local name = S.theme or "Original"
	local theme
	if name == "Custom" then
		theme = Kit.CustomTheme(Kit.HexToColor(S.customBg) or Color3.fromRGB(16, 18, 20),
			Kit.HexToColor(S.customAccent) or Color3.fromRGB(46, 196, 182),
			Kit.HexToColor(S.customText) or Color3.fromRGB(232, 238, 240))
	else
		theme = Kit.Themes[name] or Kit.Themes.Original
	end
	task.wait(0.2) -- let any button animation that started with the old colours finish
	ui:SetTheme(theme)
	themePick.Set(name, false) -- repaint the picker in the new colours
	for _, c in ipairs(customColors) do c.row.Visible = name == "Custom" end
end
Hub.applyTheme = applyTheme
playerTab:Toggle({ Id = "eventTimers", Text = "Event timers on screen", Hint = "Left side of the screen; drag it to move", Default = D("eventTimers", true) })

---------------------------------------------------------------------------
-- Event timers: a small panel on the left with the game's own schedule
-- (SpecialEventManager: cargo ship and train, weather, night and season
-- events), your seized-garage timer and live airdrop crates. Airdrops have
-- no schedule the client can see, so they show only once a crate is out.
---------------------------------------------------------------------------
local Timers = { cache = {}, events = {} }
do
	local okM, SEM = pcall(require, Modules:FindFirstChild("SpecialEventManager"))
	local okC, SEC = pcall(require, Modules:FindFirstChild("SpecialEventConfig"))
	Timers.SEM = okM and type(SEM) == "table" and SEM or nil
	if okC and type(SEC) == "table" and type(SEC.Events) == "table" then Timers.events = SEC.Events end
end
function Timers.clock(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then return string.format("%dh %02dm", math.floor(s / 3600), math.floor((s % 3600) / 60)) end
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end
-- The game's schedule code reads your PC clock (os.time) unless it is given a
-- time, so a wrong or changed clock would give wrong times. Every call here
-- passes the server's clock instead, plus the game's own DevTimeOffset.
function Timers.serverNow()
	local off = tonumber(game:GetService("Lighting"):GetAttribute("DevTimeOffset")) or 0
	return math.floor(workspace:GetServerTimeNow() + off)
end
-- Next start, cached for 2 minutes or until it passes (the manager works it
-- out from seeded random gaps, the same on every client).
function Timers.nextStart(ev, now)
	local c = Timers.cache[ev.Name]
	if c and now - c.checked < 120 and (c.at == nil or c.at > now) then return c.at end
	local SEM, at = Timers.SEM, nil
	local t = Timers.serverNow()
	local ok, v = pcall(SEM.GetNextConcurrentStart, SEM, ev.Name, t)
	if ok and type(v) == "number" then at = v end
	if not at then
		ok, v = pcall(SEM.GetNextEventStart, SEM, ev.Name, t)
		if ok and type(v) == "number" then at = v end
	end
	Timers.cache[ev.Name] = { at = at, checked = now }
	return at
end
function Timers.rows()
	local now = workspace:GetServerTimeNow()
	local live, soon, seen = {}, {}, {}
	local Lighting = game:GetService("Lighting")
	local SEM = Timers.SEM
	local function liveRow(name, left)
		local text = name
		if name == "Cargo Train" then
			local station = Lighting:GetAttribute("CargoTrainStation")
			if Lighting:GetAttribute("CargoTrainPhase") == "Stopped" and station then text = "Cargo Train, stop " .. tostring(station) end
		end
		seen[name] = true
		live[#live + 1] = { Text = text, Value = "LIVE " .. Timers.clock(left), State = "live", sort = left }
	end
	if SEM then
		local t = Timers.serverNow()
		for _, ev in ipairs(Timers.events) do
			if type(ev) == "table" and type(ev.Name) == "string" and ev.Enabled ~= false then
				local okA, active = pcall(SEM.IsEventActive, SEM, ev.Name, t)
				if okA and active then
					local okL, left = pcall(SEM.GetEventTimeRemaining, SEM, ev.Name, t)
					liveRow(ev.Name, okL and tonumber(left) or 0)
				elseif ev.Scheduled ~= false then -- unscheduled ones (meltdown, police) start on a trigger
					local at = Timers.nextStart(ev, now)
					if at and at > now then
						soon[#soon + 1] = { Text = ev.Name, Value = Timers.clock(at - now), State = at - now <= 300 and "soon" or nil, sort = at - now }
					end
				end
			end
		end
	end
	-- the server's own record of the main event, in case the manager missed it
	local name, ends = Lighting:GetAttribute("ActiveSpecialEvent"), tonumber(Lighting:GetAttribute("SpecialEventEndsAt"))
	if type(name) == "string" and name ~= "" and ends and ends > now and not seen[name] then liveRow(name, ends - now) end
	local seized = tonumber(LP:GetAttribute("PoliceSeizedGarageNextDueUnix"))
	if seized and seized > now then
		soon[#soon + 1] = { Text = "Seized garage", Value = Timers.clock(seized - now), State = seized - now <= 300 and "soon" or nil, sort = seized - now }
	end
	local falling, landed, nearest = airdropSummary()
	if landed > 0 then
		live[#live + 1] = { Text = landed > 1 and string.format("Airdrops (%d)", landed) or "Airdrop", Value = "LIVE " .. Timers.clock(nearest or 0), State = "live", sort = nearest or 0 }
	elseif falling > 0 then
		live[#live + 1] = { Text = "Airdrop", Value = "FALLING", State = "live", sort = 0 }
	end
	table.sort(live, function(a, b) return a.sort < b.sort end)
	table.sort(soon, function(a, b) return a.sort < b.sort end)
	local out = {}
	-- the game's own banners and countdowns use your PC clock; say so if it is off
	local drift = os.time() - now
	if math.abs(drift) >= 10 then
		out[1] = { Text = drift > 0 and "PC clock ahead" or "PC clock behind", Value = Timers.clock(math.abs(drift)), State = "soon" }
	end
	for _, r in ipairs(live) do out[#out + 1] = r end
	for _, r in ipairs(soon) do out[#out + 1] = r end
	while #out > 10 do table.remove(out) end
	return out
end
do
	S.timersPos = D("timersPos", {})
	local p = S.timersPos
	local pos = (type(p[1]) == "number" and type(p[4]) == "number") and UDim2.new(p[1], p[2], p[3], p[4]) or UDim2.fromOffset(12, 96)
	Timers.panel = ui:SidePanel({ Title = "EVENTS", Empty = "Nothing scheduled", Position = pos, OnMoved = function(u)
		S.timersPos = { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
		queueSave()
	end })
	Timers.panel:SetVisible(S.eventTimers ~= false)
	task.spawn(function()
		while Hub.alive do
			if S.eventTimers ~= false then
				local ok, rows = pcall(Timers.rows)
				if ok then Timers.panel:SetRows(rows) end
			end
			task.wait(1)
		end
	end)
end
Hub.timers = Timers
playerTab:Section("Keybinds")
playerTab:Toggle({ Id = "keybindNotify", Text = "Keybind notifications", Hint = "Shows ON or OFF when a key flips a switch", Default = D("keybindNotify", true) })
playerTab:Info("Click the small box next to any switch, then press a key. Give several switches the same key and it toggles them together (all on, or all off if they already are); shared keys show a *. Backspace clears. Insert shows or hides this window.")

-- One-time move from the old "keybind groups": each group's switches take its key.
do
	local binds = ui:_binds()
	local byLabel = {}
	for id, sw in pairs(ui.switches) do
		if sw.isSwitch then byLabel[(sw.tab and (sw.tab .. ": ") or "") .. sw.text] = id end
	end
	local moved = false
	for n = 1, 3 do
		local groupId = "group" .. n
		for keyName, ids in pairs(binds) do
			for i = #ids, 1, -1 do
				if ids[i] == groupId then
					table.remove(ids, i)
					for _, labelText in ipairs(S["keyGroup" .. n] or {}) do
						local id = byLabel[labelText]
						if id and not table.find(ids, id) then table.insert(ids, id) end
					end
					moved = true
				end
			end
			if #ids == 0 then binds[keyName] = nil end
		end
		S["keyGroup" .. n] = nil
	end
	if moved then queueSave() end
	ui:_paintChips()
end
playerTab:Section("Hub")
playerTab:Actions({ { Text = "Unload script", Callback = unloadScript } })
S.tpPlace, S.tpPlayer = nil, nil -- not worth remembering between sessions
placePick.Set(nil, false)

-- Live lines on Home: what each step is set to, and which one is working.
local function refreshHome()
	local areas = #(S.areas or {}) > 0 and table.concat(S.areas, ", ") or "All areas"
	steps.find.SetDetail(Auto.cooldownUntil and "Low cash: waiting at plot for sales"
		or (Auto.dumping and "Paused while unloading" or (areas .. ", " .. string.lower(S.garagePick or "nearest") .. " first")))
	steps.bid.SetDetail((S.maxBid > 0 and ("Up to " .. money(S.maxBid)) or "No max bid") .. (S.lotFilter and ", checks lots" or ""))
	local take = "Worth " .. money(S.minTake) .. "+"
	if S.takeBlue then take ..= ", outlined" end
	if #(S.takeMuts or {}) > 0 then take ..= ", " .. #S.takeMuts .. " mutation(s)" end
	if #(S.takeNames or {}) > 0 then take ..= ", " .. #S.takeNames .. " item(s)" end
	steps.take.SetDetail(take)
	steps.unload.SetDetail("At " .. tostring(S.dumpAt) .. "% cargo" .. (Auto.dumping and ", unloading now" or ""))
	steps.keep.SetDetail(keepRulesText())
	steps.safe.SetDetail(Safe.note or (S.safeLocksmith and "Lockpick, then Locksmith" or "Lockpick only"))
	safeInfo(Safe.note or "Waiting for safes in your inventory")
	do
		local n = #Lost.items()
		local head = n > 0 and string.format("%d on the map. Your car is brought to each one.", n) or "None on the map right now"
		Lost.info(Lost.running and ("Collecting: " .. (Lost.note or "...") .. "  |  press again to stop")
			or (Lost.note and (head .. "  |  last run: " .. Lost.note) or head))
	end
	Mine.info(Mine.summary())
	local range
	if S.listMin > 0 and S.listMax > 0 then range = money(S.listMin) .. " to " .. money(S.listMax)
	elseif S.listMin > 0 then range = money(S.listMin) .. "+"
	elseif S.listMax > 0 then range = "up to " .. money(S.listMax)
	else range = "any value" end
	steps.sell.SetDetail(Auto.listNote and ((Auto.listNote:gsub("^Shelves: ", ""))) or ("Items worth " .. range))

	local busyBody, busyItems = Locks.body.owner or "", Locks.items.owner or ""
	steps.find.SetActive(Auto.phase == "find" or busyBody == "quick open")
	steps.bid.SetActive(A.active)
	steps.take.SetActive(Auto.phase == "take")
	steps.unload.SetActive(Auto.phase == "unload" or busyBody == "unload" or busyItems == "unload")
	steps.keep.SetActive(busyItems:find("favorite") ~= nil)
	steps.sell.SetActive(busyItems:find("list") ~= nil)
	steps.safe.SetActive(busyItems:find("safe") ~= nil)

	-- Stats tab
	local worth = netWorth()
	if worth == math.huge then worth = nil end
	if not Stats.startNetWorth and worth then Stats.startNetWorth = worth end
	local secs = math.floor(Stats.trackedSeconds())
	statRows.since(Stats.since)
	statRows.time(string.format("%d:%02d:%02d", secs // 3600, (secs % 3600) // 60, secs % 60))
	if os.clock() - (Stats.savedAt or 0) > 30 then Stats.savedAt = os.clock(); Stats.save() end
	statRows.worthStart(Stats.startNetWorth and money(Stats.startNetWorth) or "-")
	statRows.worthNow(worth and money(worth) or "-")
	statRows.worthGain((worth and Stats.startNetWorth) and ((worth >= Stats.startNetWorth and "+" or "") .. money(worth - Stats.startNetWorth)) or "-")
	statRows.opened(Auto.joined)
	statRows.won(Stats.won)
	statRows.bids(money(Stats.bidsPaid))
	statRows.fees(money(Stats.entryFees))
	statRows.loot(money(Stats.lootValue))
	statRows.taken(Auto.picked)
	statRows.mutated(Stats.mutated)
	statRows.safes(Stats.safes)
	statRows.favorited(Auto.favorited)
	statRows.listed(Auto.listed)
	statRows.sales(string.format("%s (%d)", money(Stats.shelfSales), Stats.salesCount))
	statRows.handled(money(Stats.bidsPaid + Stats.entryFees + Stats.lootValue + Stats.shelfSales))

	local w, lim = cargoOf(myVehicle())
	cargoMeter(lim and lim > 0 and w / lim or 0, lim and string.format("%d / %d kg", math.floor(w + 0.5), lim) or "no vehicle")
	local count, cap = tonumber(LP:GetAttribute("InventoryCount")) or 0, tonumber(LP:GetAttribute("InventoryCap")) or 0
	bagMeter(cap > 0 and count / cap or 0, string.format("%d / %d", count, cap))
	homeInfo(string.format("This session: %d auctions, %d bids, %d taken, %d favorited, %d listed",
		Auto.joined, A.bids, Auto.picked, Auto.favorited, Auto.listed))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local conns = ui.conns
local function on(signal, fn) if signal then table.insert(conns, signal:Connect(fn)) end end

on(Rm.ToggleArea and Rm.ToggleArea.OnClientEvent, function(inZone, garage)
	if inZone then
		A.garage = garage
		scanLotForBlue()
		beginLotCheck(garage) -- judge the lot during the countdown
		return
	end
	-- keep the character inside the zone while an auction we opened runs
	-- (but not when we just left a lot on purpose)
	if os.clock() - (Auto.leftAt or 0) < 15 then return end
	if not garage or not (S.autoAuction or os.clock() - Auto.lastJoin < 30) then return end
	if not (A.active or os.clock() - Auto.lastJoin < 30) then return end
	task.spawn(function()
		task.wait(0.2)
		local zone = garage:FindFirstChild("AuctionZone")
		local char, hrp = getChar()
		if zone and zone:IsA("BasePart") and char and hrp then
			exitVehicle()
			local p = zone.Position
			char:PivotTo(CFrame.new(p.X, p.Y - zone.Size.Y / 2 + 3, p.Z))
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end)
end)
on(Rm.ToggleBiddingUI and Rm.ToggleBiddingUI.OnClientEvent, function(open)
	A.active = open and true or false
	A.winner, A.amount, A.nextPrice, A.paused = nil, 0, nil, false
	if open then
		beginLotCheck(A.garage) -- no-op if the check already started in the zone
		scanLotForBlue()
	else
		if A.cashShort then Auto.cashShortAfter = true end
		A.cashShort = false
		A.garage, A.hasBlue, A.startBid, A.filterGarage, A.filter = nil, false, nil, nil, nil
		-- after a lot we left on purpose, go straight on; otherwise wait for results
		if os.clock() - (Auto.leftAt or 0) > 10 then Auto.lastAuctionEnd = os.clock() end
	end
end)
on(Rm.UpdateWinning and Rm.UpdateWinning.OnClientEvent, function(amount, winner, _, nextPrice, garage)
	if A.garage and garage and garage ~= A.garage then return end
	if not amount or not winner then return end
	if not A.garage and A.active and typeof(garage) == "Instance" then
		A.garage = garage
		beginLotCheck(garage)
	end
	if winner == "Starting" then A.startBid = tonumber(amount) end
	A.amount, A.winner = amount, winner
	if nextPrice then A.nextPrice = nextPrice end
end)
on(Rm.Paused and Rm.Paused.OnClientEvent, function(paused, garage)
	if not garage or not A.garage or garage == A.garage then A.paused = paused == true end
end)
on(Rm.SpawnResult and Rm.SpawnResult.OnClientEvent, function(ok, msg) Auto.spawnResult = { ok = ok, msg = msg } end)
-- the game's red/green notices; lost-item pickups read "Added to vehicle!" or the reason it failed
on(Rm.MiningState and Rm.MiningState.OnClientEvent, function(st)
	if type(st) ~= "table" then return end
	if type(st.Reward) == "table" then -- a jewel, not a state change
		Mine.rewards += 1
		local r = st.Reward
		Mine.last = r.Name and (tostring(r.Name) .. (r.Rarity and (" (" .. tostring(r.Rarity) .. ")") or "")) or Mine.last
		return
	end
	Mine.state, Mine.stateAt = st, os.clock()
end)
on(Rm.Notify and Rm.Notify.OnClientEvent, function(msg)
	if Mine.starting and type(msg) == "string" then Mine.msg = msg end
	if not (Lost.running and type(msg) == "string") then return end
	if msg:find("Added to vehicle", 1, true) then Lost.added += 1 else Lost.msg = msg end
end)
on(Rm.OfferOverweight and Rm.OfferOverweight.OnClientEvent, function() Auto.overweightAt = os.clock() end)

-- a sale frees a shelf slot: fill it again soon (and count it)
on(Rm.CashEffect and Rm.CashEffect.OnClientEvent, function(_, amount)
	Auto.lastList = math.min(Auto.lastList, os.clock() - 6)
	if tonumber(amount) then Stats.shelfSales += tonumber(amount); Stats.salesCount += 1 end
end)
-- the game's own profit HUD events: price paid on a win, then each item's value
on(Rm.PickupStart and Rm.PickupStart.OnClientEvent, function(paid)
	Stats.won += 1
	Stats.bidsPaid += tonumber(paid) or 0
end)
on(Rm.PickupItem and Rm.PickupItem.OnClientEvent, function(value)
	Stats.lootValue += tonumber(value) or 0
end)
on(Rm.FeePaid and Rm.FeePaid.OnClientEvent, function(amount, currency)
	if currency == nil or currency == "Cash" then Stats.entryFees += tonumber(amount) or 0 end
end)

-- Instant hold E: prompts you would hold (mining, pickups, boxes) fire on a
-- tap. The hold time is set to 0 when a prompt shows; the old values come
-- back when the switch goes off or the hub unloads.
do
	local PPS = game:GetService("ProximityPromptService")
	local original = setmetatable({}, { __mode = "k" })
	local function instant(p)
		if S.instantPrompts and p:IsA("ProximityPrompt") and p.HoldDuration > 0 then
			if original[p] == nil then original[p] = p.HoldDuration end
			p.HoldDuration = 0
		end
	end
	on(PPS.PromptShown, instant)
	on(PPS.PromptButtonHoldBegan, instant)
	function Hub.restorePrompts()
		for p, hold in pairs(original) do
			if p.Parent and p.HoldDuration == 0 then pcall(function() p.HoldDuration = hold end) end
		end
		table.clear(original)
	end
end
on(game:GetService("UserInputService").JumpRequest, function()
	if not S.infJump then return end
	local _, _, hum = getChar()
	if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
on(RunService.Stepped, function()
	if not S.noclip then return end
	local char = LP.Character
	if not char then return end
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
	end
end)
local okVU, VU = pcall(game.GetService, game, "VirtualUser")
on(LP.Idled, function()
	if S.antiAfk and okVU and VU then pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end) end
end)

---------------------------------------------------------------------------
-- Loops
---------------------------------------------------------------------------

-- Airdrop markers (countdown over each crate) and alerts.
local markerFolder = Instance.new("Folder")
markerFolder.Name = "SHHubAirdrops"
markerFolder.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
local markers = {}
local AIR_COLOR = typeof(Air.cfg.MarkerColor) == "Color3" and Air.cfg.MarkerColor or Color3.fromRGB(150, 170, 90)

local function refreshAirdrops()
	local tagged = CollectionService:GetTagged(Air.TAG)
	local live = {}
	for _, inst in ipairs(tagged) do live[inst] = true end
	for inst, m in pairs(markers) do
		if not live[inst] or not S.airdropMarkers then m.board:Destroy(); markers[inst] = nil end
	end
	if S.airdropMarkers then
		for _, inst in ipairs(tagged) do
			local m = markers[inst]
			if not m then
				local adornee = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
				if adornee then
					local board = Instance.new("BillboardGui")
					board.AlwaysOnTop = true
					board.Size = UDim2.fromOffset(150, 42)
					board.StudsOffset = Vector3.new(0, 7, 0)
					board.MaxDistance = 3000
					board.Adornee = adornee
					local text = Instance.new("TextLabel")
					text.Size = UDim2.fromScale(1, 1)
					text.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
					text.BackgroundTransparency = 0.25
					text.TextColor3 = AIR_COLOR
					text.TextStrokeTransparency = 0.5
					text.Font = Enum.Font.GothamBold
					text.TextScaled = true
					text.Parent = board
					board.Parent = markerFolder
					m = { board = board, label = text }
					markers[inst] = m
				end
			end
			if m then
				local state = inst:GetAttribute(Air.STATE)
				local left = airdropTimeLeft(inst)
				local line
				if state == "falling" then line = "falling"
				elseif inst:GetAttribute("InAuction") then line = "in auction"
				elseif left then line = string.format("%d:%02d left", math.max(0, left) // 60, math.max(0, math.floor(left)) % 60)
				else line = tostring(state or "") end
				m.label.Text = "AIRDROP\n" .. line
			end
		end
	end
	-- alerts: a new wave starting to fall, and crates landing
	local falling, landed, nearest = airdropSummary()
	if S.airdropAlerts then
		if falling > 0 and (Auto.airFalling or 0) == 0 then
			ui:Toast(string.format("Airdrop incoming: %d crate%s falling", falling, falling == 1 and "" or "s"), 8)
		elseif landed > (Auto.airLanded or 0) then
			local ok, why = airdropEligible()
			ui:Toast(string.format("Airdrop landed: %d crate%s, 10 min to open%s", landed, landed == 1 and "" or "s",
				ok and "" or (" - opening " .. why)), 8)
		end
	end
	Auto.airFalling, Auto.airLanded = falling, landed
	-- summary line
	if falling + landed == 0 then
		airInfo("Airdrops: none right now")
	else
		local ok, why = airdropEligible()
		airInfo(string.format("Airdrops: %d falling, %d landed%s%s", falling, landed,
			nearest and string.format(" (nearest %d:%02d left)", math.max(0, nearest) // 60, math.max(0, math.floor(nearest)) % 60) or "",
			ok and "" or ("; " .. why)))
	end
end

local function autoStep()
	local now = os.clock()
	if A.active then
		Auto.status = "In auction" .. (A.hasBlue and " (outlined item in lot)" or "")
		if now - (Auto.lastScan or 0) > 1 then Auto.lastScan = now; scanLotForBlue() end
		return
	end
	if now - Auto.lastAuctionEnd < 3 then Auto.status = "Waiting for auction results"; return end
	-- Auto.phase tells Home which step is working; the loop clears it after each step
	Auto.phase = "take"
	if S.autoOpen and openBoxes() then return end
	local items = S.autoTake and takeable() or {}
	local full = vehicleFull(items)
	if S.autoTake and #items > 0 and not full then takeItems(items); return end
	local high = full or cargoPct() >= S.dumpAt
	if S.autoUnload and (Auto.dumping or high) then
		Auto.phase = "unload"
		Auto.dumping = true
		if now - Auto.lastDeposit < 5 then return end -- keep the paused status between rounds
		Auto.lastDeposit = now
		if dumpStep() == "wait" then return end
		Auto.dumping = false
		high = vehicleFull({}) or cargoPct() >= S.dumpAt
	end
	Auto.phase = "find"
	-- Low cash: wait at the plot for shelf sales instead of opening auctions.
	-- Resume as soon as sales bring the cash back; otherwise the cooldown repeats.
	if S.lowCashPause and (S.autoAuction or S.autoAirdrop) then
		local cash = tonumber(LP:GetAttribute("Cash")) or 0
		local low = cash < S.lowCashAt or Auto.cashShortAfter
		if low and not Auto.cooldownUntil then
			Auto.cooldownUntil = now + S.lowCashCooldown
			Auto.cooldownMark = cash
			Auto.cooldownPlotSent = false
		end
		if Auto.cooldownUntil then
			local recovered = cash >= S.lowCashAt and cash > Auto.cooldownMark
			if recovered then
				Auto.cooldownUntil, Auto.cashShortAfter = nil, false
				Auto.status = "Sales came in (" .. money(cash) .. "), back to auctions"
			else
				if not Auto.cooldownPlotSent and Rm.TeleportToPlot then
					Auto.cooldownPlotSent = true
					Rm.TeleportToPlot:FireServer()
				end
				if now >= Auto.cooldownUntil then
					Auto.cooldownUntil = now + S.lowCashCooldown -- still short: wait another round
				end
				local left = math.max(0, math.floor(Auto.cooldownUntil - now))
				Auto.status = string.format("Low cash (%s): waiting at plot for sales, %d:%02d%s", money(cash), left // 60, left % 60,
					S.autoList and "" or " (turn on Sell on shelves)")
				return
			end
		end
	end
	-- airdrop crates vanish after 10 minutes, so they go before normal auctions
	if S.autoAirdrop and not high and airdropEligible() and nextAirdrop() then
		openAirdrop()
		return
	end
	if S.autoAuction then
		if high then Auto.status = string.format("Auctions paused: cargo %d%% (turn on Auto unload)", math.floor(cargoPct())); return end
		if now - Auto.lastJoin >= 3 then joinAuction() end
		return
	end
	Auto.status = "Watching"
end

-- bidding: light and frequent
task.spawn(function()
	while Hub.alive do
		-- the lot check runs whether or not auto bid is on, so rejects leave fast
		if A.filter == "checking" and A.garage then pcall(checkLot) end
		local ok, err = pcall(bidTick, os.clock())
		if not ok then A.status = "Bid error: " .. tostring(err) end
		task.wait(0.05)
	end
end)

-- chores: remote-only work that never moves the character, so walking or
-- driving elsewhere cannot hold it up
task.spawn(function()
	while Hub.alive do
		local now = os.clock()
		local ok, err = pcall(function()
			-- favorite first, so new keepers are protected before shelves are filled
			local function chore(name, fn)
				local done, why, stuck = guardedLimit(Locks.items, name, 120, fn)
				if stuck then
					Auto.listNote = name .. " froze and was stopped; it will run again"
				elseif not done then
					Auto.listNote = name .. ": " .. tostring(why)
				end
			end
			if S.autoFav and now - Auto.lastFav >= 20 then Auto.lastFav = now; chore("auto favorite", favoritePass) end
			if S.autoSafe and now - (Auto.lastSafe or 0) >= 6 then Auto.lastSafe = now; chore("open safes", Safe.pass) end
			if S.autoList and now - Auto.lastList >= 8 then Auto.lastList = now; chore("auto list", listPass) end
			if S.autoRepair and now - Auto.lastRepair >= 15 then Auto.lastRepair = now; chore("repair shop", repairShopPass) end
		end)
		if not ok then Auto.listNote = "Chores error: " .. tostring(err) end
		task.wait(1)
	end
end)

-- automation: one movement step at a time, never overlapping
task.spawn(function()
	while Hub.alive do
		local anyAuto = S.autoTake or S.autoOpen or S.autoRepair or S.autoUnload or S.autoAuction or S.autoAirdrop
		if anyAuto then
			-- waits its turn if a button (quick open, teleport, unload) is moving you;
			-- a step that freezes for 3 minutes is stopped so the loop carries on
			local ok, err, stuck = guardedLimit(Locks.body, "automation", 180, autoStep)
			Auto.phase = nil
			if stuck then
				Auto.stuckRecoveries = (Auto.stuckRecoveries or 0) + 1
				Auto.status = "A step froze and was stopped; carrying on"
				task.spawn(exitVehicle)
			elseif not ok then
				Auto.status = "Error: " .. tostring(err)
			end
		elseif not Locks.body.owner then
			Auto.status = A.active and ("In auction" .. (A.hasBlue and " (outlined item in lot)" or "")) or "Idle"
			if A.active and os.clock() - (Auto.lastScan or 0) > 1 then Auto.lastScan = os.clock(); scanLotForBlue() end
		end
		task.wait(0.5)
	end
end)

-- character tweaks and view refresh
task.spawn(function()
	while Hub.alive do
		local _, _, hum = getChar()
		if hum then
			if S.wsOn and hum.WalkSpeed ~= S.ws then hum.WalkSpeed = S.ws end
			if S.jpOn then
				if hum.UseJumpPower then
					if hum.JumpPower ~= S.jp then hum.JumpPower = S.jp end
				else
					local h = S.jp * S.jp / (2 * workspace.Gravity)
					if math.abs(hum.JumpHeight - h) > 0.01 then hum.JumpHeight = h end
				end
			end
		end
		pcall(refreshAirdrops)
		local R = revealApi()
		if R and A.garage then
			local t = R.garageSummary(A.garage)
			-- only trust the estimate once every item has been read
			A.lotEst = (t.named > 0 and t.pending == 0) and t.est or nil
			lotInfo(string.format("Lot ~%s: %d named, %d unknown, %d sealed%s", money(t.est), t.named, t.unknown, t.sealed,
				t.pending > 0 and string.format(", %d reading", t.pending) or ""))
		else
			A.lotEst = nil
			lotInfo(R and "Lot: join an auction to see its value" or "Lot: turn on Item reveal ESP to see values")
		end
		auctionInfo(string.format("%s  |  bids sent %d  |  auctions opened %d", A.status, A.bids, Auto.joined))
		local w, lim = cargoOf(myVehicle())
		keepInfo(keepSummary())
		pcall(refreshHome)
		itemsInfo(string.format("Taken %d, opened %d, repaired %d, favorited %d  |  cargo %.1f/%s",
			Auto.picked, Auto.opened, Auto.repaired, Auto.favorited, w, lim and tostring(lim) or "-"))
		plotInfo(string.format("%s  |  listed %d", Auto.listNote or "Shelves: -", Auto.listed))
		local working = Locks.body.owner or Locks.items.owner
		ui:SetStatus(Auto.status, working and "busy" or (Auto.status == "Idle" and "idle" or "ok"))
		-- admin safety: re-check every 5 s as a safety net, and show the state
		if os.clock() - (Auto.lastStaffCheck or 0) > 5 then Auto.lastStaffCheck = os.clock(); pcall(checkStaff) end
		if #Safety.staff > 0 then
			safetyInfo((Safety.override and "Override on. " or (Safety.paused and "Paused. " or "")) .. "Staff here: " .. staffNames(Safety.staff))
		else
			safetyInfo("No staff in this server")
		end
		if Safety.paused then ui:SetStatus("Paused: admin in server (Player tab to override)", "busy") end
		task.wait(0.3)
	end
end)

function Hub.stop()
	if not Hub.alive then return end
	Hub.alive = false
	if Hub.restorePrompts then pcall(Hub.restorePrompts) end
	local _, _, hum = getChar()
	if hum then
		if S.wsOn then hum.WalkSpeed = 16 end
		if S.jpOn then if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end end
	end
	-- if an admin pause switched features off, save them as you had them
	for k in pairs(Safety.snapshot or {}) do S[k] = true end
	pcall(function() writefile(SETTINGS_PATH, HttpService:JSONEncode(S)) end)
	Stats.save()
	local R = env.UAIAuctionReveal
	if R and R.headless and R.stop then pcall(R.stop) end
	pcall(function() markerFolder:Destroy() end)
	ui:Destroy()
	if env.SHHub == Hub then env.SHHub = nil end
end

Hub.S, Hub.A, Hub.Auto, Hub.ui = S, A, Auto, ui
Hub.quickBar = quickBar
Hub.checkStaff = checkStaff
Hub.wouldKeep = function(entry) -- for testing keep rules on an inventory entry
	local def = Items[tostring(entry.ItemId)]
	return def ~= nil and matchesKeepRule(def, entry, keepSets())
end
Hub.Safety = Safety
applyTheme() -- saved theme, applied once everything is built
checkStaff() -- now that every switch exists, pause at once if an admin is already here
if S.esp then setEsp(true) end
ui:SetStatus("Loaded", "ok")
return "loaded"
