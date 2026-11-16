-- English. To add a language: copy this file to locales/xx.lua, change `Locales.en`
-- to `Locales.xx`, translate the texts on the right and set Config.Locale = 'xx'.
-- Any text you leave out falls back to English.
Locales = Locales or {}

Locales.en = {
    back = 'Back',
    choose_hint = 'Wheel or ↑ ↓',
    open_door = 'Open door',
    close_door = 'Close door',
    open_hood = 'Open hood',
    close_hood = 'Close hood',
    open_trunk = 'Open trunk',
    close_trunk = 'Close trunk',

    -- How prices are written on labels: number format (a browser locale code)
    -- and where the currency goes (%s is the number).
    number_format = 'en-US',
    price_format = '$%s',
}
