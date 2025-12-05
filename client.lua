-- Wild Client 3.0 — Полный и исправленный код (С Категориями и Текстурами)

-- =================================================================================
-- I. НАСТРОЙКИ КЛАВИШ (Bind Variables)
-- =================================================================================

-- Двумерный массив для удобного доступа к биндам
local BINDS = {
    Movement = {
        ["Fly"] = Enum.KeyCode.R,
        ["NoClip"] = Enum.KeyCode.Z,
        ["TeleportToInnocent"] = Enum.KeyCode.Insert,
    },
    Player = {
        ["Aimbot"] = Enum.KeyCode.X,
        ["MassAssassinate"] = Enum.KeyCode.L, -- KillFly
        ["AssassinateMurderer"] = Enum.KeyCode.K, -- KillFlyMurder
        ["TargetMurderer"] = Enum.KeyCode.O, -- FuckerMurder (Улучшенная логика толкания)
        ["TargetSheriff"] = Enum.KeyCode.I, -- FuckerSheriff (Улучшенная логика толкания)
        ["AntiMurdererDodge"] = Enum.KeyCode.P, -- AutoMans
    },
    Visual = {
        ["PlayerESP"] = Enum.KeyCode.N,
        ["WeaponESP"] = Enum.KeyCode.U,
        ["MenuToggle"] = Enum.KeyCode.M, -- Кнопка для открытия GUI
    }
}

-- Настройки функций
local flySpeed = 100
local aimRadius = 100
local flyAntiKickEnabled = true 

-- Настройки GUI
local GUI_BACKGROUND_TEXTURE_URL = "https://raw.githubusercontent.com/nezox1488/Texture/main/cstexture.png" 

-- =================================================================================
-- II. СЕРВИСЫ И ПЕРЕМЕННЫЕ СОСТОЯНИЯ
-- =================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Переменные состояния (задаются через _G[funcName])
local Fly, NoClip, TeleportToInnocent = false, false, false
local Aimbot, MassAssassinate, AssassinateMurderer, TargetMurderer, TargetSheriff, AntiMurdererDodge = false, false, false, false, false, false
local PlayerESP, WeaponESP, MenuToggle = false, false, false

local flyVel, flyGyro, flyStartTime
local guiActive = false
local currentCategory = "Movement"
local waitingForBind = nil -- Переменная для режима смены бинда

-- =================================================================================
-- III. УВЕДОМЛЕНИЯ И РОЛИ
-- =================================================================================
local notificationGui = Instance.new("ScreenGui", game.CoreGui)
notificationGui.Name = "WCNotification"
local notifLabel = Instance.new("TextLabel", notificationGui)
notifLabel.Size = UDim2.new(0,300,0,50)
notifLabel.Position = UDim2.new(0.5,-150,0.1,0)
notifLabel.BackgroundTransparency = 0.3
notifLabel.BackgroundColor3 = Color3.fromRGB(30,30,30)
notifLabel.TextColor3 = Color3.new(1,1,1)
notifLabel.Font = Enum.Font.SourceSansBold
notifLabel.TextSize = 24
notifLabel.Visible = false
local notifBusy = false

local function notify(t, d)
    if notifBusy then return end
    notifBusy = true
    notifLabel.Text = t
    notifLabel.Visible = true
    task.delay(d or 1.5, function()
        notifLabel.Visible = false
        notifBusy = false
    end)
end

