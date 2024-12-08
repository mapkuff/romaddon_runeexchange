
local RuneExchangeHelper = {}
_G.RuneExchangeHelper = RuneExchangeHelper

function RuneExchangeHelper.setupDropdown(dropdown, values, selectedIndex, width, onSelectScript)
    if not dropdown or not values then
        return
    end
    if not width then
        width = 120
    end
    if not selectedIndex then
        selectedIndex = 1
    end

    local selectFn = function(button)
        UIDropDownMenu_SetSelectedID(dropdown, button:GetID())
        if onSelectScript and type(onSelectScript) == "function" then
            onSelectScript(button)
        end
    end
    local onShowFn = function()
        for k, v in pairs(values) do
            UIDropDownMenu_AddButton({text = v.name, value = v.value, func = selectFn})
        end
    end

    UIDropDownMenu_SetWidth(dropdown, width)
    UIDropDownMenu_Initialize(dropdown, onShowFn)
    UIDropDownMenu_SetSelectedID(dropdown, selectedIndex)
end

function RuneExchangeHelper.mapkv(cols, mapFn)
  local result = {};
  for k, v in pairs(cols) do
    result[k] = mapFn(k, v);
  end
  return result;
end

function RuneExchangeHelper.keys(cols)
  local keyset={}
  local n=0
  for k,v in pairs(cols) do
    n=n+1
    keyset[n]=k
  end
  return keyset;
end

function RuneExchangeHelper.values(cols)
  local valueset={}
  local n=0
  for k,v in pairs(cols) do
    n=n+1
    valueset[n]=v
  end
  return valueset;
end

function RuneExchangeHelper.concatArray(col1, col2)
  local result = {};
  local n = 1;
  for k, v in pairs(col1) do
    result[n] = v;
    n = n + 1;
  end
  for k, v in pairs(col2) do
    result[n] = v;
    n = n + 1;
  end
  return result;
end

function RuneExchangeHelper.startsWith(str, start)
  return string.sub(str,1, string.len(start)) == start;
end

function RuneExchangeHelper.count(cols)
  local count = 0;
  for k, v in pairs(cols) do
    count = count + 1;
  end
  return count;
--   return #cols;
end

function RuneExchangeHelper.filterArray(cols, predFn)
  local n = 0;
  local result = {};
  for k, v in pairs(cols) do
    if predFn(k,v) then
      result[n] = v;
      n = n + 1;
    end
  end
  return result;
end

function RuneExchangeHelper.filterMap(maps, predFn)
  local result = {};
  for k, v in pairs(maps) do
    if predFn(k,v) then
      result[k] = v;
    end
  end
  return result;
end

function RuneExchangeHelper.reducekv(cols, acc, reduceFn)
  local result = acc;
  for k, v in pairs(cols) do
    result = reduceFn(result, k, v);
  end
  return result;
end

function RuneExchangeHelper.any(cols, predFn)
  for k, v in pairs(cols) do
    if predFn(k,v) then
      return true;
    end
  end
  return false;
end

function RuneExchangeHelper.take(cols, n)
  local result = {};
  local taken = 0;
  for k, v in pairs(cols) do
    if taken >= n then
      return result;
    end
    result[k] = v;
    taken = taken + 1;
  end
  return result;
end

function RuneExchangeHelper.zipkv(col1, col2, zipFn)
  local result = {};
  local size = RuneExchangeHelper.count(col1);
  for i=1, size do
    local k1, v1 = RuneExchangeHelper.nth(col1, i);
    local k2, v2 = RuneExchangeHelper.nth(col2, i);
    result[i] = zipFn(k1, v1, k2, v2);
  end
  return result;
end

function RuneExchangeHelper.window(cols, size)
  local result = {};
  local tmpResult = {};
  local n = 1;
  for _, v in pairs(cols) do
    tmpResult[n] = v;
    n = n + 1;
    if n > size then
      result = RuneExchangeHelper.addArrayElement(result, tmpResult);
      tmpResult = {};
      n = 1;
    end
  end
  if n > 1 then
    result = RuneExchangeHelper.addArrayElement(result, tmpResult);
  end
  return result;
end

function RuneExchangeHelper.flatten(cols)
  local result = {};
  local n = 1;
  for k, v in pairs(cols) do
    for k2, v2 in pairs(v) do
      result[n] = v2;
      n = n + 1;
    end
  end
  return result;
end

function RuneExchangeHelper.groupBy(cols, groupFn)
  local result = {};
  for k, v in pairs(cols) do
    local key = groupFn(k,v);
    if result[key] == nil then
      result[key] = {};
    end
    result[key] = RuneExchangeHelper.addArrayElement(result[key], v);
  end
  return result;
end

function RuneExchangeHelper.removeMap(cols, predFn)
  local result = {};
  for k, v in pairs(cols) do
    if predFn(k,v) == false then
      result[k] = v;
    end
  end
  return result;
end

function RuneExchangeHelper.addArrayElement(cols, elem)
  local result = {};
  local n = 1;
  for k, v in pairs(cols) do
    result[k] = v;
    n = n+1;
  end
  result[n] = elem;
  return result;
end

function RuneExchangeHelper.nth(cols, n)
  local i = 1;
  for k, v in pairs(cols) do
    if (i == n) then
      return k, v;
    end
    i = i + 1;
  end
  return nil, nil;
end

function RuneExchangeHelper.removeKey(cols, key)
  local result = {};
  for k, v in pairs(cols) do
    if k ~= key then
      result[k] = v;
    end
  end
  return result;
end

function RuneExchangeHelper.rest(cols)
  local result = {};
  local i = 0;
  for k,v in pairs(cols) do
    if i > 0 then
      result[i] = v;
    end
    i = i + 1;
  end
  return result;
end

function RuneExchangeHelper.range(start, stop)
  local result = {};
  local n = 1;
  for i=start, stop do
    result[n] = i;
    n = n + 1;
  end
  return result;
end

function RuneExchangeHelper.log(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg);
end
