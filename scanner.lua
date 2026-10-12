if game.PlaceId ~= 6839171747 then
	error("game is not supported!")
end
_getexecutorname = identifyexecutor or identify_executor or getexecutorname or get_executor_name or function()
	return "Unknown"
end
getexecutorname = function()
	return _getexecutorname():match("[%a%s]+")
end
setthreadcontext = setthreadcontext or set_thread_context
getthreadcontext = getthreadcontext or get_thread_context
restoremetamethod = restoremetamethod or restore_meta_method
restorefunction = restorefunction or restore_function
if not (hookfunction and hookmetamethod) then
	error(`executor is not supported! ({getexecutorname()})`)
end
if not (setthreadcontext and getthreadcontext and restoremetamethod and restorefunction) then
	warn(`this script might be broken with your executor! ({getexecutorname()})`)
end
setthreadcontext = setthreadcontext or function() end
getthreadcontext = getthreadcontext or function() end
restoremetamethod = restoremetamethod or function() end
restorefunction = restorefunction or function() end
const player = game.Players.LocalPlayer
const character = player.Character
local scanner = player.Backpack:FindFirstChild("ClientObjectScanner") or character:FindFirstChild("ClientObjectScanner")
if scanner and getgenv().CLIENT_SCANNER_LOADED then
	pcall(restoremetamethod, game, "__namecall")
	local old = getthreadcontext()
	setthreadcontext(2)
	pcall(restorefunction, require)
	setthreadcontext(old)
	scanner:Destroy()
	return
end

const root = "ClientObjectScanner"
local fs; fs = {
	rawurl = "https://raw.githubusercontent.com/tplaygd/Tplays-Addon-Stuff/main/",
	makefolder = function(path: string): ()
		makefolder(`{root}/{path}`)
	end,
	listfiles = function(path: string): {string}
		return listfiles(`{root}/{path}`)
	end,
	readfile = function(path: string): string
		return readfile(`{root}/{path}`)
	end,
	writefile = function(path: string, str: string): ()
		writefile(`{root}/{path}`, str)
	end,
	delfile = function(path: string): ()
		delfile(`{root}/{path}`)
	end,
	isfile = function(path: string): boolean
		return isfile(`{root}/{path}`)
	end,
	getcustomasset = getcustomasset and (getexecutorname() == "Potassium" and function(path: string): string
		const filename = path:gsub("[\\/]+", {
			["\\"] = "_",
			["/"] = "_"
		})
		writefile(filename, fs.readfile(path))
		task.delay(.1, delfile, filename)
		return getcustomasset(filename)
	end or function(path: string): string
		return getcustomasset(`{root}/{path}`)
	end)
}

makefolder(root)

fs.LoadCustomAsset = function(url: string, name: string?, cache_fallback: string?): string?
	if fs.getcustomasset and request then
		local fileName = `{name}` or `TMP_{tick()}`
		local success, result = pcall(fs.getcustomasset, fileName)
		result = success and result
		if result and not cache_fallback then
			return result
		elseif url:lower():sub(1, 4) == 'http' then
			local response = request({
				Url = url,
				Method = "GET"
			})
			if response.StatusCode == 200 then
				fs.writefile(fileName, response.Body)
				result = fs.getcustomasset(fileName)
				if not name then
					fs.delfile(fileName)
				end
				return result
			elseif result and cache_fallback then
				return result
			end
		elseif fs.isfile(url) then
			return fs.getcustomasset(url)
		end
	else
		warn("Executor doesn't support 'getcustomasset' or 'request', rbxassetid only.")
	end
	if url:find('rbxassetid') or tonumber(url) then
		return 'rbxassetid://'..url:match('%d+')
	end
	error(debug.traceback('Failed to load custom asset for:\n'..url))
end

fs.LoadCustomInstance = function(url: string, name: string?): Instance?
	local s, r = pcall(function()
		return game:GetObjects(fs.LoadCustomAsset(url, name))[1]
	end)
	return s and r or nil
end

