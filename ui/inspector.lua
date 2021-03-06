local Inspector = {
   renderTab = {},
}

function Client:_uiActorAllowsBehavior(actor, behavior)
   -- if actor has body and this is text, return false
   if (actor.components[self.behaviorsByName.Body.behaviorId] and behavior == self.behaviorsByName.Text) then
      return false
   end

   -- if actor has text and this is not rules or text, return false
   if (actor.components[self.behaviorsByName.Text.behaviorId] and behavior ~= self.behaviorsByName.Rules) and behavior ~= self.behaviorsByName.Text then
      return false
   end
   return true
end

function Client:_componentInspector(actorId, component)
    local behavior = self.behaviors[component.behaviorId]
    local uiName = behavior:getUiName()

    -- Spacer
    ui.box('spacer', { height = 8 }, function() end)

    -- Header
    if behavior.name ~= 'Text' then
        ui.box('header', {
            flexDirection = 'row',
        }, function()
            ui.box('title', {
                flex = 1,
            }, function()
                ui.markdown('## ' .. uiName)
            end)
            ui.button('description', {
                margin = 0,
                marginLeft = 6,
                icon = 'question',
                iconFamily = 'FontAwesome5',
                hideLabel = true,
                popoverAllowed = true,
                popoverStyle = { width = 300 },
                popover = function()
                    ui.markdown('## ' .. uiName .. '\n' .. (behavior.description or ''))
                end,
            })
            if behavior.name ~= 'Body' then
               self:_removeBehaviorButton(actorId, component, behavior, uiName)
            end
        end)
    end -- header

    -- Component's UI
    behavior:callHandler('uiComponent', component, {})
    
    ui.box('spacer', { height = 8 }, function() end)
end

