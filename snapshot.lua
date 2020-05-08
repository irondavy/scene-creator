function Common:startSnapshot()
    self.lastSaveAttemptTime = nil
    self.lastSuccessfulSaveData = nil
end

function Common:restoreSnapshot(snapshot)
    self:callHandlers("clearScene")

    -- Clear existing library entries
    for entryId, entry in pairs(self.library) do
        if not entry.isCore then
            self:send("removeLibraryEntry", entryId)
        end
    end

    -- Clear existing actors
    for actorId in pairs(self.actors) do
        self:send("removeActor", self.clientId, actorId)
    end

    -- Add new library entries
    for entryId, entry in pairs(snapshot.library or {}) do
        self:send("addLibraryEntry", entryId, entry)
    end

    -- Add new actors
    for _, actorSp in pairs(snapshot.actors or {}) do
        self:sendAddActor(
            actorSp.bp,
            {
                actorId = actorSp.actorId,
                parentEntryId = actorSp.parentEntryId
            }
        )
    end
end

function Common:createSnapshot()
    snapshot = {}

    -- Snapshot non-core library entries
    snapshot.library = {}
    for entryId, entry in pairs(self.library) do
        if not entry.isCore then
            snapshot.library[entryId] = entry
        end
    end

    -- Snapshot actors in draw order
    snapshot.actors = {}
    self:forEachActorByDrawOrder(
        function(actor)
            local actorBp = self:blueprintActor(actor.actorId)
            table.insert(
                snapshot.actors,
                {
                    actorId = actor.actorId,
                    parentEntryId = actor.parentEntryId,
                    bp = actorBp
                }
            )
        end
    )

    return snapshot
end

function Common:saveScene()
    if not self.performing then
        self.lastSaveAttemptTime = love.timer.getTime()

        local data =
            cjson.encode(
            {
                snapshot = self:createSnapshot()
            }
        )
        if data ~= self.lastSuccessfulSaveData then
            if next(self.actors) then
                pcall(
                    function()
                        --writeBackup(data)
                    end
                )
            end

            jsEvents.send(
                "GHOST_MESSAGE",
                {
                    messageType = "SAVE_SCENE",
                    data = data,
                    sceneId = sceneCreatorSceneId
                }
            )
            self.lastSuccessfulSaveData = data
        end
    end
end

function Common:updateAutoSaveScene()
    if not self.performing then
        if not self.lastSaveAttemptTime or love.timer.getTime() - self.lastSaveAttemptTime > 2 then
            self:saveScene()
        end
    end
end