const remotes = game.ReplicatedStorage.RemotesFolder
scanner = remotes.GetCleanTool:InvokeServer("ObjectScanner"):Clone()
scanner.Name = "ClientObjectScanner"
scanner.Parent = player.Backpack
scanner:SetAttribute("Durability", 1)
scanner:SetAttribute("DurabilityMax", nil)
const modules = {
	Flashlight = {HasScreen = true, Module = {
		Name = "Flashlight",
		Label = "FLASHLIGHT",
		Color = Color3.fromRGB(190, 196, 192),
		BootImage = "rbxassetid://71331205798383",
		BoxArt = "rbxassetid://71331205798383",
		Idle = "idleflash",
		Tags = {},
		Pulses = false,
		Drain = 0,
		PulseInterval = 3,
		PulseRange = 1,
		RevealTime = 1
	}},
	ThreatDetector = {Module = {
		Name = "ThreatDetector",
		Label = "THREAT DETECTOR",
		Color = Color3.fromRGB(255, 52, 52),
		FrameDark = 0.22,
		InnerDark = 0.45,
		BootImage = "rbxassetid://115800284312634",
		BoxArt = "rbxassetid://115800284312634",
		Tags = {
			ScannerThreat = "threat"
		},
		Drain = 0,
		PulseInterval = 2,
		PulseRange = 90,
		RevealTime = 1.5,
		FOVScale = 0.85
	}},
	Translator = {HasScreen = true, Module = loadstring([=[local TweenService = game:GetService("TweenService")
local TranslatorDialog = game.ReplicatedStorage.RemotesFolder:WaitForChild("TranslatorDialog")
local Rng = Random.new()
local Dictionary = {
    Name = "Translator",
    Label = "TRANSLATOR",
    Color = Color3.fromRGB(112, 87, 177),
    BootImage = "rbxassetid://129244684951811",
    BoxArt = "rbxassetid://129244684951811",
    Tags = {},
    Pulses = false,
    Drain = 2,
    PulseInterval = 3,
    PulseRange = 40,
    RevealTime = 1
}

local function Glyph()
    local Number = Rng:NextInteger(1, 41)
    return (string.sub("abcdefghijklmnopqrstuvwxyz0123456789#%&?!", Number, Number))
end

local function Decode(Arg, Label, Text, Duration, Session)
    local Array = {}
    local List = {}
    local List2 = {}

    for Index = 1, #Text do
        Array[Index] = string.sub(Text, Index, Index)
    end

    local function render(Arg)
        Label.Text = table.concat(List) .. (Arg or "")
    end

    for Key, Item in Array do
        if Arg.session ~= Session then
            return
        end

        if Item == " " then
            List[Key] = " "
            Label.Text = table.concat(List) .. ""
        else
            for _ = 1, Rng:NextInteger(2, 5) do
                local Number = Rng:NextInteger(1, 41)
                local Substring = string.sub("abcdefghijklmnopqrstuvwxyz0123456789#%&?!", Number, Number)
                Label.Text = table.concat(List) .. (Substring or "")
                task.wait(Duration)

                if Arg.session ~= Session then
                    return
                end
            end

            if Rng:NextNumber() < 0.15 then
                local Number = Rng:NextInteger(1, 41)
                List[Key] = string.sub("abcdefghijklmnopqrstuvwxyz0123456789#%&?!", Number, Number)
                table.insert(List2, Key)
            else
                List[Key] = Item
            end

            Label.Text = table.concat(List) .. ""
        end
    end

    for _, Item in List2 do
        task.wait(Duration * 4)

        for _ = 1, Rng:NextInteger(2, 4) do
            if Arg.session ~= Session then
                return
            end

            local Number = Rng:NextInteger(1, 41)
            List[Item] = string.sub("abcdefghijklmnopqrstuvwxyz0123456789#%&?!", Number, Number)
            Label.Text = table.concat(List) .. ""
            task.wait(Duration)
        end

        List[Item] = Array[Item]
        Label.Text = table.concat(List) .. ""
    end
end

local function Reset(Ui)
    for _, Item in { Ui.Speaker, Ui.Dialog } do
        Item.Text = ""
        Item.TextTransparency = 0
        local UIStroke = Item:FindFirstChildWhichIsA("UIStroke")

        if UIStroke then
            UIStroke.Transparency = 0
        end
    end
end

local function Waiting(Data, Session)
    Reset(Data.ui)
    Data.ui.Speaker.TextColor3 = Data.color
    local Count = 0

    while Data.session == Session do
        Data.ui.Speaker.Text = "WAITING" .. string.rep(".", Count)
        Count = (Count + 1) % 4
        task.wait(0.4)
    end
end

local function Fade(Arg, Session)
    task.wait(30)

    if Arg.session ~= Session then
        return
    end

    for _, Item in { Arg.ui.Speaker, Arg.ui.Dialog } do
        TweenService:Create(Item, TweenInfo.new(3), {
            TextTransparency = 1
        }):Play()
        local UIStroke = Item:FindFirstChildWhichIsA("UIStroke")

        if UIStroke then
            TweenService:Create(UIStroke, TweenInfo.new(3), {
                Transparency = 1
            }):Play()
        end
    end

    task.wait(3)

    if Arg.session ~= Session then
        return
    end

    Arg.session += 1
    task.spawn(Waiting, Arg, Arg.session)
end

function Dictionary:OnEnter()
    local Ui = self.ui

    if not Ui then
        return
    end

    Ui.Speaker.TextColor3 = self.color
    Ui.Dialog.TextColor3 = self.color
    self.session = 0
    task.spawn(Waiting, self, 0)
    self.translate = TranslatorDialog.OnClientEvent:Connect(function(Arg, Arg2, Arg3, Arg4)
        local self2 = self
        self2.session += 1
        local Session = self.session
        self.flash()
        Reset(Ui)
        task.spawn(Decode, self, Ui.Speaker, string.upper(Arg4 or ""), 0.02, Session)
        task.spawn(function()
            task.wait(0.15)
            Decode(self, Ui.Dialog, Arg2, 0.035, Session)
            Fade(self, Session)
        end)
    end)
end

function Dictionary:OnExit()
    if self.translate then
        self.translate:Disconnect()
        self.translate = nil
    end

    self.session = (self.session or 0) + 1

    if self.ui then
        Reset(self.ui)
    end
end

return Dictionary]=])()},
	Ransom = {Module = {
		Name = "Ransom",
		Label = "RANS0M",
		Color = Color3.fromRGB(95, 18, 18),
		BootImage = "rbxassetid://11924266902",
		BoxArt = "rbxassetid://11924266902",
		Tags = {},
		Pulses = false,
		Drain = 0,
		PulseInterval = 3,
		PulseRange = 1,
		RevealTime = 1
	}},
}
const fake_modules = {}
const order = {"Base", "Flashlight", "ThreatDetector", "Translator", "Ransom"}
local started = false
local loaded, loading = 0, 0
remotes.CaptionClient:Fire("loading modules...")
for name, module in modules do
	task.spawn(function()
		started = true
		loading += 1
		task.wait()
		const fake_module = Instance.new("ModuleScript")
		const path = "ClientObjectScanner/Screen/"..name
		const screen = module.HasScreen and fs.LoadCustomInstance(fs.rawurl..path, path)
		if screen then
			screen.Parent = fake_module
		end
		fake_modules[name] = fake_module
		loaded += 1
	end)
