local StarterGui = game:GetService("StarterGui")

--local table_ = {}

--function getgenv()
--	return table_
--end

--wait(5)

local function Notify(Title, Text, Duration)
	xpcall(function()
		StarterGui:SetCore("SendNotification", {
			["Title"] = Title;
			["Text"] = Text;
			["Duration"] = Duration or 5;
		})
	end, function(err)
		warn(`ERROR IN NOTIFICATION: {err}`)
	end)
end

xpcall(function()
	local HTTPService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Lighting = game:GetService("Lighting")
	local Players = game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local MaterialService = game:GetService("MaterialService")
	local TextChatService = game:GetService("TextChatService")

	local Player = Players.LocalPlayer

	Notify("INITIALIZING API", "Beginning initialization of API")

	local RootClass = '<<<ROOT>>>'

	local DefaultOverwrites = {
		Anchored = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth
	}

	local AlwaysSave = {
		'MeshId'
	}

	local PropertiesAPI = {
		Defaults = {},
		Properties = {}
	}

	local function IsDeprecated(Property)
		if not Property.Tags then return end

		return table.find(Property.Tags, 'Deprecated') ~= nil
	end

	local function IsWriteable(Property)
		return table.find(AlwaysSave, Property.Name) or Property.Security and (Property.Security == 'None' or Property.Security.Write == 'None') and (not Property.Tags or not table.find(Property.Tags, 'ReadOnly'))
	end

	local Converter = {
		AssignGUIDs = {},
		Meshes = {},
		ModelsCache = {}
	}

	local IgnorableObjects = {"WindTrail", "NewDirt", "WaterImpact", "Footprint", "Part"}
	local UnnededClasses = {"Script", "ModuleScript", "LocalScript", "SpecialMesh", "CylinderMesh", "UnionOperation"}

	local MobNames = {
		".bountyhunter", 
		".golem", 
		".megalodaunt", 
		".pirate_black", 
		".mudskipper", 
		".bandit", 
		".banditleader", 
		".deepknight", 
		".dukecultist", 
		".brainsuckerduke", 
		".thief",
		".hive_scout",
		".summer_thug",
		".special_thug",
		".gremor_nomad_leader",
		".fighter_union",
		".brainsucker"
	}

	local CloneDetectionClasses = {
		["Sound"] = {
			"SoundId";
		};

		["Part"] = {
			"Name";
			"Size";
			"Color";
			"Material";
			"Transparency";
		};

		["Highlight"] = {
			"FillColor";
			"OutlineColor";
			"FillTransparency";
			"OutlineTransparency";
			"DepthMode";
		};

		["MeshPart"] = {
			"Name";
			"MeshId";
			"Size";
		};

		["Weld"] = {
			"Part1";
			"Part0";
			"C0";
			"C1";
		};

		["Motor6D"] = {
			"Part1";
			"Part0";
			"C0";
			"C1";
		};

		["ValueBase"] = {
			"Name";
			"Value";
		};
	}

	local DontSave = {
		['Parent'] = {},
		['BrickColor'] = {},
		['Orientation'] = {"ParticleEmitter"},
		['Position'] = {},
		["WorldCFrame"] = {},
		["WorldPosition"] = {},
		['WorldPivot'] = {},
		["Grip"] = {},
		["Origin"] = {},
		["PrimaryPart"] = {},
		["UniqueId"] = {},
		["PivotOffset"] = {};
		["Pivot Offset"] = {};
	}

	local DontSaveIf = {
		Rotation = {'CFrame'},
	}

	local ValueTypeRenames = {
		int = 'number'
	}


	local function ShouldntSave(properties, property, objectClass)
		local disallow = false

		if DontSave[property] then
			disallow = not table.find(DontSave[property], objectClass)
		end

		if not DontSaveIf[property] or disallow then 
			return disallow
		end

		for i, prop in pairs(DontSaveIf[property])do
			if properties[prop] then
				return true
			end
		end
	end

	Notify("DOWNLOADING LATEST CLASSES", "This could take a while", 4)

	local PropertiesAPI = {
		Dump = {};
		Defaults = {};
		Properties = {};
	}

	PropertiesAPI.Dump = HTTPService:JSONDecode(game:HttpGet('https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json', true))
	--PropertiesAPI.Dump = HTTPService:JSONDecode(require(script:WaitForChild("api")))

	Notify("CLASSES DOWNLOADED", "Beginning next step", 2)

	function PropertiesAPI:GetDefaults(ClassName : string)
		assert(ClassName, 'No class name was given')

		if self.Defaults[ClassName] then return self.Defaults[ClassName] end

		local success, instance = pcall(function()
			return Instance.new(ClassName)
		end)

		if not success then error(instance) return {} end

		local defaults = {}
		local properties = self:GetProperties(ClassName)

		for i, property in pairs(properties)do
			pcall(function()
				defaults[property.Name] = (DefaultOverwrites[property.Name] ~= nil and DefaultOverwrites[property.Name]) or instance[property.Name]
			end)
		end

		table.sort(properties, function(a, b) return a.Name < b.Name end)

		self.Defaults[ClassName] = defaults

		instance:Destroy()

		return defaults
	end

	function PropertiesAPI:GetProperties(ClassName : string)
		assert(ClassName, 'No class name was given')

		if self.Properties[ClassName] then return self.Properties[ClassName] end

		local properties = {}

		for i, data in pairs(self.Dump.Classes)do
			if data.Name and data.Name == ClassName then
				for i, property in pairs(data.Members)do
					if not property.Name or not property.ValueType or not property.MemberType or property.MemberType ~= 'Property' or IsDeprecated(property) or not IsWriteable(property) then continue end

					table.insert(properties, property)
				end

				if data.Superclass and data.Superclass ~= RootClass then
					for i, property in pairs(self:GetProperties(data.Superclass) or {})do
						table.insert(properties, property)
					end
				end

				break
			end
		end

		table.sort(properties, function(a, b) return a.Name < b.Name end)

		self.Properties[ClassName] = properties

		return properties
	end

	function Converter:ToValue(Parent, Value)
		local Type = typeof(Value)
		local Data

		if (Type == 'Instance') and (Value:IsDescendantOf(Parent) or Value == Parent) then
			Data = Value:GetAttribute('GUID')
			--Data.Value = Converter:ConvertToTable(Value)
		elseif Type == 'CFrame' then
			Data = {Value:GetComponents()}
		elseif Type == 'Vector3' or Type == 'Vector2' then
			Data = {Value.X, Value.Y, Type == 'Vector3' and Value.Z}
		elseif Type == 'UDim2' then
			Data = {Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset}
		elseif Type == 'UDim' then
			Data = {Value.X, Value.Y}
		elseif Type == 'ColorSequence' or Type == 'NumberSequence' then
			Data = {}

			for i, keypoint in pairs(Value.Keypoints)do
				local value = self:ToValue(Parent, keypoint.Value)
				table.insert(Data, {keypoint.Time, value, (Type == "NumberSequence" and keypoint["Envelope"]) or nil})
			end
		elseif Type == 'Color3' or Type == 'BrickColor' then
			Data = {Value.r, Value.g, Value.b}
		elseif Type == 'Faces' then
			Data = {Value.Top, Value.Bottom, Value.Left, Value.Right, Value.Back, Value.Front}
		elseif Type == 'NumberRange' then
			Data = {Value.Min, Value.Max}
		elseif Type == 'EnumItem' then
			Data = Value.Value
		elseif Type == "string" then
			local NewString, Count = string.gsub(Value, "\'", "")
			NewString, Count = string.gsub(NewString, "\"", "")
			NewString, Count = string.gsub(NewString, "`", "")
			NewString, Count = string.gsub(NewString, "'", "")
			NewString, Count = string.gsub(NewString, '"', "")

			Data = NewString
		else
			Data = Value
		end

		return Data
	end

	function Converter:ConvertToTable(Object, Parent, IncludeDescendants)
		assert(Object, 'No object was passed through')

		if not Parent then Parent = Object end
		if not IncludeDescendants then IncludeDescendants = false end

		local properties = PropertiesAPI:GetProperties(Object.ClassName)
		local defaults = PropertiesAPI:GetDefaults(Object.ClassName)
		local data = {
			ClassName = Object.ClassName,
			ID = Object:GetAttribute('GUID')
		}

		if Object:IsA('Script') or ((Object:IsA('Model') or Object:IsA('Folder')) and #Object:GetChildren() <= 0) then
			return
		end

		if Object:IsA("Model") then
			data["CFrame"] = {
				Value = Converter:ToValue(Object, Object:GetPivot());
				Class = "CFrame";
			}
		end

		for i, property in pairs(properties)do
			property = property.Name
			if (defaults[property] ~= nil and Object[property] == defaults[property]) or ShouldntSave(data, property, Object.ClassName) then continue end
			if property == "Scale" and Object.ClassName == "Model" then continue end
			if typeof(data[property]) == "Instance" or (Object:IsA("Model") and property == "CFrame") then continue end

			xpcall(function()
				data[property] = { 
					Value = Converter:ToValue(Parent, Object[property]);
					Class = typeof(Object[property]);
				}
			end, function(err)
				warn(`FAILED TO SAVE: {err}`)
			end)
		end

		if IncludeDescendants then
			data.Children = {}

			for i, child in pairs(Object:GetChildren())do
				local tab = Converter:ConvertToTable(child, Parent, IncludeDescendants)
				table.insert(data.Children, tab)
			end

			if #data.Children <= 0 then
				data.Children = nil
			end
		end
		
		return data
	end

	function Converter:ConvertToSaveable(Object : Instance, IncludeDescendants:boolean)
		local data = Converter:ConvertToTable(Object, nil, IncludeDescendants)

		return HTTPService:JSONEncode(data)
	end

	local function SaveObjectToFile(Object, Name)
		local Data; 

		xpcall(function()
			Notify("CONVERTING DATA", "Refrain from doing any action.", 5)

			local Data = tostring(Converter:ConvertToSaveable(Object, true))

			xpcall(function()
				Notify("DATA CONVERTED", "Refrain from doing any action.", 5)

				writefile(`{Name}.txt`, Data)

				Notify("FILE SAVED", `You can find the save at "workspace/{Name}", you can resume now.`, 5)
			end, function(err)
				Notify("FAILED TO SAVE OBJECT", tostring(err), 5)
			end)
		end, function(err)
			Notify("FAILED TO CONVERT OBJECT", tostring(err), 5)
		end)
	end

	Notify("API INITIALIZED", "Beginning next step", 2)

	getgenv()["SessionId"] = getgenv()["SessionId"] or HTTPService:GenerateGUID(false)
	getgenv()["AddYield"] = getgenv()["AddYield"] or 0.2

	if getgenv()["Connections"] then
		for ConnectionName, Connection in getgenv()["Connections"] do
			Connection:Disconnect()
		end
	end

	getgenv()["Connections"] = {}
	getgenv()["SaveCount"] = getgenv()["SaveCount"] or 0
	getgenv()["CharacterSaves"] = getgenv()["CharacterSaves"] or 0

	if getgenv()["Folder"] then
		getgenv().Folder:Destroy()
	end

	local function Disconnect(ConnectionName)
		if getgenv().Connections[ConnectionName] then
			getgenv().Connections[ConnectionName]:Disconnect()
			getgenv().Connections[ConnectionName] = nil
		end
	end

	local function Connect(ConnectionName, Traceback)
		getgenv().Connections[ConnectionName] = Traceback
	end

	local Folder = Instance.new("Folder", MaterialService)
	Folder.Name = `Instance_{getgenv()["SessionId"]}`

	local GlobalStorage = Instance.new("Folder", Folder)
	GlobalStorage.Name = "Global"

	local ReplicatedStorageStorage = Instance.new("Folder", GlobalStorage)
	ReplicatedStorageStorage.Name = "ReplicatedStorage"

	local WorkspaceStorage = Instance.new("Folder", GlobalStorage)
	WorkspaceStorage.Name = "Workspace"

	local ThrownStorage = Instance.new("Folder", Folder)
	ThrownStorage.Name = "Thrown"

	local PlayerSpecificStorage = Instance.new("Folder", Folder)
	PlayerSpecificStorage.Name = "PlayerSpecific"

	getgenv()["Folder"] = Folder

	local TargettingPlayerFolder, AnimationsFolder, CharacterFolder;
	local TargettingCharacter;

	local CharacterSearchEnabled, ThrownSearchEnabled = true, true;
	local DupeRemovalEnabled, MobRemovalEnabled = true, true;

	local function SaveAnimations(Target)
		xpcall(function()
			if AnimationsFolder and Target ~= nil and Target:FindFirstChildOfClass("Humanoid") then
				for _, Track in next, Target:FindFirstChildOfClass("Humanoid"):GetPlayingAnimationTracks() do 
					local Id = Track.Animation.AnimationId

					if AnimationsFolder:FindFirstChild(Id) then continue end

					local Value = Instance.new("StringValue", AnimationsFolder)
					Value.Name = Id
					Value.Value = Id
				end
			else
				Notify("CANNOT SAVE", `No character selected, or character is loading or no humanoid is present.`)
			end
		end, function(err)
			warn(`RANDOM ANIMATON SAVING ERROR: {err}`)
		end)
	end

	local function AnyObjectWithPropertysLike(Class, SecondaryObject, PropertiesToCheck, Location)
		local Result = false

		xpcall(function()
			for _, Object in Location:GetDescendants() do
				if Object:IsA(Class) then
					local SameOnes = 0

					for _, PropertyName in PropertiesToCheck do
						if Object[PropertyName] == SecondaryObject[PropertyName] then
							SameOnes += 1
						end
					end

					if SameOnes >= #PropertiesToCheck then
						Result = true

						break
					end
				end
			end

			return Result
		end, function(err)
			warn(`FAILED TO CHECK IF DUPLICATE OBJECT "{SecondaryObject}:{Class}": {err}`)
		end)

		return Result
	end

	local function StoreObject(Object, Location)
		xpcall(function()
			if Object == nil or (Object ~= nil and Object.Parent == nil) then return end

			if table.find(IgnorableObjects, Object.Name) or table.find(UnnededClasses, Object.ClassName) then return end

			local OriginalParent = Object.Parent

			task.wait(getgenv()["AddYield"])

			if Object == nil or (Object ~= nil and Object.Parent ~= nil and Object.Parent ~= OriginalParent) then return end
			if Object.ClassName == "Model" then 
				if #Object:GetChildren() <= 0 then return end

				if MobRemovalEnabled then
					local IsAMob = false

					for _, MobName in MobNames do
						local FindOperation = string.find(Object.Name, MobName)

						if FindOperation ~= nil and tonumber(FindOperation) ~= nil and (FindOperation <= 1 or FindOperation == string.len(MobName)) then
							IsAMob = true
							break
						end
					end

					if IsAMob then return end
				end

				if Object:FindFirstChildOfClass("Humanoid") then
					SaveAnimations(Object)

					for _, Track in Object:FindFirstChildOfClass("Humanoid"):GetPlayingAnimationTracks() do
						pcall(function()
							Track:Stop(0)
						end)
					end

					task.wait(0.1)
				end
			end

			if DupeRemovalEnabled then
				local Proceed = true

				for Class, CloneData in CloneDetectionClasses do
					if Object:IsA(Class) then
						if AnyObjectWithPropertysLike(Class, Object, CloneData, Location) then
							Proceed = false
							break
						end
					end
				end

				if not Proceed then
					warn(`PREVENTED DUPLICATE INSTANCE: "{Object.Name}:{Object.ClassName}"`)
					return
				end
			end

			if Object.ClassName == "Attachment" then
				local Part = Instance.new("Part", Location)
				Part.Name = `{Object.Name}_ATTACHMENT_HOLDER`
				Part.Anchored = true
				Part.CFrame = Object.WorldCFrame
				Part.Transparency = 1
				Part.CanCollide = false
				Part.CanTouch = false
				Part.CanQuery = false
				Part.Size = Vector3.new(1, 1, 1)

				local Attachment = Object:Clone()
				Attachment.Parent = Part
				Attachment.CFrame = CFrame.new()
			elseif Object.ClassName == "Sound" then
				local Sound = Object:Clone()
				Sound.Parent = Location
				Sound:Stop()
			else
				Object:Clone().Parent = Location
			end

			print(`ADDED INSTANCE {Object.Name}:{Object.ClassName}`)
		end, function(err)
			warn(`ERROR SAVING INSTANCE "{(Object and Object.Name) or nil}": "{err}"`)
		end)
	end

	local function CreatePlayerFolder(Player)
		Disconnect("CharacterAdded")
		Disconnect("CharacterDescendantAdded")

		if Player == nil then 
			TargettingCharacter = nil 

			Notify("UNBOUND ALL CHARACTERS", `Character data grabber isnt grabbing anymore.`)

			return 
		end

		TargettingPlayerFolder = PlayerSpecificStorage:FindFirstChild(Player.Name) or Instance.new("Folder", PlayerSpecificStorage)
		TargettingPlayerFolder.Name = Player.Name

		AnimationsFolder = TargettingPlayerFolder:FindFirstChild("Animations") or Instance.new("Folder", TargettingPlayerFolder)
		AnimationsFolder.Name = "Animations"

		CharacterFolder = TargettingPlayerFolder:FindFirstChild("Character") or Instance.new("Folder", TargettingPlayerFolder)
		CharacterFolder.Name = "Character"

		local function ConnectMainStuff(Character)
			Disconnect("CharacterDescendantAdded")

			if Character == nil then 
				TargettingCharacter = nil
				return
			end

			TargettingCharacter = Character

			Connect("CharacterDescendantAdded", Character.DescendantAdded:Connect(function(Object)
				if not CharacterSearchEnabled then return end

				StoreObject(Object, CharacterFolder)
			end))
		end

		Connect("CharacterAdded", Player.CharacterAdded:Connect(function(Character)
			ConnectMainStuff(Character)
		end))

		ConnectMainStuff(Player.Character)

		Notify("INITIALIZED CHARACTER", `Initialized the grabber data grabber to "{Player.Name}"`)
	end

	local function GetPlayersByText(Name)
		if typeof(Name) ~= "string" then return {} end

		local List = {}

		for _, Plr in Players:GetPlayers() do
			local SamePlayer = string.lower(Name) == string.lower(Plr.Name)

			if string.find(string.lower(Plr.Name), string.lower(Name)) or SamePlayer then
				local Score = SamePlayer and 100 or math.abs(string.len(Plr.Name) - string.len(Name))

				table.insert(List, {Plr, Score})
			end
		end

		table.sort(List, function(a, b)
			return (a[2] < b[2])
		end)

		local PlayerList = {}

		for I, Part in pairs(List) do
			table.insert(PlayerList, Part[1])
		end

		return PlayerList
	end

	CreatePlayerFolder(Player)

	local Commands = {
		["target"] = function(args)
			if #args < 1 then return end

			if args[1] == "none" then
				CreatePlayerFolder(nil)
			end

			local PlayerList = GetPlayersByText(args[1])

			if #PlayerList < 1 then return end

			CreatePlayerFolder(PlayerList[1])
		end;

		["yieldtime"] = function(args)
			if #args < 1 then return end
			if tonumber(args[1]) == nil then return end

			getgenv()["AddYield"] = tonumber(args[1])

			Notify("SET YIELD", `Yield time has been set to {getgenv()["AddYield"]}`)
		end,

		["storechar"] = function(args)
			Notify("SAVING...", `Storing target character this could take a while. DONT DO ANY OTHER ACTIONS.`)

			if TargettingCharacter then
				if TargettingCharacter:FindFirstChildOfClass("Humanoid") then
					for _, Track in TargettingCharacter:FindFirstChildOfClass("Humanoid"):GetPlayingAnimationTracks() do
						pcall(function()
							Track:Stop(0)
						end)
					end
				end
				
				TargettingCharacter.Archivable = true
				
				for _, Object in TargettingCharacter:GetDescendants() do
					Object.Archivable = true
				end

				task.wait(0.1)

				SaveObjectToFile(TargettingCharacter, `CHARSAVE_{TargettingCharacter.Name}_{getgenv()["CharacterSaves"]}`)

				getgenv()["CharacterSaves"] = getgenv()["CharacterSaves"] + 1
			end

			Notify("STORED", `Successfully stored target character!`)
		end;

		["storerep"] = function(args)
			Notify("STORING...", `Storing ReplicatedStorage this could take a while. DONT DO ANY OTHER ACTIONS.`)

			ReplicatedStorageStorage:ClearAllChildren()

			for _, Object in ReplicatedStorage:GetChildren() do
				StoreObject(Object, ReplicatedStorageStorage)
			end

			Notify("STORED", `Successfully stored ReplicatedStorage!`)
		end,

		["storemap"] = function(args)
			Notify("STORING...", `Storing the map this could take a while. DONT DO ANY OTHER ACTIONS.`)

			WorkspaceStorage:ClearAllChildren()

			for _, Object in workspace:GetChildren() do
				if Object.Name ~= "Living" and Object.Name ~= "Thrown" then
					StoreObject(Object, WorkspaceStorage)
				end
			end

			Notify("STORED", `Successfully stored the map!`)
		end;

		["dupetoggle"] = function(args)
			DupeRemovalEnabled = not DupeRemovalEnabled

			Notify("DUPE FILTERING TOGGLED", `State: {DupeRemovalEnabled}`)
		end;

		["mobtoggle"] = function(args)
			MobRemovalEnabled = not MobRemovalEnabled

			Notify("DUPE FILTERING TOGGLED", `State: {DupeRemovalEnabled}`)
		end;

		["chartoggle"] = function(args)
			CharacterSearchEnabled = not CharacterSearchEnabled

			Notify("CHARACTER SEARCH TOGGLED", `State: {CharacterSearchEnabled}`)
		end;

		["throwntoggle"] = function(args)
			ThrownSearchEnabled = not ThrownSearchEnabled

			Notify("THROWN SEARCH TOGGLED", `State: {ThrownSearchEnabled}`)
		end;
	}

	Connect("UISConnectionBegan", UIS.InputBegan:Connect(function(IO, Focusing)
		if Focusing then return end

		if IO.KeyCode == Enum.KeyCode.P then
			Notify("CLEARED CHARACTER ASSETS", "Clearing character specific assets for current target")

			if CharacterFolder ~= nil then
				for _, Object in CharacterFolder:GetChildren() do
					Object:Destroy()
				end
			end
		elseif IO.KeyCode == Enum.KeyCode.L then
			Notify("CLEARED THROWN", "Clearing stored object data")

			for _, Object in ThrownStorage:GetChildren() do
				Object:Destroy()
			end
		elseif IO.UserInputType == Enum.UserInputType.MouseButton3 then
			Notify("STORED ANIMATIONS", "Stored any new animations playing on target")

			SaveAnimations(TargettingCharacter)
		elseif IO.KeyCode == Enum.KeyCode.M then
			Notify("SAVING INSTANCE", "This could take a while depending on what your saving, refrain from doing any actions.", 5)

			xpcall(function()
				SaveObjectToFile(Folder, `SAVE_{getgenv()["SaveCount"]}`)

				--saveinstance(Name, Folder)
				--saveinstance({Folder}, {FileName = Name, IgnoreArchivable = true, DisableCompression = true})

				--warn(Data)

				getgenv()["SaveCount"] = getgenv()["SaveCount"] + 1
			end, function(err)
				warn(`FAILED TO SAVE: {err}`)

				Notify("FAILED TO SAVE INSTANCE", `{err}`, 10)
			end)
		end
	end))

	local function ChattedConnection(Message)
		xpcall(function()
			local Split = string.split(Message, " ")
			local CommandName = Split[1]
			local ArgsStartIndex = 2

			if CommandName then
				print(Split[2], Split[3], Split[4], Split[5])
				if CommandName == "/e" then
					CommandName = Split[2]
					ArgsStartIndex = 3
				end

				if CommandName and Commands[CommandName] then
					local Args = {}

					for i = ArgsStartIndex, #Split, 1 do
						if Split[i] then
							table.insert(Args, Split[i])
						end
					end

					xpcall(function()
						Commands[CommandName](Args)
						--Notify("RAN COMMAND", `Ran command "{CommandName}" with no errors`)
					end, function(err)
						Notify("ERROR IN RAN COMMAND", `Ran command "{CommandName}" erroed with: {err}`)
						warn(`ERROR IN RUNNING COMMAND "{CommandName}": {err}`)
					end)
				end
			end
		end, function(err)
			Notify("ERROR IN STRING CONCAT", `{err}`)
			warn(`ERROR IN STRING CONCAT: {err}`)
		end)
	end

	Connect("ThrownCheck", workspace:WaitForChild("Thrown").ChildAdded:Connect(function(Child)
		if not ThrownSearchEnabled then return end

		StoreObject(Child, ThrownStorage)
	end))

	Connect("CommandDetectionOldChat", Player.Chatted:Connect(function(Msg, Recipient)
		if Recipient then return end

		ChattedConnection(Msg)
	end))

	Notify("INITIALIZED ALL", "The asset grabber was initialized successfully")
	warn("LOADED DEEPWOKEN ASSET GRABBER SUCCESSFULLY")
end, function(err)
	Notify("FAILED TO INITIALIZE ALL", "An error occured during initialization, show me the warning in F9")
	warn(`ERROR IN MAIN INITIALIZATION OF SCRIPT: {err}`)
end)
