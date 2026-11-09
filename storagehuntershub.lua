-- Storage Hunters Hub 3.6 (Storage Hunters: Open World)
-- Made by conradium, commissioned by rsl.
-- Auto bid, auto open auctions and airdrops, take/open/repair won items, favorites,
-- shelf listing, teleports and movement. Settings are saved.
-- Toggle the window with Right Ctrl. Stop: getgenv().SHHub.stop()

local env = getgenv()
if env.SHHub and type(env.SHHub.stop) == "function" then pcall(env.SHHub.stop) end
local Hub = { alive = true, version = "3.6.0" }
env.SHHub = Hub
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
	local self = setmetatable({ tabs = {}, conns = {}, alive = true, values = {}, onChange = nil }, Kit)
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

	local collapsed = false
	local function setCollapsed(on)
		collapsed = on
		tween(main, { Size = UDim2.fromOffset(width, on and 44 or height) }, 0.2)
		minimize.Text = on and "+" or "-"
	end
	minimize.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end)
	close.MouseButton1Click:Connect(function() self:Destroy() end)
	local key = opts.ToggleKey or Enum.KeyCode.RightControl
	self.toggleKey = key
	self.switches, self.chips = {}, {}
	table.insert(self.conns, UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if self.capturing then self:_capture(input.KeyCode); return end
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == key then main.Visible = not main.Visible; return end
		local binds = self.values.keybinds
		local id = type(binds) == "table" and binds[input.KeyCode.Name]
		local sw = id and self.switches[id]
		if sw then
			sw.flip()
			self:SetStatus(sw.text .. ": " .. (self.values[id] and "on" or "off"), "ok")
		end
	end))
	self.onClose = opts.OnClose
	return self
end

-- Quick bar at the top centre of the screen.
-- items: { { Icon = "emoji", Label = "text", Callback = fn }, ... }
function Kit:Bar(items)
	local bar = new("Frame", {
		Name = "QuickBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(0, 60), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.08, BorderSizePixel = 0,
	}, self.gui)
	corner(bar, 12)
	stroke(bar, C.line)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, bar)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, bar)
	for i, item in ipairs(items) do
		local b = new("TextButton", {
			Text = "", AutoButtonColor = false, BackgroundColor3 = C.row, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(66, 48), LayoutOrder = i,
		}, bar)
		corner(b, 8)
		label(b, item.Icon or "", 20, C.text, FONT, {
			Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 2), TextXAlignment = Enum.TextXAlignment.Center,
		})
		local caption = label(b, item.Label or "", 11, C.sub, FONT_MED, {
			Size = UDim2.new(1, -4, 0, 16), Position = UDim2.fromOffset(2, 28), TextXAlignment = Enum.TextXAlignment.Center,
		})
		b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0 }); tween(caption, { TextColor3 = C.text }) end)
		b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }); tween(caption, { TextColor3 = C.sub }) end)
		b.MouseButton1Click:Connect(function()
			task.spawn(function()
				local ok, err = pcall(item.Callback)
				if not ok then self:SetStatus("Error: " .. tostring(err)) end
			end)
		end)
	end
	return bar
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

-- Keybinds: values.keybinds maps a KeyCode name to a switch Id.
function Kit:_binds()
	if type(self.values.keybinds) ~= "table" then self.values.keybinds = {} end
	return self.values.keybinds
end

function Kit:_paintChips()
	local byId = {}
	for keyName, id in pairs(self:_binds()) do byId[id] = keyName end
	for id, chip in pairs(self.chips) do
		local k = byId[id]
		chip.Text = k and k:gsub("^Left", "L"):gsub("^Right", "R") or "+"
		chip.TextColor3 = k and C.text or C.faint
	end
end

function Kit:_capture(keyCode)
	local id = self.capturing
	self.capturing = nil
	local binds = self:_binds()
	if keyCode ~= Enum.KeyCode.Escape then
		for k, v in pairs(binds) do if v == id then binds[k] = nil end end
		if keyCode ~= Enum.KeyCode.Backspace and keyCode ~= Enum.KeyCode.Delete and keyCode ~= self.toggleKey then
			binds[keyCode.Name] = id -- a key drives one switch; this replaces any older use
		end
		self:_set("keybinds", binds, true)
	end
	self:_paintChips()
