CurrencySorter = {}

local ParentHeaders = {}

local function Storeheaders(data, lastheader)
	local SavedHeaders = CurrencySave.headers
	if data.currencyListDepth == 0 then
		if not SavedHeaders[data.name] then
			SavedHeaders[data.name] = {
				subheaders = {},
				numheaders = 0,
				order = {},
				pos = #CurrencySave.order + 1
			}
			CurrencySave.numheaders = CurrencySave.numheaders + 1
			tinsert(CurrencySave.order, data.name)
		end
	else
		ParentHeaders[data.name] = lastheader
		if not SavedHeaders[lastheader].subheaders[data.name] then
			SavedHeaders[lastheader].subheaders[data.name] = {
				pos = #SavedHeaders[lastheader].order + 1
			}
			tinsert(SavedHeaders[lastheader].order,data.name)
		end
	end
end


local function BuildList(numTokenTypes)
	if numTokenTypes == 0 then --in theory to a "loaded to early" check
		return --nope the way all our of here!
	end
	local lastheader
	local lastsubheader
	local headers = {}
	local currencyInfo = {}

	for i = 1,  numTokenTypes do
		local data =  C_CurrencyInfo.GetCurrencyListInfo(i)
		if data then
			data.currencyIndex = i
			if data.isHeader then
				Storeheaders(data, lastheader)
				if data.currencyListDepth == 0 then
					if lastheader then
						headers[lastheader].last = i-1
					end
					lastheader = data.name
					headers[data.name] = {
						start = i,
					}
					if lastsubheader then
						headers[lastsubheader].last = i-1
					end
					lastsubheader = nil
				elseif data.currencyListDepth == 1 then
					if lastsubheader then
						headers[lastsubheader].last = i-1
					end
					lastsubheader = data.name
					headers[data.name] = {
						start = i
					}
				end

			end
			currencyInfo[i] = data
		end
	end
	headers[lastheader].last = numTokenTypes
	if lastsubheader then 
		headers[lastsubheader].last =numTokenTypes
	end

	local modcurrencyInfo = {}
	for _,v in ipairs(CurrencySave.order) do
		if headers[v] then
			if headers[v].start ~= headers[v].last and #CurrencySave.headers[v].order ~= 0 then
				local Subhead = CurrencySave.headers[v].subheaders
				tinsert(modcurrencyInfo,currencyInfo[headers[v].start])
				for _, sh in ipairs(CurrencySave.headers[v].order) do
					for i = headers[sh].start, headers[sh].last do
						tinsert(modcurrencyInfo,currencyInfo[i])
					end
				end
			else
				for i = headers[v].start, headers[v].last do
					tinsert(modcurrencyInfo,currencyInfo[i])
				end
			end
		end
	end
	return modcurrencyInfo
end

local function CreateArrowButtons()
	for i, frame in pairs(TokenFrame.ScrollBox:GetFrames()) do
		if not(frame.SortUpArrow) then
			CreateFrame("Button", nil, frame ,"SortUpArrowTemplate", i)
			CreateFrame("Button", nil, frame ,"SortDownArrowTemplate", i)
			frame:HookScript("OnEnter", function (self)
				if self.elementData.isHeader then
					self.SortUpArrow:Show()
					self.SortDownArrow:Show()
				end
			end)
			frame:HookScript("OnLeave", function (self)
				self.SortUpArrow:Hide()
				self.SortDownArrow:Hide()
			end)
		end
	end
end

local function Mod_TokenFrame_Update(resetScrollPosition)
	local numTokenTypes = C_CurrencyInfo.GetCurrencyListSize();
	local newDataProvider = CreateDataProvider(BuildList(numTokenTypes));
	CharacterFrame.TokenFrame.ScrollBox:SetDataProvider(newDataProvider, not resetScrollPosition and ScrollBoxConstants.RetainScrollPosition);
	CreateArrowButtons()
end

function CurrencySorter.MoveUp(frame)
	local name = frame:GetParent().elementData.name
	local PH = ParentHeaders[name]
	if PH then
		local pos = CurrencySave.headers[PH].subheaders[name].pos
		if pos == 1 then return end
		local ParentHeader = CurrencySave.headers[PH]
		ParentHeader.subheaders[name].pos  = pos - 1
		tremove(ParentHeader.order,pos)
		tinsert(ParentHeader.order, pos - 1, name)
		ParentHeader.subheaders[ParentHeader.order[pos]].pos = pos
	else
		local pos = CurrencySave.headers[name].pos
		if pos == 1 then return end
		CurrencySave.headers[name].pos  = pos - 1
		tremove(CurrencySave.order,pos)
		tinsert(CurrencySave.order, pos - 1, name)
		CurrencySave.headers[CurrencySave.order[pos]].pos = pos
	end
	Mod_TokenFrame_Update()
end

function CurrencySorter.MoveDown(frame)
	local name = frame:GetParent().elementData.name
	local PH = ParentHeaders[name]
	if PH then
		local ParentHeader = CurrencySave.headers[PH]
		local pos = CurrencySave.headers[PH].subheaders[name].pos
		if pos == #ParentHeader.order then return end
		ParentHeader.subheaders[name].pos  = pos + 1
		tremove(ParentHeader.order,pos)
		tinsert(ParentHeader.order, pos + 1, name)
		ParentHeader.subheaders[ParentHeader.order[pos]].pos = pos
	else
		local pos = CurrencySave.headers[name].pos
		if pos == #CurrencySave.order then return end
		CurrencySave.headers[name].pos = pos + 1
		tremove(CurrencySave.order,pos)
		tinsert(CurrencySave.order, pos + 1, name)
		CurrencySave.headers[CurrencySave.order[pos]].pos = pos
	end
	Mod_TokenFrame_Update()
end

local function CreateResetButton()
	local Button = CreateFrame("Button","$parentRevertButton",TokenFrame)
	Button:SetHeight(22)
	Button:SetWidth(22)
	Button:SetPoint("RIGHT",TokenFrame.CurrencyTransferLogToggleButton,"LEFT",-5)
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
	CurrencySave = {headers = {}, numheaders = 0, order = {}}
	Mod_TokenFrame_Update()
	end	)
end





local eventFrame = CreateFrame("FRAME")

local function Load()
	hooksecurefunc(TokenFrame,"Update", Mod_TokenFrame_Update)
	CreateResetButton()
	eventFrame:UnregisterEvent("ADDON_LOADED")
end

eventFrame:SetScript("OnEvent", function(_,event, name)
	if event == "ADDON_LOADED" then
		if name =="CurrencySorter" then
			CurrencySave = CurrencySave or {headers = {}, numheaders = 0,order = {}}
			if C_AddOns.IsAddOnLoaded("Blizzard_TokenUI") then
				Load()
			end
		elseif name == "Blizzard_TokenUI" then
			Load()
		end
	end
end)
eventFrame:RegisterEvent("ADDON_LOADED")