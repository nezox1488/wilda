-- Wild Client 4.2 — С исправленной логикой и обходом через End

-- =================================================================================
-- I. НАСТРОЙКИ КЛАВИШ И СОСТОЯНИЙ
-- =================================================================================

-- Единая таблица для управления состоянием всех функций
local FUNCTION_STATES = {
    Fly = false,
    NoClip = false,
    TeleportToInnocent = false,
    Aimbot = false,
    MassAssassinate = false,
    AssassinateMurderer = false,
    TargetMurderer = false,
    TargetSheriff = false,
    AntiMurdererDodge = false,
    PlayerESP = false,
    WeaponESP = false,
    MenuToggle = false,
}

-- Бинды
local BINDS = {
    Movement = {
        ["Fly"] = Enum.KeyCode.R,
        ["NoClip"] = Enum.KeyCode.Z,
        ["TeleportToInnocent"] = Enum.KeyCode.Insert,
    },
    Player = {
        ["Aimbot"] = Enum.KeyCode.X,
        ["MassAssassinate"] = Enum.KeyCode.L, 
        ["AssassinateMurderer"] = Enum.KeyCode.K, 
        ["TargetMurderer"] = Enum.KeyCode.O, 
        ["TargetSheriff"] = Enum.KeyCode.I, 
        ["AntiMurdererDodge"] = Enum.KeyCode.P, 
    },
    Visual = {
        ["PlayerESP"] = Enum.KeyCode.N,
        ["WeaponESP"] = Enum.KeyCode.U,
        ["MenuToggle"] = Enum.KeyCode.M, 
    }
}

-- Настройки
local flySpeed = 100
local aimRadius = 100
local flyAntiKickEnabled = true 
local GUI_BACKGROUND_TEXTURE_URL = "https://i.imgur.com/L13x2nK.png"

-- ЛОГИН
local REQUIRED_LOGIN = "BetaTest"
local REQUIRED_PASSWORD = "haski228"

-- =================================================================================
-- II. СЕРВИСЫ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- =================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local loggedIn = false 
local guiActive = false
local currentCategory = "Movement"
local waitingForBind = nil 
local flyVel, flyGyro, flyStartTime

-- Уведомления и Роли
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
-- III. ОСНОВНАЯ ЛОГИКА ФУНКЦИЙ (RunService)
-- =================================================================================

local function mouse1click()
    -- game:GetService("VirtualUser"):Click(Vector2.new(0, 0)) 
end

RunService.RenderStepped:Connect(function()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end 

    -- Fly Logic
    if FUNCTION_STATES.Fly and flyVel and flyGyro then
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
            FUNCTION_STATES.Fly = false; flyVel:Destroy(); flyGyro:Destroy()
            notify("FlyAntiKick сработал: Fly выкл")
        end
    end

    -- NoClip Logic
    if FUNCTION_STATES.NoClip and LocalPlayer.Character then
        for _,part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    -- Aimbot Logic
    if FUNCTION_STATES.Aimbot then
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

    -- TargetMurderer / TargetSheriff Logic (Улучшенная логика толкания)
    if FUNCTION_STATES.TargetMurderer or FUNCTION_STATES.TargetSheriff then
        local targetRole = FUNCTION_STATES.TargetMurderer and "Murderer" or "Sheriff"
        local targetPlayer = nil
        
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and getRole(pl) == targetRole and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character.Humanoid.Health > 0 then
                targetPlayer = pl
                break
            end
        end

        if targetPlayer and LocalPlayer.Character then
            local targetRoot = targetPlayer.Character.HumanoidRootPart
            local targetHumanoid = targetPlayer.Character.Humanoid
            
            local targetVelocity = targetRoot.Velocity
            local targetDirection = targetVelocity.Magnitude > 1 and targetVelocity.Unit or targetRoot.CFrame.LookVector
            
            local pushOffset = targetDirection * -0.5 + Vector3.new(0, 0.2, 0) 
            local targetPos = targetRoot.Position + pushOffset
            
            root.CFrame = CFrame.new(targetPos) 
            
            if targetHumanoid and targetHumanoid.PlatformStand == false then
                targetRoot.Velocity = targetRoot.Velocity + Vector3.new(0, 50, 0) 
                
                if targetVelocity.Magnitude > 0.5 then
                    targetRoot.CFrame = targetRoot.CFrame * CFrame.Angles(math.rad(1), 0, 0) 
                end
                
                targetHumanoid:ChangeState(Enum.HumanoidStateType.Running)
            end

        else
            if FUNCTION_STATES.TargetMurderer then FUNCTION_STATES.TargetMurderer = false; notify("TargetMurderer: цель потеряна") end
            if FUNCTION_STATES.TargetSheriff then FUNCTION_STATES.TargetSheriff = false; notify("TargetSheriff: цель потеряна") end
        end
    end
    
    -- AntiMurdererDodge Logic
    if FUNCTION_STATES.AntiMurdererDodge and LocalPlayer.Character then
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

local function assassinateMurdererLogic()
    if FUNCTION_STATES.AssassinateMurderer then
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
                FUNCTION_STATES.AssassinateMurderer = false
                conn:Disconnect()
                notify("AssassinateMurderer: цель потеряна")
            end
        end)
    end
