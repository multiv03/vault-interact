-- vault-interact: los grupos (trabajo, banda) y los items del jugador, para las
-- opciones con `groups` e `items`. Detecta Qbox, QBCore, ESX y ox_inventory; si
-- no hay nada, todo vale. Config.TieneGrupo / Config.TieneItems mandan si están.
local fw, inv          -- lo detectado ('qbx', 'qb', 'esx', 'ox', 'ninguno'); nil = sin mirar
local QBCore, ESX
local cuentas = {}     -- ox_inventory: [item] = cantidad (se actualiza con su evento)

local function Arrancado(r) return GetResourceState(r) == 'started' end

local function Detectar()
    fw = Config.Puente.framework
    if fw == 'auto' then
        fw = Arrancado('qbx_core') and 'qbx' or Arrancado('qb-core') and 'qb'
            or Arrancado('es_extended') and 'esx' or 'ninguno'
    end
    inv = Config.Puente.inventario
    if inv == 'auto' then
        inv = Arrancado('ox_inventory') and 'ox' or (fw == 'qb' or fw == 'qbx') and 'qb'
            or fw == 'esx' and 'esx' or 'ninguno'
    end
    if fw == 'qb' and not QBCore then QBCore = exports['qb-core']:GetCoreObject() end
    if (fw == 'esx' or inv == 'esx') and not ESX then ESX = exports.es_extended:getSharedObject() end
    if inv == 'ox' then
        cuentas = setmetatable({}, { __index = function(t, item)
            local ok, n = pcall(function() return exports.ox_inventory:Search('count', item) end)
            n = ok and tonumber(n) or 0
            t[item] = n
            return n
        end })
    end
end

-- Si el framework o el inventario arrancan después, se vuelve a mirar.
local VIGILADOS = { qbx_core = true, ['qb-core'] = true, es_extended = true, ox_inventory = true }
AddEventHandler('onClientResourceStart', function(r) if VIGILADOS[r] then fw = nil end end)
AddEventHandler('onClientResourceStop', function(r) if VIGILADOS[r] then fw = nil end end)

AddEventHandler('ox_inventory:itemCount', function(item, n) if inv == 'ox' then cuentas[item] = n end end)

--- `filtro` como en ox_target: 'police', { 'police', 'ambulance' } o { police = 2 }
--- (grado mínimo). `grupos` = { [nombre] = grado }.
local function Coincide(filtro, grupos)
    local t = type(filtro)
    if t == 'string' then return grupos[filtro] ~= nil end
    if t ~= 'table' then return true end
    if filtro[1] then
        for _, n in ipairs(filtro) do if grupos[n] then return true end end
        return false
    end
    for n, g in pairs(filtro) do
        local mio = grupos[n]
        if mio and mio >= (tonumber(g) or 0) then return true end
    end
    return false
end

function LSI.TieneGrupo(filtro)
    if Config.TieneGrupo then return Config.TieneGrupo(filtro) and true or false end
    if not fw then Detectar() end
    if fw == 'qbx' then
        local ok, r = pcall(function() return exports.qbx_core:HasGroup(filtro) end)
        return ok and r and true or false
    elseif fw == 'qb' then
        local pd = QBCore.Functions.GetPlayerData() or {}
        local grupos = {}
        if pd.job then grupos[pd.job.name] = pd.job.grade and pd.job.grade.level or 0 end
        if pd.gang then grupos[pd.gang.name] = pd.gang.grade and pd.gang.grade.level or 0 end
        return Coincide(filtro, grupos)
    elseif fw == 'esx' then
        local job = (ESX.GetPlayerData() or {}).job
        return Coincide(filtro, job and { [job.name] = job.grade or 0 } or {})
    end
    return true
end

local function Cantidad(item)
    if inv == 'ox' then return cuentas[item] or 0 end
    local lista
    if inv == 'qb' then
        if fw == 'qbx' then return 0 end   -- Qbox siempre lleva ox_inventory
        lista = (QBCore.Functions.GetPlayerData() or {}).items
    elseif inv == 'esx' then
        lista = (ESX.GetPlayerData() or {}).inventory
    else
        return math.huge
    end
    local n = 0
    for _, it in pairs(lista or {}) do
        if it and it.name == item then n = n + (tonumber(it.amount or it.count) or 0) end
    end
    return n
end

--- `filtro` como en ox_target: 'lockpick', { 'lockpick', 'drill' } o { lockpick = 2 }.
--- Con `cualquiera`, basta con uno.
function LSI.TieneItems(filtro, cualquiera)
    if Config.TieneItems then return Config.TieneItems(filtro, cualquiera) and true or false end
    if not fw then Detectar() end
    if inv == 'ninguno' then return true end
    local t = type(filtro)
    if t == 'string' then return Cantidad(filtro) > 0 end
    if t ~= 'table' then return true end
    if filtro[1] then
        for _, item in ipairs(filtro) do
            local hay = Cantidad(item) > 0
            if cualquiera and hay then return true end
            if not cualquiera and not hay then return false end
        end
    else
        for item, n in pairs(filtro) do
            local hay = Cantidad(item) >= (tonumber(n) or 1)
            if cualquiera and hay then return true end
            if not cualquiera and not hay then return false end
        end
    end
    return not cualquiera
end
