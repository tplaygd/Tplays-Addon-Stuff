const player = game.Players.LocalPlayer
const character = player.Character
local briefcase = player.Backpack:FindFirstChild("ClientBriefcase") or character:FindFirstChild("ClientBriefcase")

if briefcase then
	briefcase:Destroy()
	return
end

const RunService = game:GetService("RunService")
const remotes = game.ReplicatedStorage.RemotesFolder
briefcase = remotes.GetCleanTool:InvokeServer("Briefcase"):Clone()
briefcase:SetAttribute("DurabilityBar", nil)
briefcase:SetAttribute("DurabilityMax", 0)
briefcase:SetAttribute("DurabilitySlots", nil)
local ToolClientModule = game:GetService("ReplicatedStorage").RankInfo:Clone()
ToolClientModule.Name = "ToolClientModule"
ToolClientModule.Parent = briefcase
ToolClientModule = require(ToolClientModule)
table.clear(ToolClientModule)

const anims = briefcase.Animations
const handle = briefcase.Handle
const activeAnims = {}
const priorities = {}

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
			ClientBriefcase.Connections[anim2] = anim2.Ended:Connect(function()
				pcall(game.Destroy, anim2)
			end)
		end
		return anim2
	end
end

function ok(anim, ...)
	anim = briefcase.Animations:FindFirstChild(anim)
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
		local connection = ClientBriefcase.Connections[activeAnims[anim]]
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
const items = {}
const icons = {}

const FlashSpecify = remotes.FlashSpecify

