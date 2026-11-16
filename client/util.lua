-- vault-interact: lo que comparten los ficheros del cliente.
-- El código usa los nombres internos (en español) de Config; aquí se traducen los
-- de config.lua (en inglés), se rellenan los que falten con su valor por defecto y
-- se aceptan también los configs antiguos de ls_interact (nombres en español).
LSI = {}
LSI.Recurso = GetCurrentResourceName()

function LSI.Aviso(msg, ...)
    print(('^3[%s]^0 ' .. msg):format(LSI.Recurso, ...))
end

-- ── Config ───────────────────────────────────────────────────────────────────
-- nombre en config.lua → nombre interno (con su tabla de dentro si la tiene)
local MAPA = {
    Locale = 'Idioma', Keys = 'Teclas', ScanInterval = 'Intervalo', HoldRepeat = 'CadaMantener',
    LookThreshold = 'Umbral',
    Outline = { 'Contorno', { enabled = 'activo' } },
    Theme = { 'Tema', { accent = 'acento', accentShadow = 'acentoPared', ink = 'tinta', background = 'fondo',
        text = 'texto', muted = 'suave', warning = 'aviso' } },
    Target = { 'Target', { enabled = 'activo', key = 'tecla', scrollUp = 'subir', scrollDown = 'bajar',
        distance = 'distancia', maxDistance = 'distanciaMax', scanRadius = 'radio', maxPoints = 'maxPuntos',
        threshold = 'umbral', throughWalls = 'atraviesaParedes', inVehicle = 'enVehiculo',
        entitiesInVehicle = 'entidadesEnVehiculo', selectDelay = 'retraso', sounds = 'sonidos',
        outline = { 'contorno', { object = 'objeto', vehicle = 'vehiculo' } }, vehicleDoors = 'puertas' } },
    Indicators = { 'Indicadores', { enabled = 'activo', distance = 'distancia', margin = 'margen' } },
    HideInNui = 'OcultarConNui', HideWhenDead = 'OcultarMuerto', ShouldHide = 'Ocultar',
    Bridge = { 'Puente', { inventory = 'inventario' } },
    HasGroup = 'TieneGrupo', HasItems = 'TieneItems',
}

local DEFECTO = {
    Idioma = 'en',
    Teclas = { E = 38, G = 47, Q = 44, H = 74, F = 23, R = 45, X = 73 },
    Intervalo = 250, CadaMantener = 100, Umbral = 0.3,
    Contorno = { activo = true, color = { 255, 255, 255, 255 } },
    Tema = { acento = '#fdd519', acentoPared = '#9c8207', tinta = '#0a0a0a', fondo = 'rgba(16, 16, 16, .95)',
        texto = '#ffffff', suave = '#8e8c85', aviso = '#ff8f8f' },
    Target = {
        activo = true, tecla = 'E', subir = { 15, 241, 172 }, bajar = { 14, 242, 173 },
        distancia = 2.5, radio = 10.0, maxPuntos = 32, umbral = 0.45,
        atraviesaParedes = false, enVehiculo = true, entidadesEnVehiculo = false, retraso = 400, sonidos = true,
        contorno = { objeto = true, vehiculo = false, ped = false }, puertas = true,
    },
    Indicadores = { activo = true, distancia = 5.0, margen = 2.0, max = 24 },
    OcultarConNui = true, OcultarMuerto = true,
    Ocultar = function()
        local s = LocalPlayer.state
        return s.invBusy or s.isDead or s.dead
    end,
    Puente = { framework = 'auto', inventario = 'auto' },
    Debug = false,
}

--- Pasa los nombres en inglés a los internos. Si están los dos, manda el inglés.
local function Traducir(t, mapa)
    local r = {}
    for k, v in pairs(t) do
        local m = mapa[k]
        if type(m) == 'string' then
            r[m] = v
        elseif type(m) == 'table' then
            r[m[1]] = type(v) == 'table' and Traducir(v, m[2]) or v
        elseif r[k] == nil then
            r[k] = v
        end
    end
    return r
end