local function getRole(pl)
    local bp, ch = pl:FindFirstChild("Backpack"), pl.Character
    if ch and (ch:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife"))) then
        return "Murderer"
    elseif ch and (ch:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun"))) then
        return "Sheriff"
    end
    return "Innocent"
end

-- =================================================================================
-- IV. ОСНОВНАЯ ЛОГИКА ФУНКЦИЙ (СВЯЗАННАЯ С RUNSERVICE)
-- =================================================================================

-- Имитация клика мыши
local function mouse1click()
    -- Для работы на большинстве экзекьюторов:
    -- game:GetService("VirtualUser"):Click(Vector2.new(0, 0)) 
    -- Если экзекьютор поддерживает: mouse1press(); wait(0.05); mouse1release()
end

RunService.RenderStepped:Connect(function()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end 

    -- Fly Logic
    if Fly and flyVel and flyGyro then
        local mv = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then mv += Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then mv -= Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then mv -= Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then mv += Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then mv += Camera.CFrame.UpVector end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then mv -= Camera.CFrame.UpVector end
        flyVel.Velocity = mv.Magnitude>0 and mv.Unit*flySpeed or Vector3.zero
        flyGyro.CFrame = Camera.CFrame
        if flyAntiKickEnabled and tick() - flyStartTime > 10 then
            Fly = false; flyVel:Destroy(); flyGyro:Destroy()
            notify("FlyAntiKick сработал: Fly выкл")
        end
    end

    -- NoClip Logic
    if NoClip and LocalPlayer.Character then
        for _,part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    -- Aimbot Logic
    if Aimbot then
        local mp = UIS:GetMouseLocation()
        local closest, cd = nil, aimRadius
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl~=LocalPlayer and pl.Character and pl.Character:FindFirstChild("Humanoid") and pl.Character.Humanoid.Health>0 and pl.Character:FindFirstChild("Head") then
                local pos,vis = Camera:WorldToViewportPoint(pl.Character.Head.Position)
                if vis then
                    local d = (Vector2.new(pos.X,pos.Y) - Vector2.new(mp.X,mp.Y)).Magnitude
                    if d<cd then cd=d; closest=pl end
                end
            end
        end
        if closest then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, closest.Character.Head.Position)
        end
    end

    -- TargetMurderer / TargetSheriff Logic (УЛУЧШЕННАЯ ЛОГИКА ТОЛКАНИЯ)
    if TargetMurderer or TargetSheriff then
        local targetRole = TargetMurderer and "Murderer" or "Sheriff"
        local targetPlayer = nil
        
        -- Поиск цели
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and getRole(pl) == targetRole and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character.Humanoid.Health > 0 then
                targetPlayer = pl
                break
            end
        end

        if targetPlayer and LocalPlayer.Character then
            local targetRoot = targetPlayer.Character.HumanoidRootPart
            local targetHumanoid = targetPlayer.Character.Humanoid
            
            -- 1. Определяем направление движения цели
            local targetVelocity = targetRoot.Velocity
            local targetDirection = targetVelocity.Magnitude > 1 and targetVelocity.Unit or targetRoot.CFrame.LookVector
            
            -- 2. Вычисляем CFrame для агрессивного "вклинивания"
            local pushOffset = targetDirection * -0.5 + Vector3.new(0, 0.2, 0) 
            local targetPos = targetRoot.Position + pushOffset
            
            root.CFrame = CFrame.new(targetPos) 
            
            -- 3. Применяем агрессивную нестабилизирующую силу
            if targetHumanoid and targetHumanoid.PlatformStand == false then
                -- Принудительно задаем высокую вертикальную скорость, чтобы дестабилизировать игрока
                targetRoot.Velocity = targetRoot.Velocity + Vector3.new(0, 50, 0) 
                
                -- Если цель движется, толкаем ее в обратном направлении (чтобы сбить с ног)
                if targetVelocity.Magnitude > 0.5 then
                    targetRoot.CFrame = targetRoot.CFrame * CFrame.Angles(math.rad(1), 0, 0) 
                end
                
                -- Принудительный сброс состояния
                targetHumanoid:ChangeState(Enum.HumanoidStateType.Running)
            end

        else
            if TargetMurderer then TargetMurderer = false; notify("TargetMurderer: цель потеряна") end
            if TargetSheriff then TargetSheriff = false; notify("TargetSheriff: цель потеряна") end
        end
    end
    
    -- AntiMurdererDodge Logic
    if AntiMurdererDodge and LocalPlayer.Character then
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl~=LocalPlayer and getRole(pl)=="Murderer" and pl.Character and pl.Character:FindFirstChild("Knife") then
                local dist = (root.Position - pl.Character.HumanoidRootPart.Position).Magnitude
                if dist < 10 then
                    root.Velocity = (math.random()>0.5 and root.CFrame.RightVector or -root.CFrame.RightVector)*50 + Vector3.new(0,50,0)
                end
            end
        end
    end
end)

-- AssassinateMurderer Logic (Single Target Kill Fly)
local function assassinateMurdererLogic()
    if AssassinateMurderer then
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local m = LocalPlayer.Character
            local tgt
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl~=LocalPlayer and getRole(pl)=="Murderer" and pl.Character and pl.Character.Humanoid and pl.Character.Humanoid.Health>0 then
                    tgt = pl break
                end
            end
            if tgt and m and m:FindFirstChild("HumanoidRootPart") then
                local root = m.HumanoidRootPart
                local off = tgt.Character.HumanoidRootPart.CFrame.LookVector * -3 + Vector3.new(0,3,0)
                root.CFrame = CFrame.new(tgt.Character.HumanoidRootPart.Position + off)
                mouse1click()
            else
                AssassinateMurderer = false
                conn:Disconnect()
                notify("AssassinateMurderer: цель потеряна")
            end
        end)
    end
