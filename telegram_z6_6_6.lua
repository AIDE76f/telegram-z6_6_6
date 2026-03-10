-- إعدادات الخدمات
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- الإعدادات الرئيسية
local Settings = {
    ESP = {
        Enabled = false,
        BoxColor = Color3.new(1, 0, 0),
        DistanceColor = Color3.new(1, 1, 1),
        HealthGradient = { Color3.new(0, 1, 0), Color3.new(1, 1, 0), Color3.new(1, 0, 0) },
        SnaplineEnabled = true,
        SnaplinePosition = "Center",
        RainbowEnabled = false,
        NameESP = false,
        TeamCheck = true,
        OffScreenArrow = false
    },
    Aimbot = {
        Enabled = false,
        FOV = 90,
        MaxDistance = 200,
        ShowFOV = false,
        TargetPart = "Head",
        SmoothAim = 50,
        MagicAim = false,
        AutoFire = false,
        FullHead = false
    },
    Combo = {
        InfiniteJump = {
            Enabled = false,
            Connection = nil
        },
        Speed = {
            Enabled = false,
            Multiplier = 3,
            OriginalSpeed = 16
        },
        NoWall = false
    }
}

-- تخزين الرسومات
local ESP_Drawings = {}
local CurrentTarget = nil

-- دوال مساعدة
local function GetTeam(player)
    return player and player.Team
end

local function IsSameTeam(p1, p2)
    if not Settings.ESP.TeamCheck then return false end
    local t1, t2 = GetTeam(p1), GetTeam(p2)
    return t1 and t2 and t1 == t2
end

-- إنشاء رسومات ESP للاعب
local function CreateESP(Player)
    if Player == LocalPlayer then return end
    local Drawings = {
        Box = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        Distance = Drawing.new("Text"),
        Snapline = Drawing.new("Line"),
        NameTag = Drawing.new("Text"),
        Arrow = Drawing.new("Triangle")
    }
    
    Drawings.Box.Thickness = 2
    Drawings.Box.Filled = false
    Drawings.Box.Color = Settings.ESP.BoxColor
    
    Drawings.HealthBar.Filled = true
    Drawings.HealthBar.Color = Color3.new(0, 1, 0)
    
    Drawings.Distance.Size = 16
    Drawings.Distance.Center = true
    Drawings.Distance.Color = Settings.ESP.DistanceColor
    
    Drawings.Snapline.Color = Settings.ESP.BoxColor
    
    Drawings.NameTag.Size = 16
    Drawings.NameTag.Center = true
    Drawings.NameTag.Color = Color3.new(1, 1, 1)
    Drawings.NameTag.Text = Player.Name
    
    Drawings.Arrow.Thickness = 2
    Drawings.Arrow.Color = Color3.new(1, 0, 0)
    Drawings.Arrow.Filled = false
    
    for _, DrawingObj in pairs(Drawings) do
        DrawingObj.Visible = false
    end
    
    ESP_Drawings[Player] = Drawings
end