--- El nombre que se ve en config.lua, para los avisos.
local function Publico(mapa, k)
    for en, m in pairs(mapa or {}) do
        if m == k or (type(m) == 'table' and m[1] == k) then return en, type(m) == 'table' and m[2] or nil end
    end
    return k, nil
end

--- Rellena lo que falta con el valor por defecto; un tipo equivocado también.
local function Rellenar(def, t, mapa, ruta)
    for k, dv in pairs(def) do
        local v = t[k]
        local nombre, sub = Publico(mapa, k)
        if v == nil then
            t[k] = dv
        elseif type(dv) == 'table' and type(v) == 'table' then
            if not dv[1] then Rellenar(dv, v, sub, ruta .. nombre .. '.') end
        elseif type(v) ~= type(dv) and not (type(dv) == 'function' and v == false) then
            LSI.Aviso('Config.%s%s should be a %s (got %s). Using the default.', ruta, nombre, type(dv), type(v))
            t[k] = dv
        end
    end
end

Config = Traducir(Config or {}, MAPA)
Rellenar(DEFECTO, Config, MAPA, '')

if not Locales[Config.Idioma] then
    LSI.Aviso("Config.Locale '%s' does not exist in locales/. Using 'en'.", tostring(Config.Idioma))
    Config.Idioma = 'en'
end
if not Config.Teclas[Config.Target.tecla] then
    LSI.Aviso("Config.Target.key '%s' is not in Config.Keys. Using 'E'.", tostring(Config.Target.tecla))
    Config.Target.tecla, Config.Teclas.E = 'E', Config.Teclas.E or 38
end
local VALE = { auto = true, qbx = true, qb = true, esx = true, ox = true, none = true, ninguno = true }
for _, k in ipairs({ 'framework', 'inventario' }) do
    local v = Config.Puente[k]
    if not VALE[v] then
        LSI.Aviso("Config.Bridge.%s '%s' is not valid. Using 'auto'.", k == 'inventario' and 'inventory' or k, tostring(v))
        v = 'auto'
    end
    Config.Puente[k] = v == 'none' and 'ninguno' or v
end

-- Los textos del idioma elegido; lo que falte, en inglés.
LSI.T = Locales[Config.Idioma]
if Config.Idioma ~= 'en' then setmetatable(LSI.T, { __index = Locales.en }) end

-- ── Exports ──────────────────────────────────────────────────────────────────
-- Cada export también responde como exports.ls_interact (el nombre antiguo) si el
-- recurso ya se llama de otra forma: los recursos que no se han actualizado siguen
-- funcionando. shortcut: si se reinicia este recurso, esos recursos guardan el
-- export viejo hasta que se reinician ellos; quitar cuando nadie use el nombre antiguo.
local ANTIGUO = 'ls_interact'

function LSI.Export(nombre, f)
    exports(nombre, f)
    if LSI.Recurso ~= ANTIGUO then
        AddEventHandler(('__cfx_export_%s_%s'):format(ANTIGUO, nombre), function(cb) cb(f) end)
    end
end

--- Llama sin que un error de otro recurso pare el bucle.
function LSI.Llamar(f, ...)
    if not f then return nil end
    local ok, r = pcall(f, ...)
    if not ok then LSI.Aviso('a callback from another resource failed: %s', tostring(r)) return nil end
    return r
end

function LSI.Enviar(tipo, datos) SendNUIMessage({ tipo = tipo, datos = datos }) end

--- x, y, z de un vector3/vector4, de { x =, y =, z = } o de { 1, 2, 3 }.
function LSI.Vec(v)
    if v == nil then return nil end
    local x = v.x or v[1]
    local y = v.y or v[2]
    local z = v.z or v[3]
    return tonumber(x), tonumber(y), tonumber(z)
end

--- Los hashes de modelo, siempre con signo (los nativos y `joaat` no siempre coinciden).
function LSI.Hash(m)
    local h = tonumber(m) or GetHashKey(m)
    if h > 0x7FFFFFFF then h = h - 0x100000000 end
    return h
end