end
-- =================================================================================
-- IV. СИСТЕМА ЛОГИНА (Исправлена и блокирует)
-- =================================================================================

local function createLoginGUI()
    local sg = Instance.new("ScreenGui", game.CoreGui); sg.Name = "LoginGUI"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local w = 300; local h = 200 
    local bg = Instance.new("Frame", sg)
    bg.Size = UDim2.new(0, w, 0, h)
    bg.Position = UDim2.new(0.5, -w/2, 0.5, -h/2)
    bg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    
    local corner = Instance.new("UICorner", bg)
    corner.CornerRadius = UDim.new(0, 15)

    local title = Instance.new("TextLabel", bg)
    title.Size = UDim2.new(1, 0, 0, 30) 
    title.Text = "Wild Login" 
    title.Font = Enum.Font.SourceSansBold
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.TextSize = 22
    title.Position = UDim2.new(0, 0, 0.05, 0)

    -- Логин
    local loginBox = Instance.new("TextBox", bg)
    loginBox.Size = UDim2.new(0.8, 0, 0, 30)
    loginBox.Position = UDim2.new(0.1, 0, 0.25, 0)
    loginBox.PlaceholderText = "Введите логин"
    loginBox.Font = Enum.Font.SourceSans
    loginBox.TextSize = 16
    loginBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    loginBox.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", loginBox).CornerRadius = UDim.new(0, 6)
    loginBox.TextXAlignment = Enum.TextXAlignment.Center

    -- Пароль
    local passwordBox = Instance.new("TextBox", bg)
    passwordBox.Size = UDim2.new(0.8, 0, 0, 30)
    passwordBox.Position = UDim2.new(0.1, 0, 0.45, 0)
    passwordBox.PlaceholderText = "Введите пароль"
    passwordBox.TextSize = 16
    passwordBox.Font = Enum.Font.SourceSans
    passwordBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    passwordBox.TextColor3 = Color3.new(1, 1, 1)
    passwordBox.TextXAlignment = Enum.TextXAlignment.Center
    Instance.new("UICorner", passwordBox).CornerRadius = UDim.new(0, 6)
    
    -- Простая маскировка пароля
    passwordBox.Text.Changed:Connect(function()
        if passwordBox.Text ~= "" then
            -- Note: This simple masking method doesn't hide the actual text property, but visually replaces it.
            -- In some exploits, using TextScaled/TextWrapped may be needed for better masking.
            passwordBox.Text = string.rep("*", #passwordBox.Text)
        end
    end)


    local errorLabel = Instance.new("TextLabel", bg)
    errorLabel.Size = UDim2.new(1, 0, 0, 20)
    errorLabel.Position = UDim2.new(0, 0, 0.65, 0)
    errorLabel.Text = ""
    errorLabel.Font = Enum.Font.SourceSansBold
    errorLabel.TextColor3 = Color3.fromRGB(200, 0, 0)
    errorLabel.BackgroundTransparency = 1
    errorLabel.TextSize = 16
    errorLabel.Visible = false

    
    -- Кнопка "Войти"
    local loginBtn = Instance.new("TextButton", bg)
    loginBtn.Size = UDim2.new(0.4, 0, 0, 30)
    loginBtn.Position = UDim2.new(0.1, 0, 0.8, 0)
    loginBtn.Text = "Войти"
    loginBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    loginBtn.TextColor3 = Color3.new(1, 1, 1)
    loginBtn.Font = Enum.Font.SourceSansBold
    loginBtn.TextSize = 18
    Instance.new("UICorner", loginBtn).CornerRadius = UDim.new(0, 6)

    -- Кнопка "Отмена"
    local cancelBtn = Instance.new("TextButton", bg)
    cancelBtn.Size = UDim2.new(0.4, 0, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, 30, 0.8, 0)
    cancelBtn.Text = "Отмена"
    cancelBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    cancelBtn.TextColor3 = Color3.new(1, 1, 1)
    cancelBtn.Font = Enum.Font.SourceSansBold
    cancelBtn.TextSize = 18
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)
    
    -- Логика Входа
    loginBtn.MouseButton1Click:Connect(function()
        -- Читаем актуальные данные:
        local enteredLogin = loginBox.Text 
        local actualPassword = passwordBox.Text 
        
        -- Убираем символы маскировки, если они есть (если используется простая маскировка)
        if actualPassword:sub(1,1) == "*" then
             actualPassword = actualPassword:gsub("*", "")
        end
        
        if enteredLogin == REQUIRED_LOGIN and actualPassword == REQUIRED_PASSWORD then
            loggedIn = true
            sg:Destroy()
            notify("Вход успешен! Нажмите M для открытия меню.", 3)
        else
            errorLabel.Text = "Неверный логин или пароль!"
            errorLabel.Visible = true
        end
    end)
    
    -- Логика Отмены
    cancelBtn.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)
    
    sg.Enabled = true
