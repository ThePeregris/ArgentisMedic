-- [[ Argentis |cffff0000Medic|r ]]
-- Author:  ThePeregris
-- Version: 1.4 (Abas renomeadas: Heal/Mana/Recovery)
-- Target:  Turtle WoW (1.12 / LUA 5.0)
-- Requires: Argentis Core v1.3+

Argentis = Argentis or {}
Argentis.Medic = {}

local Medic = Argentis.Medic
local Core = Argentis.Core
local UI = Argentis.UI

-- ==========================================
-- [0] LISTAS DE PRIORIDADE (mesma lógica do BannionNurse original)
-- ==========================================
-- ATENÇÃO: nomes de itens vanilla padrão. Se o Turtle WoW tiver itens
-- customizados equivalentes, ajuste essas listas.
local HealItems = {
    "Major Healing Potion", "Superior Healing Potion", "Greater Healing Potion",
    "Healing Potion", "Lesser Healing Potion", "Minor Healing Potion",
    "Major Healthstone", "Greater Healthstone", "Healthstone",
    "Lesser Healthstone", "Minor Healthstone"
}

local ManaItems = {
    "Major Mana Potion", "Superior Mana Potion", "Greater Mana Potion",
    "Mana Potion", "Lesser Mana Potion", "Minor Mana Potion",
    "Major Mana Citrine", "Mana Citrine"
}

local BandageItems = {
    "Heavy Runecloth Bandage", "Runecloth Bandage", "Heavy Mageweave Bandage",
    "Mageweave Bandage", "Heavy Silk Bandage", "Silk Bandage",
    "Heavy Wool Bandage", "Wool Bandage", "Linen Bandage"
}

-- ==========================================
-- [1] HELPERS DE BAG (uso de item por nome / por subtipo)
-- ==========================================
local function Medic_UseItemByName(name)
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, name) then
                local start, duration, enabled = GetContainerItemCooldown(bag, slot)
                if start == 0 and enabled == 1 then
                    UseContainerItem(bag, slot)
                    return true
                end
            end
        end
    end
    return false
end

local function Medic_UseFromList(list)
    for i = 1, table.getn(list) do
        if Medic_UseItemByName(list[i]) then return true end
    end
    return false
end

-- Comida detectada por itemSubType, não por nome fixo (mais robusto,
-- funciona com qualquer comida do servidor sem precisar de lista).
local function Medic_UseFoodBySubtype()
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, _, _, _, _, itemSubType = GetItemInfo(link)
                if itemSubType == "Food & Drink" then
                    local start, duration, enabled = GetContainerItemCooldown(bag, slot)
                    if start == 0 and enabled == 1 then
                        UseContainerItem(bag, slot)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ==========================================
-- [2] MONITOR PASSIVO (avisos em combate)
-- ==========================================
local lastHealWarn = 0
local lastManaWarn = 0
local WARN_INTERVAL = 3

local monitorFrame = CreateFrame("Frame")
monitorFrame:SetScript("OnUpdate", function()
    if not ArgentisMedDB or not ArgentisMedDB.Enabled then return end
    if not UnitAffectingCombat("player") then return end

    local now = GetTime()
    local db = ArgentisMedDB

    if db.Heal.Enabled then
        local hp = Core.GetHealthPct("player")
        if hp <= db.Heal.Threshold and (now - lastHealWarn) > WARN_INTERVAL then
            UIErrorsFrame:AddMessage("|cffff2020[Medic] Ative /agmed1 - Cura Baixa!|r", 1.0, 0.2, 0.2, 1.0, 3)
            lastHealWarn = now
        end
    end

    if db.Mana.Enabled then
        local isManaUser = true
        if UnitPowerType then
            isManaUser = (UnitPowerType("player") == 0)
        end
        if isManaUser then
            local mp = Core.GetManaPct("player")
            if mp <= db.Mana.Threshold and (now - lastManaWarn) > WARN_INTERVAL then
                UIErrorsFrame:AddMessage("|cff3399ff[Medic] Ative /agmed2 - Mana Baixa!|r", 0.2, 0.6, 1.0, 1.0, 3)
                lastManaWarn = now
            end
        end
    end
end)

