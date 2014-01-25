class "Player"
function Player:__init(player)
	self.player = player
	self.playerId = player:GetId()
    self.start_pos = player:GetPosition()
    self.start_world = player:GetWorld()
    self.inventory = player:GetInventory()

	self.team = nil
	self.killcount = 0
	self.deathcount = 0
end

function Player:Leave()
    self.player:SetWorld(self.start_world)
    self.player:SetPosition(self.start_pos)

    self.player:ClearInventory()
    for k,v in pairs(self.inventory) do
        self.player:GiveWeapon(k, v)
    end
end