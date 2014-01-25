class 'Deathmatch'

function Deathmatch:__init()
    Network:Subscribe("SetState", self, self.SetState)
    Network:Subscribe("SetGamemode", self, self.SetGamemode)
    Network:Subscribe("UpdateTeamScores", self, self.UpdateTeamScores)
    Network:Subscribe("UpdateDeathmatchScores", self, self.UpdateDeathmatchScores)
    Network:Subscribe("PlayerCount", self, self.PlayerCount)
    Network:Subscribe("BlockGrapple", self, self.BlockGrapple)
    Network:Subscribe("BlockParachute", self, self.BlockParachute)

    Events:Subscribe("Render", self, self.Render)
    Events:Subscribe("ModuleLoad", self, self.ModulesLoad)
    Events:Subscribe("ModulesLoad", self, self.ModulesLoad)
    Events:Subscribe("ModuleUnload", self, self.ModuleUnload)

    Events:Subscribe("LocalPlayerInput" , self , self.LocalPlayerInput)

    --states
    self.state = "Inactive"
    self.mode = nil
    self.teamnames = nil
    self.teamscores = nil
    self.deathmatchScores = nil
    self.playerCount = nil
    self.countdownTimer = nil
    self.gameTimer = nil

    self.canGrapple = true
    self.canParachute = true

    self.parachuteActions = {Action.ParachuteOpenClose, Action.DeployParachuteWhileReelingAction, Action.ExitToStuntposParachute, Action.ParachuteLandOnVehicle}
    self.blockedKeys = { }

end
---------------------------------------------------------------------------------------------------------------------
------------------------------------------------NETWORK EVENTS-------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Deathmatch:BlockGrapple()
    self.canGrapple = false
end
function Deathmatch:BlockParachute()
    self.canParachute = false
end
function Deathmatch:SetGamemode(args)
    self.mode = args.mode
    if (self.mode == "Team Deathmatch") then
        self.teamnames = {args.team1, args.team2}
    end
    print("updating gamemode", self.mode)
end
function Deathmatch:UpdateTeamScores(args)
    self.teamscores = {args.team1, args.team2}
end
function Deathmatch:UpdateDeathmatchScores(args)
    self.deathmatchScores = args
end
function Deathmatch:SetState(newstate)
    self.state = newstate
    if (newstate == "Inactive") then
        self.gameTimer = nil
        self.canGrapple = true
        self.canParachute = true
        self.teamnames = {}
    end
    if (newstate == "Lobby") then
        self.state = "Lobby"
    elseif (newstate == "Setup") then
        self.state = "Setup"
    elseif (newstate == "Countdown") then
        self.state = "Countdown"
        self.countdownTimer = Timer()
    elseif (newstate == "Running") then
        if (self.mode == "Deathmatch") then
            self.gameTimer = Timer()
        end
        self.state = "Running"
        self.countdownTimer = nil
    end
end
function Deathmatch:PlayerCount(amount)
    self.playerCount = amount
end
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Deathmatch:ModulesLoad()
    Events:Fire("HelpAddItem",
        {
            name = "Deathmatch",
            text = "le"
        } )
end

function Deathmatch:ModuleUnload()
    Events:Fire("HelpRemoveItem",
        {
            name = "Deathmatch"
        } )
end

function Deathmatch:LocalPlayerInput(args)
    if (self.state == "Running") then
        if self.canParachute == false then
            for i, action in ipairs(self.parachuteActions) do
                if args.input == action then
                    return false
                end
            end
        end
        if self.canGrapple == false then
            if args.input == Action.FireGrapple then
                return false
            end
        end
    elseif (self.state == "Setup" or self.state == "Countdown") then
        return false
    end
end
function Deathmatch:TextPos(text, size, offsetx, offsety)
    local text_width = Render:GetTextWidth(text, size)
    local text_height = Render:GetTextHeight(text, size)
    local pos = Vector2((Render.Width - text_width + offsetx)/2, (Render.Height - text_height + offsety)/2)

    return pos