-- ==========================================
-- [3] ATALHOS (uso real de item ao pressionar)
-- ==========================================
function Medic.Shortcut1_Heal()
    local db = ArgentisMedDB
    if not db.Enabled or not db.Heal.Enabled then return end

    local hp = Core.GetHealthPct("player")
    if hp > db.Heal.Threshold then return end

    Medic_UseFromList(HealItems)
end

function Medic.Shortcut2_Mana()
    local db = ArgentisMedDB
    if not db.Enabled or not db.Mana.Enabled then return end

    local mp = Core.GetManaPct("player")
    if mp > db.Mana.Threshold then return end

    Medic_UseFromList(ManaItems)
end

function Medic.Shortcut3_PostCombat()
    local db = ArgentisMedDB
    if not db.Enabled or not db.Post.Enabled then return end

    if UnitAffectingCombat("player") then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Medic]|r Não é possível usar em combate.")
        return
    end

    local hp = Core.GetHealthPct("player")
    if hp > db.Post.Threshold then return end

    if db.Post.UseBandage then
        local blocked = false
        local i = 1
        while true do
            local debuff = UnitDebuff("player", i)
            if not debuff then break end
            if string.find(debuff, "Bandage") then blocked = true; break end
            i = i + 1
        end

        if blocked then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Medic]|r Bloqueado: debuff de bandagem ativo.")
        else
            if Medic_UseFromList(BandageItems) then return end
        end
    end

    if db.Post.UseFood then
        Medic_UseFoodBySubtype()
    end
end

SLASH_AGMED1_1 = "/agmed1"; SlashCmdList["AGMED1"] = Medic.Shortcut1_Heal
SLASH_AGMED2_1 = "/agmed2"; SlashCmdList["AGMED2"] = Medic.Shortcut2_Mana
SLASH_AGMED3_1 = "/agmed3"; SlashCmdList["AGMED3"] = Medic.Shortcut3_PostCombat

-- ==========================================
-- [3.1] BOTÃO ÚNICO (SMART BUTTON)
-- ==========================================
-- Vanilla 1.12 não tem macro condicional ([combat]/[mod:alt]/etc — isso só
-- existe em expansões posteriores). A decisão precisa acontecer aqui no
-- Lua; a macro do jogador vira só uma linha: /agmed
--
-- Prioridade: ALT (qualquer estado) > Em combate > Fora de combate
function Medic.SmartButton()
    if IsAltKeyDown() then
        Medic.Shortcut2_Mana()
        return
    end

    if UnitAffectingCombat("player") then
        Medic.Shortcut1_Heal()
    else
        Medic.Shortcut3_PostCombat()
    end
end

SLASH_AGMEDBTN1 = "/agmed"; SlashCmdList["AGMEDBTN"] = Medic.SmartButton

