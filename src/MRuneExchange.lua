local MRuneExchange = {}
_G.MRuneExchange = MRuneExchange

local func, error = loadfile("Interface/AddOns/MRuneExchange/src/db.lua")
local db = func();
local helper = _G.RuneExchangeHelper;
local state = {};
local elapsed = {0 , 0}
local tmpMakingRunes = nil;
local rescans = {}

function MRuneExchange.clearState()
  state = {
    tier = "V",
    equipmentIndex = {},
    bagRuneIndex = {},
    spaceIndex = {},
    targetRune = nil,
    requiredBaseRunes = {},
    started = false,
    waitingMagicBox = nil,
    step1 = 0,
    step2 = 1,
    speed = 0.3,
    recheckCount = 0,
  };
  MRuneExchange.ScanBag();
end

-- /run for i=1,3 do for j=_start,_max do _ii, _, _name,_icount=GetBagItemInfo(j); if _icount > 0 then PickupBagItem(_ii);RuneItemButton_OnClick(_G["RuneExchangeFrame_Button"..i], "x"); _start=j+1; break; end end end
-- /wait 0.1
-- /run RuneExchangeFrame_OK_OnClick();

--RuneExchangeOk( num );

function MRuneExchange.clearLog()
  -- CLean up log text
  for i=1,9 do
    _G["MRuneExchangeFrame_Log"..i.."1"]:SetText("");
    _G["MRuneExchangeFrame_Log"..i.."2"]:SetText("");
  end
end

function RuneExchangeHelper.getItemLinkInfo(name, quality, link)
  for n=1,11 do
    getglobal("MRuneExchange_InfoTooltipTextLeft" ..n):SetText("");
    getglobal("MRuneExchange_InfoTooltipTextRight"..n):SetText("");
  end;
  MRuneExchange_InfoTooltip:SetHyperLink(link);
  local itemInfo = {isEquipment = false, isRune = false, name = name, tier = nil, linkName = ""};
  for n=1,11 do
    local textLeft = getglobal("MRuneExchange_InfoTooltipTextLeft" ..n):GetText();
    local textRight = getglobal("MRuneExchange_InfoTooltipTextRight"..n):GetText();
    if n == 1 then
      itemInfo.linkName = textLeft;
    end
    if helper.startsWith(textLeft, db.linkCaptions.Tier) then
      local tier = string.sub(textLeft, string.len(db.linkCaptions.Tier) + 2);
      itemInfo.tier = tonumber(tier);
    end
    if textLeft == db.linkCaptions.Runes or textLeft == db.linkCaptions.WeaponRune then
      itemInfo.isRune = true;
    end
  end;
  if itemInfo.tier ~= nil and itemInfo.isRune == false and quality >= 2 then
    itemInfo.isEquipment = true;
  end
  if itemInfo.isRune and itemInfo.tier == nil then
    itemInfo.isRune = false;
  end
  return itemInfo;
end

function MRuneExchange.OnLoad(this)
  MRuneExchange.clearLog();
  MRuneExchange.clearState();

  local dropdownValues = helper.range(2,6);
  table.sort(dropdownValues, function(a,b) return a > b end);

  dropdownValues = helper.mapkv(
    dropdownValues,
    function(_, tier)

      local runes = helper.filterMap(db.runes, function(k,v) return v.tier == tier end);
      runes = helper.mapkv(runes, function(k,v) return {name = "T"..v.tier .. "-"..v.name, value = k} end);
      return runes;
    end
  );
  dropdownValues = helper.flatten(dropdownValues);
  local onClick = function(button)
    MRuneExchange.pcall(MRuneExchange.OnSelectTargetRune, button);
  end
  helper.setupDropdown(MRuneExchangeFrame_SelectRuneDropdown, dropdownValues, 1000, 120, onClick);
  MRuneExchangeFrame_StartButton:Disable();
  MRuneExchangeFrame_SpeedSlider:SetValueStepMode("FLOAT");
  MRuneExchangeFrame_SpeedSlider:SetMinMaxValues(0.1, 1);
  MRuneExchangeFrame_SpeedSlider:SetValue(state.speed);
  RuneExchangeFrame:Hide();
  --this:RegisterEvent("BAG_ITEM_UPDATE");
end