-- تحديث ESP للاعب
local function UpdateESP(Player, Drawings)
    if not Settings.ESP.Enabled or not Player.Character or IsSameTeam(Player, LocalPlayer) then
        for _, DrawingObj in pairs(Drawings) do
            DrawingObj.Visible = false
        end
        return
    end
    
    local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    local Head = Player.Character:FindFirstChild("Head")
    
    if not Humanoid or Humanoid.Health <= 0 or not Head then
        for _, DrawingObj in pairs(Drawings) do
            DrawingObj.Visible = false
        end
        return
    end
    
    local HeadPos, OnScreen = Camera:WorldToViewportPoint(Head.Position)
    local Distance = (Head.Position - Camera.CFrame.Position).Magnitude
    local Scale = 1000 / Distance
    
    Drawings.Box.Size = Vector2.new(Scale, Scale * 1.5)
    Drawings.Box.Position = Vector2.new(HeadPos.X - Scale/2, HeadPos.Y - Scale * 0.75)
    Drawings.Box.Visible = OnScreen
    
    local HealthPercent = Humanoid.Health / Humanoid.MaxHealth
    local HealthColorIndex = math.clamp(3 - HealthPercent * 2, 1, 3)
    local HealthColor = Settings.ESP.HealthGradient[math.floor(HealthColorIndex)]:Lerp(
        Settings.ESP.HealthGradient[math.ceil(HealthColorIndex)],
        HealthColorIndex % 1
    )
    
    Drawings.HealthBar.Size = Vector2.new(4, Scale * 1.5 * HealthPercent)
    Drawings.HealthBar.Position = Vector2.new(
        HeadPos.X + Scale/2 + 2,
        HeadPos.Y - Scale * 0.75 + (Scale * 1.5 * (1 - HealthPercent))
    )
    Drawings.HealthBar.Color = HealthColor
    Drawings.HealthBar.Visible = OnScreen
    
    Drawings.Distance.Text = math.floor(Distance) .. "m"
    Drawings.Distance.Position = Vector2.new(HeadPos.X, HeadPos.Y + Scale * 0.75 + 5)
    Drawings.Distance.Visible = OnScreen
    
    if Settings.ESP.NameESP then
        Drawings.NameTag.Position = Vector2.new(HeadPos.X, HeadPos.Y - Scale * 0.75 - 20)
        Drawings.NameTag.Visible = OnScreen
    else
        Drawings.NameTag.Visible = false
    end
    
    if Settings.ESP.RainbowEnabled then
        local Hue = (tick() * 0.5) % 1
        Drawings.Box.Color = Color3.fromHSV(Hue, 1, 1)
        Drawings.Snapline.Color = Color3.fromHSV(Hue, 1, 1)
        Drawings.Arrow.Color = Color3.fromHSV(Hue, 1, 1)
    else
        Drawings.Box.Color = Settings.ESP.BoxColor
        Drawings.Snapline.Color = Settings.ESP.BoxColor
        Drawings.Arrow.Color = Settings.ESP.BoxColor
    end
    
    if Settings.ESP.SnaplineEnabled and OnScreen then
        local SnaplineY
        if Settings.ESP.SnaplinePosition == "Bottom" then
            SnaplineY = Camera.ViewportSize.Y
        elseif Settings.ESP.SnaplinePosition == "Top" then
            SnaplineY = 0
        else
            SnaplineY = Camera.ViewportSize.Y / 2
        end
        
        Drawings.Snapline.From = Vector2.new(HeadPos.X, HeadPos.Y + Scale * 0.75)
        Drawings.Snapline.To = Vector2.new(Camera.ViewportSize.X / 2, SnaplineY)
        Drawings.Snapline.Visible = true
    else
        Drawings.Snapline.Visible = false
    end
    
    if Settings.ESP.OffScreenArrow and not OnScreen then
        local Center = Camera.ViewportSize / 2
        local Dir = (Vector2.new(HeadPos.X, HeadPos.Y) - Center).Unit
        local ArrowPos = Center + Dir * 100
        local Angle = math.atan2(Dir.Y, Dir.X)
        
        local Point1 = ArrowPos + Vector2.new(math.cos(Angle) * 20, math.sin(Angle) * 20)
        local Point2 = ArrowPos + Vector2.new(math.cos(Angle + 2.5) * 10, math.sin(Angle + 2.5) * 10)
        local Point3 = ArrowPos + Vector2.new(math.cos(Angle - 2.5) * 10, math.sin(Angle - 2.5) * 10)
        
        Drawings.Arrow.Point1 = Point1
        Drawings.Arrow.Point2 = Point2
        Drawings.Arrow.Point3 = Point3
        Drawings.Arrow.Visible = true
    else
        Drawings.Arrow.Visible = false
    end
end