end
function Deathmatch:Render()
    if (self.state == "Inactive") then return end
    if Game:GetState() ~= GUIState.Game then return end

    if (self.state ~= "Inactive") then
        local pos = Vector2(3, Render.Height - 20)
        Render:DrawText(pos, "Deathmatch 0.0.5 By Patawic", Color(255, 255, 255), TextSize.Default) 
    end
    if (self.state == "Setup") then
        self:PlayersLeft()

        local text = "Initializing"
        local textinfo = self:TextPos(text, TextSize.VeryLarge, 0, -200)
        Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.VeryLarge)    

        local text = "Please Wait..."
        local textinfo = self:TextPos(text, TextSize.Default, 0, -155)
        Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.Default)        

    elseif (self.state == "Countdown") then
        self:PlayersLeft()

        local time = 3 - math.floor(math.clamp(self.countdownTimer:GetSeconds(), 0 , 3))
        local message = {"Go!", "One", "Two", "Three"}
        local text = message[time + 1]
        local textinfo = self:TextPos(text, TextSize.Huge, 0, -200)
        Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.Huge)  
        
    elseif (self.state == "Running") then
        if (self.mode == "Deathmatch") then 
            local s = 300 - self.gameTimer:GetSeconds()
            local text = string.format("%.2d:%.2d", s/60%60, s%60)

            local text_width = Render:GetTextWidth(text, TextSize.VeryLarge)
            local pos = Vector2(Render.Width/2 - (text_width/2), 30)
            Render:DrawText(pos, text, Color(255, 255, 255), TextSize.VeryLarge)

            if (self.deathmatchScores ~= nil) then
                local text_width = Render:GetTextWidth("Top Kills", TextSize.Default)
                Render:DrawText(Vector2(Render.Width - text_width - 75,150), "Top Kills", Color(255, 255, 255), TextSize.Default)
                for index=0,10,1 do
                    if self.deathmatchScores[index] ~= nil then
                        Render:DrawText(Vector2(Render.Width - 215,170 + index*18), self.deathmatchScores[index].player .. ": " .. self.deathmatchScores[index].score, Color(255, 255, 255), TextSize.Default)
                    end
                end
            end
        elseif (self.mode == "Team Deathmatch") then

            local text_width = Render:GetTextWidth(self.teamnames[1], 25)
            local pos = Vector2(((175 - text_width)/2) + Render.Width/2 - 175, 10)
            Render:DrawText(pos, self.teamnames[1], Color(255, 255, 255), 25)

            local text_width = Render:GetTextWidth(tostring(self.teamscores[1]), TextSize.VeryLarge)
            local pos = Vector2(((175 - text_width)/2) + Render.Width/2 - 175, 45)
            Render:DrawText(pos, tostring(self.teamscores[1]), Color(255, 255, 255), TextSize.VeryLarge)

            local text_width = Render:GetTextWidth(self.teamnames[2], 25)
            local pos = Vector2(((175 - text_width)/2) + Render.Width/2, 10)
            Render:DrawText(pos, self.teamnames[2], Color(255, 255, 255), 25)

            local text_width = Render:GetTextWidth(tostring(self.teamscores[2]), TextSize.VeryLarge)
            local pos = Vector2(((175 - text_width)/2) + Render.Width/2, 45)
            Render:DrawText(pos, tostring(self.teamscores[2]), Color(255, 255, 255), TextSize.VeryLarge)

            Render:DrawLine(Vector2(Render.Width/2, 0 ), Vector2(Render.Width/2, 80), Color(255, 255, 255))
        elseif (self.mode == "Last Man Standing") then
            --RENDER PLAYER COUNT IN WORLD
            self:PlayersLeft() 
        end
    end

end

function Deathmatch:PlayersLeft()
        local angle = Angle(Camera:GetAngle().yaw, 0, math.pi) * Angle(math.pi, 0, 0)
        Render:SetTransform(self:Transform(Vector3(14130, 455, 14340), angle, 0.025))
        local text = "Players Left: " .. tostring(self.playerCount)
        Render:DrawText(Vector3(-Render:GetTextWidth(text, TextSize.Huge)/2, 0, 0), text, Color(255, 255, 255), TextSize.Huge) 
end
function Deathmatch:Transform(vector, angle, scale)
    local transform = Transform3()
    transform:Translate(vector)
    transform:Rotate(angle)
    transform:Scale(scale)
    return transform
end
Deathmatch = Deathmatch()