function MRuneExchange.OnEvent(this, event)
  if event == "BAG_ITEM_UPDATE" then
    MRuneExchange.ScanBag(arg1, arg1)
  end
end

function MRuneExchange.OnSelectTargetRune(button)
  MRuneExchange.ScanBag();
  MRuneExchange.clearState();
  state.targetRune = button.value;
  MRuneExchange.calcBaseRunes();
end


function MRuneExchange.ScanBag()
  helper.log("=======  Scanning bag ============");
  if RuneExchangeFrame:IsVisible() == false then
    return
  end
  state.equipmentIndex = {};
  state.bagRuneIndex = {};
  state.spaceIndex = {};
  for i= 1, 180 do
    local inventoryIndex, icon, name, itemCount, locked, quality = GetBagItemInfo (i)
    if itemCount == 0 then
      state.spaceIndex[inventoryIndex] = {inventoryIndex = inventoryIndex, bagIndex = i};
    end
    if itemCount >= 1 then
      local itemLink = GetBagItemLink(inventoryIndex);
      local itemInfo = helper.getItemLinkInfo(name, quality, itemLink);
      if itemInfo.isEquipment then
        state.equipmentIndex[inventoryIndex] = {inventoryIndex = inventoryIndex, bagIndex = i};
      end
      if itemInfo.isRune then
        state.bagRuneIndex[inventoryIndex] = {bagIndex=i, inventoryIndex=inventoryIndex, itemCount=itemCount, name=name};
      end
    end
  end
  local computedRunes = helper.groupBy(state.bagRuneIndex, function(k,v) return v.name end);
  computedRunes = helper.mapkv(
    computedRunes,
    function(k,v)
      return helper.reducekv(
        v,
        {
          name = k,
          totalCount = 0,
          items = {},
        },
        function(acc, k2, v2)
          acc.totalCount = acc.totalCount + v2.itemCount;
          acc.items = helper.addArrayElement(acc.items, v2);
          return acc;
        end
      );
    end
  );
  state.computedRunes = computedRunes;
  MRuneExchange.calcBaseRunes();
end

function MRuneExchange.calcBaseRunes()
  if RuneExchangeFrame:IsVisible() == false then
    return;
  end
  if state.targetRune == nil then
    return;
  end
  helper.log("[mRuneExchange] calculate base runes !!")
  MRuneExchange.clearLog();
  state.requiredBaseRunes = MRuneExchange.findRequiredRunes(db.runes[state.targetRune].mats, function(rune) return rune.isBase == true end);
  local numberOfItemRequired = 0;
  for k,v in pairs(state.requiredBaseRunes) do
    numberOfItemRequired = numberOfItemRequired + (v*3);
  end
  local numberOfNeededItems = numberOfItemRequired - helper.count(state.equipmentIndex);
  if (numberOfNeededItems < 0) then
    numberOfNeededItems = 0;
  end
  _G["MRuneExchangeFrame_Log11"]:SetText("Need items: " .. numberOfNeededItems);
  local n1 = 2;
  local n2 = 1;
  for k,v in pairs(state.requiredBaseRunes) do
    local txt = "need: " .. v .. "x " .. db.runes[k].name .. " " .. state.tier;
    _G["MRuneExchangeFrame_Log"..n1..n2]:SetText(txt);
    n2 = n2 + 1;
    if n2 == 3 then
      n1 = n1 + 1;
      n2 = 1;
    end
  end
end

function MRuneExchange.findRequiredRunes(runes, predFn)
  local magicBoxItems = {};
  for i=51,55 do
    local icon, name, itemCount = GetGoodsItemInfo(i);
    if name~="" or icon~="" then
      magicBoxItems[name] = itemCount;
    end
  end
  runes = helper.groupBy(runes, function(k,v) return v end);
  runes = helper.mapkv(runes, function(k,v) return helper.count(v) end);
  runes = helper.mapkv(
    runes,
    function(k,v)
      local runeName = db.runes[k].name .. " " .. state.tier;
      local foundInBag = (state.computedRunes[runeName] or {totalCount=0}).totalCount;
      local foundInMagicBox = magicBoxItems[runeName] or 0;
      local remainRequiredRune =  v - foundInBag - foundInMagicBox;
      --helper.log("runeName="..runeName..", foundInBag="..foundInBag..", foundInMagicBox="..foundInMagicBox..", remainRequiredRune="..remainRequiredRune);
      if remainRequiredRune < 0 then
        return 0;
      end
      return remainRequiredRune;
    end
  );
   runes = helper.filterMap(
     runes,
     function(k,v)
       return v > 0
     end
   );
  runes = helper.mapkv(
    runes,
    function(k,v)
      local result = {};
      for i=1,v do
        result = helper.addArrayElement(result, k);
      end
      return result;
    end
  );
  runes = helper.flatten(runes);
  if helper.any(runes, function(k,v) return predFn(db.runes[v]) == false end) then
    runes = helper.mapkv(runes, function(k,v) return db.runes[v].mats end);
    runes = helper.flatten(runes);
    return MRuneExchange.findRequiredRunes(runes, predFn);
  end

  runes = helper.groupBy(runes, function(k,v) return v end);
  runes = helper.mapkv(runes, function(k,v) return helper.count(v) end);
  return runes;