end
const timeout_load = os.clock()+5
repeat task.wait() until os.clock() >= timeout_load or (started and loaded >= loading)
local limit = 1
local current = 0
for _,_ in modules do limit += 1 end
const iModule = scanner and scanner:FindFirstChild("ToolClientModule")
const module = iModule and require(iModule)
local old = getthreadcontext()
setthreadcontext(2)
local req; req = hookfunction(require, function(module)
	for name, fake_module in fake_modules do
		if module == fake_module then
			return modules[name].Module
		end
	end
	return req(module)
end)
setthreadcontext(old)
local wait; wait = hookmetamethod(game, "__namecall", function(self, ...)
	if not checkcaller() and self == iModule and getnamecallmethod() == "FindFirstChild" then
		return fake_modules[({...})[1]] or wait(self, ...)
	end
	return wait(self, ...)
end)
const parent = debug.getupvalue(module.fire, 1)
const anims = parent.Animations
const handle = parent.Handle
const priorities = {
	idle_open = "Action2"
}
const activeAnims = {}
function setMode(mode)
	parent:SetAttribute("ScannerMode", mode)
end
function addAnim(anim, ...)
	if anims:FindFirstChild(anim) then
		local priority = priorities[anims[anim].Name]
		local anim2 = character.Humanoid:LoadAnimation(anims[anim])
		if priority then
			anim2.Priority = priority
		end
		activeAnims[anims[anim].Name] = anim2
		anim2:Play(...)
		if not anim2.Looped then
			ClientScanner.Connections[anim2] = anim2.Ended:Connect(function()
				pcall(game.Destroy, anim2)
			end)
		end
		return anim2
	end