end

-- A small key chip on a switch row; click it, then press a key.
function Kit:_bindChip(row, x, id, text, flip)
	self.switches[id] = { text = text, flip = flip }
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
	self.statusText.Text = text
	self.statusDot.BackgroundColor3 = state == "busy" and C.accent or (state == "ok" and C.good or C.faint)
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
		BackgroundColor3 = C.panel, BackgroundTransparency = 1, AutoButtonColor = false, Text = name, TextSize = 13,
		Font = FONT_MED, TextColor3 = C.sub, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = #self.tabs + 1,
	}, self.tabBar)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, button)
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

function Tab:_row(height)
	local row = new("Frame", { BackgroundColor3 = C.row, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height or 38), LayoutOrder = self:_next() }, self.page)
	corner(row, 8)
	return row
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

function Tab:Section(text)
	local l = label(self.page, string.upper(text), 11, C.faint, FONT_BOLD, { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = self:_next() })
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 6) }, l)
	return l
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
	if o.Bind ~= false then kit:_bindChip(row, -92, o.Id, o.Text, function() api.Set(not kit.values[o.Id], true) end) end
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
	kit:_bindChip(row, -198, o.Id, o.Text, function() api.SetOn(not kit.values[o.Id], true) end)
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
local SETTINGS_PATH = DIR .. "/hub_settings.json"
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
	if lock == Locks.body then Auto.busy = true end
	local result = table.pack(pcall(fn, ...))
	lock.owner = nil
	if lock == Locks.body then Auto.busy = false end
	if not result[1] then return false, result[2] end
	return true, table.unpack(result, 2, result.n)
end
local function runBody(who, fn, ...) return guarded(Locks.body, who, fn, ...) end
local function runItems(who, fn, ...) return guarded(Locks.items, who, fn, ...) end

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

local function firePrompt(p)
	if not (p and p.Parent) then return false end
	if p.HoldDuration > 0 then p.HoldDuration = 0 end
	if type(fireproximityprompt) == "function" and pcall(fireproximityprompt, p) then return true end
	return (pcall(function() p:InputHoldBegin(); task.wait(0.05); p:InputHoldEnd() end))
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
	pcall(LP.RequestStreamAroundAsync, LP, pos, 3)
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
	if prompt then firePrompt(prompt) end
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

local function scanLotForBlue()
	local g = A.garage
	local floor = g and g:FindFirstChild("Floorspace")
	local found = false
	for _, m in ipairs(floor and floor:GetChildren() or {}) do
		if m:IsA("Model") then
			local spot = m:GetAttribute("SpotOutline")
			if spot == true or spot == LP.UserId then spotted[m] = true end
			if spotted[m] or m:GetAttribute("PlayAuraSound") == true then found = true end
		end
	end
	A.hasBlue = found
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
	-- 1. an outlined (blue) item: take this lot, skip the other checks
	scanLotForBlue()
	if A.hasBlue then A.filter, A.filterWhy = "pass", "outlined item in the lot"; return end
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
	if type(cash) == "number" and price > cash - S.keepCash then A.status = "Not enough cash for " .. money(price); return end
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
	pcall(LP.RequestStreamAroundAsync, LP, g:GetPivot().Position, 3)
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
	placeNear(part.Position, 2.5)
	task.wait(0.4)
	firePrompt(prompt)
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
local okAirCfg, AirCfg = pcall(require, Modules:FindFirstChild("MilitaryAirdropConfig"))
if not okAirCfg or type(AirCfg) ~= "table" then AirCfg = {} end
local AIR_TAG = AirCfg.Tag or "MilitaryAirdrop"
local AIR_GARAGE = AirCfg.GarageId or "Camo Airdrop"
local AIR_ATTR = type(AirCfg.Attributes) == "table" and AirCfg.Attributes or {}
local AIR_STATE = AIR_ATTR.State or "AirdropState"
local AIR_EXPIRES = AIR_ATTR.ExpiresAt or "AirdropExpiresAt"
local airDef = okGarages and type(GarageDefs) == "table" and GarageDefs[AIR_GARAGE] or {}
local AIR_MIN_WORTH = tonumber(airDef.MinNetWorth) or 0
local AIR_FEE = type(airDef.EntryCost) == "table" and tonumber(airDef.EntryCost.Max or airDef.EntryCost.Min) or 0
local CollectionService = game:GetService("CollectionService")

