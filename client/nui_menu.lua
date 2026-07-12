local preview = require 'client.modules.preview'

local nuiMenuOpen = false
local nuiItems = {}
local cachedPayload

local function addItem(payload, item, categoryId, itemType)
    local id = ('%s:%s:%s'):format(categoryId, itemType, item.Command or item.Label)

    nuiItems[id] = {
        type = itemType,
        data = item,
    }

    payload.items[#payload.items + 1] = {
        id = id,
        label = item.Label,
        command = item.Command,
        description = item.Command and ('/%s'):format(item.Command) or item.Label,
        categoryId = categoryId,
        type = itemType,
    }
end

local function isValidEmote(emote)
    if emote.Hide then return false end
    if emote.NSFW and Config.enableNSFWEmotes == 'false' then return false end
    if emote.Gang and not Config.enableGangEmotes then return false end
    if emote.SocialMovement and not Config.enableSocialMovementEmotes then return false end
    if not DoesAnimDictExist(emote.Dictionary) then return false end

    if emote?.Options?.Props then
        local props = emote.Options.Props

        for i = 1, #props do
            if not IsModelValid(joaat(props[i].Name)) then
                return false
            end
        end
    end

    return true
end

local function buildNuiPayload()
    if cachedPayload then
        return cachedPayload
    end

    local payload = {
        categories = {
            {
                id = 'all',
                label = locale('all') or 'Alle',
            }
        },
        items = {},
    }

    nuiItems = {}

    for i = 1, #Emotes do
        local submenu = Emotes[i]
        local shouldAddCategory = true

        if submenu.name == 'Consumable Emotes' and not Config.enableConsumableEmotes then
            shouldAddCategory = false
        elseif submenu.name == 'Synchronized Emotes' and not Config.enableSynchronizedEmotes then
            shouldAddCategory = false
        elseif submenu.name == 'Synchronized Dance Emotes' and not Config.enableSynchronizedEmotes then
            shouldAddCategory = false
        elseif submenu.name == 'Animal Emotes' and not Config.enableAnimalEmotes then
            shouldAddCategory = false
        end

        if shouldAddCategory then
            local categoryId = ('emotes_%s'):format(i)
            local firstItemIndex = #payload.items

            for k = 1, #submenu.options do
                local emote = submenu.options[k]

                if isValidEmote(emote) then
                    addItem(payload, emote, categoryId, 'emote')
                end
            end

            if #payload.items > firstItemIndex then
                payload.categories[#payload.categories + 1] = {
                    id = categoryId,
                    label = submenu.name,
                }
            end
        end
    end

    if #Walks > 0 then
        payload.categories[#payload.categories + 1] = {
            id = 'walks',
            label = locale('walking_styles'),
        }

        for i = 1, #Walks do
            addItem(payload, Walks[i], 'walks', 'walk')
        end
    end

    if #Scenarios > 0 then
        payload.categories[#payload.categories + 1] = {
            id = 'scenarios',
            label = locale('scenarios'),
        }

        for i = 1, #Scenarios do
            addItem(payload, Scenarios[i], 'scenarios', 'scenario')
        end
    end

    if #Expressions > 0 then
        payload.categories[#payload.categories + 1] = {
            id = 'expressions',
            label = locale('facial_expressions'),
        }

        for i = 1, #Expressions do
            addItem(payload, Expressions[i], 'expressions', 'expression')
        end
    end

    cachedPayload = payload

    return cachedPayload
end

local function refreshNuiPayload()
    cachedPayload = nil
    nuiItems = {}

    return buildNuiPayload()
end
exports('refreshMenuCache', refreshNuiPayload)

local function openNuiMenu()
    if PlayerState.isLimited then return end

    nuiMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'SET_EMOTE_MENU',
        data = buildNuiPayload(),
    })
    SendNUIMessage({
        action = 'UPDATE_VISIBILITY',
        data = true,
    })
end

function CloseMenu()
    nuiMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'UPDATE_VISIBILITY',
        data = false,
    })
end
exports('closeMenu', CloseMenu)

function ToggleMenu()
    if nuiMenuOpen then
        CloseMenu()
        return
    end

    openNuiMenu()
end
exports('toggleMenu', ToggleMenu)

RegisterNUICallback('closeEmoteMenu', function(_, cb)
    CloseMenu()
    cb(true)
end)

RegisterNUICallback('playEmoteMenuItem', function(data, cb)
    local item = nuiItems[data.id]

    if not item then
        cb(false)
        return
    end

    CloseMenu()

    if item.type == 'walk' then
        SetWalk(item.data.Walk)
    elseif item.type == 'expression' then
        SetExpression(item.data.Expression)
    else
        PlayEmote(item.data)
    end

    cb(true)
end)

RegisterNUICallback('previewEmoteMenuItem', function(data, cb)
    local item = nuiItems[data.id]

    if item and item.type == 'emote' and Config.enableEmotePreview then
        preview.showEmote(item.data)
    end

    cb(true)
end)

RegisterNUICallback('cancelEmoteMenuItem', function(data, cb)
    CloseMenu()

    if data.type == 'emote' then
        CancelEmote()
    elseif data.type == 'walk' then
        ResetWalk()
    elseif data.type == 'expression' then
        ResetExpression()
    elseif data.type == 'all' then
        CancelEmote()
        ResetWalk()
        ResetExpression()
    end

    cb(true)
end)

for i = 1, #Config.menuCommands do
    Utils.addCommand(Config.menuCommands[i], {
        help = locale('open_emote_menu')
    }, function()
        ToggleMenu()
    end)
end

if Config.menuKeybind ~= '' and #Config.menuCommands > 0 then
    RegisterKeyMapping(Config.menuCommands[1], locale('open_emote_menu'), 'keyboard', Config.menuKeybind)
end

CreateThread(function()
    Wait(1000)
    refreshNuiPayload()
end)