end

-- =================================================================================
-- V. GUI-ИНТЕРФЕЙС И ЛОГИКА (Main Menu)
-- ... (Этот блок остается прежним) ...
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

local function massAssassinate()

    task.spawn(function()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then notify("Нет персонажа!", 1.5); return end

        -- Проходим по всем игрокам
        for _,pl in ipairs(Players:GetPlayers()) do
            -- Пропускаем себя и мертвых
            if pl~=LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character:FindFirstChild("Humanoid") and pl.Character.Humanoid.Health > 0 then
                
                local tgt = pl.Character.HumanoidRootPart
                
                -- 1. Телепорт прямо в цель (минимальное смещение Y 0.5 для лучшего попадания)
                root.CFrame = CFrame.new(tgt.Position + Vector3.new(0, 0.5, 0))
                
                -- 2. Клик ЛКМ 5 раз быстро
                for i = 1, 5 do
                    mouse1click()
                    task.wait(0.01) -- Очень маленькая задержка для быстрого удара
                end
                
                task.wait(0.1) -- Небольшая пауза перед переходом к следующей цели
            end
        end
        
        notify("MassAssassinate завершен!", 1.5)
    end)
    notify("MassAssassinate активирован", 1.5)
end

-- Вспомогательные функции GUI
local functionsToUpdate = {} 

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

local function createToggle(funcName, category)
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
    
    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 6)
    
    local function update(customState)
        local state = customState ~= nil and customState or FUNCTION_STATES[funcName]
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(0,150,0) or Color3.fromRGB(150,0,0)
        FUNCTION_STATES[funcName] = state 
    end
    
    btn.MouseButton1Click:Connect(function()
        if funcName == "TeleportToInnocent" then teleportToInnocent() return end
        if funcName == "MassAssassinate" then massAssassinate() return end
        
        FUNCTION_STATES[funcName] = not FUNCTION_STATES[funcName]
        update()
        if funcName == "AssassinateMurderer" then assassinateMurdererLogic() end
        
        -- Специальная логика для Fly/NoClip
        if funcName == "Fly" and FUNCTION_STATES.Fly == false then 
             if flyVel then flyVel:Destroy(); flyVel=nil end
             if flyGyro then flyGyro:Destroy(); flyGyro=nil end
        elseif funcName == "Fly" and FUNCTION_STATES.Fly == true then
             local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
             if root then
                 flyVel = Instance.new("BodyVelocity", root)
                 flyGyro = Instance.new("BodyGyro", root)
                 flyVel.MaxForce = Vector3.new(1e9,1e9,1e9)
                 flyGyro.MaxTorque = Vector3.new(1e9,1e9,1e9)
                 flyGyro.CFrame = Camera.CFrame
                 flyStartTime = tick()
             end
        end

        notify(funcName .. (FUNCTION_STATES[funcName] and " Вкл" or " Выкл"))
    end)
    
    btn.InputBegan:Connect(function(input, gpe)
        if not gpe and input.UserInputType == Enum.UserInputType.MouseButton2 then
            startBindChange(funcName)
        end
    end)
    
    local function updateLabelText()
         lbl.Text = getBindText()
    end
    
    functionsToUpdate[funcName] = {label = lbl, update = update, funcName = funcName, getBindText = updateLabelText}

    update()
    return f
end

local function updateFunctionList(parentFrame, category)
    for _, child in pairs(parentFrame.ScrollingFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local funcData = {}

    if category == "Movement" then
        funcData = {
            {"Fly", "Movement"},
            {"NoClip", "Movement"},
            {"TeleportToInnocent", "Movement"}, 
        }
    elseif category == "Player" then
        funcData = {
            {"Aimbot", "Player"},
            {"MassAssassinate", "Player"}, 
            {"AssassinateMurderer", "Player"},
            {"TargetMurderer", "Player"},
            {"TargetSheriff", "Player"},
            {"AntiMurdererDodge", "Player"},
        }
    elseif category == "Visual" then
        funcData = {
            {"PlayerESP", "Visual"},
            {"WeaponESP", "Visual"},
            {"MenuToggle", "Visual"}, 
        }
    end
    
    for _, data in ipairs(funcData) do
        local f = createToggle(data[1], data[2])
        f.Parent = parentFrame.ScrollingFrame
    end
    
    if functionsToUpdate["MenuToggle"] then
        functionsToUpdate["MenuToggle"].update(true)
    end
end

-- ГЛАВНЫЙ GUI (Main Menu)
local function createGUI()
    local sg = Instance.new("ScreenGui", game.CoreGui); sg.Name="WildClientGUI"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

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

    local title = Instance.new("TextLabel", frm)
    title.Size = UDim2.new(1, 0, 0, 40) 
    title.Text = "Wild Client 3.0"
    title.Font = Enum.Font.SourceSansBold
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.TextSize = 26
    
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

    updateFunctionList(funcList, currentCategory)
    catFrame.MovementButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)

    return sg