end

-- =================================================================================
-- V. СТРУКТУРНЫЕ ФУНКЦИИ (GUI И БИНДИНГ)
-- =================================================================================

-- Функция для телепортации к не-убийце/шерифу
local function teleportToInnocent()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then notify("Нет персонажа!", 1.5) return end
    
    local innocents = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and getRole(pl) == "Innocent" and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character.Humanoid.Health > 0 then
            table.insert(innocents, pl)
        end
    end

    if #innocents > 0 then
        local target = innocents[math.random(1, #innocents)]
        root.CFrame = CFrame.new(target.Character.HumanoidRootPart.Position + Vector3.new(0, 5, 0))
        notify("TeleportToInnocent: к " .. target.Name, 2)
    else
        notify("TeleportToInnocent: Нет подходящих целей.", 2)
    end
end

-- Функция MassAssassinate (KillFly)
local function massAssassinate()
    if getRole(LocalPlayer) ~= "Murderer" then notify("MassAssassinate только для Murderer") return end
    task.spawn(function()
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl~=LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                local root = LocalPlayer.Character.HumanoidRootPart
                local tgt = pl.Character.HumanoidRootPart
                if (root.Position - tgt.Position).Magnitude < 500 then
                    root.CFrame = CFrame.new(tgt.Position + Vector3.new(0,2,0))
                    wait(0.2); mouse1click(); wait(0.3)
                end
            end
        end
    end)
    notify("MassAssassinate активирован", 1.5)
end

-- Функция для обновления текущего значения бинда
local function updateBind(funcName, newKey)
    local category
    for cat, funcs in pairs(BINDS) do
        if funcs[funcName] then
            category = cat
            break
        end
    end

    if category then
        BINDS[category][funcName] = newKey
        notify(funcName .. " теперь бинд: [" .. newKey.Name .. "]", 2)
    end
end

-- Инициация режима смены бинда
local function startBindChange(funcName)
    waitingForBind = funcName
    local sg = game.CoreGui:FindFirstChild("WildClientGUI")
    if sg then
        local prompt = sg.BindPrompt
        prompt.Text = "Нажмите на кнопку на которую хотите поставить бинд для: " .. funcName
        prompt.Visible = true
    end
    notify("Режим смены бинда Вкл", 1)
end

-- Создание кнопки-переключателя
local functionsToUpdate = {} 
local function createToggle(funcName, funcRef, category)
    local f = Instance.new("Frame")
    f.Name = funcName .. "Frame"
    f.Size = UDim2.new(1,0,0,40)
    f.BackgroundColor3 = Color3.fromRGB(30,30,30)
    
    local corner = Instance.new("UICorner", f)
    corner.CornerRadius = UDim.new(0, 8) 

    local lbl = Instance.new("TextLabel",f)
    lbl.Size = UDim2.new(0.65,0,1,0)
    
    local function getBindText()
        return funcName .. " [" .. BINDS[category][funcName].Name .. "]"
    end

    lbl.Text = getBindText()
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Font = Enum.Font.SourceSansBold
    lbl.BackgroundTransparency = 1
    lbl.TextSize = 18
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Position = UDim2.new(0.05, 0, 0, 0)
    
    local btn = Instance.new("TextButton",f)
    btn.Size = UDim2.new(0.3,0,0.8,0)
    btn.Position = UDim2.new(0.7,0,0.1,0)
    btn.Text="OFF"
    btn.BackgroundColor3 = Color3.fromRGB(200,0,0)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 18
    
    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 6)
    
    -- Обновление состояния кнопки
    local function update(customState)
        local state = customState ~= nil and customState or funcRef
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(0,150,0) or Color3.fromRGB(150,0,0)
        _G[funcName] = state 
    end
    
    -- Обработка клика
    btn.MouseButton1Click:Connect(function()
        if funcName == "TeleportToInnocent" then teleportToInnocent() return end
        if funcName == "MassAssassinate" then massAssassinate() return end
        
        funcRef = not funcRef
        update(funcRef)
        if funcName == "AssassinateMurderer" then assassinateMurdererLogic() end
        notify(funcName .. (funcRef and " Вкл" or " Выкл"))
    end)
    
    -- Обработка нажатия СРЕДНЕЙ кнопки мыши (для смены бинда)
    btn.InputBegan:Connect(function(input, gpe)
        if not gpe and input.UserInputType == Enum.UserInputType.MouseButton2 then
            startBindChange(funcName)
        end
    end)
    
    local function updateLabelText()
         lbl.Text = getBindText()
    end
    
    functionsToUpdate[funcName] = {label = lbl, update = update, funcName = funcName, getBindText = updateLabelText}

    update(funcRef)
    return f
end

-- Функция, которая заполняет список функций
local function updateFunctionList(parentFrame, category)
    -- Очистка
    for _, child in pairs(parentFrame.ScrollingFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local funcData = {}

    if category == "Movement" then
        funcData = {
            {"Fly", Fly, "Movement"},
            {"NoClip", NoClip, "Movement"},
            {"TeleportToInnocent", TeleportToInnocent, "Movement"}, 
        }
    elseif category == "Player" then
        funcData = {
            {"Aimbot", Aimbot, "Player"},
            {"MassAssassinate", MassAssassinate, "Player"}, 
            {"AssassinateMurderer", AssassinateMurderer, "Player"},
            {"TargetMurderer", TargetMurderer, "Player"},
            {"TargetSheriff", TargetSheriff, "Player"},
            {"AntiMurdererDodge", AntiMurdererDodge, "Player"},
        }
    elseif category == "Visual" then
        funcData = {
            {"PlayerESP", PlayerESP, "Visual"},
            {"WeaponESP", WeaponESP, "Visual"},
            {"MenuToggle", MenuToggle, "Visual"}, 
        }
    end
    
    -- Создание элементов
    for _, data in ipairs(funcData) do
        local f = createToggle(data[1], data[2], data[3])
        f.Parent = parentFrame.ScrollingFrame
    end
    
    -- Установка MenuToggle всегда ON в UI
    if category == "Visual" then
        if functionsToUpdate["MenuToggle"] then
            functionsToUpdate["MenuToggle"].update(true)
        end
    end
end

-- GUI Setup
local function createGUI()
    local sg = Instance.new("ScreenGui", game.CoreGui); sg.Name="WildClientGUI"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- 1. Main Background (Texture)
    local bg = Instance.new("ImageLabel", sg)
    bg.Size = UDim2.new(0, 450, 0, 400) 
    bg.Position = UDim2.new(0.5, -225, 0.5, -200)
    bg.Image = GUI_BACKGROUND_TEXTURE_URL
    bg.ScaleType = Enum.ScaleType.Slice
    bg.SliceCenter = Rect.new(10, 10, 10, 10)
    
    local corner = Instance.new("UICorner", bg)
    corner.CornerRadius = UDim.new(0, 15) 

    local frm = Instance.new("Frame", bg)
    frm.Name = "MainFrame"
    frm.Size = UDim2.new(1, -20, 1, -20)
    frm.Position = UDim2.new(0, 10, 0, 10)
    frm.BackgroundTransparency = 1 

    -- 2. Title
    local title = Instance.new("TextLabel", frm)
    title.Size = UDim2.new(1, 0, 0, 40) 
    title.Text = "Wild Client 3.0"
    title.Font = Enum.Font.SourceSansBold
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.TextSize = 26
    
    -- 3. Category Buttons
    local catFrame = Instance.new("Frame", frm)
    catFrame.Name = "CategoryFrame"
    catFrame.Size = UDim2.new(1, 0, 0, 30)
    catFrame.Position = UDim2.new(0, 0, 0, 45)
    catFrame.BackgroundTransparency = 1 

    local listLayoutCat = Instance.new("UIListLayout", catFrame)
    listLayoutCat.FillDirection = Enum.FillDirection.Horizontal
    listLayoutCat.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayoutCat.Padding = UDim.new(0, 5)

    local function createCategoryButton(name)
        local btn = Instance.new("TextButton", catFrame)
        btn.Name = name .. "Button"
        btn.Size = UDim2.new(0, 100, 1, 0)
        btn.Text = name
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 16
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 5)
        
        btn.MouseButton1Click:Connect(function()
            currentCategory = name
            updateFunctionList(frm.FunctionList, name)
            for _, v in pairs(catFrame:GetChildren()) do
                if v:IsA("TextButton") then
                    v.BackgroundColor3 = v.Name == name .. "Button" and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
                end
            end
        end)
        return btn
    end

    createCategoryButton("Movement")
    createCategoryButton("Player")
    createCategoryButton("Visual")
    
    -- 4. Function List Frame
    local funcList = Instance.new("Frame", frm)
    funcList.Name = "FunctionList"
    funcList.Size = UDim2.new(1, 0, 1, -85)
    funcList.Position = UDim2.new(0, 0, 0, 85)
    funcList.BackgroundTransparency = 1 
    
    local scroll = Instance.new("ScrollingFrame", funcList)
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    
    local listLayoutFunc = Instance.new("UIListLayout", scroll)
    listLayoutFunc.Padding = UDim.new(0, 5)
    listLayoutFunc.SortOrder = Enum.SortOrder.LayoutOrder
    
    -- 5. Bind Prompt Label
    local bindPrompt = Instance.new("TextLabel", sg)
    bindPrompt.Name = "BindPrompt"
    bindPrompt.Size = UDim2.new(0, 400, 0, 30)
    bindPrompt.Position = UDim2.new(0.5, -200, 1, -40)
    bindPrompt.BackgroundTransparency = 0.1
    bindPrompt.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bindPrompt.TextColor3 = Color3.new(1, 1, 0)
    bindPrompt.Font = Enum.Font.SourceSansBold
    bindPrompt.TextSize = 16
    bindPrompt.Visible = false

    
    -- Инициализация и выбор первой категории
    updateFunctionList(funcList, currentCategory)
    catFrame.MovementButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)

    return sg
