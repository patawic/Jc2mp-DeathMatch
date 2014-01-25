function math.round(x)
	if x%2 ~= 0.5 then
		return math.floor(x+0.5)
	end
	return x-0.5
end
class "Deathmatch"
function Deathmatch:__init(name, manager, world)
	self.name = name
	self.deathmatchManager = manager
	self.world = world

	self.team1names = {"Military"}
	self.team2names = {"Ular Boys", "Reapers", "Roachers", "The Agency"}
	self.team1score = 250
	self.team2score = 250
	self.team1players = {}
	self.team2players = {}
	self.models = 	{
						["Military"] = 66, 
						["Ular Boys"] = 27, 
						["Reapers"] = 12, 
						["Roachers"] = 85, 
						["The Agency"] = 51
					}		
	self.gamemodes = {"Deathmatch" , "Team Deathmatch" , "Last Man Standing"}
	self.state = "Lobby"
	self.startTimer = Timer()

	self.players = {}
	self.eventPlayers = {}

	self.map = Map(self.deathmatchManager)
	self.spawns = self.map:LoadMap()
	self.minPlayers = self.spawns.minPlayers
	self.maxPlayers = self.spawns.maxPlayers
	self.startPlayers = 0
	self.numPlayers = 0
	self.mode = table.randomvalue(self.gamemodes)
	self.weapon = table.randomvalue(self.spawns.Weapons)

	self.team1name = table.randomvalue(self.team1names)
	self.team2name = table.randomvalue(self.team2names)

	self.globalStartTimer = Timer()
	self.setupTimer = nil
	self.countdownTimer = nil
	self.gameTimer = nil

	Events:Subscribe("PostTick", self, self.PostTick)

	Events:Subscribe("JoinGamemode", self, self.JoinGamemode)
	Events:Subscribe("PlayerDeath", self, self.PlayerDeath)
	Events:Subscribe("PlayerQuit", self, self.PlayerLeave)

	Events:Subscribe("ModuleUnload", self, self.ModuleUnload)

	Events:Subscribe("EnterDeathmatch", self, self.JoinPlayer)
	Events:Subscribe("LeaveLobby", self, self.RemovePlayer)
	self:MessageGlobal("A Deathmatch event is about to begin! (Type: " .. self.mode ..  ", Location: " .. self.spawns.Location .. ", Maximum Players: " .. self.maxPlayers ..") /deathmatch to join")
end
---------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------EVENTS----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Deathmatch:PostTick()
	if (self.state == "Lobby") then
		if ((self.numPlayers >= self.minPlayers and self.startTimer:GetSeconds() > 20) or (self.numPlayers >= self.minPlayers and self.globalStartTimer:GetSeconds() > 300)) then
			self:Start()
		end
	elseif (self.state == "Setup") then
		if (self.setupTimer:GetSeconds() > 3) then
			self.countdownTimer = Timer()
			--set state
			self.state = "Countdown"
			self:SetClientState()
			self.setupTimer = nil

		end
	elseif (self.state == "Countdown") then
		if (self.countdownTimer:GetSeconds() > 4) then
			--set state
			self.state = "Running"
			self:SetClientState()
			self.countdownTimer = nil
		end
	elseif (self.state == "Running") then
		if (self.mode == "Deathmatch") then
			self:Deathmatch()
		elseif (self.mode == "Team Deathmatch") then
			self:TeamDeathmatch()
		elseif (self.mode == "Last Man Standing") then
			self:PlayerCount()
		end
	end
end

function Deathmatch:PlayerDeath(args)
	if self:HasPlayer(args.player) then
		if (self.mode == "Deathmatch") then
			if (self.state ~= "Lobby" and args.player:GetWorld() == self.world) then
				local newspawn = table.randomvalue(self.spawns.SpawnPoint)
				args.player:Teleport(newspawn.position, newspawn.angle)

				if (self.eventPlayers[args.player:GetId()] ~= nil) then
					self.eventPlayers[args.player:GetId()].deathcount = self.eventPlayers[args.player:GetId()].deathcount + 1
				end
				if (args.killer ~= nil) then
					if (self.eventPlayers[args.killer:GetId()] ~= nil) then
						self.eventPlayers[args.killer:GetId()].killcount = self.eventPlayers[args.killer:GetId()].killcount + 1
					end
				end

				local scores = {}
				for index, player in pairs(self.eventPlayers) do
  					local args = {}
    				args.player = player.player:GetName()
    				args.score = player.killcount
  					table.insert(scores, args)
				end
				table.sort(scores, function(a, b) return a.score > b.score end)
				Network:SendToPlayers(self.players, "DeathmatchScores", scores)
			end
		elseif (self.mode == "Team Deathmatch") then
			if (self.state ~= "Lobby" and args.player:GetWorld() == self.world) then		
				local newspawn = table.randomvalue(self.spawns.SpawnPoint)
				args.player:Teleport(newspawn.position, newspawn.angle)	
				if (self.eventPlayers[args.player:GetId()] ~= nil) then
					if (self.eventPlayers[args.player:GetId()].team == "Military") then
						self.team1score = self.team1score - 1
					else
						self.team2score = self.team2score - 1
					end
				end
				local scores = {}
				scores.team1 = self.team1score
				scores.team2 = self.team2score
				Network:Send(args.player, "UpdateTeamScores", scores)
			end
		elseif (self.mode == "Last Man Standing") then		
			if (self.state ~= "Lobby" and args.player:GetWorld() == self.world) then
				local numberEnding = ""
				local lastDigit = self.numPlayers % 10
				if ((self.numPlayers < 10) or (self.numPlayers > 20 and self.numPlayers < 110) or (self.numPlayers > 120)) then
					if (lastDigit  == 1) then
						numberEnding = "st"
					elseif (lastDigit == 2) then
						numberEnding = "nd"
					elseif (lastDigit == 3) then
						numberEnding = "rd"
					else
						numberEnding = "th"
					end
				else
					numberEnding = "th"
				end
				self:MessagePlayer(args.player, "Congratulations you came " ..tostring(self.numPlayers) .. numberEnding)
				self:RemovePlayer(args.player)
			end
		end
	end
