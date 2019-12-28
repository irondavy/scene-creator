-- 'multi' boilerplate
Game = require('multi.server', { root = true })
Common, Server, Client = Game.Common, Game.Server, Game.Client
require 'Common'


-- Start / stop

function Server:start()
    Common.start(self)

    -- Server-local initialization below


    local worldId = self.physics:newWorld(0, 32 * 64, true)


    -- Walls

    local function createWall(x, y, width, height)
        local bodyId = self.physics:newBody(worldId, x, y)
        local shapeId = self.physics:newRectangleShape(width, height)
        local fixtureId = self.physics:newFixture(bodyId, shapeId)
        self.physics:destroyObject(shapeId)
    end

    local wallThickness = 20

    createWall(800 / 2, wallThickness / 2, 800, wallThickness)
    createWall(800 / 2, 450 - wallThickness / 2, 800, wallThickness)
    createWall(wallThickness / 2, 450 / 2, wallThickness, 450)
    createWall(800 - wallThickness / 2, 450 / 2, wallThickness, 450)
end


-- Connect / reconnect / disconnect

function Server:syncClient(clientId)
    -- Perform a full synchronization for a new or reconnecting client

    local function send(kind, ...) -- Shorthand to send messages to this client only
        self:send({
            kind = kind,
            to = clientId,
            selfSend = false,
            channel = MAIN_RELIABLE_CHANNEL,
        }, ...)
    end

    -- Sync physics (do this before stuff below so that the physics world exists)
    self.physics:syncNewClient({
        clientId = clientId,
        channel = MAIN_RELIABLE_CHANNEL,
    })

    -- Sync mes
    for clientId, me in pairs(self.mes) do
        send('me', clientId, me)
    end
end

function Server:connect(clientId)
    self:syncClient(clientId)
end

function Server:reconnect(clientId)
    self:syncClient(clientId)
end

function Server:disconnect(clientId)
end


-- Test

function Server.receivers:remove(time, x, y)
    local worldId, world = self.physics:getWorld()
    if world then
        -- Find body under touch
        local body, bodyId
        world:queryBoundingBox(
            x - 1, y - 1, x + 1, y + 1,
            function(fixture)
                -- The query only tests AABB overlap -- check if we've actually touched the shape
                if fixture:testPoint(x, y) then
                    local candidateBody = fixture:getBody()
                    local candidateBodyId = self.physics:idForObject(candidateBody)

                    -- Skip if the body isn't networked
                    if not candidateBodyId then
                        return true
                    end

                    -- Seems good!
                    body, bodyId = candidateBody, candidateBodyId
                    return false
                end
                return true
            end)

        -- If found, add this touch
        if bodyId then
            self.physics:destroyObject(bodyId)
        end
    end
end


-- Update

function Server:update(dt)
    Common.update(self, dt)


    -- Silly test of adding bodies dynamically
    local worldId, world = self.physics:getWorld()
    if worldId then
        if not self.lastBodyCreateTime or self.time - self.lastBodyCreateTime > 3 then
            local function createDynamicBody(shapeId)
                local bodyId = self.physics:newBody(worldId, math.random(70, 800 - 70), math.random(70, 70), 'dynamic')
                local fixtureId = self.physics:newFixture(bodyId, shapeId, 1)
                self.physics:destroyObject(shapeId)
                self.physics:setFriction(fixtureId, 0.4)
                self.physics:setLinearDamping(bodyId, 2.8)
            end

            for i = 1, 3 do -- Circles
                createDynamicBody(self.physics:newCircleShape(math.random(10, 20)))
            end

            self.lastBodyCreateTime = self.time
        end
    end
end