end

-- Обработка открытия/закрытия GUI и биндов
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    local key = input.KeyCode

    -- === ОБХОД СИСТЕМЫ ЛОГИНА (END KEY BYPASS) ===
    if key == Enum.KeyCode.End then
        loggedIn = true
        local loginGui = game.CoreGui:FindFirstChild("LoginGUI")
        if loginGui then
            loginGui:Destroy()
        end
        notify("Bypass активирован! Логин пропущен. Нажмите M.", 3)
        return -- Прерываем дальнейшую обработку
    end
    -- =============================================

    -- Блокируем доступ, если не залогинен
    if not loggedIn and key == BINDS.Visual.MenuToggle then
        local loginGui = game.CoreGui:FindFirstChild("LoginGUI")
        if not loginGui then
            createLoginGUI()
        end
        return
    end

    -- Режим смены бинда
    if waitingForBind and key ~= Enum.KeyCode.Unknown and key ~= Enum.KeyCode.LeftShift and key ~= Enum.KeyCode.RightShift then
        updateBind(waitingForBind, key)
        for funcName, funcData in pairs(functionsToUpdate) do
            funcData.label.Text = funcData.getBindText()
        end
        waitingForBind = nil
        local sg = game.CoreGui:FindFirstChild("WildClientGUI")
        if sg then sg.BindPrompt.Visible = false end
        return
    end

    -- Обход всех биндов (ТОЛЬКО после логина)
    if loggedIn then
        for category, funcs in pairs(BINDS) do
            for funcName, bindKey in pairs(funcs) do
                if key == bindKey then
                    
                    -- Специальная обработка для MenuToggle
                    if funcName == "MenuToggle" then
                        guiActive = not guiActive
                        if guiActive then
                            local sg = createGUI()
                        else
                            local sg = game.CoreGui:FindFirstChild("WildClientGUI")
                            if sg then sg:Destroy() end
                        end
                    
                    -- Функции с немедленным действием
                    elseif funcName == "TeleportToInnocent" then
                        teleportToInnocent()
                    elseif funcName == "MassAssassinate" then
                        massAssassinate()
                    
                    -- Функции-переключатели
                    else
                        local newState = not FUNCTION_STATES[funcName]
                        FUNCTION_STATES[funcName] = newState
                        
                        -- Логика Fly для горячей клавиши
                        if funcName == "Fly" then
                            if newState == false then 
                                if flyVel then flyVel:Destroy(); flyVel=nil end
                                if flyGyro then flyGyro:Destroy(); flyGyro=nil end
                            else
                                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if root then
                                    flyVel = Instance.new("BodyVelocity", root)
                                    flyGyro = Instance.new("BodyGyro", root)
                                    flyVel.MaxForce = Vector3.new(1e9,1e9,1e9)
                                    flyGyro.MaxTorque = Vector3.new(1e9,1e9,1e9)
                                    flyGyro.CFrame = Camera.CFrame
                                    flyStartTime = tick()
                                end
                            end
                        end
                        
                        if funcName == "AssassinateMurderer" then assassinateMurdererLogic() end
                        notify(funcName .. (newState and " Вкл" or " Выкл"))
                    end
                    
                    -- Обновление UI, если открыто
                    if guiActive and functionsToUpdate[funcName] then
                        functionsToUpdate[funcName].update(FUNCTION_STATES[funcName])
                    end
                    
                    return
                end
            end
        end
    end
end)

-- =================================================================================
-- VI. ВИЗУАЛЬНАЯ ЛОГИКА (ESP)
-- =================================================================================

-- PlayerESP
local espBoxes = {}
task.spawn(function()
    while true do
        if FUNCTION_STATES.PlayerESP then
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
        task.wait(0.5) 
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
        if FUNCTION_STATES.WeaponESP then
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
        task.wait(3)
    end
end)

-- ОТКРЫТИЕ ОКНА ЛОГИНА ПРИ ЗАПУСКЕ
createLoginGUI()
