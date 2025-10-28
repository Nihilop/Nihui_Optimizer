--[[
LibDataBroker-1.1
Simple data broker for minimap buttons
]]

local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 1)
if not lib then return end

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.attributestorage = lib.attributestorage or {}
lib.namestorage = lib.namestorage or {}
lib.proxystorage = lib.proxystorage or {}

local attributestorage, namestorage, callbacks = lib.attributestorage, lib.namestorage, lib.callbacks

function lib:NewDataObject(name, dataobj)
    if not name or namestorage[name] then return end

    dataobj = dataobj or {}
    namestorage[name] = dataobj
    attributestorage[dataobj] = {}

    callbacks:Fire("LibDataBroker_DataObjectCreated", name, dataobj)
    return dataobj
end

function lib:DataObjectIterator()
    return pairs(namestorage)
end

function lib:GetDataObjectByName(name)
    return namestorage[name]
end

function lib:GetNameByDataObject(dataobj)
    for name, obj in pairs(namestorage) do
        if obj == dataobj then
            return name
        end
    end
end