end

function MRuneExchange.clearMagicBox()
  helper.log("==========================")
  for i=51,55 do
    local icon,name=GetGoodsItemInfo(i);
    if name~="" or icon~="" then
      local link = GetBagItemLink(i)
      local itemInfo = helper.getItemLinkInfo("magic"..i, 0, link);
      helper.log(itemInfo.linkName);
      if itemInfo.isRune and state.computedRunes[itemInfo.linkName] ~= nil then
        local _, target = helper.nth(state.computedRunes[itemInfo.linkName].inventoryIndexes, 1);
        PickupBagItem(i);
        PickupBagItem(target.inventoryIndex);
        rescans[target.bagIndex] = 1;
        return false;
      end
      local _, target = helper.nth(state.spaceIndex, 1);
      PickupBagItem(i);
      PickupBagItem(target.inventoryIndex);
      rescans[target.bagIndex] = 1;
      return false;
    end
  end
  return true;
end

function MRuneExchange.clearCursor()
  if CursorHasItem() then
    local _, _i = helper.nth(state.spaceIndex, 1);
    if _i ~= nil then
      PickupBagItem(_i.inventoryIndex);
    end
  end
end
function MRuneExchange.pcallOnUpdate(_elapsedTime)
  local status, err = pcall(MRuneExchange.OnUpdate, _elapsedTime);
  if status == false then
    state.started = false;
    helper.log("Error: " .. err);
    error(err);
  end
end
function MRuneExchange.pcall(arg0, arg1, arg2, arg3, arg4)
  local status, err = true, null;
  if arg0 == MRuneExchange.OnLoad then
    status, err = pcall(MRuneExchange.OnLoad, arg1)
  end
  if arg0 == MRuneExchange.OnEvent then
    status, err = pcall(MRuneExchange.OnEvent, arg1)
  end
  if arg0 == MRuneExchange.OnUpdate then
    status, err = pcall(MRuneExchange.OnUpdate, arg1)
  end
  if arg0 == MRuneExchange.ScanBag then
    status, err = pcall(MRuneExchange.ScanBag)
  end
  if arg0 == MRuneExchange.OnSelectTargetRune then
    status, err = pcall(MRuneExchange.OnSelectTargetRune, arg1)
  end
  if status == false then
    state.started = false;
    helper.log("Error: " .. err);
    error(err);
  end
end

local effects = {};
local makingEffect = false;
local finalEffect = false;