-- دالة العثور على أفضل هدف
local function FindBestTarget()
    local BestTarget = nil
    local BestAngle = math.huge
    local BestDistance = math.huge
    
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character then
            if Settings.ESP.TeamCheck and IsSameTeam(Player, LocalPlayer) then
                continue
            end
            local Head = Player.Character:FindFirstChild("Head")
            if Head then
                local Direction = (Head.Position - Camera.CFrame.Position).Unit
                local LookVector = Camera.CFrame.LookVector
                local Angle = math.deg(math.acos(Direction:Dot(LookVector)))
                local Distance = (Head.Position - Camera.CFrame.Position).Magnitude
                
                if Angle <= Settings.Aimbot.FOV / 2 and Distance <= Settings.Aimbot.MaxDistance then
                    local RaycastParams = RaycastParams.new()
                    RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
                    RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    
                    local RayResult = workspace:Raycast(Camera.CFrame.Position, Direction * Distance, RaycastParams)
                    if RayResult and RayResult.Instance:IsDescendantOf(Player.Character) then
                        if Angle < BestAngle then
                            BestAngle = Angle
                            BestDistance = Distance
                            BestTarget = Player
                        elseif Angle == BestAngle and Distance < BestDistance then
                            BestDistance = Distance
                            BestTarget = Player
                        end
                    end
                end
            end
        end
    end
    
    return BestTarget, BestAngle
end

-- دائرة FOV
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 100
FOVCircle.Filled = false
FOVCircle.Visible = Settings.Aimbot.ShowFOV
FOVCircle.Color = Color3.new(1, 1, 1)

-- بناء واجهة المستخدم
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ScriptGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 1000

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 370, 0, 450) -- زيادة الارتفاع قليلاً لاستيعاب التبويبة الرابعة
MainFrame.Position = UDim2.new(0, 10, 0, 10)
MainFrame.BackgroundColor3 = Color3.new(0.05, 0.05, 0.05)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ZIndex = 100
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 101
TitleBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(0, 200, 0, 30)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.new(1, 1, 1)
TitleLabel.Text = "Advanced GUI v2.0"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 102
TitleLabel.Parent = TitleBar

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Position = UDim2.new(1, -25, 0, 5)
CloseButton.BackgroundColor3 = Color3.new(1, 0, 0)
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Text = "X"
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 16
CloseButton.ZIndex = 102
CloseButton.Parent = TitleBar
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseButton
CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Position = UDim2.new(1, -50, 0, 5)
MinimizeButton.BackgroundColor3 = Color3.new(1, 0.5, 0)
MinimizeButton.TextColor3 = Color3.new(1, 1, 1)
MinimizeButton.Text = "-"
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.TextSize = 20
MinimizeButton.ZIndex = 102
MinimizeButton.Parent = TitleBar
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 5)
MinCorner.Parent = MinimizeButton

local TabsFrame = Instance.new("Frame")
TabsFrame.Name = "TabsFrame"
TabsFrame.Size = UDim2.new(0, 150, 0, MainFrame.Size.Y.Offset - TitleBar.Size.Y.Offset)
TabsFrame.Position = UDim2.new(0, 0, 0, TitleBar.Size.Y.Offset)
TabsFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
TabsFrame.BorderSizePixel = 0
TabsFrame.ZIndex = 101
TabsFrame.Parent = MainFrame
local TabsCorner = Instance.new("UICorner")
TabsCorner.CornerRadius = UDim.new(0, 10)
TabsCorner.Parent = TabsFrame

-- أزرار التبويبات (الآن 4 أزرار)
local ESPTab = Instance.new("TextButton")
ESPTab.Name = "ESPTabButton"
ESPTab.Size = UDim2.new(1, -10, 0, 40)
ESPTab.Position = UDim2.new(0, 5, 0, 10)
ESPTab.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
ESPTab.TextColor3 = Color3.new(1, 1, 1)
ESPTab.Text = "ESP"
ESPTab.Font = Enum.Font.GothamBold
ESPTab.TextSize = 14
ESPTab.ZIndex = 102
ESPTab.Parent = TabsFrame
local ESPTabCorner = Instance.new("UICorner")
ESPTabCorner.CornerRadius = UDim.new(0, 5)
ESPTabCorner.Parent = ESPTab

