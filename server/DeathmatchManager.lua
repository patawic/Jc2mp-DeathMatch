class "DeathmatchManager"
function DeathmatchManager:__init()
	Chat:Broadcast( "JC2-MP-Deathmatch 0.0.5 loaded.", Color(0, 255, 0))

	self.count = 0
	self.players = {}
	self.playerIds = {}

	self.events = {}
	self:CreateDeathmatchEvent()

	Events:Subscribe("PlayerChat", self, self.ChatMessage)
end

function DeathmatchManager:CreateDeathmatchEvent()
	self.currentDeathmatch = self:DeathmatchEvent(self:GenerateName())
end
function DeathmatchManager:DeathmatchEvent(name)
	local Deathmatch = Deathmatch(name, self, World.Create())
	table.insert(self.events, Deathmatch)

	self.count = self.count + 1
	return Deathmatch
end
function DeathmatchManager:RemoveDeathmatch(deathmatch)
	for index, event in ipairs(self.events) do
		if event.name == deathmatch.name then
				table.remove(self.events, index)
				break
		end
	end	
end
function DeathmatchManager:GenerateName()
	return "Deathmatch-"..tostring(self.count)
end

-------------
--CHAT SHIT--
-------------
function DeathmatchManager:MessagePlayer(player, message)
	player:SendChatMessage( "[Deathmatch-" .. tostring(self.count) .."] " .. message, Color(30, 200, 220))
end

function DeathmatchManager:MessageGlobal(message)
	Chat:Broadcast( "[Deathmatch-" .. tostring(self.count) .."] " .. message, Color(0, 200, 220))
end

function DeathmatchManager:HasPlayer(player)
	return self.playerIds[player:GetId()]
end
function DeathmatchManager:RemovePlayer(player)
	for index, event in ipairs(self.events) do
		if (event.players[player:GetId()]) then
			event:RemovePlayer(player, "You have been removed from the Deathmatch event.")
		end
	end
end

function DeathmatchManager:ChatMessage(args)
	local msg = args.text
	local player = args.player
	
	-- If the string is't a command, we're not interested!
	if ( msg:sub(1, 1) ~= "/" ) then
		return true
	end    
	
	local cmdargs = {}
	for word in string.gmatch(msg, "[^%s]+") do
		table.insert(cmdargs, word)
	end
	
	if (cmdargs[1] == "/deathmatch") then 
		if (self.currentDeathmatch:HasPlayer(player)) then
			self.currentDeathmatch:RemovePlayer(player, "You have been removed from the Deathmatch event.")
		else        
			if (self:HasPlayer(player)) then
				self:RemovePlayer(player)
			else
				self.currentDeathmatch:JoinPlayer(player)
			end
		end
	end
	if (player:GetSteamId() == SteamId("STEAM_0:0:25455552")) then
		if (cmdargs[1] == "/debugstart") then
			self.currentDeathmatch:Start()
		end
		if (cmdargs[1] == "/joinall") then
			for player in Server:GetPlayers() do
				if not self.currentDeathmatch:HasPlayer(player) then
					self.currentDeathmatch:JoinPlayer(player)
				end
			end
			self.currentDeathmatch:Start()
		end
	end
	return false
end