-- 1. SETUP & VARIABLES ----------------------------
local AddonName = "AtomCrosshair"
local frame = CreateFrame("Frame", "AtomCrosshairMain", UIParent)

-- Create textures: Borders on BACKGROUND, Main lines on ARTWORK (so they sit on top)
local hBorder = frame:CreateTexture(nil, "BACKGROUND")
local vBorder = frame:CreateTexture(nil, "BACKGROUND")
local hLine = frame:CreateTexture(nil, "ARTWORK")
local vLine = frame:CreateTexture(nil, "ARTWORK")

-- Default Settings
local defaults = {
    Color = {0, 1, 0, 1},
    Size = 50,
    Thickness = 3,
    AlwaysOn = false, 
    OffsetX = 0,
    OffsetY = 0,
    BorderThickness = 1,
    BorderColor = {0, 0, 0, 1}
}

-- 2. CORE FUNCTIONS -------------------------------
local function UpdateVisuals()
    if not AtomCrosshairDB then return end
    
    local c = AtomCrosshairDB.Color
    if type(c) ~= "table" or #c < 3 then c = defaults.Color end
    
    local bc = AtomCrosshairDB.BorderColor
    if type(bc) ~= "table" or #bc < 3 then bc = defaults.BorderColor end

    local s = AtomCrosshairDB.Size or defaults.Size
    local t = AtomCrosshairDB.Thickness or defaults.Thickness
    local x = AtomCrosshairDB.OffsetX or 0
    local y = AtomCrosshairDB.OffsetY or 0
    local bt = AtomCrosshairDB.BorderThickness or defaults.BorderThickness

    frame:SetSize(s, s)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

    -- Main Lines
    hLine:SetHeight(t);
    hLine:SetWidth(s);
    hLine:SetPoint("CENTER");
    hLine:SetColorTexture(unpack(c));

    vLine:SetWidth(t);
    vLine:SetHeight(s);
    vLine:SetPoint("CENTER");
    vLine:SetColorTexture(unpack(c));
    
    -- Borders
    if bt > 0 then
        hBorder:Show();
        vBorder:Show()
        
        hBorder:SetHeight(t + (bt * 2));
        hBorder:SetWidth(s + (bt * 2));
        hBorder:SetPoint("CENTER")
        hBorder:SetColorTexture(unpack(bc))

        vBorder:SetWidth(t + (bt * 2));
        vBorder:SetHeight(s + (bt * 2));
        vBorder:SetPoint("CENTER")
        vBorder:SetColorTexture(unpack(bc))
    else
        hBorder:Hide();
        vBorder:Hide()
    end
end

-- Decides whether to Show or Hide the frame
local function CheckVisibility()
    if not AtomCrosshairDB then return end

    if AtomCrosshairDB.AlwaysOn then
        frame:Show()
    else
        if UnitAffectingCombat("player") then
            frame:Show()
        else
            frame:Hide()
        end
    end
end

-- 3. EVENT HANDLING -------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        -- Initialize Database
        if not AtomCrosshairDB then
            AtomCrosshairDB = CopyTable(defaults)
        else
            for k, v in pairs(defaults) do
                if AtomCrosshairDB[k] == nil then
                    if type(v) == "table" then
                        AtomCrosshairDB[k] = CopyTable(v)
                    else
                        AtomCrosshairDB[k] = v
                    end
                end
            end
            
            -- 2. SANITY CHECK: Fix corrupt color tables
            if type(AtomCrosshairDB.BorderColor) ~= "table" or #AtomCrosshairDB.BorderColor < 3 then
                 AtomCrosshairDB.BorderColor = CopyTable(defaults.BorderColor)
            end
            
            if type(AtomCrosshairDB.Color) ~= "table" or #AtomCrosshairDB.Color < 3 then
                 AtomCrosshairDB.Color = CopyTable(defaults.Color)
            end
        end
        
        -- Initialize Options Panel
        self:CreateOptionsPanel()
        -- Apply initial look
        UpdateVisuals()
        CheckVisibility()

    elseif event == "PLAYER_REGEN_DISABLED" then
        CheckVisibility()
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        CheckVisibility()

    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckVisibility()
    end
end)