local AimbotTab = Instance.new("TextButton")
AimbotTab.Name = "AimbotTabButton"
AimbotTab.Size = UDim2.new(1, -10, 0, 40)
AimbotTab.Position = UDim2.new(0, 5, 0, 60)
AimbotTab.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
AimbotTab.TextColor3 = Color3.new(1, 1, 1)
AimbotTab.Text = "Aimbot"
AimbotTab.Font = Enum.Font.GothamBold
AimbotTab.TextSize = 14
AimbotTab.ZIndex = 102
AimbotTab.Parent = TabsFrame
local AimbotTabCorner = Instance.new("UICorner")
AimbotTabCorner.CornerRadius = UDim.new(0, 5)
AimbotTabCorner.Parent = AimbotTab

local ComboTab = Instance.new("TextButton")
ComboTab.Name = "ComboTabButton"
ComboTab.Size = UDim2.new(1, -10, 0, 40)
ComboTab.Position = UDim2.new(0, 5, 0, 110)
ComboTab.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
ComboTab.TextColor3 = Color3.new(1, 1, 1)
ComboTab.Text = "Combo"
ComboTab.Font = Enum.Font.GothamBold
ComboTab.TextSize = 14
ComboTab.ZIndex = 102
ComboTab.Parent = TabsFrame
local ComboTabCorner = Instance.new("UICorner")
ComboTabCorner.CornerRadius = UDim.new(0, 5)
ComboTabCorner.Parent = ComboTab

-- زر التبويبة الرابعة: My Information
local InfoTab = Instance.new("TextButton")
InfoTab.Name = "InfoTabButton"
InfoTab.Size = UDim2.new(1, -10, 0, 40)
InfoTab.Position = UDim2.new(0, 5, 0, 160)
InfoTab.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
InfoTab.TextColor3 = Color3.new(1, 1, 1)
InfoTab.Text = "My Info"
InfoTab.Font = Enum.Font.GothamBold
InfoTab.TextSize = 14
InfoTab.ZIndex = 102
InfoTab.Parent = TabsFrame
local InfoTabCorner = Instance.new("UICorner")
InfoTabCorner.CornerRadius = UDim.new(0, 5)
InfoTabCorner.Parent = InfoTab

-- إطارات المحتوى (ScrollingFrame للتبويبات الثلاثة الأولى، وFrame عادي للتبويبة الرابعة)
local function CreateScrollTab(name)
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Name = name .. "TabContent"
    Scroll.Size = UDim2.new(0, MainFrame.Size.X.Offset - TabsFrame.Size.X.Offset - 20, 0, MainFrame.Size.Y.Offset - TitleBar.Size.Y.Offset - 20)
    Scroll.Position = UDim2.new(0, TabsFrame.Size.X.Offset + 10, 0, TitleBar.Size.Y.Offset + 10)
    Scroll.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    Scroll.BorderSizePixel = 0
    Scroll.ZIndex = 101
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Scroll.ScrollBarThickness = 8
    Scroll.Parent = MainFrame
    return Scroll
end

local ESPContent = CreateScrollTab("ESP")
local AimbotContent = CreateScrollTab("Aimbot")
local ComboContent = CreateScrollTab("Combo")

-- محتوى تبويبة My Information (ليس ScrollingFrame، لأنه لا يحتاج تمرير)
local InfoContent = Instance.new("Frame")
InfoContent.Name = "InfoTabContent"
InfoContent.Size = UDim2.new(0, MainFrame.Size.X.Offset - TabsFrame.Size.X.Offset - 20, 0, MainFrame.Size.Y.Offset - TitleBar.Size.Y.Offset - 20)
InfoContent.Position = UDim2.new(0, TabsFrame.Size.X.Offset + 10, 0, TitleBar.Size.Y.Offset + 10)
InfoContent.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
InfoContent.BorderSizePixel = 0
InfoContent.ZIndex = 101
InfoContent.Parent = MainFrame
InfoContent.Visible = false