function MRuneExchange.HandleEffect()
  MRuneExchange.clearCursor();
  local _, targetEffect = helper.nth(effects, 1);
  effects = helper.rest(effects);

  if targetEffect.action == "MAKE_BASE_RUNE" then
    local index1 = GetBagItemInfo(targetEffect.item1);
    local index2 = GetBagItemInfo(targetEffect.item2);
    local index3 = GetBagItemInfo(targetEffect.item3);
    PickupBagItem(index1);
    RuneItemButton_OnClick(_G["RuneExchangeFrame_Button1"], "x");
    PickupBagItem(index2);
    RuneItemButton_OnClick(_G["RuneExchangeFrame_Button2"], "x");
    PickupBagItem(index3);
    RuneItemButton_OnClick(_G["RuneExchangeFrame_Button3"], "x");
    RuneExchangeOk( db.baseRuneMap[targetEffect.rune] );
    return;
  end
  if targetEffect.action == "MERGE_RUNE" then
    local sourceIndex = GetBagItemInfo(targetEffect.source);
    local destIndex = GetBagItemInfo(targetEffect.dest);
    PickupBagItem(sourceIndex);
    PickupBagItem(destIndex);
    return;
  end
  if targetEffect.action == "MOVE_ITEM_TO_MAGIC_BOX" then
    local sourceIndex = GetBagItemInfo(targetEffect.source);
    PickupBagItem(sourceIndex);
    PickupBagItem(targetEffect.dest);
    return;
  end
  if targetEffect.action == "SPLIT_ITEM" then
    local sourceIndex = GetBagItemInfo(targetEffect.source);
    local destIndex = GetBagItemInfo(targetEffect.dest);
    SplitBagItem(sourceIndex, targetEffect.amount);
    PickupBagItem(destIndex);
    return;
  end
  if targetEffect.action == "MAGIC_BOX_COMBINE_ITEM" then
    MagicBoxRequest();
    return;
  end
  if targetEffect.action == "TAKE_ITEM_FROM_MAGIC_BOX" then
    local icon, name, itemCount = GetGoodsItemInfo(targetEffect.source);
    if not (name~="" or icon~="") then
      state.waitingMagicBox = targetEffect.source;
      effects = helper.concatArray({targetEffect}, effects);
      return;
    end
    local destIndex = GetBagItemInfo(targetEffect.dest);
    PickupBagItem(targetEffect.source);
    PickupBagItem(destIndex);
    return;
  end
  if targetEffect.action == "RESCAN_BAG" then
    MRuneExchange.ScanBag();
    return;
  end

  error("Unknown effect: " .. targetEffect.action);
end