local function airdropTimeLeft(inst)
	local expires = tonumber(inst:GetAttribute(AIR_EXPIRES))
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
		if g:GetAttribute("GarageId") == AIR_GARAGE and pos then
			local d = (g:GetPivot().Position - pos).Magnitude
			if d < 80 and (not bestD or d < bestD) then best, bestD = g, d end
		end
	end
	return best
end

local function airdropSummary()
	local falling, landed, nearest = 0, 0, nil
	for _, inst in ipairs(CollectionService:GetTagged(AIR_TAG)) do
		local state = inst:GetAttribute(AIR_STATE)
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
	if netWorth() < AIR_MIN_WORTH then
		return false, string.format("needs %s net worth, you have %s", money(AIR_MIN_WORTH), money(netWorth()))
	end
	local cash = tonumber(LP:GetAttribute("Cash")) or 0
	if cash - AIR_FEE < S.keepCash then return false, "not enough cash for the " .. money(AIR_FEE) .. " entry" end
	return true
end

-- Picks the landed crate to open: not in an auction, not about to vanish, nearest first.
local function nextAirdrop()
	local _, hrp = getChar()
	local best, bestD
	for _, inst in ipairs(CollectionService:GetTagged(AIR_TAG)) do
		local left = airdropTimeLeft(inst)
		local g = inst:GetAttribute(AIR_STATE) == "landed" and (left or 0) > 25 and airdropGarage(inst)
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
		if not Hub.alive then return end
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

