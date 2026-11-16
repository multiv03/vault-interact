-- vault-interact: las interacciones, con la misma API que ox_target.
-- Zonas (caja, esfera, polígono), puntos sueltos, modelos, entidades y opciones
-- globales para peds, vehículos, objetos y jugadores. Cada sitio con opciones se
-- vuelve un punto (una entidad con huesos u offsets da un punto por cada uno):
-- al acercarse se ve un indicador y, al mirarlo, la etiqueta enseña sus
-- opciones. La rueda (o las flechas) elige y E usa la opción.
--
-- Las opciones son las de ox_target: label, name, icon, iconColor, distance,
-- groups, items, anyItem, bones, offset, absoluteOffset, offsetSize,
-- canInteract, onSelect, export, event, serverEvent, command, openMenu y
-- menuName. Y dos más: holdTime (ms que hay que mantener la tecla) y cooldown
-- (ms hasta que se puede volver a usar).
local Z = LSI.Zonas
local T = LSI.T
local Llamar = LSI.Llamar
local RECURSO = LSI.Recurso
local sqrt, max, min = math.sqrt, math.max, math.min

local peds, vehiculos, objetos, jugadores, globales = {}, {}, {}, {}, {}
local TIPOS = { [1] = peds, [2] = vehiculos, [3] = objetos }
local NOMBRE_TIPO = { [1] = 'ped', [2] = 'vehiculo', [3] = 'objeto' }
local modelos = {}    -- [hash] = opciones
local entidades = {}  -- [netId] = opciones
local locales = {}    -- [entidad] = opciones
local zonas = {}      -- [id] = zona (de LSI.Zonas.Crear, con sus opciones)
local nZonas = 0
local dims = {}       -- [modelo] = { minX, minY, minZ, maxX, maxY, maxZ }

local desactivado = false
local est = { historial = {}, sel = 1 }   -- el punto que se mira: su submenú y la opción elegida
local mantenido                           -- { id, op, inicio, dur } mientras se mantiene la tecla
local siguienteEleccion = 0
local enMenu = false
local margen = Config.Indicadores.activo and Config.Indicadores.margen or 0.0

local VOLVER = { name = 'builtin:goback', label = T.back, icon = 'fa-solid fa-circle-chevron-left', _volver = true }

-- ── Las opciones ─────────────────────────────────────────────────────────────
local function Distancia(d)
    d = tonumber(d) or Config.Target.distancia
    local tope = Config.Target.distanciaMax
    if tope and d > tope then d = tope end
    return d
end

--- Una opción o una lista de opciones → lista (como checkOptions de ox_target).
local function Opciones(opciones, recurso)
    if type(opciones) ~= 'table' then
        LSI.Aviso('%s: options must be a table (got %s)', tostring(recurso), type(opciones))
        return {}
    end
    if opciones[1] == nil then
        if opciones.label or opciones.name then return { opciones } end
        return {}
    end
    return opciones
end

--- Lo que se calcula una vez por opción: de dónde cuelga en la entidad y su distancia.
local function Preparar(op, recurso)
    op.resource = recurso
    local b = op.bones
    if type(b) == 'string' then b = { b } end
    if type(b) == 'table' and b[1] then
        op._huesos = b
        op._ancla = 'b:' .. table.concat(b, ',')
    elseif op.offset then
        local x, y, z = LSI.Vec(op.offset)
        op._off = { x or 0.0, y or 0.0, z or 0.0 }
        op._ancla = ('o:%.3f,%.3f,%.3f%s'):format(op._off[1], op._off[2], op._off[3], op.absoluteOffset and 'a' or '')
    else
        op._ancla = 'c'
    end
    op._dist = Distancia(op.distance)
    return op
end

local function QuitarDe(lista, nombres, recurso, avisar)
    if type(nombres) ~= 'table' then nombres = { nombres } end
    for i = #lista, 1, -1 do
        local op = lista[i]
        if op.resource == recurso then
            for j = 1, #nombres do
                if op.name == nombres[j] then
                    table.remove(lista, i)
                    if avisar and Config.Debug then LSI.Aviso("%s: option '%s' replaced (same name)", recurso, op.name) end
                    break
                end
            end
        end
    end
end

