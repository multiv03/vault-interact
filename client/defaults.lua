-- vault-interact: las opciones de serie de ox_target, abrir y cerrar puertas, capó
-- y maletero de cualquier vehículo. Cada puerta es un punto en su manilla.
-- No se ponen si el ox_target de verdad o sleepless_interact están arrancados
-- (ya traen las suyas).
-- Respeta el convar de ox_target: setr ox_target:defaults 0 las quita.
if not Config.Target.puertas or GetConvarInt('ox_target:defaults', 1) ~= 1 then return end

local T = LSI.T
local API = LSI.API
local RECURSO = LSI.Recurso

local PUERTAS = {
    { n = 0, huesos = { 'handle_dside_f', 'door_dside_f', 'seat_dside_f' } },
    { n = 1, huesos = { 'handle_pside_f', 'door_pside_f', 'seat_pside_f' } },
    { n = 2, huesos = { 'handle_dside_r', 'door_dside_r', 'seat_dside_r' } },
    { n = 3, huesos = { 'handle_pside_r', 'door_pside_r', 'seat_pside_r' } },
    { n = 4, offset = vector3(0.5, 0.88, 0.62), abrir = 'open_hood', cerrar = 'close_hood', icono = 'fa-solid fa-car' },
    { n = 5, offset = vector3(0.5, 0.1, 0.62), abrir = 'open_trunk', cerrar = 'close_trunk', icono = 'fa-solid fa-car-rear' },
}

local function Alternar(veh, n)
    if GetVehicleDoorLockStatus(veh) == 2 then return end
    if GetVehicleDoorAngleRatio(veh, n) > 0.0 then
        SetVehicleDoorShut(veh, n, false)
    else
        SetVehicleDoorOpen(veh, n, false, false)
    end
end

local function Puede(veh, n, abierta)
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then return false end
    if not GetIsDoorValid(veh, n) or IsVehicleDoorDamaged(veh, n) then return false end
    if GetVehicleDoorLockStatus(veh) > 1 then return false end
    return (GetVehicleDoorAngleRatio(veh, n) > 0.0) == abierta
end

local function Usar(datos, n)
    local veh = datos.entity
    if not NetworkGetEntityIsNetworked(veh) or NetworkGetEntityOwner(veh) == PlayerId() then
        return Alternar(veh, n)
    end
    TriggerServerEvent(RECURSO .. ':door', VehToNet(veh), n)
end

RegisterNetEvent(RECURSO .. ':door', function(netId, n)
    local veh = NetToVeh(netId)
    if veh ~= 0 and DoesEntityExist(veh) then Alternar(veh, n) end
end)

local opciones = {}
for _, p in ipairs(PUERTAS) do
    for _, abierta in ipairs({ false, true }) do
        local n = p.n
        opciones[#opciones + 1] = {
            name = ('%s:door%d%s'):format(RECURSO, n, abierta and 'c' or 'o'),
            label = T[abierta and (p.cerrar or 'close_door') or (p.abrir or 'open_door')],
            icon = p.icono or 'fa-solid fa-car-side',
            bones = p.huesos,
            offset = p.offset,
            distance = p.huesos and 1.6 or 2.0,
            canInteract = function(veh) return Puede(veh, n, abierta) end,
            onSelect = function(datos) Usar(datos, n) end,
        }
    end
end

local NOMBRES = {}
for i, op in ipairs(opciones) do NOMBRES[i] = op.name end

--- El ox_target de verdad (no el puente de este recurso) u otro que ocupa su
--- sitio está arrancado.
local function OxOriginal()
    if GetResourceState('sleepless_interact') == 'started' then return true end
    local s = GetResourceState('ox_target')
    if s ~= 'started' and s ~= 'starting' then return false end
    return GetResourceMetadata('ox_target', 'vault_interact_bridge', 0) ~= 'yes'
        and GetResourceMetadata('ox_target', 'ls_interact_puente', 0) ~= 'yes'
end

local puestas = false
local function Poner()
    if OxOriginal() then
        if puestas then API.removeGlobalVehicle(RECURSO, NOMBRES) puestas = false end
    elseif not puestas then
        API.addGlobalVehicle(RECURSO, opciones)
        puestas = true
    end
end

Poner()
AddEventHandler('onClientResourceStart', function(r) if r == 'ox_target' or r == 'sleepless_interact' then Poner() end end)
AddEventHandler('onClientResourceStop', function(r) if r == 'ox_target' or r == 'sleepless_interact' then SetTimeout(0, Poner) end end)
