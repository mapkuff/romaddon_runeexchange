

local db = {};

-- INTL
local intl = {};
local language = string.lower(GetLanguage())
local func, error = loadfile("Interface/AddOns/MRuneExchange/src/intl/"..language..".lua")
if error then
  func, error = loadfile("Interface/AddOns/MRuneExchange/src/intl/en.lua")
end
intl = func();
db.intl = intl;

-- Runes
db.runes = {
  -- T6
  Enigma =      {name = intl.RuneNames.Enigma, isBase = false, mats = {"Assassin", "Tyrant"}, tier=6},
  Judge =       {name = intl.RuneNames.Judge, isBase = false, mats = {"Sage", "Tyrant"}, tier=6},
  Massacre =    {name = intl.RuneNames.Massacre, isBase = false, mats = {"Assassin", "Sage"}, tier=6},
  -- T5
  Tyrant =      {name = intl.RuneNames.Tyrant, isBase = false, mats = {"Accuracy", "Raid"}, tier=5},
  Assassin =    {name = intl.RuneNames.Assassin, isBase = false, mats = {"Curse", "Raid"}, tier=5},
  Sage =        {name = intl.RuneNames.Sage, isBase = false, mats = {"Curse", "Accuracy"}, tier=5},
  -- T4
  Curse =       {name = intl.RuneNames.Curse, isBase = false, mats = {"Destruction", "Enchantment"}, tier=4},
  Raid =        {name = intl.RuneNames.Raid, isBase = false, mats = {"Dauntlessness", "Madness"}, tier=4},
  Accuracy =    {name = intl.RuneNames.Accuracy, isBase = false, mats = {"Dauntlessness", "Enchantment"}, tier=4},
  -- T3
  Destruction =     {name = intl.RuneNames.Destruction, isBase = false, mats = {"Grasp", "Capability"}, tier=3},
  Enchantment =     {name = intl.RuneNames.Enchantment, isBase = false, mats = {"Capability", "Keenness"}, tier=3},
  Dauntlessness =   {name = intl.RuneNames.Dauntlessness, isBase = false, mats = {"Capability", "Comprehension"}, tier=3},
  Madness =         {name = intl.RuneNames.Madness, isBase = false, mats = {"Comprehension", "Grasp"}, tier=3},
  -- T2
  Grasp =           {name = intl.RuneNames.Grasp, isBase = false, mats = {"WIS", "STR"}, tier=2},
  Capability =      {name = intl.RuneNames.Capability, isBase = false, mats = {"MP", "STA"}, tier=2},
  Keenness =        {name = intl.RuneNames.Keenness, isBase = false, mats = {"HP", "AGI"}, tier=2},
  Comprehension =   {name = intl.RuneNames.Comprehension, isBase = false, mats = {"HP", "INT"}, tier=2},
  Ferocity =        {name = intl.RuneNames.Ferocity, isBase = false, mats = {"STA", "HP"}, tier=2},
  -- BASE
  WIS =           {name = intl.RuneNames.WIS, isBase = true, mats = {}},
  STR =           {name = intl.RuneNames.STR, isBase = true, mats = {}},
  MP =           {name = intl.RuneNames.MP, isBase = true, mats = {}},
  STA =           {name = intl.RuneNames.STA, isBase = true, mats = {}},
  HP =           {name = intl.RuneNames.HP, isBase = true, mats = {}},
  AGI =           {name = intl.RuneNames.AGI, isBase = true, mats = {}},
  INT =           {name = intl.RuneNames.INT, isBase = true, mats = {}},
};

db.linkCaptions = intl.linkCaptions;

db.baseRuneMap = {
  WIS = 3,
  STR = 0,
  MP = 6,
  STA = 1,
  HP = 5,
  AGI = 4,
  INT = 2,
};

return db;