-- إضافة زوايا دائرية للمحتوى (اختياري)
local InfoCorner = Instance.new("UICorner")
InfoCorner.CornerRadius = UDim.new(0, 10)
InfoCorner.Parent = InfoContent

-- إضافة النصوص داخل InfoContent
local function CreateRainbowLabel(parent, text, yPos, size)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, size or 50)
    label.Position = UDim2.new(0, 10, 0, yPos)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamBold
    label.TextSize = size and size-10 or 40
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.ZIndex = 102
    label.Parent = parent
    return label
end

-- إنشاء النصوص مع إمكانية تحديث الألوان (رينبو)
local InfoLabels = {}
do
    local y = 20
    table.insert(InfoLabels, CreateRainbowLabel(InfoContent, "My Information", y, 50))
    y = y + 60
    table.insert(InfoLabels, CreateRainbowLabel(InfoContent, "Telegram:", y, 40))
    y = y + 50
    table.insert(InfoLabels, CreateRainbowLabel(InfoContent, "@jj_j4j", y, 40))
    y = y + 50
    table.insert(InfoLabels, CreateRainbowLabel(InfoContent, "@z6_6_6", y, 40))
    y = y + 50
    table.insert(InfoLabels, CreateRainbowLabel(InfoContent, "✨ Contact me ✨", y, 40))
end

-- دوال مساعدة لإنشاء العناصر في التبويبات الأخرى (كما كانت)
local function CreateToggle(parent, text, getFunc, setFunc, y)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 180, 0, 40)
    btn.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.ZIndex = 101
    btn.Parent = parent
    btn.Position = UDim2.new(0, 10, 0, y)
    
    local ind = Instance.new("Frame")
    ind.Size = UDim2.new(0, 20, 0, 20)
    ind.Position = UDim2.new(1, -25, 0, 5)
    ind.BackgroundColor3 = getFunc() and Color3.new(0,1,0) or Color3.new(1,0,0)
    ind.BorderSizePixel = 0
    ind.ZIndex = 102
    ind.Parent = btn
    local indCorner = Instance.new("UICorner")
    indCorner.CornerRadius = UDim.new(0,5)
    indCorner.Parent = ind
    
    btn.MouseButton1Click:Connect(function()
        setFunc(not getFunc())
        ind.BackgroundColor3 = getFunc() and Color3.new(0,1,0) or Color3.new(1,0,0)
    end)
    
    return y + 50
end

local function CreateInput(parent, label, getFunc, setFunc, y, minVal, maxVal)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 180, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Text = label
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 101
    lbl.Parent = parent
    lbl.Position = UDim2.new(0, 10, 0, y)
    y = y + 20
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 180, 0, 40)
    box.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Text = tostring(getFunc())
    box.Font = Enum.Font.GothamBold
    box.TextSize = 14
    box.ZIndex = 101
    box.Parent = parent
    box.Position = UDim2.new(0, 10, 0, y)
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0,5)
    boxCorner.Parent = box
    
    box.FocusLost:Connect(function(enter)
        if enter then
            local v = tonumber(box.Text)
            if v then
                v = math.clamp(v, minVal, maxVal)
                setFunc(v)
            end
            box.Text = tostring(getFunc())
        end
    end)
    
    return y + 50
end

local function CreateDropdown(parent, label, getFunc, setFunc, options, y)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 180, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Text = label
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 101
    lbl.Parent = parent
    lbl.Position = UDim2.new(0, 10, 0, y)
    y = y + 20
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 180, 0, 40)
    btn.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = getFunc()
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.ZIndex = 101
    btn.Parent = parent
    btn.Position = UDim2.new(0, 10, 0, y)
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0,5)
    btnCorner.Parent = btn
    
    local idx = 1
    for i, opt in ipairs(options) do
        if opt == getFunc() then idx = i end
    end
    
    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        setFunc(options[idx])
        btn.Text = getFunc()
    end)
    
    return y + 50
end