end
function ok(anim, ...)
	anim = parent.Animations:FindFirstChild(anim)
	if anim then
		for _, anim2 in character.Humanoid:GetPlayingAnimationTracks() do
			if anim2.Animation.AnimationId == anim.AnimationId then
				anim2:Stop(...)
				anim2:Destroy()
			end
		end
	end
end
function stopAnim(anim, ...)
	if activeAnims[anim] then
		local connection = ClientScanner.Connections[activeAnims[anim]]
		if connection then
			connection:Disconnect()
			connection = nil
		end
		activeAnims[anim]:Stop(...)
		activeAnims[anim]:Destroy()
		activeAnims[anim] = nil
	else
		ok(anim, ...)
	end
end
const playingSounds = {}
function playSound(soundName)
	local sound = handle:FindFirstChild(soundName)
	sound = sound and sound:IsA("Sound") and sound
	if sound then
		playingSounds[soundName] = true
		sound:Play()
	end
end
function stopSound(soundName, reset)
	local sound = handle:FindFirstChild(soundName)
	sound = sound and sound:IsA("Sound") and sound
	if sound then
		playingSounds[soundName] = nil
		sound:Stop()
		sound.TimePosition = reset and 0 or sound.TimePosition
	end
end
local cd = -1/0
local inspecting = false
local hadRansom = false
function fire()
	if os.clock() < cd then return end
	cd = os.clock()+.66
	inspecting = false
	if inspect_task then
		task.cancel(inspect_task)
		inspect_task = nil
	end
	stopAnim("inspect", 0)
	stopAnim("inspect_open", 0)
	if hadRansom or math.random(0,100)~=0 then
		current = (current+1)%limit
	else
		current = #limit
	end
	local mode = current > 0 and order[current] or ""
	if current <= 0 then
		addAnim("close")
		addAnim("idle")
		stopAnim("idle_open", 0)
		stopAnim("idleflash", 0)
		playSound("CloseSystem")
		stopSound("BootSystem", true)
		stopSound("SystemIdle", true)
	elseif current == 1 then
		addAnim("open")
		addAnim("idle_open", .3)
		stopAnim("idle", 0)
		playSound("BootSystem")
		playSound("SystemIdle")
	elseif current > 1 then
		addAnim("next_mode")
		playSound("NextMode")
	end
	setMode(mode)