local function keepSummary()
	if not S.autoFav then return "Auto favorite is off" end
	local parts = {}
	if S.favGearMin > 0 then parts[#parts + 1] = "gear worth " .. money(S.favGearMin) .. "+" end
	if #(S.favGearMuts or {}) > 0 then parts[#parts + 1] = "gear with " .. table.concat(S.favGearMuts, " or ") end
	if S.favGavel then
		parts[#parts + 1] = #(S.favGavelMuts or {}) > 0 and ("gavels with " .. table.concat(S.favGavelMuts, " or ")) or "all gavels"
	end
	if #(S.favItems or {}) > 0 then parts[#parts + 1] = #S.favItems .. " always-keep item(s)" end
	return #parts > 0 and ("Keeps: " .. table.concat(parts, ", ")) or "No keep rules set"
end

-- True when an inventory entry should never leave: already favorited, or it
-- matches a keep rule (even if auto favorite has not reached it yet).
local function isKept(e)
	if type(e) ~= "table" then return true end
	if e.Favorited == true then return true end
	if not (S.autoFav and keepRulesActive()) then return false end
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
		if not Hub.alive then return end
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
			Auto.lastList = 0
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
		pcall(LP.RequestStreamAroundAsync, LP, pt, 3)
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
	Auto.lastList = 0 -- put the unloaded items on shelves soon
	Auto.status = string.format("Unloaded %d item(s) at your plot; cargo %d%%", #guids, math.floor(cargoPct()))
	return "wait"
end

local function listPass()
	if not Rm.ShelfAutoStock then return end
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

local ui = Kit.Window({ Title = "Storage Hunters", Credit = "by conradium · commissioned by rsl", OnClose = function() Hub.stop() end })
ui.values = S
S.keybinds = type(saved.keybinds) == "table" and saved.keybinds or {}
ui.onChange = function(id, value)
	queueSave()
	if id == "shopBar" then if Hub.quickBar then Hub.quickBar.Visible = value end
	elseif id == "esp" then setEsp(value)
	elseif id == "espDistance" or id == "espMinConf" then applyEsp() end
end

local auction = ui:Tab("Auction")
auction:Section("Bidding")
auction:Toggle({ Id = "autoBid", Text = "Auto bid", Hint = "Bids whenever you are outbid", Default = D("autoBid", false) })
auction:Number({ Id = "maxBid", Text = "Max bid", Hint = "0 = no limit", Default = D("maxBid", 0), Min = 0, Prefix = "$" })
auction:Number({ Id = "blueMaxBid", Text = "Max bid with an outlined item", Hint = "Ignores lot value; 0 = same as max bid", Default = D("blueMaxBid", 0), Min = 0, Prefix = "$" })
auction:Number({ Id = "keepCash", Text = "Always keep cash", Default = D("keepCash", 0), Min = 0, Prefix = "$" })
auction:Number({ Id = "bidDelay", Text = "Bid delay", Default = D("bidDelay", 0.35), Min = 0.05, Max = 3, Suffix = "s" })
auction:Number({ Id = "bidPctOfValue", Text = "Max bid as % of lot value", Hint = "Uses the item reveal estimate; 0 = off", Default = D("bidPctOfValue", 0), Min = 0, Max = 1000, Suffix = "%" })
auction:Section("Lot filter")
auction:Toggle({ Id = "lotFilter", Text = "Check lots before bidding", Hint = "Lots with an outlined item always pass", Default = D("lotFilter", false) })
auction:Number({ Id = "minStartBid", Text = "Starting bid at least", Hint = "0 = any", Default = D("minStartBid", 0), Min = 0, Prefix = "$" })
auction:List({ Id = "lotMuts", Text = "Lot has a mutation", Hint = "At least one item with any of these", Multi = true, Options = mutationNames, Default = D("lotMuts", {}), Empty = "Any" })
auction:Toggle({ Id = "leaveFailed", Text = "Leave lots that fail", Hint = "Moves on at once; skips that garage 5 min (no fee refund)", Default = D("leaveFailed", true) })
auction:Section("Item reveal")
auction:Toggle({ Id = "esp", Text = "Item reveal ESP", Hint = "Names hidden items and X-rayed boxes", Default = D("esp", false) })
auction:Number({ Id = "espDistance", Text = "Label distance", Default = D("espDistance", 150), Min = 50, Max = 500, Suffix = " studs" })
auction:Number({ Id = "espMinConf", Text = "Minimum match confidence", Default = D("espMinConf", 25), Min = 0, Max = 100, Suffix = "%" })
local lotInfo = auction:Info("Lot: -")
auction:Section("Airdrops")
auction:Toggle({ Id = "airdropAlerts", Text = "Airdrop alerts", Hint = "Pop-up when crates fall and land", Default = D("airdropAlerts", true) })
auction:Toggle({ Id = "airdropMarkers", Text = "Airdrop markers", Hint = "Countdown label on each crate", Default = D("airdropMarkers", true) })
auction:Toggle({ Id = "autoAirdrop", Text = "Auto open airdrops", Hint = "Needs " .. money(AIR_MIN_WORTH) .. " net worth; before normal auctions", Default = D("autoAirdrop", false) })
local airInfo = auction:Info("Airdrops: none right now")
auction:Section("Where")
auction:List({ Id = "areas", Text = "Areas", Hint = "Where to open auctions", Multi = true, Options = areaNames, Default = D("areas", {}), Empty = "All" })
auction:Choice({ Id = "garagePick", Text = "Garage choice", Options = { "Nearest", "Cheapest", "Priciest" }, Default = D("garagePick", "Nearest") })
auction:Number({ Id = "maxEntry", Text = "Max entry fee", Hint = "0 = any", Default = D("maxEntry", 0), Min = 0, Prefix = "$" })
auction:Toggle({ Id = "autoAuction", Text = "Auto open auctions", Hint = "Opens the next garage when you are free", Default = D("autoAuction", false) })
auction:Toggle({ Id = "bringCar", Text = "Bring car to auctions", Hint = "Parks your car outside the garage before opening it", Default = D("bringCar", false) })
auction:Button({ Text = "Quick open auction", Action = "Open", Callback = function()
	if A.active then ui:SetStatus("Already in an auction", "ok"); return end
	local ok, err = runBody("quick open", joinAuction)
	if not ok then Auto.status = "Open failed: " .. tostring(err) end
end })
auction:Button({ Text = "Leave current auction", Action = "Leave", Callback = function() invoke(Rm.LeaveAuction) end })
local auctionInfo = auction:Info("Waiting for auction")

local itemsTab = ui:Tab("Items")
itemsTab:Section("After winning")
itemsTab:Toggle({ Id = "autoTake", Text = "Auto take items", Hint = "Adds won items to your vehicle", Default = D("autoTake", false) })
itemsTab:Number({ Id = "minTake", Text = "Minimum value to take", Hint = "Cheaper items are left behind", Default = D("minTake", 0), Min = 0, Prefix = "$" })
itemsTab:Toggle({ Id = "takeBlue", Text = "Always take outlined items", Hint = "Blue or white outline; ignores the minimum", Default = D("takeBlue", true) })
itemsTab:List({ Id = "takeMuts", Text = "Always take mutations", Hint = "Ignores the minimum for these", Multi = true, Options = mutationNames, Default = D("takeMuts", {}), Empty = "None" })
itemsTab:List({ Id = "takeNames", Text = "Always take", Hint = "These items, ignoring the minimum", Multi = true, Options = itemNames, Default = D("takeNames", {}), Empty = "None" })
itemsTab:Toggle({ Id = "autoOpen", Text = "Auto open boxes", Default = D("autoOpen", false) })
itemsTab:Toggle({ Id = "autoRepair", Text = "Auto repair", Hint = "Wrench on won items, plus repair shop slots", Default = D("autoRepair", false) })
itemsTab:Section("Keep (favorite)")
itemsTab:Toggle({ Id = "autoFav", Text = "Auto favorite", Hint = "Kept items are never listed or sold", Default = D("autoFav", false) })
local keepInfo = itemsTab:Info("-")
itemsTab:Number({ Id = "favGearMin", Text = "Gear minimum price", Hint = "Keep gear worth at least this; 0 = off", Default = D("favGearMin", 0), Min = 0, Prefix = "$" })
itemsTab:List({ Id = "favGearMuts", Text = "Gear mutations", Hint = "Keep gear with any of these, at any price", Multi = true, Options = mutationNames, Default = D("favGearMuts", {}), Empty = "None" })
itemsTab:Toggle({ Id = "favGavel", Text = "Gavel", Hint = "Keep Gavel trophies", Default = D("favGavel", false) })
itemsTab:List({ Id = "favGavelMuts", Text = "Gavel mutations", Hint = "Only gavels with any of these; none = all", Multi = true, Options = mutationNames, Default = D("favGavelMuts", {}), Empty = "Any" })
itemsTab:List({ Id = "favItems", Text = "Always keep", Hint = "These items at any value", Multi = true, Options = itemNames, Default = D("favItems", {}), Empty = "None" })
itemsTab:Button({ Text = "Favorite matching items now", Action = "Run", Callback = function() runItems("favorite", favoritePass) end })
local itemsInfo = itemsTab:Info("-")

local plotTab = ui:Tab("Plot")
plotTab:Section("Shelves")
plotTab:Toggle({ Id = "autoList", Text = "Auto list on shelves", Hint = "Fills free slots with unfavorited items", Default = D("autoList", false) })
plotTab:Number({ Id = "listMin", Text = "Only list items worth at least", Hint = "0 = no minimum", Default = D("listMin", 0), Min = 0, Prefix = "$" })
plotTab:Number({ Id = "listMax", Text = "Only list items worth at most", Hint = "0 = no maximum", Default = D("listMax", 0), Min = 0, Prefix = "$" })
plotTab:Button({ Text = "Fill shelves now", Action = "Fill", Callback = function() runItems("list", listPass) end })
local function goToPlot()
	if not Rm.TeleportToPlot then return end
	runBody("plot teleport", function()
		Rm.TeleportToPlot:FireServer()
		task.wait(1)
	end)
	ui:SetStatus("Teleported to your plot", "ok")
end
plotTab:Button({ Text = "Go to my plot", Action = "Go", Callback = goToPlot })
plotTab:Section("Vehicle")
plotTab:Toggle({ Id = "autoUnload", Text = "Auto unload at plot", Hint = "Pauses auctions and unloads when cargo is high", Default = D("autoUnload", false) })
plotTab:Number({ Id = "dumpAt", Text = "Unload when cargo reaches", Hint = "Auctions resume 30 points below this", Default = D("dumpAt", 85), Min = 40, Max = 100, Suffix = "%" })
plotTab:Toggle({ Id = "unloadAnywhere", Text = "Try unloading without moving", Hint = "Falls back to driving to the plot if refused", Default = D("unloadAnywhere", true) })
local function unloadNow()
	if Locks.body.owner then ui:SetStatus("Unload queued after " .. Locks.body.owner, "busy") end
	local ok, err = runBody("unload", dumpStep, true)
	if not ok then Auto.status = "Unload error: " .. tostring(err) end
end
plotTab:Button({ Text = "Unload vehicle now", Action = "Unload", Callback = unloadNow })
local plotInfo = plotTab:Info("-")

-- Top bar: one button per shop screen, plus your plot.
local SHOP_LOOK = {
	RepairShop = { "🔧", "Repair" }, LocksmithShop = { "🔑", "Locksmith" }, WashShop = { "🧼", "Wash" },
	CleaningShop = { "🧴", "Sprays" }, GradingShop = { "🏅", "Grading" }, VehicleDealership = { "🚗", "Cars" },
	TrailerShop = { "🚚", "Trailers" }, EnergyShop = { "☕", "Drinks" }, Clubs = { "👥", "Clubs" },
	PawnShop = { "💰", "Pawn" }, Authentication = { "🔍", "Authenticate" },
}
local barItems = {
	{ Icon = "🏠", Label = "Plot", Callback = goToPlot },
	{ Icon = "📦", Label = "Unload", Callback = unloadNow },
}
for _, name in ipairs(shopNames) do
	local look = SHOP_LOOK[shopScreens[name].screen] or { "🛒", name:match("^(.-) %(") or name }
	barItems[#barItems + 1] = { Icon = look[1], Label = look[2], Callback = function()
		local ok, err = openShop(name)
		if not ok then ui:SetStatus("Could not open " .. look[2] .. ": " .. tostring(err)) end
	end }
end
local quickBar = ui:Bar(barItems)

local moveTab = ui:Tab("Move")
moveTab:Section("Shops")
moveTab:Toggle({ Id = "shopBar", Text = "Shop bar at the top", Hint = "One button per shop screen", Default = D("shopBar", true) })
quickBar.Visible = S.shopBar
moveTab:Section("Teleport")
moveTab:Button({ Text = "Go to my plot", Action = "Go", Callback = goToPlot })
local placePick = moveTab:List({ Id = "tpPlace", Text = "Place", Multi = false, Options = placeNames, Empty = "Pick one" })
moveTab:Button({ Text = "Go to place", Action = "Go", Callback = function()
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
moveTab:List({ Id = "tpPlayer", Text = "Player", Multi = false, Options = playerNames, Empty = "Pick one" })
moveTab:Button({ Text = "Go to player", Action = "Go", Callback = function()
	local p = S.tpPlayer and Players:FindFirstChild(S.tpPlayer)
	local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if hrp then runBody("teleport", tpTo, hrp.Position + Vector3.new(3, 0, 0)) else ui:SetStatus("Player has no character") end
end })
moveTab:Section("Movement")
moveTab:Toggle({ Id = "wsOn", Text = "Walk speed", Default = D("wsOn", false) })
moveTab:Number({ Id = "ws", Text = "Speed", Default = D("ws", 32), Min = 16, Max = 150 })
moveTab:Toggle({ Id = "jpOn", Text = "Jump power", Default = D("jpOn", false) })
moveTab:Number({ Id = "jp", Text = "Power", Default = D("jp", 75), Min = 50, Max = 250 })
moveTab:Toggle({ Id = "infJump", Text = "Infinite jump", Default = D("infJump", false) })
moveTab:Toggle({ Id = "noclip", Text = "Noclip", Default = D("noclip", false) })
moveTab:Toggle({ Id = "antiAfk", Text = "Anti AFK", Default = D("antiAfk", true) })
S.tpPlace, S.tpPlayer = nil, nil -- not worth remembering between sessions
placePick.Set(nil, false)

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
on(Rm.OfferOverweight and Rm.OfferOverweight.OnClientEvent, function() Auto.overweightAt = os.clock() end)

-- a sale frees a shelf slot: fill it again soon
on(Rm.CashEffect and Rm.CashEffect.OnClientEvent, function()
	Auto.lastList = math.min(Auto.lastList, os.clock() - 6)
end)

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
local AIR_COLOR = typeof(AirCfg.MarkerColor) == "Color3" and AirCfg.MarkerColor or Color3.fromRGB(150, 170, 90)

local function refreshAirdrops()
	local tagged = CollectionService:GetTagged(AIR_TAG)
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
				local state = inst:GetAttribute(AIR_STATE)
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
	if S.autoOpen and openBoxes() then return end
	local items = S.autoTake and takeable() or {}
	local full = vehicleFull(items)
	if S.autoTake and #items > 0 and not full then takeItems(items); return end
	local high = full or cargoPct() >= S.dumpAt
	if S.autoUnload and (Auto.dumping or high) then
		Auto.dumping = true
		if now - Auto.lastDeposit < 5 then return end -- keep the paused status between rounds
		Auto.lastDeposit = now
		if dumpStep() == "wait" then return end
		Auto.dumping = false
		high = vehicleFull({}) or cargoPct() >= S.dumpAt
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
				local done, why = runItems(name, fn)
				if not done then Auto.listNote = name .. ": " .. tostring(why) end
			end
			if S.autoFav and now - Auto.lastFav >= 20 then Auto.lastFav = now; chore("auto favorite", favoritePass) end
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
			-- waits its turn if a button (quick open, teleport, unload) is moving you
			local ok, err = runBody("automation", autoStep)
			if not ok then Auto.status = "Error: " .. tostring(err) end
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
		itemsInfo(string.format("Taken %d, opened %d, repaired %d, favorited %d  |  cargo %.1f/%s",
			Auto.picked, Auto.opened, Auto.repaired, Auto.favorited, w, lim and tostring(lim) or "-"))
		plotInfo(string.format("%s  |  listed %d", Auto.listNote or "Shelves: -", Auto.listed))
		local working = Locks.body.owner or Locks.items.owner
		ui:SetStatus(Auto.status, working and "busy" or (Auto.status == "Idle" and "idle" or "ok"))
		task.wait(0.3)
	end
end)

function Hub.stop()
	if not Hub.alive then return end
	Hub.alive = false
	local _, _, hum = getChar()
	if hum then
		if S.wsOn then hum.WalkSpeed = 16 end
		if S.jpOn then if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end end
	end
	pcall(function() writefile(SETTINGS_PATH, HttpService:JSONEncode(S)) end)
	local R = env.UAIAuctionReveal
	if R and R.headless and R.stop then pcall(R.stop) end
	pcall(function() markerFolder:Destroy() end)
	ui:Destroy()
	if env.SHHub == Hub then env.SHHub = nil end
end

Hub.S, Hub.A, Hub.Auto, Hub.ui = S, A, Auto, ui
Hub.quickBar = quickBar
if S.esp then setEsp(true) end
ui:SetStatus("Loaded", "ok")
return "loaded"