function Client:_removeBehaviorButton(actorId, component, behavior, uiName)
    ui.button('remove', {
        margin = 0,
        marginLeft = 6,
        icon = 'close',
        iconFamily = 'FontAwesome',
        hideLabel = true,
        onClick = function()
            if next(component.dependents) ~= nil then -- Has dependents?
                local names = {}
                for dependentId in pairs(component.dependents) do
                    local dependent = self.behaviors[dependentId]
                    table.insert(names, dependent:getUiName())
                end
                local list = ''
                for i = 1, #names do
                    if i > 1 then
                        if i < #names then
                            list = list .. ', '
                        else
                            list = list .. ' and '
                        end
                    end
                    list = list .. "'" .. names[i] .. "'"
                end
                local message = (list .. ' need' .. (#names > 1 and '' or 's') .. " '" ..
                    uiName .. "'.")
                castle.system.alert("Cannot remove '" .. uiName .. "'", message)
            else
                castle.system.alert({
                    title = 'Remove behavior?',
                    message = "Remove '" .. uiName .. "' from this actor?",
                    okLabel = 'Yes',
                    cancelLabel = 'No',
                    onOk = function()
                        local behaviorId = component.behaviorId
                        local componentBp = {}
                        behavior:callHandler('blueprintComponent', component, componentBp)
                        self:command('remove ' .. uiName, {
                            params = { 'behaviorId', 'componentBp' },
                        }, function()
                            local behavior = self.behaviors[behaviorId]
                            if not behavior.components[actorId] then
                                return 'behavior was removed'
                            end
                            self:send('removeComponent', self.clientId, actorId, behaviorId)
                            self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
                        end, function()
                            local behavior = self.behaviors[behaviorId]
                            if behavior.components[actorId] then
                                return 'behavior was added'
                            end
                            self:send('addComponent', self.clientId, actorId, behaviorId, componentBp)
                            self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
                        end)
                    end
                })
            end
        end,
    })
end

function Client:_addBehavior(actor, behaviorId, closePopover)
    closePopover = closePopover or function() end
    local behavior = self.behaviors[behaviorId]
    local actorId = actor.actorId

    -- Get full order of adding behaviors in case of non-present dependencies
    local order = {}
    local visited = {}
    local function visit(behavior)
        if visited[behavior.behaviorId] then
            return
        end
        visited[behavior.behaviorId] = true
        if not actor.components[behavior.behaviorId] then
            for _, dependency in pairs(behavior.dependencies) do
                visit(dependency)
            end
            table.insert(order, behavior.behaviorId)
        end
    end
    visit(behavior)

    -- Prompt if adding more than one behavior, else add immediately
    local function doIt()
        closePopover()

        self:command('add ' .. behavior:getUiName(), {
            params = { 'behaviorId', 'order' },
        }, function()
            local behavior = self.behaviors[behaviorId]
            if behavior.components[actorId] then
                return 'behavior was added'
            end
            for i = 1, #order do
                self:send('addComponent', self.clientId, actorId, order[i], {}, {
                    interactive = true,
                })
            end
            self.openComponentBehaviorId = behaviorId
            self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
        end, function()
            local behavior = self.behaviors[behaviorId]
            if not behavior.components[actorId] then
                return 'behavior was removed'
            end
            for i = #order, 1, -1 do
                self:send('removeComponent', self.clientId, actorId, order[i])
            end
            self.updateCounts[actorId] = (self.updateCounts[actorId] or 1) + 1
        end)
    end
    if #order > 1 then
        local list = ''
        for i = 1, #order - 1 do
            if i > 1 then
                if i < #order - 1 then
                    list = list .. ', '
                else
                    list = list .. ' and '
                end
            end
            list = list .. "'" .. self.behaviors[order[i]]:getUiName() .. "'"
        end
        local message = ("'" .. behavior:getUiName() .. "' needs " .. list ..
            '. Add ' .. (#order == 2 and 'it' or 'them') .. ' also?')
        castle.system.alert({
            title = 'Add needed behaviors?',
            message = message,
            okLabel = 'Yes',
            cancelLabel = 'No',
            onOk = function()
                doIt()
            end,
            onCancel = function()
                closePopover()
            end
        })
    else
        doIt()
    end
end

function Client:_addBehaviorButton(actor)
    ui.button('add behavior', {
        icon = 'plus',
        iconFamily = 'FontAwesome5',
        hideLabel = true,
        popoverAllowed = true,
        popoverStyle = { width = 300, height = 300 },
        popover = function(closePopover)
            self:uiLibrary({
                id = 'add behavior',
                filterType = 'behavior',
                filterBehavior = function(behavior)
                   -- skip behavior limitations enforced at ui level
                   if not self:_uiActorAllowsBehavior(actor, behavior) then return false end

                   -- Skip behaviors we already have, skip tools
                    return not (actor.components[behavior.behaviorId] or behavior.tool)
                end,
                emptyText = 'No other behaviors to add!',
                buttons = function(entry)
                    ui.button('add to actor', {
                        flex = 1,
                        icon = 'plus',
                        iconFamily = 'FontAwesome5',
                        onClick = function()
                           local behaviorId = entry.behaviorId
                           self:_addBehavior(actor, behaviorId, closePopover)
                        end,
                    })
                end,
            })
        end,
    })

end

function Inspector:orderedComponents(components)
    local order = {}
    -- Sort by `behaviorId`
    for behaviorId, component in pairs(components) do
        local behavior = self.behaviors[behaviorId]
        if not behavior.tool and behavior.handlers.uiComponent then
            table.insert(order, component)
        end
    end
    table.sort(order, function (component1, component2)
        return component1.behaviorId < component2.behaviorId
    end)
    return order
end

function Inspector:tabByName(tabName)
   for _, tab in ipairs(self.inspectorTabs) do
      if tab.name == tabName then return tab end
   end
   return nil
end

function Inspector:renderBehaviors(tabName, actor)
   local tab = Inspector.tabByName(self, tabName)
   for _, behaviorName in ipairs(tab.behaviors) do
      local behavior = self.behaviorsByName[behaviorName]
      if not behavior then
         print('tab references unknown behavior: ' .. behaviorName)
         return
      end

      if self:_uiActorAllowsBehavior(actor, behavior) then
          local component = actor.components[behavior.behaviorId]
          if component then
             self:_componentInspector(actor.actorId, component)
          else
             -- show a row to add component to actor
             ui.box('behavior-' .. behavior:getUiName(), {
                 marginBottom = 16
             }, function()
                 ui.box('add-behavior-row', {
                     flexDirection = 'row',
                     marginBottom = 16,
                 }, function()
                    ui.box('title', {
                        flex = 1,
                    }, function()
                        ui.markdown('## ' .. behavior:getUiName())
                    end)
                    ui.button('add-behavior', {
                        margin = 0,
                        marginLeft = 6,
                        icon = 'plus',
                        iconFamily = 'FontAwesome5',
                        hideLabel = true,
                        onClick = function()
                           self:_addBehavior(actor, behavior.behaviorId)
                        end
                    })
                 end)
                 ui.box('description', function() ui.markdown('#### ' .. (behavior.description or '')) end)
             end)
         end
      end
   end
end

function Inspector.renderTab:general(actor)
   -- General behaviors
   Inspector.renderBehaviors(self, 'general', actor)

   -- Spacer
   ui.box('spacer-2', { height = 8 }, function() end)
   
   -- Save blueprint
   self:_saveBlueprintButton(actor)
end

function Inspector.renderTab:movement(actor)
   Inspector.renderBehaviors(self, 'movement', actor)
end

function Inspector.renderTab:rules(actor)
    -- Make sure `self.openComponentBehaviorId` is valid
    if not self.behaviors[self.openComponentBehaviorId] then
        self.openComponentBehaviorId = nil
    end
    ui.scrollBox('inspector-rules-box', function()
        local behaviorId = self.behaviorsByName.Rules.behaviorId
        local component = actor.components[behaviorId]
        if component then
           self:_componentInspector(actor.actorId, component)
        else
            ui.button('Add Rules', {
                flex = 1,
                icon = 'plus',
                iconFamily = 'FontAwesome5',
                onClick = function()
                   self:_addBehavior(actor, behaviorId)
                end,
            })
        end
    end)
end

function Client:uiInspector()
   local actorId = next(self.selectedActorIds)
   if actorId then
      local actor = self.actors[actorId]

      -- Does the active tool have a panel?
      local activeTool = self.activeToolBehaviorId and self.tools[self.activeToolBehaviorId]

      if activeTool and activeTool.handlers.uiPanel then
          local uiName = activeTool:getUiName()
          ui.scrollBox('inspector-tool-' .. uiName, {
              padding = 2,
              margin = 2,
              flex = 1,
          }, function()
              activeTool:callHandler('uiPanel')
          end)
          return
      end
      
      local render = Inspector.renderTab[self.selectedInspectorTab]
      if render then
         render(self, actor)
      else
         Inspector.renderTab['general'](self, actor)
      end
   end
end