end
const inspect = parent.Inspect
parent.RemoteInspect.Name = "__RemoteInspect"
local inspectCd = -1/0
local prevMode = ""
ClientScanner = {
	Connections = {
		ModeChanged = parent:GetAttributeChangedSignal("ScannerMode"):Connect(function()
			local mode = parent:GetAttribute("ScannerMode") or ""
			if mode == "Ransom" then
				hadRansom = true
				parent:SetAttribute("CannotInspect", true)
				parent:SetAttribute("ScannerLock", true)
				parent:SetAttribute("DontUnequip", true)
				task.wait()
				player.PlayerGui.MainUI.Initiator.Main_Game.ToggleInventory:Fire(false)
				task.wait(3)
				parent:SetAttribute("CannotInspect", false)
				task.wait()
				inspect:Fire()
				task.wait()
				parent:SetAttribute("CannotInspect", true)
				task.wait(5)
				player.PlayerGui.MainUI.Initiator.Main_Game.ToggleInventory:Fire(true)
				parent:SetAttribute("CannotInspect", false)
				parent:SetAttribute("ScannerLock", false)
				parent:SetAttribute("DontUnequip", nil)
				inspecting = false
				if inspect_task then
					task.cancel(inspect_task)
					inspect_task = nil
				end
				stopAnim("inspect", 0)
				stopAnim("inspect_open", 0)
				current = 0
				addAnim("close")
				addAnim("idle")
				stopAnim("idle_open", 0)
				stopAnim("idleflash", 0)
				playSound("CloseSystem")
				stopSound("BootSystem", true)
				stopSound("SystemIdle", true)
				setMode("")
			end
			if mode == "Flashlight" then
				addAnim("idleflash")
				stopAnim("idle_open", 0)
				local Neon = handle:FindFirstChild("Neon")
				if Neon then
					if Neon:GetAttribute("BaseTransparency") == nil then
						Neon:SetAttribute("BaseTransparency", Neon.Transparency)
						Neon:SetAttribute("BaseMaterial", Neon.Material.Name)
						Neon:SetAttribute("BaseColor", Neon.Color)
					end
					Neon.Material = Enum.Material.Neon
					Neon.Color = Color3.fromRGB(222, 255, 232)
					Neon.Transparency = 0.1
					for _, Descendant in Neon:QueryDescendants("Light, ParticleEmitter, Beam") do
						Descendant.Enabled = true
					end
				end
				parent:SetAttribute("LightSourceStrong", true)
				parent:SetAttribute("LightSource", true)
				parent:SetAttribute("Enabled", true)
			elseif mode ~= "Flashlight" and prevMode == "Flashlight" then
				if mode ~= "" then
					addAnim("idle_open")
					stopAnim("idleflash", 0)
				end
				local Neon = handle:FindFirstChild("Neon")
				if Neon then
					Neon.Material = Enum.Material[Neon:GetAttribute("BaseMaterial") or "SmoothPlastic"]
					Neon.Color = Neon:GetAttribute("BaseColor") or Neon.Color
					Neon.Transparency = Neon:GetAttribute("BaseTransparency") or 1
					for _, Descendant in Neon:QueryDescendants("Light, ParticleEmitter, Beam") do
						Descendant.Enabled = false
					end
				end
				parent:SetAttribute("LightSourceStrong", nil)
				parent:SetAttribute("LightSource", nil)
				parent:SetAttribute("Enabled", false)
			end
			prevMode = mode or ""
		end),
		Equipped = parent.Equipped:Connect(function()
			local grip = character.RightHand:WaitForChild("RightGrip", 3)
			if grip then
				local motor6d = Instance.new("Motor6D", grip.Parent)
				motor6d.C0 = grip.C0
				motor6d.C1 = CFrame.new(-1.20000005, -0.150000006, 0.300000012, -1, 0, 0, 0, 1, 0, 0, 0, -1)
				motor6d.Name = "Handle"
				motor6d.Part0 = grip.Part0
				motor6d.Part1 = grip.Part1
				grip:Destroy()
			end
		end),
		Unequipped = parent.Unequipped:Connect(function()
			inspecting = false
			current = 0
			if inspect_task then
				task.cancel(inspect_task)
				inspect_task = nil
			end
			for sound, _ in playingSounds do
				stopSound(sound, true)
			end
			for anim, _ in activeAnims do
				stopAnim(anim)
			end
			setMode("")
			local motor6d = character.RightHand:WaitForChild("Handle", 3)
			if motor6d then
				motor6d:Destroy()
			end
		end),
		Inspect = inspect.Event:Connect(function()
			if os.clock() < cd then return end
			cd = os.clock()+.2
			if parent:GetAttribute("CannotInspect") then return end
			local mode = parent:GetAttribute("ScannerMode") or ""
			if mode == "" then
				stopAnim("inspect", 0)
				addAnim("inspect")
			elseif mode ~= "EGG" then
				if inspecting then
					inspecting = false
					if inspect_task then
						task.cancel(inspect_task)
						inspect_task = nil
					end
					local inspect_open = activeAnims["inspect_open"] or addAnim("inspect_open")
					inspect_open.TimePosition = 3
					inspect_open:AdjustSpeed(1)
				else
					inspecting = true
					stopAnim("inspect_open", 0)
					local inspect_anim = addAnim("inspect_open")
					inspect_task = task.delay(3, function()
						inspect_anim:AdjustSpeed(0)
						inspect_anim.TimePosition = 3
						inspect_task = nil
					end)
				end
			end
		end)
	}
}
hookfunction(module.fire, function()
	if parent:GetAttribute("ScannerLock") then
		return
	end
	fire()
end)
remotes.CaptionClient:Fire("script by @tplaygd, execute again to remove the scanner")
getgenv().CLIENT_SCANNER_LOADED = true
