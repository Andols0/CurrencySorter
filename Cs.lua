--Game Version 9.2.7, Version 9.2.7
Cs_order = {}

local IndexList = {}

local ListChanged = false

CurrencySorter = {}

local function GetIndex(Index)
	return IndexList[Index] or Index
end


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
	for i = 1, #Cs_order do
		--print(Cs_order[i].start, Cs_order[i].stop)
		for I = Cs_order[i].start, Cs_order[i].stop do
			IndexList[Pos] = I
			Pos = Pos + 1
		end
	end
end

local function Mod_TokenFrame_Update()
	local numTokenTypes = C_CurrencyInfo.GetCurrencyListSize();

	BuildList(numTokenTypes)

	if ( numTokenTypes == 0 ) then
		CharacterFrameTab3:Hide();
	else
		CharacterFrameTab3:Show();
	end

	if (not TokenFrameContainer.buttons) then
		return;
	end

	-- Setup the buttons
	local scrollFrame = TokenFrameContainer;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numButtons = #buttons;
	local name, isHeader, isExpanded, isUnused, isWatched, count, icon;
	local button, index;
	for i=1, numButtons do
		index = GetIndex(offset+i); --I wish i didn't have to copy the whole function only to transform the index.
		local currencyInfo = C_CurrencyInfo.GetCurrencyListInfo(index);
		button = buttons[i];
		button.check:Hide();
		if ( not currencyInfo or not currencyInfo.name or currencyInfo.name == "" ) then
			button:Hide();
		else
			name = currencyInfo.name;
			isHeader = currencyInfo.isHeader;
			isExpanded = currencyInfo.isHeaderExpanded;
			isUnused = currencyInfo.isTypeUnused;
			isWatched = currencyInfo.isShowInBackpack;
			count = currencyInfo.quantity;
			icon = currencyInfo.iconFileID;
			if ( isHeader ) then
				button.categoryLeft:Show();
				button.categoryRight:Show();
				button.categoryMiddle:Show();
				button.expandIcon:Show();
				button.count:SetText("");
				button.icon:SetTexture("");
				if ( isExpanded ) then
					button.expandIcon:SetTexCoord(0.5625, 1, 0, 0.4375);
				else
					button.expandIcon:SetTexCoord(0, 0.4375, 0, 0.4375);
				end
				button.highlight:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton");
				button.highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -2);
				button.highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 2);
				button.name:SetText(name);
				button.name:SetFontObject("GameFontNormal");
				button.name:SetPoint("LEFT", 22, 0);
				button.LinkButton:Hide();
			else
				button.categoryLeft:Hide();
				button.categoryRight:Hide();
				button.categoryMiddle:Hide();
				button.expandIcon:Hide();
				button.count:SetText(BreakUpLargeNumbers(count));
				button.icon:SetTexture(icon);
				if ( isWatched ) then
					button.check:Show();
				end
				button.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
				button.highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0);
				button.highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0);
				--Gray out the text if the count is 0
				if ( count == 0 ) then
					button.count:SetFontObject("GameFontDisable");
					button.name:SetFontObject("GameFontDisable");
				else
					button.count:SetFontObject("GameFontHighlight");
					button.name:SetFontObject("GameFontHighlight");
				end
				button.name:SetText(name);
				button.name:SetPoint("LEFT", 11, 0);
				button.LinkButton:Show();
			end
			--Manage highlight
			if ( name == TokenFrame.selectedToken ) then
				TokenFrame.selectedID = index;
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end

			button.index = index;
			button.isHeader = isHeader;
			button.isExpanded = isExpanded;
			button.isUnused = isUnused;
			button.isWatched = isWatched;
			button:Show();
		end
	end
	local totalHeight = numTokenTypes * (button:GetHeight()+TOKEN_BUTTON_OFFSET);
	local displayedHeight = #buttons * (button:GetHeight()+TOKEN_BUTTON_OFFSET);

	HybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight);
end

function CurrencySorter.MoveUp(frame)
	ListChanged = true
	--print("Up")
	for i = 1, #Cs_order do
		if Cs_order[i].name == frame:GetParent().name:GetText() and i ~= 1 then
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
		if Cs_order[i].name == frame:GetParent().name:GetText() and i ~= #Cs_order then
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
	for i = 1, #TokenFrameContainer.buttons do
		CreateFrame("Button", "$parentSortUp",_G["TokenFrameContainerButton"..i],"SortUpArrowTemplate",i)
		CreateFrame("Button", "$parentSortDown",_G["TokenFrameContainerButton"..i],"SortDownArrowTemplate",i)
		_G["TokenFrameContainerButton"..i]:HookScript("OnEnter", function (self)
			if self.isHeader then
				self.SortUpArrow:Show()
				self.SortDownArrow:Show()
			end
		end)
		_G["TokenFrameContainerButton"..i]:HookScript("OnLeave", function (self)
			self.SortUpArrow:Hide()
			self.SortDownArrow:Hide()
		end)
	end
	ButtonsCreated = true
end


local eventFrame = CreateFrame("FRAME")

local function Load()
	hooksecurefunc("TokenFrame_Update",Mod_TokenFrame_Update)
	hooksecurefunc(TokenFrameContainer,"update",Mod_TokenFrame_Update)
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