end

function Deathmatch:PlayerLeave(args)
	if (self:HasPlayer(args.player)) then
		self:RemovePlayer(args.player)
	end
end


function Deathmatch:SetClientState(newstate)
	for index,player in pairs(self.players) do
		if newstate == nil then
			Network:Send(player, "SetState", self.state)
		else
			Network:Send(player, "SetState", newstate)
		end
	end
end

function Deathmatch:UpdatePlayerCount()  
	for id ,player in pairs(self.players) do
		Network:Send(player, "PlayerCount", self.numPlayers)
	end
end

function Deathmatch:ModuleUnload()
	for k,p in pairs(self.eventPlayers) do
		if (self.state ~= "Lobby") then
			p:Leave()
			self:MessagePlayer(p.player, "Deathmatch script unloaded. You have been restored to your starting position.")
			self:SetClientState("Inactive")
		end
	end
end
function Deathmatch:JoinGamemode( args )
	if args.name ~= "Deathmatch" then
		self:RemovePlayer(args.player)
	end
end
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Deathmatch:Deathmatch()
	if (self.gameTimer ~= nil) then
		if (self.gameTimer:GetSeconds() > 300) then
			local killcount = 0
			local player = nil
			for index, player in pairs(self.eventPlayers) do
				if player.killcount > killcount then
					local player = player.player
					self:RemovePlayer(player)
				end
			end	
			print(player:GetName() .. " won the deathmatch")
		else
			if (self.numPlayers == 0 or self.numPlayers == 1) then
				for k,p in pairs(self.players) do
					self:RemovePlayer(p, "Deathmatch ran out of players. You have been removed")
					self:Cleanup()
				end
			end
		end
	else
		self.gameTimer = Timer()
	end
