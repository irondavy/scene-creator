ui = castle.ui

UNIT = 1
MAX_BODY_SIZE = UNIT * 40
MIN_BODY_SIZE = UNIT / 4
DEFAULT_VIEW_WIDTH = 10 * UNIT
MIN_VIEW_WIDTH = DEFAULT_VIEW_WIDTH / 10
MAX_VIEW_WIDTH = DEFAULT_VIEW_WIDTH * 4
VIEW_HEIGHT_TO_WIDTH_RATIO = 7 / 5

CHECKERBOARD_IMAGE_URL =
    "https://raw.githubusercontent.com/nikki93/edit-world/4c9d0d6f92b3a67879c7a5714e6608530093b45a/assets/checkerboard.png"

serpent = require "vendor.serpent"
bitser = require "vendor.bitser"
inspect = require "vendor.inspect"

jsEvents = require "__ghost__.jsEvents"
jsBridge = require "__ghost__.bridge"
cjson = require "cjson"
copas = require "copas"

-- Modules

if not castle.system.isRemoteServer() then
    tove = require "vendor.tove"
end

resource_loader = require "resource_loader"
util = require "util"
helps = require "helps"

require "actor_behavior" -- -- -- Message kind definition -- Start / stop

require "behaviors.body"
require "behaviors.image"
require "behaviors.drawing"

require "behaviors.circle_shape"

require "behaviors.solid"
require "behaviors.bouncy"

require "behaviors.moving"
require "behaviors.falling"
require "behaviors.sliding"
require "behaviors.slowdown"
require "behaviors.friction"
require "behaviors.speed_limit"
require "behaviors.rotating_motion"

require "behaviors.sling"
require "behaviors.drag"

require "behaviors.rules"
require "behaviors.tags"
require "behaviors.counter"
require "behaviors.text"

require "tools.grab"
require "tools.draw"

require "library"
require "snapshot"
require "command"
require "variables"

function Common:start()
    self.onEndOfFrames = {}

    self._nextIdSuffix = 1

    self:startActorBehavior()
    self:startLibrary()
    self:startSnapshot()
    self:startCommand()
    self:startVariables()

    self.performing = true
    self.paused = false
end

function Common:stop()
    self:stopActorBehavior()
end

function Common:send(opts, ...)
    if type(opts) == "string" then -- Shorthand
        opts = {kind = opts}
    end

    local kind = opts.kind
    assert(type(kind) == "string", "send: `kind` needs to be a string")

    print("send calling " .. kind .. "()")

    self.receivers[kind](self, 0, ...)
end

function Common:generateId()
    local suffix = tostring(self._nextIdSuffix)
    self._nextIdSuffix = self._nextIdSuffix + 1

    local prefix = "0"

    return prefix .. "-" .. suffix
end

-- Users

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end
--
--function Common.receivers:ping(time, clientId)
--   self.lastPingTimes[clientId] = time
--end

-- Performance

function Common:updatePerformance(dt)
    if self.performing and not self.paused then
        self:callHandlers("prePerform", dt)
        self:callHandlers("perform", dt)
        self:callHandlers("postPerform", dt)
    end
end

function Common.receivers:setPerforming(time, performing)
    if self.performing ~= performing then
        self.performing = performing
        self:callHandlers("setPerforming", performing)
    end
end

function Common.receivers:setPaused(time, paused)
    if self.paused ~= paused then
        self.paused = paused
        self:callHandlers("setPaused", paused)
    end
end

function Common.receivers:clearScene(time)
    self:callHandlers("clearScene", paused)
end
--

-- Methods

function Common:fireOnEndOfFrame()
    local onEndOfFrames = self.onEndOfFrames
    for _, func in ipairs(onEndOfFrames) do
        func()
    end
    self.onEndOfFrames = {}
end

function Common:restartScene()
    if self.rewindSnapshotId then
        self:send("setPaused", true)

        -- TODO: jesse
        self:send(
            {
                selfSendOnly = not (not self.server),
                kind = "restoreSnapshot"
            },
            self.rewindSnapshotId,
            {stopPerforming = false}
        )

        network.async(
            function()
                copas.sleep(0.4)
                self:send("setPaused", false)
            end
        )
    end
end