--- Añade opciones a una lista. Una opción con el mismo `name` (y del mismo
--- recurso) que otra ya puesta la sustituye.
local function Anadir(lista, opciones, recurso)
    opciones = Opciones(opciones, recurso)
    local nombres = {}
    for _, op in ipairs(opciones) do
        if type(op) == 'table' and op.name then nombres[#nombres + 1] = op.name end
    end
    if nombres[1] then QuitarDe(lista, nombres, recurso, true) end
    for _, op in ipairs(opciones) do
        if type(op) == 'table' then lista[#lista + 1] = Preparar(op, recurso) end
    end
end

local function QuitarRecurso(lista, recurso)
    for i = #lista, 1, -1 do
        if lista[i].resource == recurso then table.remove(lista, i) end
    end
end

local function MaxDist(lista)
    local m = 0
    for _, op in ipairs(lista) do if op._dist > m then m = op._dist end end
    return m
end

-- ── API (la de ox_target, con el recurso que llama delante) ──────────────────
local API = {}
LSI.API = API

local function NuevaZona(recurso, tipo, datos)
    if type(datos) ~= 'table' then
        LSI.Aviso('%s: zone data must be a table', tostring(recurso))
        return nil
    end
    local ok, z = pcall(Z.Crear, tipo, datos)
    if not ok then
        LSI.Aviso('%s: invalid zone %s (%s)', tostring(recurso), tostring(datos.name or tipo), tostring(z))
        return nil
    end
    nZonas = nZonas + 1
    z.id, z.name, z.resource = nZonas, datos.name, recurso
    z.drawSprite, z.debug, z.color = datos.drawSprite, datos.debug, datos.debugColour
    z.opciones = {}
    Anadir(z.opciones, datos.options, recurso)
    z._max = MaxDist(z.opciones)
    zonas[z.id] = z
    if z.debug then LSI.Aviso('%s: zone %s has debug enabled', tostring(recurso), tostring(z.name or z.id)) end
    return z.id
end

function API.addBoxZone(r, datos) return NuevaZona(r, 'box', datos) end
function API.addSphereZone(r, datos) return NuevaZona(r, 'sphere', datos) end
function API.addPolyZone(r, datos) return NuevaZona(r, 'poly', datos) end

--- Extra (no está en ox_target): opciones en un punto suelto del mundo.
--- `coords` puede ser una lista de puntos; entonces devuelve una lista de ids.
function API.addCoords(r, coords, opciones)
    if type(coords) == 'table' and coords[1] ~= nil and type(coords[1]) ~= 'number' then
        local ids = {}
        for i, c in ipairs(coords) do ids[i] = NuevaZona(r, 'punto', { coords = c, options = opciones }) end
        return ids
    end
    return NuevaZona(r, 'punto', { coords = coords, options = opciones })
end

function API.zoneExists(r, id)
    if type(id) == 'number' then return zonas[id] ~= nil end
    if type(id) == 'string' then
        for _, z in pairs(zonas) do if z.name == id then return true end end
    end
    return false
end

function API.removeZone(r, id, silencio)
    if type(id) == 'table' then
        for _, i in ipairs(id) do API.removeZone(r, i, silencio) end
        return
    end
    if type(id) == 'string' then
        local hubo = false
        for k, z in pairs(zonas) do
            if z.name == id then zonas[k] = nil hubo = true end
        end
        if hubo then return end
    elseif id and zonas[id] then
        zonas[id] = nil
        return
    end
    if not silencio and Config.Debug then LSI.Aviso('%s: zone %s does not exist', tostring(r), tostring(id)) end
end

API.removeCoords = API.removeZone

function API.addGlobalPed(r, o) Anadir(peds, o, r) end
function API.removeGlobalPed(r, o) QuitarDe(peds, o, r) end
function API.addGlobalVehicle(r, o) Anadir(vehiculos, o, r) end
function API.removeGlobalVehicle(r, o) QuitarDe(vehiculos, o, r) end
function API.addGlobalObject(r, o) Anadir(objetos, o, r) end
function API.removeGlobalObject(r, o) QuitarDe(objetos, o, r) end
function API.addGlobalPlayer(r, o) Anadir(jugadores, o, r) end
function API.removeGlobalPlayer(r, o) QuitarDe(jugadores, o, r) end
function API.addGlobalOption(r, o) Anadir(globales, o, r) end
function API.removeGlobalOption(r, o) QuitarDe(globales, o, r) end

local function Lista(v) return type(v) == 'table' and v or { v } end

function API.addModel(r, arr, opciones)
    for _, m in ipairs(Lista(arr)) do
        local h = LSI.Hash(m)
        modelos[h] = modelos[h] or {}
        Anadir(modelos[h], opciones, r)
    end
end

function API.removeModel(r, arr, opciones)
    for _, m in ipairs(Lista(arr)) do
        local h = LSI.Hash(m)
        if modelos[h] then
            if opciones then QuitarDe(modelos[h], opciones, r) end
            if not opciones or not modelos[h][1] then modelos[h] = nil end
        end
    end
end

function API.addEntity(r, arr, opciones)
    for _, netId in ipairs(Lista(arr)) do
        netId = tonumber(netId)
        if netId and NetworkDoesNetworkIdExist(netId) then
            if not entidades[netId] then
                entidades[netId] = {}
                local ent = NetworkGetEntityFromNetworkId(netId)
                if ent ~= 0 and not Entity(ent).state.hasTargetOptions then
                    TriggerServerEvent(RECURSO .. ':hasOptions', netId)
                end
            end
            Anadir(entidades[netId], opciones, r)
        end
    end
end

function API.removeEntity(r, arr, opciones)
    for _, netId in ipairs(Lista(arr)) do
        netId = tonumber(netId)
        if netId and entidades[netId] then
            if opciones then QuitarDe(entidades[netId], opciones, r) end
            if not opciones or not entidades[netId][1] then entidades[netId] = nil end
        end
    end
end

function API.addLocalEntity(r, arr, opciones)
    for _, ent in ipairs(Lista(arr)) do
        if ent and DoesEntityExist(ent) then
            locales[ent] = locales[ent] or {}
            Anadir(locales[ent], opciones, r)
        else
            LSI.Aviso("%s: entity '%s' does not exist", tostring(r), tostring(ent))
        end
    end
end

function API.removeLocalEntity(r, arr, opciones)
    for _, ent in ipairs(Lista(arr)) do
        if locales[ent] then
            if opciones then QuitarDe(locales[ent], opciones, r) end
            if not opciones or not locales[ent][1] then locales[ent] = nil end
        end
    end
end

function API.getTargetOptions(r, ent, tipo, modelo)
    if not ent then
        return { global = globales, peds = peds, vehicles = vehiculos, objects = objetos, players = jugadores }
    end
    if IsPedAPlayer(ent) then return { global = jugadores } end
    local netId = NetworkGetEntityIsNetworked(ent) and NetworkGetNetworkIdFromEntity(ent)
    return {
        global = tipo == 1 and peds or tipo == 2 and vehiculos or objetos,
        model = modelos[LSI.Hash(modelo or GetEntityModel(ent))],
        entity = netId and entidades[netId] or nil,
        localEntity = locales[ent],
    }
end

--- Con true no se ve ninguna interacción (los proveedores siguen).
function API.disableTargeting(r, valor)
    desactivado = valor == true
    LSI.Forzar()
end

--- true mientras se miran las opciones de algo.
function API.isActive(r) return enMenu end

-- Las entidades en red que ya no existen (lo avisa el servidor).
RegisterNetEvent(RECURSO .. ':forgetEntities', function(arr)
    if type(arr) ~= 'table' then return end
    for _, netId in ipairs(arr) do entidades[netId] = nil end
end)

-- Las entidades locales borradas se olvidan cada minuto.
CreateThread(function()
    while true do
        Wait(60000)
        for ent in pairs(locales) do
            if not DoesEntityExist(ent) then locales[ent] = nil end
        end
    end
end)

-- Un recurso que se para se lleva sus opciones y sus zonas.
AddEventHandler('onClientResourceStop', function(res)
    if res == RECURSO then return end
    for _, l in ipairs({ peds, vehiculos, objetos, jugadores, globales }) do QuitarRecurso(l, res) end
    for _, t in ipairs({ modelos, entidades, locales }) do
        for k, l in pairs(t) do
            QuitarRecurso(l, res)
            if not l[1] then t[k] = nil end
        end
    end
    for id, z in pairs(zonas) do
        if z.resource == res then zonas[id] = nil end
    end
end)

-- ── Los puntos que hay cerca ─────────────────────────────────────────────────
local function Bloqueado(ped)
    if Config.OcultarConNui and IsNuiFocused() then return true end
    if Config.OcultarMuerto and (IsEntityDead(ped) or IsPedFatallyInjured(ped)) then return true end
    if Config.Ocultar then
        local ok, r = pcall(Config.Ocultar)
        if ok and r then return true end
    end
    return false
end

--- Si la opción se puede usar ahora (sin mirar la distancia).
local function Ve(op, ent, d, base)
    if op._cd and GetGameTimer() < op._cd then return false end
    if op.groups and not LSI.TieneGrupo(op.groups) then return false end
    if op.items and not LSI.TieneItems(op.items, op.anyItem) then return false end
    if op.canInteract then
        local ok, r = pcall(op.canInteract, ent, d, vector3(base.x, base.y, base.z), op.name, base.hueso)
        if not ok then
            if Config.Debug then
                LSI.Aviso('canInteract of %s (%s) failed: %s', tostring(op.resource), tostring(op.name or op.label), tostring(r))
            end
            return false
        end
        return r and true or false
    end
    return true
end

--- Añade el punto `base` (x, y, z, umbral, tol...) si alguna de sus opciones se
--- puede usar. Las que están a su distancia van al menú; las que solo están
--- dentro del margen, al indicador.
local function Punto(lista, id, opciones, d, base)
    local menu = est.id == id and est.menu or nil
    local cerca, n, alguna = {}, 0, false
    for _, op in ipairs(opciones) do
        if op.menuName == menu and d <= op._dist + margen and Ve(op, base.ent or 0, d, base) then
            alguna = true
            if d <= op._dist then n = n + 1 cerca[n] = op end
        end
    end
    if not alguna then return end
    base.id, base._t, base.dist, base.opciones = id, true, d, cerca
    base.soloIndicador = n == 0
    base.ind = Config.Indicadores.activo and d <= Config.Indicadores.distancia
        and not (base.zona and base.zona.drawSprite == false)
    lista[#lista + 1] = base
end

local function Dims(ent)
    local m = GetEntityModel(ent)
    local d = dims[m]
    if not d then
        local a, b = GetModelDimensions(m)
        d = { a.x, a.y, a.z, b.x, b.y, b.z }
        dims[m] = d
    end
    return d
end

--- Dónde cuelga una opción en una entidad: un hueso, un offset o el centro.
local function Ancla(ent, tipo, op)
    if op._huesos then
        for _, nombre in ipairs(op._huesos) do
            local i = GetEntityBoneIndexByName(ent, nombre)
            if i ~= -1 then
                local p = GetEntityBonePosition_2(ent, i)
                return { x = p.x, y = p.y, z = p.z, hueso = i, umbral = Config.Target.umbral, tol = 0.6 }
            end
        end
        return nil
    end
    if op._off then
        local d = Dims(ent)
        local ox, oy, oz = op._off[1], op._off[2], op._off[3]
        if not op.absoluteOffset then
            ox = (d[4] - d[1]) * ox + d[1]
            oy = (d[5] - d[2]) * oy + d[2]
            oz = (d[6] - d[3]) * oz + d[3]
        end
        local p = GetOffsetFromEntityInWorldCoords(ent, ox, oy, oz)
        local u = op.offsetSize and min(op.offsetSize * 0.5, 1.0) or Config.Target.umbral
        return { x = p.x, y = p.y, z = p.z, off = { ox, oy, oz }, umbral = u, tol = 0.6 }
    end
    if tipo == 1 then
        local p = GetPedBoneCoords(ent, 24818, 0.0, 0.0, 0.0)
        return { x = p.x, y = p.y, z = p.z, pecho = true, anclaEnt = true, umbral = 0.5, tol = 0.8 }
    end
    local d = Dims(ent)
    local cx, cy, cz = (d[1] + d[4]) / 2, (d[2] + d[5]) / 2, (d[3] + d[6]) / 2
    local p = GetOffsetFromEntityInWorldCoords(ent, cx, cy, cz)
    local ext = max(d[4] - d[1], d[5] - d[2], d[6] - d[3]) / 2
    return { x = p.x, y = p.y, z = p.z, off = { cx, cy, cz }, anclaEnt = true, caja = d,
        umbral = max(0.35, min(ext * 0.6, 1.5)), tol = max(ext, 0.6) }
end

--- Distancia del jugador a la caja del modelo (como medir hasta su superficie).
local function DistanciaCaja(ent, d, px, py, pz)
    local l = GetOffsetFromEntityGivenWorldCoords(ent, px, py, pz)
    local ex = max(d[1] - l.x, 0, l.x - d[4])
    local ey = max(d[2] - l.y, 0, l.y - d[5])
    local ez = max(d[3] - l.z, 0, l.z - d[6])
    return sqrt(ex * ex + ey * ey + ez * ez)
end

--- Los puntos de una entidad: uno por cada sitio distinto del que cuelgan sus opciones.
local function PuntosEntidad(lista, ent, tipo, fuentes, px, py, pz)
    local grupos, orden = {}, {}
    for i = 1, #fuentes do
        local f = fuentes[i]
        for j = 1, #f do
            local op = f[j]
            local g = grupos[op._ancla]
            if g then
                g[#g + 1] = op
            else
                grupos[op._ancla] = { op }
                orden[#orden + 1] = op._ancla
            end
        end
    end
    local contorno = Config.Target.contorno and Config.Target.contorno[NOMBRE_TIPO[tipo]]
    for _, k in ipairs(orden) do
        local g = grupos[k]
        local base = Ancla(ent, tipo, g[1])
        if base then
            local d
            if base.caja then
                d = DistanciaCaja(ent, base.caja, px, py, pz)
            else
                local dx, dy, dz = base.x - px, base.y - py, base.z - pz
                d = sqrt(dx * dx + dy * dy + dz * dz)
            end
            base.ent = ent
            if contorno then base.entidades = { ent } end
            Punto(lista, 'e' .. ent .. k, g, d, base)
        end
    end
end

-- Lo que hay cargado alrededor (de los pools del juego). Recorrer los pools
-- enteros cuesta, así que se hace cada 500 ms con 10 m de más y en cada barrido
-- solo se miran estos.
local cerca, cercaHasta, cercaFirma = {}, 0, ''

local function Cerca(px, py, pz, obj, veh, ped)
    local firma = (obj and 'o' or '') .. (veh and 'v' or '') .. (ped and 'p' or '')
    local ahora = GetGameTimer()
    if ahora < cercaHasta and firma == cercaFirma then return cerca end
    cerca, cercaHasta, cercaFirma = {}, ahora + 500, firma
    local r = Config.Target.radio + 10.0
    local r2 = r * r
    local function De(pool)
        for _, ent in ipairs(GetGamePool(pool)) do
            local c = GetEntityCoords(ent)
            local dx, dy, dz = c.x - px, c.y - py, c.z - pz
            if dx * dx + dy * dy + dz * dz <= r2 then cerca[#cerca + 1] = ent end
        end
    end
    if obj then De('CObject') end
    if veh then De('CVehicle') end
    if ped then De('CPed') end
    return cerca
end

local function Entidades(lista, ped, veh, px, py, pz)
    local r2 = Config.Target.radio * Config.Target.radio
    local vistas = {}

    local function Considerar(ent)
        if vistas[ent] or ent == ped or ent == veh then return end
        vistas[ent] = true
        local c = GetEntityCoords(ent)
        local dx, dy, dz = c.x - px, c.y - py, c.z - pz
        if dx * dx + dy * dy + dz * dz > r2 then return end
        local tipo = GetEntityType(ent)
        if tipo == 0 then return end
        local fuentes, n = {}, 0
        if tipo == 1 and IsPedAPlayer(ent) then
            if jugadores[1] then n = n + 1 fuentes[n] = jugadores end
        else
            local l = locales[ent]
            if l and l[1] then n = n + 1 fuentes[n] = l end
            if NetworkGetEntityIsNetworked(ent) then
                local e = entidades[NetworkGetNetworkIdFromEntity(ent)]
                if e and e[1] then n = n + 1 fuentes[n] = e end
            end
            local m = modelos[LSI.Hash(GetEntityModel(ent))]
            if m and m[1] then n = n + 1 fuentes[n] = m end
            local g = TIPOS[tipo]
            if g and g[1] then n = n + 1 fuentes[n] = g end
        end
        if globales[1] then n = n + 1 fuentes[n] = globales end
        if n > 0 then PuntosEntidad(lista, ent, tipo, fuentes, px, py, pz) end
    end

    for ent in pairs(locales) do
        if DoesEntityExist(ent) then Considerar(ent) end
    end
    for netId in pairs(entidades) do
        if NetworkDoesNetworkIdExist(netId) then
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent ~= 0 and DoesEntityExist(ent) then Considerar(ent) end
        end
    end
    -- el resto se busca entre lo que hay cargado alrededor, solo si hace falta
    local hayModelos = next(modelos) ~= nil
    local obj = hayModelos or objetos[1] ~= nil or globales[1] ~= nil
    local vehs = hayModelos or vehiculos[1] ~= nil or globales[1] ~= nil
    local gente = hayModelos or peds[1] ~= nil or jugadores[1] ~= nil or globales[1] ~= nil
    if obj or vehs or gente then
        for _, ent in ipairs(Cerca(px, py, pz, obj, vehs, gente)) do
            if DoesEntityExist(ent) then Considerar(ent) end
        end
    end
end

--- Quita los puntos tapados por una pared (desde la cabeza del jugador).
local function Visibles(lista, ped, veh)
    table.sort(lista, function(a, b) return a.dist < b.dist end)
    local cabeza = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local ignorar = veh ~= 0 and veh or ped
    local fuera, n = {}, 0
    for i = 1, min(#lista, Config.Target.maxPuntos) do
        local c = lista[i]
        local h = StartExpensiveSynchronousShapeTestLosProbe(cabeza.x, cabeza.y, cabeza.z, c.x, c.y, c.z, 19, ignorar, 7)
        local _, hit, fin, _, ent = GetShapeTestResult(h)
        local ve = not (hit == true or hit == 1) or (c.ent and ent == c.ent)
            or (c.zona and Z.Contiene(c.zona, fin.x, fin.y, fin.z))
        if not ve then
            local dx, dy, dz = fin.x - c.x, fin.y - c.y, fin.z - c.z
            ve = dx * dx + dy * dy + dz * dz <= c.tol * c.tol
        end
        if ve then n = n + 1 fuera[n] = c end
    end
    return fuera
end

local function Candidatos()
    if desactivado or not Config.Target.activo then return nil end
    local ped = PlayerPedId()
    if Bloqueado(ped) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and not Config.Target.enVehiculo then return nil end
    local pc = GetEntityCoords(ped)
    local px, py, pz = pc.x, pc.y, pc.z
    local lista = {}

    for id, z in pairs(zonas) do
        local lejos = z._max + margen
        local dx, dy, dz = px - z.cx, py - z.cy, pz - z.cz
        local r = z.radio + lejos
        if dx * dx + dy * dy + dz * dz <= r * r then
            local d = Z.Distancia(z, px, py, pz)
            if d <= lejos then
                Punto(lista, 'z' .. id, z.opciones, d,
                    { zona = z, x = z.cx, y = z.cy, z = z.cz, umbral = z.umbral, tol = z.tol })
            end
        end
    end

    if veh == 0 or Config.Target.entidadesEnVehiculo then Entidades(lista, ped, veh, px, py, pz) end

    if lista[1] and not Config.Target.atraviesaParedes then
        lista = Visibles(lista, ped, veh)
    elseif #lista > Config.Target.maxPuntos then
        table.sort(lista, function(a, b) return a.dist < b.dist end)
        for i = #lista, Config.Target.maxPuntos + 1, -1 do lista[i] = nil end
    end
    return lista
end

--- La posición de un punto que cuelga de una entidad (que se mueve), una vez por frame.
function LSI.Posicion(c)
    local ent = c.ent
    if not ent or c.zona then return end
    local f = GetFrameCount()
    if c._f == f then return end
    c._f = f
    if not DoesEntityExist(ent) then return end
    local p
    if c.hueso then
        p = GetEntityBonePosition_2(ent, c.hueso)
    elseif c.pecho then
        p = GetPedBoneCoords(ent, 24818, 0.0, 0.0, 0.0)
    elseif c.off then
        p = GetOffsetFromEntityInWorldCoords(ent, c.off[1], c.off[2], c.off[3])
    else
        return
    end
    c.x, c.y, c.z = p.x, p.y, p.z
end

--- Si el jugador está mirando el punto `c`. `g` es lo que toca el rayo de
--- físicas; `t` y `d`, dónde queda el punto en el rayo de la cámara y a cuánto.
function LSI.Apuntado(c, g, o, dx, dy, dz, t, d)
    -- el rayo toca la entidad o cae dentro de la zona
    if g.hit then
        if c.anclaEnt and g.ent == c.ent then return true end
        if c.zona and Z.Contiene(c.zona, g.x, g.y, g.z) then return true end
    end
    -- el rayo cruza la zona antes de chocar con otra cosa
    if c.zona then
        local te = Z.Rayo(c.zona, o.x, o.y, o.z, dx, dy, dz)
        if te then return Config.Target.atraviesaParedes or te <= g.d + 0.25 end
    end
    -- el punto queda cerca del rayo y no hay nada delante
    if t <= 0 or d >= c.umbral then return false end
    if Config.Target.atraviesaParedes then return true end
    return not g.hit or g.ent == c.ent or g.d >= t - c.tol
end

-- ── El menú: la etiqueta, la rueda y la tecla ────────────────────────────────
local function Clave(op) return op.name or op.label end

--- Las opciones del menú de ahora (con «Volver» delante en un submenú).
local function Menu(c)
    local ops = c.opciones
    if est.id == c.id and est.menu then
        local l = { VOLVER }
        for i = 1, #ops do l[i + 1] = ops[i] end
        return l
    end
    return ops
end

--- La opción elegida: se sigue por su nombre aunque cambie la lista.
local function Seleccion(c, lista)
    if est.id ~= c.id then est = { id = c.id, historial = {}, sel = 1 } end
    if est.selK then
        for i, op in ipairs(lista) do
            if Clave(op) == est.selK then est.sel = i return i end
        end
    end
    est.sel = max(1, min(est.sel, #lista))
    return est.sel
end

local function Etiqueta(c)
    local lista = Menu(c)
    if not lista[1] then return nil end
    local sel = Seleccion(c, lista)
    local ops = {}
    for i, op in ipairs(lista) do
        ops[i] = { t = tostring(op.label or op.name or '?'), i = op.icon, c = op.iconColor, h = op.holdTime and true or nil }
    end
    return { opciones = ops, sel = sel, tecla = Config.Target.tecla, ayuda = #lista > 1 and T.choose_hint or nil }
end

--- Lo que manda ox_target a onSelect, eventos y exports: la opción sin sus
--- funciones, más la entidad, la zona, las coordenadas y la distancia.
local QUITAR = { icon = true, groups = true, items = true, canInteract = true, onSelect = true,
    export = true, event = true, serverEvent = true, command = true }

local function Respuesta(op, c, servidor)
    local r = {}
    for k, v in pairs(op) do
        if type(k) == 'string' and not QUITAR[k] and k:sub(1, 1) ~= '_' then r[k] = v end
    end
    local ent = c.ent or 0
    if servidor then
        ent = ent ~= 0 and NetworkGetEntityIsNetworked(ent) and NetworkGetNetworkIdFromEntity(ent) or 0
    end
    r.entity = ent
    r.zone = c.zona and c.zona.id or nil
    r.coords = vector3(c.x, c.y, c.z)
    r.distance = c.dist
    return r
end

local function Sonido(nombre)
    if Config.Target.sonidos then PlaySoundFrontend(-1, nombre, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
end

local function Progreso(p) LSI.Enviar('progreso', p) end

local function Ejecutar(c, op)
    siguienteEleccion = GetGameTimer() + Config.Target.retraso
    Sonido('SELECT')
    if op._volver then
        est.menu = table.remove(est.historial)
        est.sel, est.selK = 1, nil
        LSI.Forzar()
        return
    end
    if op.openMenu then
        est.historial[#est.historial + 1] = est.menu
        est.menu = op.openMenu ~= 'home' and op.openMenu or nil
        est.sel, est.selK = 1, nil
    end
    if tonumber(op.cooldown) then op._cd = GetGameTimer() + tonumber(op.cooldown) end
    -- en su propio hilo: así un onSelect puede esperar (Wait) sin parar el bucle
    CreateThread(function()
        if op.onSelect then
            Llamar(op.onSelect, op.qtarget and (c.ent or 0) or Respuesta(op, c))
        elseif op.export then
            Llamar(function() exports[op.resource][op.export](nil, Respuesta(op, c)) end)
        elseif op.event then
            TriggerEvent(op.event, Respuesta(op, c))
        elseif op.serverEvent then
            TriggerServerEvent(op.serverEvent, Respuesta(op, c, true))
        elseif op.command then
            ExecuteCommand(op.command)
        end
    end)
    LSI.Forzar()
end

local function Pulsar(c)
    if GetGameTimer() < siguienteEleccion then return end
    local lista = Menu(c)
    local op = lista[Seleccion(c, lista)]
    if not op then return end
    local dur = tonumber(op.holdTime)
    if dur and dur > 0 then
        mantenido = { id = c.id, op = op, inicio = GetGameTimer(), dur = dur }
        Progreso(0)
        return
    end
    Ejecutar(c, op)
end

local function Soltar()
    if mantenido then mantenido = nil Progreso(false) end
end

local BLOQUEAR = { 14, 15, 16, 17, 99, 100, 261, 262 }
for _, k in ipairs(Config.Target.subir) do BLOQUEAR[#BLOQUEAR + 1] = k end
for _, k in ipairs(Config.Target.bajar) do BLOQUEAR[#BLOQUEAR + 1] = k end

local function Alguna(controles)
    for _, k in ipairs(controles) do
        if IsDisabledControlJustPressed(0, k) then return true end
    end
    return false
end

--- Cada frame mientras se mira un punto: la rueda y la barra de mantener.
local function Frame(c)
    local lista = Menu(c)
    local n = #lista
    if n > 1 then
        for _, k in ipairs(BLOQUEAR) do DisableControlAction(0, k, true) end
        local mov = Alguna(Config.Target.subir) and -1 or Alguna(Config.Target.bajar) and 1 or 0
        if mov ~= 0 and not mantenido then
            local sel = (Seleccion(c, lista) - 1 + mov) % n + 1
            est.sel, est.selK = sel, Clave(lista[sel])
            Sonido('NAV_UP_DOWN')
            LSI.Rehacer()
        end
    end
    if mantenido then
        if mantenido.id ~= c.id then Soltar() return end
        local p = (GetGameTimer() - mantenido.inicio) / mantenido.dur
        if p >= 1 then
            local op = mantenido.op
            mantenido = nil
            Progreso(false)
            Ejecutar(c, op)
        else
            Progreso(p)
        end
    end
end

local function Cambio(c)
    local id = c and c.id
    if est.id ~= id then
        est = { id = id, historial = {}, sel = 1 }
        Soltar()
    end
    enMenu = c ~= nil
end

LSI.RegistrarInterno('_target', {
    candidatos = Candidatos,
    etiqueta = Etiqueta,
    teclas = { Config.Target.tecla },
    pulsar = Pulsar,
    soltar = Soltar,
    cambio = Cambio,
    cadaFrame = Frame,
})

-- ── Exports: la API de ox_target, también en exports['vault-interact'] ────────
for nombre, f in pairs(API) do
    LSI.Export(nombre, function(...) return f(GetInvokingResource() or RECURSO, ...) end)
end

-- ── Debug: las zonas con `debug = true` se dibujan ───────────────────────────
CreateThread(function()
    while true do
        local hay = false
        local pc = GetEntityCoords(PlayerPedId())
        for _, z in pairs(zonas) do
            if z.debug then
                hay = true
                local dx, dy = pc.x - z.cx, pc.y - z.cy
                if dx * dx + dy * dy < 2500 then Z.Dibujar(z) end
            end
        end
        Wait(hay and 0 or 1000)
    end
end)
