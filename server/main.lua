-- vault-interact (servidor): las entidades en red con opciones (para olvidarlas
-- cuando desaparecen) y las puertas de los vehículos de otros jugadores.
local conOpciones = {}   -- [netId] = entidad
local RECURSO = GetCurrentResourceName()

RegisterNetEvent(RECURSO .. ':hasOptions', function(netId)
    netId = tonumber(netId)
    if not netId then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) then return end
    Entity(ent).state.hasTargetOptions = true
    conOpciones[netId] = ent
end)

-- La puerta la mueve quien controla el vehículo; solo si quien lo pide está al lado.
RegisterNetEvent(RECURSO .. ':door', function(netId, puerta)
    local src = source
    netId, puerta = tonumber(netId), tonumber(puerta)
    if not netId or not puerta or puerta < 0 or puerta > 5 then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 10.0 then return end
    local dueno = NetworkGetEntityOwner(veh)
    if dueno and dueno > 0 then TriggerClientEvent(RECURSO .. ':door', dueno, netId, puerta) end
end)

CreateThread(function()
    while true do
        Wait(10000)
        local quitar, n = {}, 0
        for netId, ent in pairs(conOpciones) do
            if not DoesEntityExist(ent) or not Entity(ent).state.hasTargetOptions then
                conOpciones[netId] = nil
                n = n + 1
                quitar[n] = netId
            end
        end
        if n > 0 then TriggerClientEvent(RECURSO .. ':forgetEntities', -1, quitar) end
    end
end)