-- تعبئة تبويبة ESP
do
    local y = 10
    y = CreateToggle(ESPContent, "ESP", 
        function() return Settings.ESP.Enabled end,
        function(v) Settings.ESP.Enabled = v end, y)
    y = CreateToggle(ESPContent, "Snapline", 
        function() return Settings.ESP.SnaplineEnabled end,
        function(v) Settings.ESP.SnaplineEnabled = v end, y)
    y = CreateDropdown(ESPContent, "Position", 
        function() return Settings.ESP.SnaplinePosition end,
        function(v) Settings.ESP.SnaplinePosition = v end,
        {"Center", "Top", "Bottom"}, y)
    y = CreateToggle(ESPContent, "Rainbow", 
        function() return Settings.ESP.RainbowEnabled end,
        function(v) Settings.ESP.RainbowEnabled = v end, y)
    y = CreateToggle(ESPContent, "Name ESP", 
        function() return Settings.ESP.NameESP end,
        function(v) Settings.ESP.NameESP = v end, y)
    y = CreateToggle(ESPContent, "Team Check", 
        function() return Settings.ESP.TeamCheck end,
        function(v) Settings.ESP.TeamCheck = v end, y)
    y = CreateToggle(ESPContent, "Off-Screen Arrow", 
        function() return Settings.ESP.OffScreenArrow end,
        function(v) Settings.ESP.OffScreenArrow = v end, y)
    ESPContent.CanvasSize = UDim2.new(0,0,0,y)
end

-- تعبئة تبويبة Aimbot
do
    local y = 10
    y = CreateToggle(AimbotContent, "Aimbot", 
        function() return Settings.Aimbot.Enabled end,
        function(v) Settings.Aimbot.Enabled = v end, y)
    y = CreateToggle(AimbotContent, "FOV Circle", 
        function() return Settings.Aimbot.ShowFOV end,
        function(v) 
            Settings.Aimbot.ShowFOV = v
            FOVCircle.Visible = v
        end, y)
    y = CreateInput(AimbotContent, "FOV:", 
        function() return Settings.Aimbot.FOV end,
        function(v) Settings.Aimbot.FOV = v end, y, 1, 360)
    y = CreateInput(AimbotContent, "Max Distance:", 
        function() return Settings.Aimbot.MaxDistance end,
        function(v) Settings.Aimbot.MaxDistance = v end, y, 1, 10000)
    y = CreateInput(AimbotContent, "Smooth Aim (1-100):", 
        function() return Settings.Aimbot.SmoothAim end,
        function(v) Settings.Aimbot.SmoothAim = v end, y, 1, 100)
    y = CreateToggle(AimbotContent, "Magic Aim", 
        function() return Settings.Aimbot.MagicAim end,
        function(v) Settings.Aimbot.MagicAim = v end, y)
    y = CreateToggle(AimbotContent, "Auto Fire", 
        function() return Settings.Aimbot.AutoFire end,
        function(v) Settings.Aimbot.AutoFire = v end, y)
    y = CreateToggle(AimbotContent, "Full Head", 
        function() return Settings.Aimbot.FullHead end,
        function(v) Settings.Aimbot.FullHead = v end, y)
    AimbotContent.CanvasSize = UDim2.new(0,0,0,y)
end

