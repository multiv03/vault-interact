-- Bridge: every call to exports.ox_target / exports.qtarget goes to vault-interact
-- together with the name of the resource that made it, so its options are
-- removed automatically when that resource stops.
local TARGET = 'vault-interact'

local API = {
    'addPolyZone', 'addBoxZone', 'addSphereZone', 'zoneExists', 'removeZone',
    'addGlobalPed', 'removeGlobalPed', 'addGlobalVehicle', 'removeGlobalVehicle',
    'addGlobalObject', 'removeGlobalObject', 'addGlobalPlayer', 'removeGlobalPlayer',
    'addGlobalOption', 'removeGlobalOption', 'addModel', 'removeModel',
    'addEntity', 'removeEntity', 'addLocalEntity', 'removeLocalEntity',
    'getTargetOptions', 'disableTargeting', 'isActive',
    'addCoords', 'removeCoords',
}

local QTARGET = {
    'AddBoxZone', 'AddPolyZone', 'AddCircleZone', 'RemoveZone', 'AddTargetBone',
    'AddTargetEntity', 'RemoveTargetEntity', 'AddTargetModel', 'RemoveTargetModel',
    'Ped', 'RemovePed', 'Vehicle', 'RemoveVehicle', 'Object', 'RemoveObject', 'Player', 'RemovePlayer',
}

for _, name in ipairs(API) do
    exports(name, function(...)
        return exports[TARGET]:_puente(name, GetInvokingResource(), ...)
    end)
end

for _, name in ipairs(QTARGET) do
    AddEventHandler(('__cfx_export_qtarget_%s'):format(name), function(setCB)
        setCB(function(...)
            return exports[TARGET]:_puente('qt:' .. name, GetInvokingResource(), ...)
        end)
    end)
end