end
function Deathmatch:TeamDeathmatch()
	if (self.team1score == 0 or self.team2score == 0 and self.state ~= "Lobby") then
		if (self.team1score > self.team2score) then
			for index, player in pairs(self.eventPlayers) do
				if player.team == self.team1name then
					self:RemovePlayer(player.player, "Congratulations your team won!")
					print(self.team1name .. " won the deathmatch")
				else
					self:RemovePlayer(player.player, "Your Team lost the deathmatch!")
				end
			end
		else
			for index, player in pairs(self.eventPlayers) do
				if player.team == self.team2name then
					self:RemovePlayer(player.player, "Congratulations your team won!")
					print(self.team2name .. " won the deathmatch")
				else
					self:RemovePlayer(player.player, "Your Team lost the deathmatch!")
				end
			end
		end
		self:Cleanup()
	end
	if (#self.team1players == 0 or #self.team2players == 0) then
		for k,p in pairs(self.players) do
			self:RemovePlayer(p, "Team Deathmatch ran out of players. You have been removed")
			self:Cleanup()
		end
	end
end
function Deathmatch:PlayerCount()
	if (self.numPlayers == 1 and self.state ~= "Lobby") then
	--kick everyone out and broadcast the winner
		for k,p in pairs(self.players) do
			self:MessageGlobal(p:GetName() .. " has won the Deathmatch!")
			print("[" ..self.name .. "] " .. p:GetName() .. " won the deathmatch event")

			self:RemovePlayer(p, "Congratulations you came 1st!")
		end
		self:Cleanup()
	elseif (self.numPlayers == 0) then
		print ("no players left")
		self:Cleanup()
	end
end
---------------------------------------------------------------------------------------------------------------------
--------------------------------------------------EVENT START--------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Deathmatch:Start()
	self.state = "Setup"
	self.startPlayers = self.numPlayers
	self.setupTimer = Timer()
	self:SetClientState()

	local tempPlayers = {}
	for id , player in pairs(self.players) do
				table.insert(tempPlayers , player)
	end
	local divider = math.floor(self.maxPlayers / self.numPlayers)
	local idInc = 1

	for index, player in ipairs(tempPlayers)do 
		if (player:GetHealth() == 0) then
			self:RemovePlayer(player, "You have been removed from the Deathmatch event.")
		else
			player:SetWorld(self.world)
			player:SetPosition(self.spawns.SpawnPoint[math.round(idInc)].position)
			player:ClearInventory()
			player:GiveWeapon(1,  Weapon(self.weapon.id))
			if (self.mode == "Team Deathmatch") then
				if (index%2 == 0) then
					self.eventPlayers[player:GetId()].team = team1name
					player:SetModelId(self.models["" .. self.team1name .. ""])
					self.team1players[player:GetId()] = player
				else
					self.eventPlayers[player:GetId()].team = team2name
					player:SetModelId(self.models["" .. self.team2name .. ""])
					self.team2players[player:GetId()] = player
				end
			end
			--get client to disable/enable functionality
			if (self.spawns.canGrapple == "false") then
				Network:Send(player, "BlockGrapple")
			end
			if (self.spawns.canParachute == "false") then
				Network:Send(player, "BlockParachute")
			end
			--tell client what gamemode is active
			local args = {}
			args.mode = self.mode
			if (self.mode == "Team Deathmatch") then
				args.team1 = table.randomvalue(self.team1names)
				args.team2 = table.randomvalue(self.team2names)
			end
			Network:Send(player, "SetGamemode", args)

			local args = {}
			args.team1 = self.team1score
			args.team2 = self.team2score
			Network:Send(player, "UpdateTeamScores", args)
		end
		idInc = idInc + divider
	end
	--[[for i=1,self.maxPlayers,1 do
		local vehicle = Vehicle.Create(21, self.spawns.SpawnPoint[i].position, self.spawns.SpawnPoint[i].angle)
		local color = Color(math.random(255),math.random(255),math.random(255))
		vehicle:SetEnabled(true)
		vehicle:SetHealth(1)
		vehicle:SetDeathRemove(true)
		vehicle:SetUnoccupiedRemove(true)
		vehicle:SetWorld(self.world)
		vehicle:SetColors(color, color)
	end]]
	self:MessageGlobal("Starting Deathmatch event with " .. tostring(self.numPlayers) .. " players.")
	print("[" ..self.name .. "] Started Event at (Location: " .. self.spawns.Location .. ", Players: " .. self.startPlayers .. ")")
	self.deathmatchManager:CreateDeathmatchEvent()
end
---------------------------------------------------------------------------------------------------------------------
-------------------------------------------PLAYER JOINING/LEAVING----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Deathmatch:HasPlayer(player)
	return self.players[player:GetId()] ~= nil
end

function Deathmatch:JoinPlayer(player)
	if (player:GetWorld() ~= DefaultWorld and player:GetWorld() ~= world) then
		self:MessagePlayer(player, "You must exit other gamemodes before you can join.")
	else
		if (self.state == "Lobby") then
			local p = Player(player)
			self.eventPlayers[player:GetId()] = p
			self.players[player:GetId()] = player

			self.deathmatchManager.playerIds[player:GetId()] = true
			self.numPlayers = self.numPlayers + 1
			self:MessagePlayer(player, "You have been entered into the next Deathmatch event! It will begin shortly.") 

			Network:Send(player, "SetState", "Lobby")
			self:UpdatePlayerCount()
			self.startTimer:Restart()

			if (self.numPlayers == self.maxPlayers) then
				self:Start()
			end
		end
	end
end

function Deathmatch:RemovePlayer(player, message)
	if message ~= nil then
		self:MessagePlayer(player, message)    
	end
	local p = self.eventPlayers[player:GetId()]
	if p == nil then return end
	self.players[player:GetId()] = nil
	self.eventPlayers[player:GetId()] = nil
	self.deathmatchManager.playerIds[player:GetId()] = nil
	self.numPlayers = self.numPlayers - 1
	if (self.state ~= "Lobby") then
		p:Leave()
	end
	Network:Send(player, "SetState", "Inactive")
	self:UpdatePlayerCount()
end
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------CLEANUP-----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Deathmatch:Cleanup()
	self.state = "Cleanup"
	self.world:Remove()
	self.deathmatchManager:RemoveDeathmatch(self)
	for index, player in pairs(self.players) do
		self:RemovePlayer(player)
	end
end
---------------------------------------------------------------------------------------------------------------------
----------------------------------------------------CHAT-------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Deathmatch:MessagePlayer(player, message)
	player:SendChatMessage("[" ..self.name .. "] " .. message, Color(30, 190, 0))
end

function Deathmatch:MessageGlobal(message)
	Chat:Broadcast("[" ..self.name .. "] " .. message, Color(0, 255, 0) )
end