-- ==========================================
-- [4] PAINEL DE CONFIGURAÇÃO ("/ag medic")
-- ==========================================
local function CreateThresholdField(parent, label, x, y, getValue, setValue)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetText(label)

    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetWidth(40)
    edit:SetHeight(20)
    edit:SetPoint("LEFT", text, "RIGHT", 12, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(3)
    edit:SetText(tostring(getValue()))

    edit:SetScript("OnTextChanged", function()
        local raw = this:GetText()
        local filtered = string.gsub(raw, "%D", "")
        if filtered ~= raw then this:SetText(filtered) end
    end)

    edit:SetScript("OnEnterPressed", function()
        local val = tonumber(this:GetText())
        if val then
            if val < 1 then val = 1 end
            if val > 100 then val = 100 end
            setValue(val)
            this:SetText(tostring(val))
        end
        this:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    return edit
end

local function CreateToggle(parent, name, label, x, y, getValue, setValue)
    local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    getglobal(name.."Text"):SetText(label)
    check:SetChecked(getValue())
    check:SetScript("OnClick", function()
        setValue(this:GetChecked() == 1)
    end)
    return check
end

local function BuildGeneralTab(content, db)
    CreateToggle(content, "ArgentisMedic_EnabledCheck", "Módulo Ativo", 4, -4,
        function() return db.Enabled end,
        function(v) db.Enabled = v end)

    local info = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -30)
    info:SetWidth(380)
    info:SetJustifyH("LEFT")
    info:SetText(
        "|cffffcc00Heal (Atalho 1)|r\n" ..
        "Avisa o jogador quando a HP estiver abaixo do nível configurado.\n" ..
        "Comando (macro): |cffffffff/agmed1|r\n" ..
        "Utiliza Poções de Cura / Healthstones quando pressionado.\n\n" ..

        "|cffffcc00Mana (Atalho 2)|r\n" ..
        "Avisa o jogador quando a Mana estiver abaixo do nível configurado.\n" ..
        "Comando (macro): |cffffffff/agmed2|r\n" ..
        "Utiliza Poções de Mana quando pressionado.\n\n" ..

        "|cffffcc00Recovery (Atalho 3)|r\n" ..
        "Executa fora de combate, se a HP estiver abaixo do nível configurado.\n" ..
        "Comando (macro): |cffffffff/agmed3|r\n" ..
        "Utiliza Bandagem e/ou Comida (conforme configurado) quando pressionado.\n\n" ..

        "|cffffcc00Botão Único (opcional)|r\n" ..
        "Comando (macro): |cffffffff/agmed|r\n" ..
        "ALT = Mana | Em combate = Heal | Fora de combate = Recovery."
    )
end

local function BuildHealTab(content, db)
    CreateToggle(content, "ArgentisMedic_HealEnabledCheck", "Ativo", 4, -4,
        function() return db.Heal.Enabled end,
        function(v) db.Heal.Enabled = v end)

    CreateThresholdField(content, "Avisar/Usar se HP <= (%)", 4, -34,
        function() return db.Heal.Threshold end,
        function(v) db.Heal.Threshold = v end)
end

local function BuildManaTab(content, db)
    CreateToggle(content, "ArgentisMedic_ManaEnabledCheck", "Ativo", 4, -4,
        function() return db.Mana.Enabled end,
        function(v) db.Mana.Enabled = v end)

    CreateThresholdField(content, "Avisar/Usar se Mana <= (%)", 4, -34,
        function() return db.Mana.Threshold end,
        function(v) db.Mana.Threshold = v end)
end

local function BuildPostTab(content, db)
    CreateToggle(content, "ArgentisMedic_PostEnabledCheck", "Ativo", 4, -4,
        function() return db.Post.Enabled end,
        function(v) db.Post.Enabled = v end)

    CreateThresholdField(content, "Só executa se HP <= (%)", 4, -34,
        function() return db.Post.Threshold end,
        function(v) db.Post.Threshold = v end)

    CreateToggle(content, "ArgentisMedic_PostBandageCheck", "Usar Bandagem", 4, -64,
        function() return db.Post.UseBandage end,
        function(v) db.Post.UseBandage = v end)

    CreateToggle(content, "ArgentisMedic_PostFoodCheck", "Usar Comida", 4, -88,
        function() return db.Post.UseFood end,
        function(v) db.Post.UseFood = v end)
end

local medicPanel = nil
local function ToggleMedicPanel()
    if not medicPanel then
        medicPanel = UI.CreatePanel("Argentis Medic", ArgentisMedDB, {
            { title = "Geral",    build = BuildGeneralTab },
            { title = "Heal",     build = BuildHealTab },
            { title = "Mana",     build = BuildManaTab },
            { title = "Recovery", build = BuildPostTab }
        })
    end
    UI.TogglePanel(medicPanel)
end

-- ==========================================
-- [5] INIT
-- ==========================================
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loadFrame:SetScript("OnEvent", function()
    if not ArgentisMedDB then
        ArgentisMedDB = {
            Enabled = true,
            Heal = { Enabled = true, Threshold = 50 },
            Mana = { Enabled = true, Threshold = 30 },
            Post = { Enabled = true, Threshold = 90, UseBandage = true, UseFood = true }
        }
    end

    Core.RegisterPanelCommand("medic", ToggleMedicPanel)
    Core.RegisterModuleCommand("ArgentisMedic", "/ag medic")

    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Argentis Medic]|r v1.4 Loaded.")
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Argentis Medic]|r Configuração: |cffffffff/ag medic|r")
end)
