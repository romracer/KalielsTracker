--- MSA-Event-1.0
--- Based on AceEvent-3.0
--- - Wrapped API - aggregates all same events into one frame and control them separately
--- - Unwrapped API - same as AceEvent
--- Copyright (c) 2024, Marouan Sabbagh <mar.sabbagh@gmail.com>
--- All Rights Reserved.

local name, version = "MSA-Event-1.0", 0

local lib = LibStub:NewLibrary(name, version)
if not lib then return end

local CallbackHandler = LibStub("CallbackHandler-1.0")

-- Lua API
local pairs = pairs
local strmatch = string.match
local tinsert = table.insert
local tonumber = tonumber
local type = type

-- Registry Blizzard Events
lib.frame = lib.frame or CreateFrame("Frame")
lib.events = lib.events or CallbackHandler:New(lib, "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents")

function lib.events:OnUsed(target, event)
    lib.frame:RegisterEvent(event)
end

function lib.events:OnUnused(target, event)
    lib.frame:UnregisterEvent(event)
end

lib.frame:SetScript("OnEvent", function(_, event, ...)
    lib.events:Fire(event, ...)
end)

-- Registry Event Handlers
lib.eventHandlers = lib.eventHandlers or {}

local function handleEvent(self, event, ...)
    local list = lib.eventHandlers[event]
    if list then
        --print("|cff00ffff"..event, "|r...", ...)
        for id, handler in pairs(list) do
            local eventID = event.."-"..id
            if type(handler) == "function" then
                handler(eventID, ...)
            else
                self[handler](self, eventID, ...)
            end
        end
    end
end

function lib:RegEvent(event, methodOrName)
    local list = lib.eventHandlers[event]
    if not list then
        list = {}
        lib.eventHandlers[event] = list
        self:RegisterEvent(event, handleEvent, self)
    end
    tinsert(list, methodOrName)
    --print("|cff00ff00REG|r ...", event.."-"..#list)
end

function lib:UnregEvent(eventID)
    --print("|cffff0000UNREG|r ...", eventID)
    local event, id = strmatch(eventID, "^(%S+)-(%d+)$")
    local list = lib.eventHandlers[event]
    if list then
        id = tonumber(id)
        list[id] = nil
        if not next(list) then
            self:UnregisterEvent(event)
        end
    end
end

function lib:UnregAllEvents()
    --print("|cffff0000UNREG|r ... ALL events")
    lib.eventHandlers = {}
    self:UnregisterAllEvents()
end

------------------------------------------------------------------------------------------------------------------------
-- Embed handling
------------------------------------------------------------------------------------------------------------------------

lib.embeds = lib.embeds or {}

local mixins = {
    "RegEvent", "UnregEvent", "UnregAllEvents",  -- Wrapped
    "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents"  -- Unwrapped
}

function lib:Embed(target)
    for _, v in pairs(mixins) do
        target[v] = self[v]
    end
    self.embeds[target] = true
    return target
end

function lib:OnEmbedDisable(target)
    target:UnregAllEvents()
end

for target in pairs(lib.embeds) do
    lib:Embed(target)
end