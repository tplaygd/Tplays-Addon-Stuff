-- original version module: https://create.roblox.com/store/asset/112320879621247/Table-Viewer

--- Services ---
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

--- Types ---
export type Settings = {
	StartingSize: Vector2,

	MinSize: Vector2,
	MaxSize: Vector2,

	Expanded: boolean, -- Whether the table is expanded by default.
	NumberPrecision: number, -- Decimal places to show for numbers. -1 for no rounding.
	Font: Enum.Font, -- Font to use for the table headers/values.
	TextTruncateType: Enum.TextTruncate,

	TypeOrdering: {
		["boolean"]: number,
		["number"]: number,
		["string"]: number,
		["table"]: number,
		["function"]: number,
		["Instance"]: number,
		["Other"]: number, -- Enum, UDim2, Vector3, RaycastParams, etc.
	},

	SyntaxHighlighting: {
		["Default"]: Color3, -- Field title color.
		["boolean"]: Color3,
		["number"]: Color3,
		["string"]: Color3,
		["table"]: Color3,
		["function"]: Color3,
		["Instance"]: Color3,
		["Other"]: Color3, -- Enum, UDim2, Vector3, RaycastParams, etc.
	},
}

export type ViewerOptions = {
	Title: string,
	AppendWrenchEmoji: boolean,
	ShowTableValue: boolean,
	FilterOnType: boolean,
	CaseSensitive: boolean,
	OrderTablesBasedOffNumberOfElements: boolean,
	ShowExtraAnimationTrackData: boolean,
	Settings: Settings,
}

export type Table = { [any]: any }

export type TableViewer = {
	Data: Table,
	Options: ViewerOptions,

	Update: (self: TableViewer, newData: Table) -> (),
}

export type TableViewerPublic = {
	new: (data: Table, options: ViewerOptions?) -> TableViewer,
}

export type TableViewerGui = Frame & {
	Header: Frame & {
		HeaderLabel: TextLabel,
		HideButton: TextButton,
	},

	Footer: Frame & {
		Exclusions: TextBox,
		FieldFilter: TextBox,
		ResizeButton: TextButton,
	},

	Viewer: Frame & {
		Table: ScrollingFrame & {
			ListLayout: UIListLayout,
			UIPadding: UIPadding,
		},
	},

	UIDragDetector: UIDragDetector,
}

type EntryGui = ImageButton & {
	Children: Frame & {
		ListLayout: UIListLayout,
	},

	TitleBar: Frame & {
		ExpansionIcon: ImageButton,
		FieldValue: TextBox,
		Title: TextBox,
	},
}

type Association = {
	Key: string,
	Gui: EntryGui,
	Parent: Association?,
	Depth: number,
	Value: any,
}
type Associations = { [string]: Association | Associations }

type TableViewerPrivate = {
	Data: Table,
	Options: ViewerOptions,
	_associations: Associations,
	_keyFilters: { string },
	_typeExclusions: { string },
	_ui: TableViewerGui,

	Update: (self: TableViewerPrivate, newData: Table) -> (),
	_FormatFieldKey: (self: TableViewerPrivate, key: any) -> string,
	_FormatFieldValue: (self: TableViewerPrivate, value: any) -> string,
	_CreateBaseUI: (self: TableViewerPrivate) -> TableViewerGui,
	_CreateEntry: (self: TableViewerPrivate) -> EntryGui,
	_UpdateUI: (self: TableViewerPrivate, association: Association, depth: number?) -> (),
	_UpdateFiltersAndExclusions: (self: TableViewerPrivate) -> (),
	_UpdateAssociations: (self: TableViewerPrivate, lastData: Table?) -> (),
}

--- Variables ---
local KEYS = {
	RemovalKey = "__MARKED_FOR_REMOVAL__",
}

local DEFAULT_SETTINGS = {
	StartingSize = Vector2.new(300, 400),

	MinSize = Vector2.new(200, 44),
	MaxSize = Vector2.new(8192, 8192),

	Expanded = false,
	NumberPrecision = -1,
	Font = "SourceSansPro",
	TextTruncateType = Enum.TextTruncate.SplitWord,

	TypeOrdering = {
		-- These are in the thousands to account for the amount of elements in a table.
		["boolean"] = 1000,
		["number"] = 2000,
		["string"] = 3000,
		["Instance"] = 4000,
		["Other"] = 5000,
		["function"] = 6000,
		["table"] = 7000,
	},

	SyntaxHighlighting = {
		["Default"] = Color3.fromRGB(200, 200, 200),
		["boolean"] = Color3.fromRGB(86, 156, 214),
		["number"] = Color3.fromRGB(181, 206, 168),
		["string"] = Color3.fromRGB(206, 145, 120),
		["table"] = Color3.fromRGB(224, 167, 86),
		["function"] = Color3.fromRGB(197, 134, 192),
		["Instance"] = Color3.fromRGB(78, 201, 176),
		["Other"] = Color3.fromRGB(86, 156, 214),
	},
} :: Settings