end

-- Обработка открытия/закрытия GUI
UIS.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == BINDS.Visual.MenuToggle then
        guiActive = not guiActive
        if guiActive then
            local sg = createGUI()
        else
            local sg = game.CoreGui:FindFirstChild("WildClientGUI")
            if sg then sg:Destroy() end
        end
    end
end)

-- =================================================================================
-- VI. ВИЗУАЛЬНАЯ ЛОГИКА (ESP)
-- =================================================================================

-- ESP
local espBoxes = {}
task.spawn(function()
    while true do
        if PlayerESP then
            for _,b in pairs(espBoxes) do b:Destroy() end; espBoxes={}
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl~=LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                    local col = getRole(pl)=="Murderer" and Color3.new(1,0,0) or getRole(pl)=="Sheriff" and Color3.new(0,0.7,1) or Color3.new(1,1,1)
                    local box = Instance.new("BoxHandleAdornment")
                    box.Size = Vector3.new(4,6,1)
                    box.Adornee = pl.Character.HumanoidRootPart
                    box.AlwaysOnTop = true
                    box.Transparency = 0.4
                    box.Color3 = col
                    box.ZIndex = 5
                    box.Parent = pl.Character.HumanoidRootPart
                    espBoxes[pl] = box
                end
            end
        else
            for _,b in pairs(espBoxes) do b:Destroy() end; espBoxes={}
        end
        wait(5)
    end
end)

-- WeaponESP
local weaponBoxes = {}
local function clearWBox()
    for _,v in pairs(weaponBoxes) do v:Destroy() end
    weaponBoxes = {}
end
task.spawn(function()
    while true do
        if WeaponESP then
            clearWBox()
            for _,obj in ipairs(workspace:GetDescendants()) do
                if obj.Name=="Gun" and obj:IsA("Tool") and obj.Parent~=LocalPlayer.Character then
                    local box = Instance.new("BoxHandleAdornment")
                    box.Size = obj.Handle.Size + Vector3.new(0.2,0.2,0.2)
                    box.Adornee = obj.Handle
                    box.Color3 = Color3.new(0,1,0)
                    box.AlwaysOnTop = true
                    box.Transparency = 0.3
                    box.ZIndex = 6
                    box.Parent = obj.Handle
                    weaponBoxes[obj] = box
                end
            end
        else
            clearWBox()
        end
        wait(3)
    end
end)