-- تعبئة تبويبة Combo
do
    local y = 10
    y = CreateToggle(ComboContent, "Infinite Jump", 
        function() return Settings.Combo.InfiniteJump.Enabled end,
        function(v) 
            Settings.Combo.InfiniteJump.Enabled = v
            if v then
                if not Settings.Combo.InfiniteJump.Connection then
                    Settings.Combo.InfiniteJump.Connection = UserInputService.JumpRequest:Connect(function()
                        if Settings.Combo.InfiniteJump.Enabled and LocalPlayer.Character then
                            local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if Humanoid then
                                Humanoid:ChangeState("Jumping")
                            end
                        end
                    end)
                end
            else
                if Settings.Combo.InfiniteJump.Connection then
                    Settings.Combo.InfiniteJump.Connection:Disconnect()
                    Settings.Combo.InfiniteJump.Connection = nil
                end
            end
        end, y)
    y = CreateToggle(ComboContent, "Speed", 
        function() return Settings.Combo.Speed.Enabled end,
        function(v) 
            Settings.Combo.Speed.Enabled = v
            if v and LocalPlayer.Character then
                local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if Humanoid then
                    Settings.Combo.Speed.OriginalSpeed = Humanoid.WalkSpeed
                end
            end
        end, y)
    y = CreateInput(ComboContent, "Speed Multiplier (1-6):", 
        function() return Settings.Combo.Speed.Multiplier end,
        function(v) Settings.Combo.Speed.Multiplier = v end, y, 1, 6)
    y = CreateToggle(ComboContent, "No Wall", 
        function() return Settings.Combo.NoWall end,
        function(v) Settings.Combo.NoWall = v end, y)
    ComboContent.CanvasSize = UDim2.new(0,0,0,y)
end

-- تطبيق تأثير Hover على الأزرار
local function ApplyHover(btn)
    local origSize = btn.Size
    local origColor = btn.BackgroundColor3
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {Size = origSize + UDim2.new(0,5,0,5), BackgroundColor3 = Color3.new(0.25,0.25,0.25)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {Size = origSize, BackgroundColor3 = origColor}):Play()
    end)
end

for _, obj in ipairs(MainFrame:GetDescendants()) do
    if obj:IsA("TextButton") and obj ~= MinimizeButton and obj ~= CloseButton then
        ApplyHover(obj)
    end
end
ApplyHover(MinimizeButton)
ApplyHover(CloseButton)

-- تبديل التبويبات (الآن 4 تبويبات)
local CurrentTab = "ESP"
local function SwitchTab(tab)
    CurrentTab = tab
    ESPContent.Visible = (tab == "ESP")
    AimbotContent.Visible = (tab == "Aimbot")
    ComboContent.Visible = (tab == "Combo")
    InfoContent.Visible = (tab == "Info")
    
    ESPTab.BackgroundColor3 = (tab == "ESP") and Color3.new(0.2,0.2,0.2) or Color3.new(0.15,0.15,0.15)
    AimbotTab.BackgroundColor3 = (tab == "Aimbot") and Color3.new(0.2,0.2,0.2) or Color3.new(0.15,0.15,0.15)
    ComboTab.BackgroundColor3 = (tab == "Combo") and Color3.new(0.2,0.2,0.2) or Color3.new(0.15,0.15,0.15)
    InfoTab.BackgroundColor3 = (tab == "Info") and Color3.new(0.2,0.2,0.2) or Color3.new(0.15,0.15,0.15)
end

ESPTab.MouseButton1Click:Connect(function() SwitchTab("ESP") end)
AimbotTab.MouseButton1Click:Connect(function() SwitchTab("Aimbot") end)
ComboTab.MouseButton1Click:Connect(function() SwitchTab("Combo") end)
InfoTab.MouseButton1Click:Connect(function() SwitchTab("Info") end)

-- زر التصغير
local Minimized = false
MinimizeButton.MouseButton1Click:Connect(function()
    Minimized = not Minimized
    TweenService:Create(MainFrame, TweenInfo.new(0.3), {
        Size = Minimized and UDim2.new(0,370,0,30) or UDim2.new(0,370,0,450)
    }):Play()
    TabsFrame.Visible = not Minimized
    ESPContent.Visible = not Minimized and CurrentTab=="ESP"
    AimbotContent.Visible = not Minimized and CurrentTab=="Aimbot"
    ComboContent.Visible = not Minimized and CurrentTab=="Combo"
    InfoContent.Visible = not Minimized and CurrentTab=="Info"
    MinimizeButton.Text = Minimized and "+" or "-"
end)