-- 4. OPTIONS PANEL (SETTINGS) ---------------------
function frame:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "AtomCrosshairOptions", UIParent)
    panel.name = "AtomCrosshair"
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("AtomCrosshair Settings")

    -- Checkbox: Always On
    local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    cb.Text:SetText("Always show (ignore combat status)")
    cb:SetChecked(AtomCrosshairDB.AlwaysOn)
    cb:SetScript("OnClick", function(self)
        AtomCrosshairDB.AlwaysOn = self:GetChecked()
        CheckVisibility()
    end)

    -- === COLOR PICKER HELPER ===
    local function CreateColorPicker(name, labelText, parent, anchorTo, getVal, setVal)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -20)
        label:SetText(labelText)

        local colorSwatch = CreateFrame("Button", nil, parent)
        colorSwatch:SetSize(40, 20)
        colorSwatch:SetPoint("LEFT", label, "RIGHT", 10, 0)
        
        local swatchBg = colorSwatch:CreateTexture(nil, "BACKGROUND")
        swatchBg:SetAllPoints()
        
        -- SAFETY: Ensure getVal returns a valid table before unpacking
        local c = getVal()
        if type(c) == "table" and #c >= 3 then
            swatchBg:SetColorTexture(unpack(c))
        else
            swatchBg:SetColorTexture(1, 1, 1, 1) -- Fallback white
        end
        
        local border = colorSwatch:CreateTexture(nil, "BORDER")
        border:SetAllPoints()
        border:SetColorTexture(0.5, 0.5, 0.5, 0.5)
        border:SetDrawLayer("BORDER", -1)

        colorSwatch:SetScript("OnClick", function()
            local r, g, b, a = unpack(getVal())
            
            local function OnColorSelect()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newA = ColorPickerFrame:GetColorAlpha()
                setVal({newR, newG, newB, newA})
                swatchBg:SetColorTexture(newR, newG, newB, newA)
                UpdateVisuals()
            end

            local function OnCancel()
                setVal({r, g, b, a})
                swatchBg:SetColorTexture(r, g, b, a)
                UpdateVisuals()
            end

            local info = {
                swatchFunc = OnColorSelect,
                opacityFunc = OnColorSelect,
                cancelFunc = OnCancel,
                hasOpacity = true,
                r = r, g = g, b = b, opacity = a,
            }
            
            if ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow(info)
            else
                ColorPickerFrame.func = OnColorSelect
                ColorPickerFrame.opacityFunc = OnColorSelect
                ColorPickerFrame.cancelFunc = OnCancel
                ColorPickerFrame.hasOpacity = true
                ColorPickerFrame:SetColorRGB(r, g, b)
                ColorPickerFrame.opacity = a
                ColorPickerFrame:Show()
            end
        end)
        
        return label
    end

    -- Main Color Picker
    local colorLabel = CreateColorPicker("MainColor", "Crosshair colour", panel, cb,
        function() return AtomCrosshairDB.Color end,
        function(val) AtomCrosshairDB.Color = val end
    )

    -- Border Color Picker
    local borderColorLabel = CreateColorPicker("BorderColor", "Border colour", panel, colorLabel,
        function() return AtomCrosshairDB.BorderColor or defaults.BorderColor end,
        function(val) AtomCrosshairDB.BorderColor = val end
    )

    -- === SLIDER HELPER ===
    local function CreateSlider(name, parent, label, minVal, maxVal, getVal, setVal)
        local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        slider:SetWidth(200)
        slider:SetHeight(20)
        slider:SetOrientation('HORIZONTAL')
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        
        _G[name .. "Low"]:SetText(minVal)
        _G[name .. "High"]:SetText(maxVal)
        _G[name .. "Text"]:SetText(label .. ": " .. math.floor(getVal()))
        
        slider:SetValue(getVal())
        
        slider:SetScript("OnValueChanged", function(self, value)
            setVal(value)
            _G[name .. "Text"]:SetText(label .. ": " .. math.floor(value))
        end)
        
        return slider
    end

    -- Size Slider
    local sizeSlider = CreateSlider("AtomCrosshairSizeSlider", panel, "Size", 5, 100,
        function() return AtomCrosshairDB.Size end,
        function(val) 
            AtomCrosshairDB.Size = val
            UpdateVisuals()
        end
    )
    sizeSlider:SetPoint("TOPLEFT", borderColorLabel, "BOTTOMLEFT", 0, -40)

    -- Thickness Slider
    local thicknessSlider = CreateSlider("AtomCrosshairThicknessSlider", panel, "Thickness", 1, 20,
        function() return AtomCrosshairDB.Thickness or defaults.Thickness end,
        function(val)
            AtomCrosshairDB.Thickness = val
            UpdateVisuals()
        end
    )
    thicknessSlider:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -40)

    -- Border Thickness Slider
    local borderThicknessSlider = CreateSlider("AtomCrosshairBorderThicknessSlider", panel, "Border thickness", 0, 10,
        function() return AtomCrosshairDB.BorderThickness or defaults.BorderThickness end,
        function(val)
            AtomCrosshairDB.BorderThickness = val
            UpdateVisuals()
        end
    )
    borderThicknessSlider:SetPoint("TOPLEFT", thicknessSlider, "BOTTOMLEFT", 0, -40)

    -- X Offset Slider
    local xSlider = CreateSlider("AtomCrosshairXSlider", panel, "X offset", -500, 500,
        function() return AtomCrosshairDB.OffsetX or 0 end,
        function(val)
            AtomCrosshairDB.OffsetX = val
            UpdateVisuals()
        end
    )
    xSlider:SetPoint("TOPLEFT", borderThicknessSlider, "BOTTOMLEFT", 0, -40)

    -- Reset X Button
    local resetX = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetX:SetSize(60, 20)
    resetX:SetText("Reset")
    resetX:SetPoint("LEFT", xSlider, "RIGHT", 15, 0)
    resetX:SetScript("OnClick", function()
        AtomCrosshairDB.OffsetX = 0
        xSlider:SetValue(0)
        UpdateVisuals()
    end)

    -- Y Offset Slider
    local ySlider = CreateSlider("AtomCrosshairYSlider", panel, "Y offset", -400, 400,
        function() return AtomCrosshairDB.OffsetY or 0 end,
        function(val)
            AtomCrosshairDB.OffsetY = val
            UpdateVisuals()
        end
    )
    ySlider:SetPoint("TOPLEFT", xSlider, "BOTTOMLEFT", 0, -40)

    -- Reset Y Button
    local resetY = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetY:SetSize(60, 20)
    resetY:SetText("Reset")
    resetY:SetPoint("LEFT", ySlider, "RIGHT", 15, 0)
    resetY:SetScript("OnClick", function()
        AtomCrosshairDB.OffsetY = 0
        ySlider:SetValue(0)
        UpdateVisuals()
    end)

    -- Register the panel
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "AtomCrosshair")
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(panel)
    end
end