function MRuneExchange.OnUpdate(_elapsedTime)
  elapsed[1] = elapsed[1] + _elapsedTime;
  elapsed[2] = elapsed[2] + _elapsedTime;

  if elapsed[1] > 1 then
    -- UI Stuff
    elapsed[1] = 0;
    MRuneExchange.validate();
    local speed = MRuneExchangeFrame_SpeedSlider:GetValue();
    state.speed = speed;
  end
  --
  if elapsed[2] > state.speed and state.started == true then
    elapsed[2] = 0;
    if MagicBoxFrame.sw==false then
      MagicBoxFrame_SwitchBox(MagicBoxFramePureButton)
      return;
    end
    if state.waitingMagicBox ~= nil then
      local icon, name, itemCount = GetGoodsItemInfo(state.waitingMagicBox);
      if not (name~="" or icon~="") then
        helper.log("[mRuneExchange] Waiting for magic box");
        return;
      end
      state.waitingMagicBox = nil;
      return;
    end
    if helper.count(effects) > 0 then
      helper.log("[mRuneExchange] Handling effect");
      MRuneExchange.HandleEffect()
      return;
    end
    --if makingEffect == true then
    --  helper.log("[mRuneExchange] Queing creating effect");
    --  return;
    --end

    helper.log("[mRuneExchange] Making Effect");
    makingEffect = true;
    MRuneExchange.ScanBag();

    if state.freshStarted then
      state.freshStarted = false;
      local newEffects = {};
      local spaceUsed = 0;
      for i=51,55 do
        local icon, name, itemCount = GetGoodsItemInfo(i);
        if name~="" or icon~="" then
          if spaceUsed > helper.count(state.spaceIndex) then
            state.started = false;
            helper.log("[mRuneExchange] Not enough space");
            return;
          end
          local _, targetSpace = helper.nth(state.spaceIndex, spaceUsed + 1);
          spaceUsed = spaceUsed + 1;
          newEffects = helper.addArrayElement(newEffects, { action = "TAKE_ITEM_FROM_MAGIC_BOX", source = i, dest = targetSpace.bagIndex });
        end
      end
      if helper.count(newEffects) > 0 then
        effects = newEffects;
        makingEffect = false;
        return;
      end
    end

    if finalEffect then
      state.started = false;
      finalEffect = false;
      return;
    end

    if helper.count(state.requiredBaseRunes) > 0 and helper.count(state.equipmentIndex) >= 3 then
      helper.log("[mRuneExchange] Making base rune effect");
      local amountOfItemRequired = helper.reducekv(
        helper.mapkv(state.requiredBaseRunes, function(k,v) return v*3  end),
        0,
        function(acc, k, v) return acc + v  end
      )
      local runes = helper.mapkv(
        state.requiredBaseRunes,
        function(k,v)
          result = {};
          for i=1,v do
            result[i] = k;
          end
          return result;
        end
      )
      runes = helper.flatten(runes);
      helper.log("[mRuneExchange] amountOfItemRequired="..amountOfItemRequired);
      local baseRuneEffects = helper.mapkv(state.equipmentIndex, function(k, v) return v.bagIndex  end)
      baseRuneEffects = helper.take(baseRuneEffects, amountOfItemRequired)
      baseRuneEffects = helper.window(baseRuneEffects, 3);
      baseRuneEffects = helper.filterArray(baseRuneEffects, function(k,v) return helper.count(v) == 3 end);
      baseRuneEffects = helper.mapkv(baseRuneEffects, function(k,v) return { action = "MAKE_BASE_RUNE", item1 = v[1], item2 = v[2], item3 = v[3] } end)
      baseRuneEffects = helper.zipkv(baseRuneEffects, runes, function(k1,v1, k2, v2) v1.rune = v2; return v1; end);
      baseRuneEffects = helper.addArrayElement(baseRuneEffects, { action = "RESCAN_BAG" });
      effects = baseRuneEffects;
      makingEffect = false;
      return;
    end
    if helper.count(state.requiredBaseRunes) > 0 and helper.count(state.equipmentIndex) < 3 then
      helper.log("[mRuneExchange] Not enough equipment items");
      state.started = false;
      makingEffect = false;
    end
    if helper.any(state.computedRunes, function(k,v) return helper.count(v.items) > 1 end) then
      helper.log("[mRuneExchange] making Merging runes effect");
      local newEffects = helper.filterMap(state.computedRunes, function(k,v) return helper.count(v.items) > 1 end);
      newEffects = helper.mapkv(
        newEffects,
        function(k,v)
          local result = {}
          local items = helper.values(v.items);
          for i=2, helper.count(items) do
            result = helper.addArrayElement(result, {
              action = "MERGE_RUNE",
              dest = items[1].bagIndex,
              source = items[i].bagIndex
            });
          end
          return result;
        end
      );
      newEffects = helper.values(newEffects);
      newEffects = helper.flatten(newEffects);
      newEffects = helper.addArrayElement(newEffects, { action = "RESCAN_BAG" });
      effects = newEffects;
      makingEffect = false;
      return;
    end

    for targetRuneTier=2,7 do
      if targetRuneTier > db.runes[state.targetRune].tier then
        helper.log("[mRuneExchange] Completed !!");
        makingEffect = false;
        state.started = false;
      end
      local requireRunes = {};
      if targetRuneTier == db.runes[state.targetRune].tier then
        requireRunes[state.targetRune] = 1;
        finalEffect = true;
      end
      if targetRuneTier < db.runes[state.targetRune].tier then
        requireRunes = MRuneExchange.findRequiredRunes(db.runes[state.targetRune].mats, function(rune) return rune.tier == targetRuneTier end);
      end
      if helper.count(requireRunes) > 0 then
        local spaceCount = helper.count(state.spaceIndex);
        if (spaceCount == 0) then
          helper.log("[mRuneExchange] Not enough space");
          state.started = false;
          makingEffect = false;
          return;
        end
        helper.log("[mRuneExchange] Making runes combination effect");
        local newEffects = helper.mapkv(requireRunes, function(k,v) return { rune = k, amount = v } end);
        newEffects = helper.values(newEffects);
        newEffects = helper.mapkv(
          newEffects,
          function(k,v)
            local result = {};
            local runeMat1 = db.runes[v.rune].mats[1];
            local runeMat1Name = db.runes[runeMat1].name .. " " .. state.tier;
            local runeMat2 = db.runes[v.rune].mats[2];
            local runeMat2Name = db.runes[runeMat2].name .. " " .. state.tier;
            if (state.computedRunes[runeMat1Name] == nil or state.computedRunes[runeMat2Name] == nil) then
              helper.log("[mRuneExchange] not enough materials, return empty effect");
              return {};
            end
            state.computedRunes[runeMat1Name].remainingAmount = state.computedRunes[runeMat1Name].remainingAmount or state.computedRunes[runeMat1Name].totalCount;
            state.computedRunes[runeMat2Name].remainingAmount = state.computedRunes[runeMat2Name].remainingAmount or state.computedRunes[runeMat2Name].totalCount;
            if k > spaceCount then
              helper.log("[mRuneExchange] not enough space, return empty effect");
              return {};
            end
            local _, targetSpace = helper.nth(state.spaceIndex, k);
            -- MAT 1
            if state.computedRunes[runeMat1Name].remainingAmount < v.amount then
              error("[mRuneExchange][Error] remaining amount of mat1 is less than acmount")
            end
            if state.computedRunes[runeMat1Name].remainingAmount == v.amount then
              local items = helper.values(state.computedRunes[runeMat1Name].items);
              result = helper.addArrayElement(result, { action = "MOVE_ITEM_TO_MAGIC_BOX", source = items[1].bagIndex, dest = 51 });
            end
            if state.computedRunes[runeMat1Name].remainingAmount > v.amount then
              local items = helper.values(state.computedRunes[runeMat1Name].items);
              result = helper.addArrayElement(result, { action = "SPLIT_ITEM", amount = v.amount, source = items[1].bagIndex, dest = targetSpace.bagIndex });
              result = helper.addArrayElement(result, { action = "MOVE_ITEM_TO_MAGIC_BOX", source = targetSpace.bagIndex, dest = 51 });
            end
            state.computedRunes[runeMat1Name].remainingAmount = state.computedRunes[runeMat1Name].remainingAmount - v.amount;
            -- MAT 2
            if state.computedRunes[runeMat2Name].remainingAmount < v.amount then
              error("[mRuneExchange][Error] remaining amount of mat2 is less than acmount")
            end
            if state.computedRunes[runeMat2Name].remainingAmount == v.amount then
              local items = helper.values(state.computedRunes[runeMat2Name].items);
              result = helper.addArrayElement(result, { action = "MOVE_ITEM_TO_MAGIC_BOX", source = items[1].bagIndex, dest = 52 });
            end
            if state.computedRunes[runeMat2Name].remainingAmount > v.amount then
              local items = helper.values(state.computedRunes[runeMat2Name].items);
              result = helper.addArrayElement(result, { action = "SPLIT_ITEM", amount = v.amount, source = items[1].bagIndex, dest = targetSpace.bagIndex });
              result = helper.addArrayElement(result, { action = "MOVE_ITEM_TO_MAGIC_BOX", source = targetSpace.bagIndex, dest = 52 });
            end
            state.computedRunes[runeMat2Name].remainingAmount = state.computedRunes[runeMat2Name].remainingAmount - v.amount;

            result = helper.addArrayElement(result, { action = "MAGIC_BOX_COMBINE_ITEM" });
            result = helper.addArrayElement(result, { action = "TAKE_ITEM_FROM_MAGIC_BOX", source = 51, dest = targetSpace.bagIndex });
            return result;
          end
        );
        newEffects = helper.flatten(newEffects);
        newEffects = helper.addArrayElement(newEffects, { action = "RESCAN_BAG" });
        effects = newEffects;
        makingEffect = false;
        return;
      end
    end
  end
end





function MRuneExchange.validate()
  if MagicBoxFrame:IsVisible() == false then
    state.started = false;
    MRuneExchangeFrame_StatusText:SetText("Please open Magic Box");
    MRuneExchangeFrame_StartButton:Disable();
    return;
  end
  if helper.count(state.equipmentIndex) < 3 and helper.count(state.requiredBaseRunes) > 0 then
    MRuneExchangeFrame_StatusText:SetText("Not enough equipment items");
    MRuneExchangeFrame_StartButton:Disable();
    return;
  end
  if state.targetRune == nil then
    state.started = false;
    MRuneExchangeFrame_StatusText:SetText("Please select rune");
    MRuneExchangeFrame_StartButton:Disable();
    return;
  end

  if state.started == true then
    MRuneExchangeFrame_StatusText:SetText("Started !!");
    MRuneExchangeFrame_StartButton:Disable();
    return;
  end
  MRuneExchangeFrame_StatusText:SetText("Ready");
  MRuneExchangeFrame_StartButton:Enable();
end

function MRuneExchange.startExchange()
  --MRuneExchange.ScanBag();
  state.freshStarted = true;
  state.makingEffect = false;
  state.started = true;
end