local DEFAULT_VIEWER_OPTIONS = {
	Title = "Table Viewer",
	AppendWrenchEmoji = true,
	ShowTableValue = true,
	FilterOnType = true,
	CaseSensitive = false, -- Case sensitivity for filters and exclusions.
	OrderTablesBasedOffNumberOfElements = true,
	ShowExtraAnimationTrackData = true,
	Settings = DEFAULT_SETTINGS,
} :: ViewerOptions

--- Functions ---
local function DeepClone(tbl: Table): Table
	if typeof(tbl) ~= "table" then
		return tbl
	end

	local clone: Table = {}
	for key, value in tbl do
		if typeof(value) == "table" then
			clone[key] = DeepClone(value)
		else
			clone[key] = value
		end
	end

	return clone
end

local function GetDiff(new: Table, old: Table): Table
	-- Support non-tables. Note: this means this function technically returns any (and the parameters are also any).
	-- However, it's being kept as "Table" because that's the primary use-case.
	if typeof(new) ~= "table" or typeof(old) ~= "table" then
		return new
	end

	if not next(old) then
		return new
	end

	-- Track removed items.
	local function TrackDeletions(current: Table, previous: Table, diffRef: Table)
		for key, previousValue in previous do
			local currentValue = current[key]
			if typeof(currentValue) == "table" and typeof(previousValue) == "table" then
				diffRef[key] = diffRef[key] or {}
				TrackDeletions(currentValue, previous[key], diffRef[key])
				if not next(diffRef[key]) then
					diffRef[key] = nil
				end
			elseif currentValue == nil then
				diffRef[key] = KEYS.RemovalKey
			end
		end
	end
	local diff: Table = {}
	TrackDeletions(new, old, diff)

	-- Track new and changed items.
	local function TrackMutations(current: Table, previous: Table, diffRef: Table)
		for key, currentValue in current do
			local previousValue = previous[key]
			if typeof(currentValue) == "table" and typeof(previousValue) == "table" then
				diffRef[key] = diffRef[key] or {}
				TrackMutations(currentValue, previousValue, diffRef[key])
				if not next(diffRef[key]) then
					diffRef[key] = nil
				end
			elseif currentValue ~= previousValue then
				diffRef[key] = currentValue
			end
		end
	end
	TrackMutations(new, old, diff)

	return diff
end

local function Patch(src: Table, patch: Table): Table
	for key, patchValue in patch do
		if patchValue == KEYS.RemovalKey then
			src[key] = nil
		elseif typeof(patchValue) == "table" and typeof(src[key]) == "table" then
			src[key] = Patch(src[key], patchValue)
		else
			src[key] = patchValue
		end
	end

	return src
end

local function GetN(tbl: Table): number
	local n = 0
	for _ in tbl do
		n += 1
	end

	return n
end

local function GetInstancePath(instance: Instance?, includeInstance: boolean?): string
	local function IsService(serviceName: string): boolean
		local successful: boolean, isActuallyService: boolean = pcall(function()
			local service = game:GetService(serviceName)
			if not service then
				return false
			end

			return true
		end)
		return successful and isActuallyService
	end

	local function SanitizePathSegment(segment: string): string
		if IsService(segment) then
			return `game:GetService("{segment}")`
		end

		if segment:find("^%d+") or segment:find("[^%w_]") then
			return `["{segment}"]`
		else
			return `.{segment}`
		end
	end

	if not instance then
		return "nil"
	end

	includeInstance = includeInstance ~= false
	if instance == game then
		return if includeInstance then "game" else "nil"
	end

	local path = ""
	local parent = if includeInstance then instance else instance.Parent
	while parent do
		local segment = parent.Name
		path = `{SanitizePathSegment(segment)}{path}`
		if IsService(segment) then
			return path
		end
		parent = parent.Parent
	end

	return path
end

--- Table Viewer ---
local TableViewer = {}
TableViewer.__index = TableViewer

function TableViewer.new(data: Table, options: ViewerOptions?): TableViewer
	options = (
		if options then Patch(DeepClone(DEFAULT_VIEWER_OPTIONS), options) else DeepClone(DEFAULT_VIEWER_OPTIONS)
	) :: ViewerOptions
	local viewer = setmetatable({
		Data = DeepClone(data),
		Options = options,

		_associations = {} :: Associations,
		_keyFilters = {},
		_typeExclusions = {},
	}, TableViewer) :: TableViewerPrivate

	-- Create initial UI and associations.
	viewer._ui = viewer:_CreateBaseUI()
	viewer:_UpdateAssociations()

	-- Create and parent UI.
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TableViewer"
	screenGui.ResetOnSpawn = false
	viewer._ui.Parent = screenGui
	screenGui.Parent = gethui()

	return viewer :: TableViewer
