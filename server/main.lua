local QBCore = exports['qb-core']:GetCoreObject()
local currentDivingArea = math.random(1, #Config.CoralLocations)
local availableCoral = {}

-- Functions

local function getItemPrice(amount, price)
    for k, v in pairs(Config.PriceModifiers) do
        local modifier = #Config.PriceModifiers == k and amount >= v.minAmount or amount >= v.minAmount and amount <= v.maxAmount
        if modifier then
            price /= 100 * math.random(v.minPercentage, v.maxPercentage)
            price = math.ceil(price)
        end
    end
    return price
end

local function hasCoral(src)
    local Player = QBCore.Functions.GetPlayer(src)
    availableCoral = {}
    for _, v in pairs(Config.CoralTypes) do
        local item = Player.Functions.GetItemByName(v.item)
        if item then availableCoral[#availableCoral+1] = v end
    end
    return next(availableCoral)
end

-- Events

RegisterNetEvent('qb-diving:server:CallCops', function(coords)
    for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
        if Player then
            if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
                local msg = Lang:t("info.cop_msg")
                TriggerClientEvent('qb-diving:client:CallCops', Player.PlayerData.source, coords, msg)
                local alertData = {
                    title = Lang:t("info.cop_title"),
                    coords = coords,
                    description = msg
                }
                TriggerClientEvent("qb-phone:client:addPoliceAlert", -1, alertData)
            end
        end
    end
end)

RegisterNetEvent('qb-diving:server:SellCoral', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if hasCoral(src) then
        for _, v in pairs(availableCoral) do
            local item = Player.Functions.GetItemByName(v.item)
            local price = item.amount * v.price
            local reward = getItemPrice(item.amount, price)
            Player.Functions.RemoveItem(item.name, item.amount)
            Player.Functions.AddMoney('cash', math.ceil(reward / item.amount), "sold-coral")
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item.name], "remove")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.no_coral"), 'error')
    end
end)

RegisterNetEvent('qb-diving:server:TakeCoral', function(area, coral, bool)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local coralType = math.random(1, #Config.CoralTypes)
    local amount = math.random(1, Config.CoralTypes[coralType].maxAmount)
    local ItemData = QBCore.Shared.Items[Config.CoralTypes[coralType].item]
    if amount > 1 then
        for _ = 1, amount, 1 do
            Player.Functions.AddItem(ItemData["name"], 1)
            TriggerClientEvent('inventory:client:ItemBox', src, ItemData, "add")
            Wait(250)
        end
    else
        Player.Functions.AddItem(ItemData["name"], amount)
        TriggerClientEvent('inventory:client:ItemBox', src, ItemData, "add")
    end
    if (Config.CoralLocations[area].TotalCoral - 1) == 0 then
        for _, v in pairs(Config.CoralLocations[currentDivingArea].coords.Coral) do
            v.PickedUp = false
        end
        Config.CoralLocations[currentDivingArea].TotalCoral = Config.CoralLocations[currentDivingArea].DefaultCoral
        local newLocation = math.random(1, #Config.CoralLocations)
        while newLocation == currentDivingArea do
            Wait(0)
            newLocation = math.random(1, #Config.CoralLocations)
        end
        currentDivingArea = newLocation
        TriggerClientEvent('qb-diving:client:NewLocations', -1)
    else
        Config.CoralLocations[area].coords.Coral[coral].PickedUp = bool
        Config.CoralLocations[area].TotalCoral = Config.CoralLocations[area].TotalCoral - 1
    end
    TriggerClientEvent('qb-diving:client:UpdateCoral', -1, area, coral, bool)
end)

RegisterNetEvent('qb-diving:server:RemoveGear', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.RemoveItem("diving_gear", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["diving_gear"], "remove")
end)

RegisterNetEvent('qb-diving:server:GiveBackGear', function(oxygen)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if oxygen > 0 then
        Player.Functions.AddItem("diving_gear", 1, false, {['oxygen']=oxygen})
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["diving_gear"], "add")
    end
end)

-- Callbacks

QBCore.Functions.CreateCallback('qb-diving:server:GetDivingConfig', function(_, cb)
    cb(Config.CoralLocations, currentDivingArea)
end)

QBCore.Functions.CreateCallback('qb-diving:server:RemoveGear', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false)
        return
    end
    local divingGear = Player.Functions.GetItemByName("diving_gear")
    if divingGear.amount > 0 then
        local oxygen = 400
        if divingGear.info.oxygen ~= nil then
            oxygen = divingGear.info.oxygen
        end
        Player.Functions.RemoveItem("diving_gear", 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["diving_gear"], "remove")
        cb(true, oxygen)
        return
    end
    cb(false, 0)
end)

-- Items

QBCore.Functions.CreateUseableItem("diving_gear", function(source)
    TriggerClientEvent("qb-diving:client:UseGear", source, true)
end)

-- Commands

QBCore.Commands.Add("divingsuit", Lang:t("info.command_diving"), {}, false, function(source)
    TriggerClientEvent("qb-diving:client:UseGear", source, false)
end)