ToolClientModule.fire = function()
	if os.clock() < cd then return end
	cd = os.clock()+.66
	if briefcase:GetAttribute("Durability") then
		stopAnim("inspect", 0)
		addAnim("throw")
		playSound("sound_throw")
		local item = items[#items]
		table.remove(items, #items)
		table.remove(icons, #icons)
		item:SetAttribute("ClientBriefcased")
		item:PivotTo(item:GetPivot()-item:GetPivot().Position+character:GetPivot().Position)
		task.spawn(function()
			for _ = 1,3 do
				local main = item:FindFirstChild("Main") or item:FindFirstChildWhichIsA("BasePart")
				if main then
					main.AssemblyLinearVelocity = workspace.CurrentCamera.CFrame.LookVector*20+character.PrimaryPart.AssemblyLinearVelocity
				end
				task.wait()
			end
		end)
		firesignal(FlashSpecify.OnClientEvent, 
			"ManageContents",
			briefcase,
			icons,
			icons
		)
		briefcase:SetAttribute("Durability", briefcase:GetAttribute("Durability")-1)
	end
end

const inspect = Instance.new("BindableEvent", briefcase)
inspect.Name = "Inspect"
briefcase.RemoteInspect.Name = "__RemoteInspect"
local inspectCd = -1/0

function grabbed(drop)
	addAnim("offhand")
	playSound("sound_offhand")
	if not drop:GetAttribute("ClientBriefcased") then
		drop:SetAttribute("ClientBriefcased", true)
		table.insert(items, drop)
		table.insert(icons, "rbxassetid://0")
		briefcase:SetAttribute("Durability", briefcase:GetAttribute("Durability")+1)
		firesignal(FlashSpecify.OnClientEvent, 
			"ManageContents",
			briefcase,
			icons,
			icons
		)
	end
end

function disconnectConnections(t)
	for _, c in t do
		if typeof(c) == "table" then
			disconnectConnections(c)
		elseif typeof(c) == "RBXScriptConnection" and c.Disconnect then
			pcall(c.Disconnect)
		end
	end
end

ClientBriefcase = {
	Connections = {
		Equipped = briefcase.Equipped:Connect(function()
			if not ClientBriefcase then return end
			addAnim("idle")
			local grip = character.RightHand:WaitForChild("RightGrip", 3)
			if grip then
				local motor6d = Instance.new("Motor6D", grip.Parent)
				motor6d.C0 = grip.C0
				motor6d.C1 = grip.C1
				motor6d.Name = "Handle"
				motor6d.Part0 = grip.Part0
				motor6d.Part1 = grip.Part1
				grip:Destroy()
			end
			for _, drop in workspace.Drops:QueryDescendants("> Model") do
				drop.ClientPrompt.Enabled = true
				drop.ModulePrompt.Enabled = false
			end
		end),
		Unequipped = briefcase.Unequipped:Connect(function()
			if not ClientBriefcase then return end
			for sound, _ in playingSounds do
				stopSound(sound, true)
			end
			for anim, _ in activeAnims do
				stopAnim(anim)
			end
			for _, drop in workspace.Drops:QueryDescendants("> Model") do
				drop.ClientPrompt.Enabled = false
				drop.ModulePrompt.Enabled = true
			end
			local motor6d = character.RightHand:WaitForChild("Handle", 3)
			if motor6d then
				motor6d:Destroy()
			end
		end),
		Inspect = inspect.Event:Connect(function()
			if not ClientBriefcase then return end
			if os.clock() < cd then return end
			cd = os.clock()+.2
			if briefcase:GetAttribute("CannotInspect") then return end
			stopAnim("inspect", 0)
			addAnim("inspect")
			playSound("sound_inspect")
		end),
		Drops = {},
		LoopTPDrops = RunService.PreRender:Connect(function()
			if not ClientBriefcase then return end
			for _, drop in workspace.Drops:QueryDescendants("> Model[$ClientBriefcased=true]") do
				drop:PivotTo(drop:GetPivot()-drop:GetPivot().Position+character:GetPivot().Position*Vector3.new(1,0,1)+Vector3.new(0,-10000,0))
				local main = drop:FindFirstChild("Main") or drop:FindFirstChildWhichIsA("BasePart")
				if main then
					main.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end),
		DropAdded = workspace.Drops.ChildAdded:Connect(function(drop)
			if not ClientBriefcase then return end
			local fakePrompt = drop:WaitForChild("ModulePrompt"):Clone()
			fakePrompt.Name = "ClientPrompt"
			fakePrompt.Parent = drop
			fakePrompt.Enabled = briefcase.Parent == character
			drop.ModulePrompt.Enabled = briefcase.Parent ~= character
			ClientBriefcase.Connections.Drops[drop] = {
				Triggered = fakePrompt.Triggered:Connect(function()
					grabbed(drop)
				end),
				DropRemoved = drop.AncestryChanged:Connect(function()
					local found = table.find(items, drop)
					if found then
						table.remove(items, found)
						table.remove(icons, found)
						briefcase:SetAttribute("Durability", briefcase:GetAttribute("Durability")-1)
					end
					disconnectConnections(ClientBriefcase.Connections.Drops[drop])
					ClientBriefcase.Connections.Drops[drop] = nil
				end)
			}
		end)
	}
}

for _, drop in workspace.Drops:QueryDescendants("> Model") do
	task.spawn(function()
		local fakePrompt = drop:WaitForChild("ModulePrompt"):Clone()
		fakePrompt.Name = "ClientPrompt"
		fakePrompt.Parent = drop
		fakePrompt.Enabled = briefcase.Parent == character
		drop.ModulePrompt.Enabled = briefcase.Parent ~= character
		ClientBriefcase.Connections.Drops[drop] = {
			Triggered = fakePrompt.Triggered:Connect(function()
				grabbed(drop)
			end),
			DropRemoved = drop.AncestryChanged:Connect(function()
				local found = table.find(items, drop)
				if found then
					table.remove(items, found)
					table.remove(icons, found)
					briefcase:SetAttribute("Durability", briefcase:GetAttribute("Durability")-1)
				end
				disconnectConnections(ClientBriefcase.Connections.Drops[drop])
				ClientBriefcase.Connections.Drops[drop] = nil
			end)
		}
	end)
end

briefcase.Name = "ClientBriefcase"
briefcase.Parent = player.Backpack

remotes.CaptionClient:Fire("script by @tplaygd, execute again to remove the briefcase")

while briefcase.Parent do
	task.wait()
end

disconnectConnections(ClientBriefcase.Connections)

for _, drop in workspace.Drops:QueryDescendants("> Model") do
	local prompt = drop:FindFirstChild("ClientPrompt")
	if prompt then
		pcall(game.Destroy, prompt)
	end
	drop.ModulePrompt.Enabled = true
	if drop:GetAttribute("ClientBriefcased") then
		drop:PivotTo(character:GetPivot())
	end
	drop:SetAttribute("ClientBriefcased")
end

table.clear(ClientBriefcase)
ClientBriefcase = nil