end

function TableViewer:Update(newData: Table)
	local lastData = self.Data
	self.Data = DeepClone(newData)
	self:_UpdateAssociations(lastData)
end

function TableViewer:_FormatFieldKey(key: any): string
	self = self :: TableViewerPrivate

	local keyType = typeof(key)
	if keyType == "string" then
		return key
	elseif keyType == "number" or keyType == "function" or keyType == "table" then
		return tostring(key)
	else
		return `<{keyType}> ({tostring(key)})`
	end
end

function TableViewer:_FormatFieldValue(value: any): string
	self = self :: TableViewerPrivate

	if typeof(value) == "table" then
		if self.Options.ShowTableValue then
			return `<Table> ({GetN(value)} Items)`
		else
			return ""
		end
	elseif typeof(value) == "function" then
		return "<Function>"
	elseif typeof(value) == "string" then
		return `"{value}"`
	elseif typeof(value) == "Instance" then
		if value.ClassName == "AnimationTrack" and self.Options.ShowExtraAnimationTrackData then
			local animationTrack = value :: AnimationTrack
			return `<AnimationTrack: {animationTrack.Animation.AnimationId}> ({animationTrack.Priority.Name}, {animationTrack.Looped}, {animationTrack.Length}, {animationTrack.Speed})`
		else
			return `<Instance: {value.ClassName}> ({GetInstancePath(value)})`
		end
	elseif typeof(value) == "number" then
		local precision = self.Options.Settings.NumberPrecision
		if precision >= 0 then
			return (`%.{precision}f`):format(value):gsub("(%.%d-)0+$", "%1"):gsub("%.$", "")
		else
			return tostring(value)
		end
	else
		local valueAsString = tostring(value)
		local precision = self.Options.Settings.NumberPrecision
		if valueAsString:find("%d") and precision >= 0 then
			-- If there is a number in this value type, then update precision inline.
			for number in valueAsString:gmatch("%-?%d+%.?%d+") do
				valueAsString = valueAsString:gsub(
					number,
					((`%.{precision}f`):format(number):gsub("(%.%d-)0+$", "%1"):gsub("%.$", ""))
				)
			end

			return `<{typeof(value)}> ({valueAsString})`
		else
			return tostring(value)
		end
	end
end

