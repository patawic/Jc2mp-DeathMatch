class "Map"
function Map:__init(manager)
	self.derbyManager = manager
	self.manifestPath = "server/Maps/Manifest.txt"
	self.courseNames = {}
	self.numMaps = 0

	self:LoadManifest(self.manifestPath)
end
---------------------------------------------------------------------------------------------------------------------
------------------------------------------------MANIFEST LOADING-----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Map:LoadManifest(path)
	local tempFile , tempFileError = io.open(path , "r")
	if tempFileError then
			print()
			print("*ERROR*")
			print(tempFileError)
			print()
			fatalError = true
			return
	else
			io.close(tempFile)
	end
	-- Loop through each line in the manifest.
	for line in io.lines(path) do
		-- Make sure this line has stuff in it.
		if string.find(line , "%S") then
				-- Add the entire line, sans comments, to self.courseNames
				table.insert(self.courseNames , line:trim())
				self.numMaps = self.numMaps + 1
		end
	end
end
---------------------------------------------------------------------------------------------------------------------
-----------------------------------------------COURSE FILE PARSING---------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Map:LoadMap(name)
	if name == nil then
		name = self:PickRandomMap()
		print("map selected: " .. name)
	end
	local path = "server/Maps/" .. name:trim() .. ".map"
	--check if path is invalid
	if path == nil then
		print("*ERROR* - Map path is nil!")
		return nil
	end	
	local file = io.open(path , "r") 
	--check if file exists
	if not file then
		print("*ERROR* - Cannot open map file: "..path)
		return nil
	end

	local map = {}
	map.Location = nil
	map.Boundary = {}
	map.minPlayers = nil
	map.maxPlayers = nil
	map.canGrapple = nil
	map.canParachute = nil
	map.Weapons = nil
	map.SpawnPoint = {}

	--loop through file line by line
	for line in file:lines() do
		if line:sub(1,1) == "L" then
			map.Location =  self:Location(line)
		elseif line:sub(1,1) == "B" then
			local boundary = self:Boundary(line)
			map.Boundary.position = boundary.position
			map.Boundary.radius = boundary.radius
		elseif line:sub(1,1) == "P" then
			local playerCount = self:Players(line)
			map.minPlayers = playerCount.minPlayers
			map.maxPlayers = playerCount.maxPlayers
		elseif line:sub(1,1) == "C" and line:sub(4,4) == "G" then
			map.canGrapple = self:Grapple(line)
		elseif line:sub(1,1) == "C" and line:sub(4,4) == "P" then
			map.canParachute = self:Parachute(line)
		elseif line:sub(1,1) == "W" then
			map.Weapons = self:ParseWeapons(line)
		elseif line:sub(1,1) == "S" then
			table.insert(map.SpawnPoint, self:PlayerSpawn(line))
		end
	end
	return map
end
function Map:Location(line)
	line = line:gsub("Location%(", "")
	line = line:gsub("%)", "")

	return line
end
function Map:Boundary(line)
	line = line:gsub("Boundary%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")   
	local args = {}
	-- Create tables containing appropriate strings
	args.position	= Vector3(tonumber(tokens[1]), tonumber(tokens[2]), tonumber(tokens[3]))
	args.radius		= tonumber(tokens[4])

	return args
end
function Map:Players(line)
	line = line:gsub("Players%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")   
	local args = {}

	args.minPlayers = tonumber(tokens[1])
	args.maxPlayers = tonumber(tokens[2])

	return args
end
function Map:Grapple(line)
	line = line:gsub("CanGrapple%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	return line
end
function Map:Parachute(line)
	line = line:gsub("CanParachute%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	return line
end
function Map:ParseWeapons(line)
	line = line:gsub("Weapons%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")
	local args = {}
	for index, weapon in pairs(tokens) do

		local weapon = {}
		if (tokens[index] == "Handgun") then
				weapon.id = Weapon.Handgun
				weapon.slot = WeaponSlot.Right
		elseif (tokens[index] == "SMG") then
				weapon.id = Weapon.SMG
				weapon.slot = WeaponSlot.Right        
		elseif (tokens[index] == "SawnOffShotgun") then
				weapon.id = Weapon.SawnOffShotgun
				weapon.slot = WeaponSlot.Right
		elseif (tokens[index] == "Assault") then
				weapon.id = Weapon.Assault
				weapon.slot = WeaponSlot.Primary        
		elseif (tokens[index] == "Shotgun") then
				weapon.id = Weapon.Shotgun
				weapon.slot = WeaponSlot.Primary                   
		elseif (tokens[index] == "MachineGun") then
				weapon.id = Weapon.MachineGun 
				weapon.slot = WeaponSlot.Primary
		end
		table.insert(args, weapon)
	end
	return args
end
function Map:PlayerSpawn(line)
	line = line:gsub("Spawn%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")   
	local args = {}
	-- Create tables containing appropriate strings
	args.position	= Vector3(tonumber(tokens[1]), tonumber(tokens[2]), tonumber(tokens[3]))
	args.angle		= Angle(tonumber(tokens[4]), tonumber(tokens[5]), tonumber(tokens[6]))

	return args
end
function Map:PickRandomMap()
	return table.randomvalue(self.courseNames)
end