-- حلقة التحديث الرئيسية (مع إضافة تأثير الرينبو على نصوص My Information)
RunService.RenderStepped:Connect(function()
    -- تحديث دائرة FOV
    if Settings.Aimbot.ShowFOV and Camera then
        local Center = Camera.ViewportSize / 2
        FOVCircle.Position = Vector2.new(Center.X, Center.Y)
        FOVCircle.Radius = Settings.Aimbot.FOV * 5
    end
    
    -- تحديث ESP
    for Player, Drawings in pairs(ESP_Drawings) do
        pcall(function() UpdateESP(Player, Drawings) end)
    end
    
    -- تحديث سرعة المشي
    if LocalPlayer.Character then
        local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            if Settings.Combo.Speed.Enabled then
                local baseSpeed = Settings.Combo.Speed.OriginalSpeed or 16
                Humanoid.WalkSpeed = baseSpeed * Settings.Combo.Speed.Multiplier
            else
                if Settings.Combo.Speed.OriginalSpeed then
                    Humanoid.WalkSpeed = Settings.Combo.Speed.OriginalSpeed
                end
            end
        end
        
        -- No Wall
        if Settings.Combo.NoWall then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
    
    -- منطق Aimbot
    if Settings.Aimbot.Enabled and Camera then
        local BestTarget, BestAngle = FindBestTarget()
        
        if Settings.Aimbot.MagicAim and BestTarget then
            CurrentTarget = BestTarget
        else
            if BestTarget then
                if CurrentTarget and CurrentTarget ~= BestTarget then
                    if CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("Head") then
                        local Head = CurrentTarget.Character.Head
                        local Dir = (Head.Position - Camera.CFrame.Position).Unit
                        local CurAngle = math.deg(math.acos(Dir:Dot(Camera.CFrame.LookVector)))
                        local Dist = (Head.Position - Camera.CFrame.Position).Magnitude
                        if CurAngle <= Settings.Aimbot.FOV/2 and Dist <= Settings.Aimbot.MaxDistance then
                            BestTarget = CurrentTarget
                        else
                            CurrentTarget = BestTarget
                        end
                    else
                        CurrentTarget = BestTarget
                    end
                else
                    CurrentTarget = BestTarget
                end
            else
                CurrentTarget = nil
            end
        end
        
        if CurrentTarget and CurrentTarget.Character then
            local Head = CurrentTarget.Character:FindFirstChild("Head")
            if Head then
                local TargetCF = CFrame.lookAt(Camera.CFrame.Position, Head.Position)
                local Speed = Settings.Aimbot.MagicAim and 1 or (Settings.Aimbot.SmoothAim / 100)
                Camera.CFrame = Camera.CFrame:Lerp(TargetCF, Speed)
            end
        end
        
        -- Auto Fire
        if Settings.Aimbot.AutoFire and CurrentTarget and CurrentTarget.Character then
            local Head = CurrentTarget.Character:FindFirstChild("Head")
            if Head then
                local Dir = (Head.Position - Camera.CFrame.Position).Unit
                local Look = Camera.CFrame.LookVector
                local Angle = math.deg(math.acos(Dir:Dot(Look)))
                if Angle < 5 then
                    local Tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if Tool then
                        Tool:Activate()
                    else
                        VirtualUser:Button1Down(Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2))
                        wait(0.1)
                        VirtualUser:Button1Up(Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2))
                    end
                end
            end
        end
    else
        CurrentTarget = nil
    end
    
    -- تأثير الرينبو على نصوص My Information
    local hue = (tick() % 5) / 5  -- دورة كل 5 ثوانٍ
    for _, label in ipairs(InfoLabels) do
        label.TextColor3 = Color3.fromHSV(hue, 1, 1)
    end
end)

-- إضافة اللاعبين
Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer then CreateESP(plr) end
end)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then CreateESP(plr) end
end

-- إزالة اللاعبين
Players.PlayerRemoving:Connect(function(plr)
    if ESP_Drawings[plr] then
        for _, d in pairs(ESP_Drawings[plr]) do d:Remove() end
        ESP_Drawings[plr] = nil
    end
    if CurrentTarget == plr then CurrentTarget = nil end
end)

-- تحديث الكاميرا
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)