function TableViewer:_CreateBaseUI(): TableViewerGui
	self = self :: TableViewerPrivate

	local Frame1 = Instance.new("Frame")
	Frame1.Name = "TableViewer"
	Frame1.BorderSizePixel = 0
	Frame1.Size = UDim2.fromOffset(self.Options.Settings.StartingSize.X, self.Options.Settings.StartingSize.Y)
	Frame1.BorderColor3 = Color3.new(0, 0, 0)
	Frame1.Position = UDim2.new(0.2710728049278259, 0, 0.3370607793331146, 0)
	Frame1.BackgroundTransparency = 0.5
	Frame1.BackgroundColor3 = Color3.new(0.121569, 0.121569, 0.121569)

	local Frame2 = Instance.new("Frame")
	Frame2.Name = "Header"
	Frame2.BorderSizePixel = 0
	Frame2.Size = UDim2.new(1, 0, 0, 24)
	Frame2.BorderColor3 = Color3.new(0, 0, 0)
	Frame2.BackgroundTransparency = 0.5
	Frame2.BackgroundColor3 = Color3.new(0.243137, 0.243137, 0.243137)
	Frame2.Parent = Frame1

	local TextButton1 = Instance.new("TextButton")
	TextButton1.AutoButtonColor = false
	TextButton1.Name = "HideButton"
	TextButton1.TextSize = 14
	TextButton1.FontFace = Font.new(
		`rbxasset://fonts/families/{self.Options.Settings.Font}.json`,
		Enum.FontWeight.Regular,
		Enum.FontStyle.Normal
	)
	TextButton1.AnchorPoint = Vector2.new(1, 0)
	TextButton1.Size = UDim2.new(0, 24, 0, 24)
	TextButton1.Position = UDim2.new(1, 0, 0, 0)
	TextButton1.TextColor3 = Color3.new(0.784314, 0.784314, 0.784314)
	TextButton1.Text = "🔼"
	TextButton1.BackgroundTransparency = 1
	TextButton1.Parent = Frame2

	local TextLabel1 = Instance.new("TextLabel")
	TextLabel1.FontFace =
		Font.new(`rbxasset://fonts/families/SourceSansPro.json`, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	TextLabel1.Name = "HeaderLabel"
	TextLabel1.AnchorPoint = Vector2.new(0.5, 0)
	TextLabel1.AutomaticSize = Enum.AutomaticSize.X
	TextLabel1.TextSize = 14
	TextLabel1.Size = UDim2.new(0, 0, 0, 24)
	TextLabel1.TextColor3 = Color3.new(0.862745, 0.862745, 0.862745)
	TextLabel1.Text = `{if self.Options.AppendWrenchEmoji then "🔧  " else ""}{self.Options.Title}`
	TextLabel1.BackgroundTransparency = 1
	TextLabel1.Position = UDim2.new(0.5, 0, 0, 0)
	TextLabel1.Parent = Frame2

	local Frame3 = Instance.new("Frame")
	Frame3.Name = "Footer"
	Frame3.AnchorPoint = Vector2.new(0, 1)
	Frame3.BorderSizePixel = 0
	Frame3.Size = UDim2.new(1, 0, 0, 20)
	Frame3.BorderColor3 = Color3.new(0, 0, 0)
	Frame3.Position = UDim2.new(0, 0, 1, 0)
	Frame3.BackgroundTransparency = 0.5
	Frame3.BackgroundColor3 = Color3.new(0.243137, 0.243137, 0.243137)
	Frame3.Parent = Frame1

	local TextButton2 = Instance.new("TextButton")
	TextButton2.TextWrapped = true
	TextButton2.AutoButtonColor = false
	TextButton2.Name = "ResizeButton"
	TextButton2.TextScaled = true
	TextButton2.FontFace =
		Font.new(`rbxasset://fonts/families/SourceSansPro.json`, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	TextButton2.AnchorPoint = Vector2.new(1, 1)
	TextButton2.Size = UDim2.new(0, 16, 0, 16)
	TextButton2.Position = UDim2.new(1, -1, 1, -1)
	TextButton2.TextColor3 = Color3.new(0.784314, 0.784314, 0.784314)
	TextButton2.Text = "↘️"
	TextButton2.BackgroundTransparency = 1
	TextButton2.Parent = Frame3

	local TextBox1 = Instance.new("TextBox")
	TextBox1.TextWrapped = true
	TextBox1.Active = false
	TextBox1.Name = "FieldFilter"
	TextBox1.FontFace =
		Font.new(`rbxasset://fonts/families/SourceSansPro.json`, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	TextBox1.Size = UDim2.new(0.43799999356269836, 0, 1, 0)
	TextBox1.Selectable = false
	TextBox1.Position = UDim2.new(0, 4, 0, 0)
	TextBox1.PlaceholderText = "Field Filter"
	TextBox1.TextColor3 = Color3.new(0, 0.666667, 0)
	TextBox1.Text = ""
	TextBox1.BackgroundTransparency = 1
	TextBox1.TextXAlignment = Enum.TextXAlignment.Left
	TextBox1.ClearTextOnFocus = false
	TextBox1.TextSize = 14
	TextBox1.Parent = Frame3

	local TextBox2 = Instance.new("TextBox")
	TextBox2.TextWrapped = true
	TextBox2.Active = false
	TextBox2.Name = "Exclusions"
	TextBox2.FontFace =
		Font.new(`rbxasset://fonts/families/SourceSansPro.json`, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	TextBox2.Size = UDim2.new(0.5, -20, 1, 0)
	TextBox2.Selectable = false
	TextBox2.Position = UDim2.new(0.5, 0, 0, 0)
	TextBox2.PlaceholderText = "Type Exclusions"
	TextBox2.TextColor3 = Color3.new(0.784314, 0, 0)
	TextBox2.Text = ""
	TextBox2.CursorPosition = -1
	TextBox2.BackgroundTransparency = 1
	TextBox2.TextXAlignment = Enum.TextXAlignment.Left
	TextBox2.ClearTextOnFocus = false
	TextBox2.TextSize = 14
	TextBox2.Parent = Frame3

	local Frame4 = Instance.new("Frame")
	Frame4.Name = "Viewer"
	Frame4.BorderSizePixel = 0
	Frame4.Size = UDim2.new(1, 0, 1, -44)
	Frame4.BorderColor3 = Color3.new(0, 0, 0)
	Frame4.Position = UDim2.new(0, 0, 0, 24)
	Frame4.BackgroundTransparency = 0.5
	Frame4.BackgroundColor3 = Color3.new(0.121569, 0.121569, 0.121569)
	Frame4.Parent = Frame1

	local ScrollingFrame1 = Instance.new("ScrollingFrame")
	ScrollingFrame1.Active = true
	ScrollingFrame1.BorderSizePixel = 0
	ScrollingFrame1.CanvasSize = UDim2.new(0, 0, 0, 0)
	ScrollingFrame1.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	ScrollingFrame1.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	ScrollingFrame1.Name = "Table"
	ScrollingFrame1.Size = UDim2.new(1, 0, 1, 0)
	ScrollingFrame1.BorderColor3 = Color3.new(0, 0, 0)
	ScrollingFrame1.ScrollBarThickness = 4
	ScrollingFrame1.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ScrollingFrame1.BackgroundTransparency = 1
	ScrollingFrame1.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	ScrollingFrame1.BackgroundColor3 = Color3.new(1, 1, 1)
	ScrollingFrame1.Parent = Frame4

	local UIListLayout1 = Instance.new("UIListLayout")
	UIListLayout1.HorizontalAlignment = Enum.HorizontalAlignment.Right
	UIListLayout1.Name = "ListLayout"
	UIListLayout1.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout1.Parent = ScrollingFrame1

	local UIPadding1 = Instance.new("UIPadding")
	UIPadding1.PaddingRight = UDim.new(0, 8)
	UIPadding1.PaddingLeft = UDim.new(0, 3)
	UIPadding1.Parent = ScrollingFrame1

	local UIDragDetector1 = Instance.new("UIDragDetector")
	UIDragDetector1.DragRelativity = Enum.UIDragDetectorDragRelativity.Relative
	UIDragDetector1.Parent = Frame1

	do -- Handle resizing.
		local resizing = false
		local offsetFromResizeButton = Vector2.zero
		TextButton2.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end

			local mousePosition = Vector2.new(input.Position.X, input.Position.Y)
			offsetFromResizeButton = (Frame1.AbsolutePosition + Frame1.AbsoluteSize) - mousePosition
			resizing = true
		end)

		UserInputService.InputChanged:Connect(function(input: InputObject)
			if not resizing or input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			local mousePosition = Vector2.new(input.Position.X, input.Position.Y)
			local size = mousePosition - Frame1.AbsolutePosition + offsetFromResizeButton
			local x = math.clamp(size.X, self.Options.Settings.MinSize.X, self.Options.Settings.MaxSize.X)
			local y = math.clamp(size.Y, self.Options.Settings.MinSize.Y, self.Options.Settings.MaxSize.Y)
			Frame1.Size = UDim2.fromOffset(x, y)
		end)

		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end

			resizing = false
		end)
	end

	do -- Handle hiding and showing.
		local lastSize = Frame1.Size
		TextButton1.Activated:Connect(function()
			local visible = not Frame3.Visible
			if visible then
				Frame1.Size = lastSize
				TextLabel1.AnchorPoint = Vector2.new(0.5, 0)
				TextLabel1.Position = UDim2.fromScale(0.5, 0)
				Frame3.Visible = true
				Frame4.Visible = true
				TextButton1.Text = "🔼"
			else
				lastSize = Frame1.Size
				Frame1.Size = UDim2.fromOffset(TextLabel1.AbsoluteSize.X + 30, 24)
				TextLabel1.AnchorPoint = Vector2.new(0, 0)
				TextLabel1.Position = UDim2.fromOffset(5, 0)
				Frame3.Visible = false
				Frame4.Visible = false
				TextButton1.Text = "🔽"
			end
		end)
	end

	do -- Handle filters and exclusions.
		local function UpdateFilters()
			local caseSensitive = self.Options.CaseSensitive
			self._keyFilters = (if caseSensitive then TextBox1.Text else TextBox1.Text:lower()):split(",")
			if self._keyFilters[1] == "" then
				table.clear(self._keyFilters)
			end
			self:_UpdateFiltersAndExclusions()
		end

		local function UpdateExclusions()
			local caseSensitive = self.Options.CaseSensitive
			self._typeExclusions = (if caseSensitive then TextBox2.Text else TextBox2.Text:lower()):split(",")
			if self._typeExclusions[1] == "" then
				table.clear(self._typeExclusions)
			end
			self:_UpdateFiltersAndExclusions()
		end

		if self.Options.FilterOnType then
			TextBox1:GetPropertyChangedSignal("Text"):Connect(UpdateFilters)
			TextBox2:GetPropertyChangedSignal("Text"):Connect(UpdateExclusions)
		else
			TextBox1.FocusLost:Connect(UpdateFilters)
			TextBox2.FocusLost:Connect(UpdateExclusions)
		end
	end

	return Frame1
end

function TableViewer:_CreateEntry(name: string, association: Association): EntryGui
	self = self :: TableViewerPrivate

	local ImageButton1 = Instance.new("ImageButton")
	ImageButton1.BorderSizePixel = 0
	ImageButton1.AutoButtonColor = false
	ImageButton1.BackgroundColor3 = Color3.new(1, 1, 1)
	ImageButton1.Name = "FieldTitle"
	ImageButton1.BackgroundTransparency = 1
	ImageButton1.AutomaticSize = Enum.AutomaticSize.Y
	ImageButton1.Size = UDim2.new(1, 0, 0, 0)
	ImageButton1.BorderColor3 = Color3.new(0, 0, 0)

	local Frame1 = Instance.new("Frame")
	Frame1.Name = "Children"
	Frame1.BorderSizePixel = 0
	Frame1.AutomaticSize = Enum.AutomaticSize.Y
	Frame1.Size = UDim2.new(1, 0, 0, 0)
	Frame1.BorderColor3 = Color3.new(0, 0, 0)
	Frame1.Position = UDim2.new(0, 0, 0, 20)
	Frame1.BackgroundTransparency = 1
	Frame1.BackgroundColor3 = Color3.new(1, 1, 1)
	Frame1.Parent = ImageButton1

	local UIListLayout1 = Instance.new("UIListLayout")
	UIListLayout1.Name = "ListLayout"
	UIListLayout1.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout1.Parent = Frame1

	local Frame2 = Instance.new("Frame")
	Frame2.Name = "TitleBar"
	Frame2.BorderSizePixel = 0
	Frame2.Size = UDim2.new(1, 0, 0, 20)
	Frame2.BorderColor3 = Color3.new(0, 0, 0)
	Frame2.BackgroundTransparency = 1
	Frame2.AnchorPoint = Vector2.new(1, 0)
	Frame2.Position = UDim2.fromScale(1, 0)
	Frame2.BackgroundColor3 = Color3.new(1, 1, 1)
	Frame2.Parent = ImageButton1

	local ImageButton2 = Instance.new("ImageButton")
	ImageButton2.BorderSizePixel = 0
	ImageButton2.ScaleType = Enum.ScaleType.Fit
	ImageButton2.AutoButtonColor = false
	ImageButton2.Name = "ExpansionIcon"
	ImageButton2.BackgroundTransparency = 1
	ImageButton2.Image = "rbxassetid://8445470826"
	ImageButton2.ImageRectSize = Vector2.new(96, 96)
	ImageButton2.Size = UDim2.new(0, 20, 0, 20)
	ImageButton2.BorderColor3 = Color3.new(0, 0, 0)
	ImageButton2.Visible = false
	ImageButton2.ImageRectOffset = Vector2.new(404, 404)
	ImageButton2.Parent = Frame2

	local TextBox1 = Instance.new("TextBox")
	TextBox1.TextWrapped = true
	TextBox1.TextTruncate = self.Options.Settings.TextTruncateType
	TextBox1.TextEditable = false
	TextBox1.Name = "FieldValue"
	TextBox1.FontFace = Font.new(
		`rbxasset://fonts/families/{self.Options.Settings.Font}.json`,
		Enum.FontWeight.Regular,
		Enum.FontStyle.Normal
	)
	TextBox1.Size = UDim2.new(0.75, -10, 0, 20)
	TextBox1.AnchorPoint = Vector2.new(1, 0)
	TextBox1.Selectable = false
	TextBox1.Position = UDim2.new(1, 0, 0, 0)
	TextBox1.TextColor3 = Color3.new(0.878431, 0.654902, 0.337255)
	TextBox1.Text = ""
	TextBox1.BackgroundTransparency = 1
	TextBox1.TextXAlignment = Enum.TextXAlignment.Right
	TextBox1.ClearTextOnFocus = false
	TextBox1.TextSize = 14
	TextBox1.Parent = Frame2

	local TextBox2 = Instance.new("TextBox")
	TextBox2.TextTruncate = self.Options.Settings.TextTruncateType
	TextBox2.BorderSizePixel = 0
	TextBox2.TextEditable = false
	TextBox2.Name = "Title"
	TextBox2.BackgroundColor3 = Color3.new(1, 1, 1)
	TextBox2.FontFace = Font.new(
		`rbxasset://fonts/families/{self.Options.Settings.Font}.json`,
		Enum.FontWeight.Regular,
		Enum.FontStyle.Normal
	)
	TextBox2.Size = UDim2.new(0.25, -10, 0, 20)
	TextBox2.Selectable = false
	TextBox2.Position = UDim2.new(0, 4, 0, 0)
	TextBox2.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	TextBox2.BorderColor3 = Color3.new(0, 0, 0)
	TextBox2.Text = tostring(name)
	TextBox2.BackgroundTransparency = 1
	TextBox2.TextXAlignment = Enum.TextXAlignment.Left
	TextBox2.ClearTextOnFocus = false
	TextBox2.TextSize = 14
	TextBox2.Parent = Frame2

	-- Handle expanding and collapsing.
	if typeof(association.Value) == "table" then
		local function Expand(expanded: boolean?)
			expanded = if expanded == nil then not (ImageButton2.Image == "rbxassetid://8445470826") else expanded
			if expanded then
				ImageButton2.Image = "rbxassetid://8445470826"
				ImageButton2.ImageRectOffset = Vector2.new(404, 404)
				ImageButton2.ImageRectSize = Vector2.new(96, 96)
			else
				ImageButton2.Image = "rbxassetid://114955670841058"
				ImageButton2.ImageRectOffset = Vector2.zero
				ImageButton2.ImageRectSize = Vector2.zero
			end
			Frame1.Visible = expanded
		end

		ImageButton2.Activated:Connect(function()
			Expand()
		end)
		Expand(self.Options.Settings.Expanded)
	end

	-- Parent entry.
	if association.Parent and association.Parent.Gui then
		ImageButton1.Parent = association.Parent.Gui.Children
	else
		ImageButton1.Parent = self._ui.Viewer.Table
	end

	-- Display entry based off filters and exclusions.
	if self._keyFilters[1] and typeof(association.Value) ~= "table" then
		local visible = false
		for _, filter in self._keyFilters do
			local key = tostring(association.Key)
			key = if self.Options.CaseSensitive then key else key:lower()
			if typeof(key) == "string" and key:find(filter) or typeof(key) == "number" and key == filter then
				visible = true
				break
			end
		end
		ImageButton1.Visible = visible
	else
		ImageButton1.Visible = true
	end
	if self._typeExclusions[1] then
		local caseSensitive = self.Options.CaseSensitive
		for _, exclusion in self._typeExclusions do
			local valueType = if caseSensitive then typeof(association.Value) else typeof(association.Value):lower()
			if valueType == exclusion then
				ImageButton1.Visible = false
				break
			end
		end
	end

	return ImageButton1
end

function TableViewer:_UpdateUI(association: Association, depth: number?)
	self = self :: TableViewerPrivate

	local highlighting = self.Options.Settings.SyntaxHighlighting
	local gui = association.Gui
	local value = association.Value
	local canExpand = typeof(value) == "table" and GetN(value) > 0
	gui.TitleBar.FieldValue.Text = self:_FormatFieldValue(value)
	gui.TitleBar.Title.TextColor3 = highlighting.Default
	gui.TitleBar.FieldValue.TextColor3 = highlighting[typeof(value)] or highlighting.Other
	gui.TitleBar.Size = UDim2.new(1, -16 * (depth or association.Depth), 0, 20)
	gui.TitleBar.ExpansionIcon.Visible = canExpand
	gui.TitleBar.Title.Text = self:_FormatFieldKey(association.Key)
	if canExpand then
		gui.TitleBar.Title.Position = UDim2.fromOffset(20, 0)
		gui.TitleBar.Title.Size = UDim2.new(0.563, -40, 0, 20)
	else
		gui.TitleBar.Title.Position = UDim2.fromOffset(4, 0)
		gui.TitleBar.Title.Size = UDim2.new(0.563, -24, 0, 20)
	end
end

function TableViewer:_UpdateFiltersAndExclusions()
	self = self :: TableViewerPrivate

	local function ForceShow(association: Association)
		association.Gui.Visible = true
		if typeof(association.Value) == "table" then
			for _, child in association.Value do
				ForceShow(child)
			end
		end
	end

	local function Update(root: Associations)
		local filters = self._keyFilters
		local exclusions = self._typeExclusions
		local caseSensitive = self.Options.CaseSensitive
		for _, association in root do
			if not association.Gui then
				continue
			end

			-- Update visibility.
			if filters[1] and typeof(association.Value) ~= "table" then
				local visible = false
				for _, filter in filters do
					local key = tostring(association.Key)
					key = if caseSensitive then key else key:lower()
					if typeof(key) == "string" and key:find(filter) or typeof(key) == "number" and key == filter then
						visible = true
						break
					end
				end
				association.Gui.Visible = visible
			else
				association.Gui.Visible = true
			end
			if exclusions[1] then
				for _, exclusion in exclusions do
					local valueType = if caseSensitive
						then typeof(association.Value)
						else typeof(association.Value):lower()
					if valueType == exclusion then
						association.Gui.Visible = false
						break
					end
				end
			end

			-- Recurse.
			if association.Gui.Visible and typeof(association.Value) == "table" then
				local forceShow = false
				for _, filter in filters do
					local key = tostring(association.Key)
					key = if self.Options.CaseSensitive then key else key:lower()
					if typeof(key) == "string" and key:find(filter) or typeof(key) == "number" and key == filter then
						forceShow = true
					end
				end

				if forceShow then
					-- If the table's key is in the filter, force show it and all its descendants.
					ForceShow(association)
				else
					Update(association.Value)
				end
			end
		end
	end

	local function AtLeastOneVisible(association: Association): boolean
		if typeof(association.Value) == "table" then
			for _, child in association.Value do
				if AtLeastOneVisible(child) then
					return true
				end
			end
		else
			return association.Gui.Visible
		end
	end

	local function HideEmptyTables(root: Associations)
		for _, association in root do
			if not association.Gui then
				continue
			end

			if typeof(association.Value) == "table" then
				if not AtLeastOneVisible(association) then
					association.Gui.Visible = false
				end
				HideEmptyTables(association.Value)
			end
		end
	end

	Update(self._associations)
	HideEmptyTables(self._associations)
end

function TableViewer:_UpdateAssociations(lastData: Table?)
	self = self :: TableViewerPrivate

	local function Update(diff: Table, associations: Associations, depth: number?)
		depth = depth or 0
		for key, value in diff do
			if value == KEYS.RemovalKey then
				local association
				if associations[key] then
					association = associations[key]
					associations[key] = nil
				elseif typeof(associations.Value) == "table" then
					association = associations.Value[key]
					associations.Value[key] = nil
				end
				if association and association.Gui then
					pcall(game.Destroy, association.Gui)
				end

				continue
			end

			if typeof(value) == "table" then
				local existingAssociation
				if typeof(associations[key]) == "table" then
					existingAssociation = associations[key]
				elseif typeof(associations.Value) == "table" then
					existingAssociation = associations.Value[key]
				end

				if not existingAssociation then
					existingAssociation = {
						Key = key,
						Parent = associations,
						Depth = depth,
						Value = {}, -- Child associations.
					}
					existingAssociation.Gui = self:_CreateEntry(key, existingAssociation)
					if typeof(associations.Value) == "table" then
						associations.Value[key] = existingAssociation
					else
						associations[key] = existingAssociation
					end
				end
				Update(value, existingAssociation, depth + 1)
				self:_UpdateUI(existingAssociation, depth)
			else
				local childAssociation
				local association = associations[key]
				if typeof(associations.Value) == "table" then
					-- This is a parent association.
					childAssociation = associations.Value[key]
					if not childAssociation then
						childAssociation = {
							Key = key,
							Parent = associations,
							Depth = depth,
							Value = value,
						}
						childAssociation.Gui = self:_CreateEntry(key, childAssociation)
						associations.Value[key] = childAssociation
					else
						-- Update existing association.
						childAssociation.Value = value
					end
				elseif association == nil then
					-- New association that is not a table.
					childAssociation = {
						Key = key,
						Parent = associations,
						Depth = depth,
						Value = value,
					}
					childAssociation.Gui = self:_CreateEntry(key, childAssociation)
					associations[key] = childAssociation
				else
					-- Update existing association.
					childAssociation = association
					childAssociation.Value = value
				end
				self:_UpdateUI(childAssociation, depth)
				if childAssociation.Parent and childAssociation.Parent.Gui then
					self:_UpdateUI(childAssociation.Parent)
				end
			end
		end
	end

	local function UpdateOrder(diff: Table, associations: Associations)
		for key, value in diff do
			if value == KEYS.RemovalKey then
				continue
			end

			local keys = {}
			local association = if typeof(associations.Value) == "table"
				then associations.Value[key]
				else associations[key]
			if typeof(association.Parent.Value) == "table" then
				for _, assoc in association.Parent.Value do
					table.insert(keys, assoc.Key)
				end
			elseif not association.Parent.Key then
				for _, assoc in association.Parent do
					table.insert(keys, assoc.Key)
				end
			end
			table.sort(keys, function(a: any, b: any)
				-- Numbers before strings.
				if typeof(a) == "number" and typeof(b) == "string" then
					return true
				elseif typeof(a) == "string" and typeof(b) == "number" then
					return false
				end

				if typeof(a) == "number" and typeof(b) == "number" then
					return a < b
				else
					return tostring(a):lower() < tostring(b):lower()
				end
			end)
			local extraOrder = self.Options.Settings.TypeOrdering[typeof(value)]
				or self.Options.Settings.TypeOrdering.Other
			association.Gui.LayoutOrder = (table.find(keys, association.Key) or 0) + extraOrder

			if typeof(association.Value) == "table" then
				if self.Options.OrderTablesBasedOffNumberOfElements then
					association.Gui.LayoutOrder += GetN(association.Value) * 100
				end
				UpdateOrder(value, association)
			end
		end
	end

	local diff = GetDiff(self.Data, lastData or {})
	Update(diff, self._associations)
	UpdateOrder(diff, self._associations)
end

return TableViewer :: TableViewerPublic
