Cs_order = Cs_order or {}

local ListChanged = false

CurrencySorter = {}

local function Update_Cs_order(numTokenTypes,currencyInfo)
	--print("Update")
	local HeaderOrdering = {}
	local CurrentHead = currencyInfo[1].name --setting the first for logic reasons
	for i=1, #Cs_order do
		HeaderOrdering[Cs_order[i].name] = i
	end
	for i = 1, numTokenTypes do
		local name, isHeader = currencyInfo[i].name, currencyInfo[i].isHeader
		if isHeader then
			if CurrentHead ~= name then
				Cs_order[HeaderOrdering[CurrentHead]].stop = i - 1
				HeaderOrdering[CurrentHead] = nil
			end
			CurrentHead = name
			if not HeaderOrdering[CurrentHead] then --A new category appeared
				--print("New",CurrentHead)
				HeaderOrdering[CurrentHead] = #Cs_order + 1
			end
			Cs_order[HeaderOrdering[CurrentHead]] = {name = name, start = i}
		end
		if i == numTokenTypes then
			Cs_order[HeaderOrdering[CurrentHead]].stop = i
			HeaderOrdering[CurrentHead] = nil
		end
	end
	for _, v in pairs(HeaderOrdering) do
		--print("Removing",k,v)
		tremove(Cs_order,v)
	end
end

local function FirstTimeSetup(numTokenTypes)
	--print("Firsttime")
	local Cat = 1
	local Headers = 0
	for i = 1, numTokenTypes do
		local currencyInfo = C_CurrencyInfo.GetCurrencyListInfo(i)
		if currencyInfo.isHeader then
			Headers = Headers + 1
			if Cs_order[Cat] and not ( i == Cs_order[Cat].start) then
				Cs_order[Cat].stop = i - 1
				Cat = Cat + 1
			end
			local Category = {}
			Category.name = currencyInfo.name
			Category.start = i
			Cs_order[Cat] = Category
		end
		if i == numTokenTypes then
			Cs_order[Cat].stop = i
		end
	end
	Cs_order.Firsttime = true
	Cs_order.NumCat = Headers
	ListChanged = false
end


local function BuildList(numTokenTypes)
	if numTokenTypes == 0 then --in theory to a "loaded to early" check
		return --nope the way all our of here!
	end
	--print("Build")
	local Headers = 0
	local currencyInfo = {} --Lets keep an local cache when building the lists
	if not(Cs_order.Firsttime) then
		FirstTimeSetup(numTokenTypes)
	else
		for i = 1,  numTokenTypes do
			currencyInfo[i] = C_CurrencyInfo.GetCurrencyListInfo(i)
			if currencyInfo[i].isHeader then
				Headers = Headers + 1
			end
		end
		ListChanged = ListChanged or Cs_order.NumCat ~= Headers or Cs_order.Nummax ~= numTokenTypes
	end

	Cs_order.Nummax = numTokenTypes
	Cs_order.NumCat = Headers

	if ListChanged then
		Update_Cs_order(numTokenTypes,currencyInfo)
		ListChanged = false
	end

	local Pos = 1
	local IndexList = {}
	for i = 1, #Cs_order do
		--print(Cs_order[i].start, Cs_order[i].stop)
		for I = Cs_order[i].start, Cs_order[i].stop do
			IndexList[Pos] = {index = I}
			Pos = Pos + 1
		end
	end
	return IndexList
end
local function Mod_TokenFrame_Update(resetScrollPosition)
	local numTokenTypes = C_CurrencyInfo.GetCurrencyListSize();
	if CharacterFrameTab3:IsVisible() then
		local newDataProvider = CreateDataProvider(BuildList(numTokenTypes));
		CharacterFrame.TokenFrame.ScrollBox:SetDataProvider(newDataProvider, not resetScrollPosition and ScrollBoxConstants.RetainScrollPosition);
	end
end

function CurrencySorter.MoveUp(frame)
	ListChanged = true
	--print("Up")
	for i = 1, #Cs_order do
		if Cs_order[i].name == frame:GetParent().Name:GetText() and i ~= 1 then
			--print("Moving")
			local Temp = Cs_order[i]
			tremove(Cs_order,i)
			tinsert(Cs_order, i - 1, Temp)
			Mod_TokenFrame_Update()
			break
		end
	end
end

function CurrencySorter.MoveDown(frame)
	ListChanged = true
	--print("Down")
	for i = 1, #Cs_order do
		if Cs_order[i].name == frame:GetParent().Name:GetText() and i ~= #Cs_order then
			local Temp = Cs_order[i]
			tremove(Cs_order,i)
			tinsert(Cs_order, i + 1, Temp)
			Mod_TokenFrame_Update()
			break
		end
	end
end

local function CreateResetButton()
	local Button = CreateFrame("Button","$parentRevertButton",TokenFrame)
	Button:SetHeight(22)
	Button:SetWidth(22)
	Button:SetPoint("TOPRIGHT",TokenFrame,"TOPRIGHT",-8,-40)
	Button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
	Button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down");
	Button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled");
	Button:Show()
	Button:SetFrameStrata("HIGH")
	Button:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Button,"ANCHOR_RIGHT")
		GameTooltip:SetText("Reset to default sorting")
	end)
	Button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	Button:SetScript("OnClick", function()
	Cs_order={}
	Mod_TokenFrame_Update()
	end	)
end


local ButtonsCreated = false
local function CreateArrowButtons()

	if ButtonsCreated then return end
	for i, frame in pairs(TokenFrame.ScrollBox:GetFrames()) do
		CreateFrame("Button", nil, frame ,"SortUpArrowTemplate", i)
		CreateFrame("Button", nil, frame ,"SortDownArrowTemplate", i)
		frame:HookScript("OnEnter", function (self)
			if self.isHeader then
				self.SortUpArrow:Show()
				self.SortDownArrow:Show()
			end
		end)
		frame:HookScript("OnLeave", function (self)
			self.SortUpArrow:Hide()
			self.SortDownArrow:Hide()
		end)
	end
	ButtonsCreated = true
end


local eventFrame = CreateFrame("FRAME")

local function Load()
	hooksecurefunc("TokenFrame_Update", Mod_TokenFrame_Update)
	TokenFrame:HookScript("OnShow",CreateArrowButtons)
	CreateResetButton()
	eventFrame:UnregisterEvent("ADDON_LOADED")
end

eventFrame:SetScript("OnEvent", function(_,event, name)
	if event == "ADDON_LOADED" then
		if name =="CurrencySorter" then
			if IsAddOnLoaded("Blizzard_TokenUI") then
				Load()
			end
		elseif name == "Blizzard_TokenUI" then
			Load()
		end
	end
end)
eventFrame:RegisterEvent("ADDON_LOADED")