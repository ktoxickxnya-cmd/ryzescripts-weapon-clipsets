local lastWeaponHash, currentSet = nil, nil
local pausedForAimShoot = false
local lastActionTime = 0
local lastDesiredSet = nil

local WEAPON_UNARMED = GetHashKey('WEAPON_UNARMED')
local INPUT_AIM    = 25 -- Right mouse / LT
local INPUT_ATTACK = 24 -- Left mouse  / RT
local REAPPLY_DELAY_MS = 280 -- cooldown after last aim/shoot/reload

-- ===============================
-- Group constants and resolvers
-- ===============================
local GROUP_HASH = {
  PISTOL   = 416676503,
  SMG      = 970310034,
  RIFLE    = 1159398588,
  MG       = 860033945,
  SHOTGUN  = -1212426201,
  SNIPER   = -1569042529,
  HEAVY    = -1609580060,
  THROWN   = 1548507267,
  MELEE    = 2725924767,
}

local function groupNameToHash(name)
  return name and GROUP_HASH[string.upper(name)] or nil
end

local function resolveWeaponHash(key)
  if type(key) == 'number' then return key end
  if type(key) == 'string' then return GetHashKey(string.upper(key)) end
  return nil
end

-- =========================================
-- Built-in vanilla weapon fallback by group
-- (If native group lookup fails/odd, use this)
-- =========================================
local VANILLA_WEAPONS = {
  PISTOL = {
    "WEAPON_PISTOL","WEAPON_COMBATPISTOL","WEAPON_APPISTOL","WEAPON_PISTOL50",
    "WEAPON_SNSPISTOL","WEAPON_HEAVYPISTOL","WEAPON_VINTAGEPISTOL",
    "WEAPON_MARKSMANPISTOL","WEAPON_REVOLVER","WEAPON_DOUBLEACTION",
    "WEAPON_PISTOL_MK2","WEAPON_SNSPISTOL_MK2","WEAPON_REVOLVER_MK2",
    "WEAPON_CERAMICPISTOL","WEAPON_NAVYREVOLVER","WEAPON_GADGETPISTOL",
    "WEAPON_PISTOLXM3"
  },
  SMG = {
    "WEAPON_MICROSMG","WEAPON_SMG","WEAPON_ASSAULTSMG","WEAPON_COMBATPDW",
    "WEAPON_MACHINEPISTOL","WEAPON_MINISMG","WEAPON_SMG_MK2"
  },
  RIFLE = {
    "WEAPON_ASSAULTRIFLE","WEAPON_CARBINERIFLE","WEAPON_ADVANCEDRIFLE",
    "WEAPON_SPECIALCARBINE","WEAPON_BULLPUPRIFLE","WEAPON_COMPACTRIFLE",
    "WEAPON_ASSAULTRIFLE_MK2","WEAPON_CARBINERIFLE_MK2","WEAPON_SPECIALCARBINE_MK2",
    "WEAPON_BULLPUPRIFLE_MK2","WEAPON_MILITARYRIFLE","WEAPON_TACTICALRIFLE",
    "WEAPON_HEAVYRIFLE"
  },
  MG = {
    "WEAPON_MG","WEAPON_COMBATMG","WEAPON_COMBATMG_MK2","WEAPON_GUSENBERG"
  },
  SHOTGUN = {
    "WEAPON_PUMPSHOTGUN","WEAPON_SAWNOFFSHOTGUN","WEAPON_BULLPUPSHOTGUN",
    "WEAPON_ASSAULTSHOTGUN","WEAPON_HEAVYSHOTGUN","WEAPON_MUSKET",
    "WEAPON_DBSHOTGUN","WEAPON_AUTOSHOTGUN","WEAPON_PUMPSHOTGUN_MK2",
    "WEAPON_COMBATSHOTGUN"
  },
  SNIPER = {
    "WEAPON_SNIPERRIFLE","WEAPON_HEAVYSNIPER","WEAPON_HEAVYSNIPER_MK2",
    "WEAPON_MARKSMANRIFLE","WEAPON_MARKSMANRIFLE_MK2","WEAPON_PRECISIONRIFLE"
  },
  HEAVY = {
    "WEAPON_RPG","WEAPON_GRENADELAUNCHER","WEAPON_HOMINGLAUNCHER",
    "WEAPON_MINIGUN","WEAPON_FIREWORK","WEAPON_RAILGUN","WEAPON_COMPACTLAUNCHER",
    "WEAPON_RAYMINIGUN","WEAPON_RAILGUNXM3"
  },
  THROWN = {
    "WEAPON_GRENADE","WEAPON_STICKYBOMB","WEAPON_PROXMINE","WEAPON_SMOKEGRENADE",
    "WEAPON_MOLOTOV","WEAPON_PIPEBOMB","WEAPON_SNOWBALL","WEAPON_FLARE","WEAPON_BALL"
  },
  MELEE = {
    "WEAPON_KNIFE","WEAPON_NIGHTSTICK","WEAPON_HAMMER","WEAPON_BAT","WEAPON_CROWBAR",
    "WEAPON_GOLFCLUB","WEAPON_BOTTLE","WEAPON_DAGGER","WEAPON_HATCHET","WEAPON_MACHETE",
    "WEAPON_SWITCHBLADE","WEAPON_BATTLEAXE","WEAPON_POOLCUE","WEAPON_WRENCH",
    "WEAPON_KNUCKLE","WEAPON_FLASHLIGHT","WEAPON_STONE_HATCHET"
  }
}

-- Precompute: name->hash and hash->group-hash
local WEAPON_GROUP_BY_HASH = {}
do
  for gname, list in pairs(VANILLA_WEAPONS) do
    local ghash = groupNameToHash(gname)
    if ghash then
      for _, wname in ipairs(list) do
        local wh = GetHashKey(wname)
        WEAPON_GROUP_BY_HASH[wh] = ghash
      end
    end
  end
end

-- ===============================
-- Resolve GroupMap (string -> hash)
-- ===============================
local RESOLVED_GROUP_MAP = {}
do
  for k, v in pairs(Config.GroupMap or {}) do
    if type(k) == "number" then
      RESOLVED_GROUP_MAP[k] = v
    elseif type(k) == "string" then
      local gh = groupNameToHash(k)
      if gh then RESOLVED_GROUP_MAP[gh] = v end
    end
  end
end

-- ===============================
-- Name-based custom overrides (from CONFIG)  <<< ADDED
-- ===============================
-- Uses names from Config.CustomWeaponNameOverrides and resolves them to hashes once.
local RESOLVED_NAME_OVERRIDES = {}
do
  local src = Config.CustomWeaponNameOverrides
  if type(src) == 'table' then
    for name, key in pairs(src) do
      if type(name) == 'string' and type(key) == 'string' then
        RESOLVED_NAME_OVERRIDES[GetHashKey(string.upper(name))] = key
      end
    end
  end
end

-- ===============================
-- Helpers
-- ===============================
local function requestAnySet(name)
  if not name or name == '' then return false end
  if HasClipSetLoaded(name) or HasAnimSetLoaded(name) then return true end
  RequestClipSet(name); RequestAnimSet(name)
  local t = GetGameTimer() + 3000
  while GetGameTimer() < t do
    if HasClipSetLoaded(name) or HasAnimSetLoaded(name) then return true end
    Wait(0)
  end
  return (HasClipSetLoaded(name) or HasAnimSetLoaded(name))
end

local function hardReset(ped)
  ResetPedWeaponMovementClipset(ped)
  ResetPedStrafeClipset(ped)
  currentSet = nil
end

local function applySet(ped, setName)
  if not setName or setName == '' then return end
  if currentSet == setName then return end
  if not requestAnySet(setName) then return end
  SetPedWeaponMovementClipset(ped, setName)
  if Config.ApplyStrafeClipset then
    SetPedStrafeClipset(ped, setName)
  end
  currentSet = setName
end

local function isAimingNow()
  return IsPlayerFreeAiming(PlayerId()) or IsAimCamActive() or IsControlPressed(0, INPUT_AIM)
end

local function pauseSet(ped)
  if currentSet then
    ResetPedWeaponMovementClipset(ped)
    ResetPedStrafeClipset(ped)
    currentSet = nil
  end
  pausedForAimShoot = true
  lastActionTime = GetGameTimer()
end

local function resumeSetIfReady(ped)
  if not pausedForAimShoot then return end
  if isAimingNow() then
    lastActionTime = GetGameTimer()
    return
  end
  if (GetGameTimer() - lastActionTime) >= REAPPLY_DELAY_MS and lastDesiredSet and lastDesiredSet ~= '' then
    pausedForAimShoot = false
    applySet(ped, lastDesiredSet)
  end
end

-- Core: decide which set to use
local function getDesiredSet(weaponHash)
  if not weaponHash or weaponHash == 0 or weaponHash == WEAPON_UNARMED then return nil end

  -- 0) Name-based overrides from config (wins first)  <<< ADDED
  local nameKey = RESOLVED_NAME_OVERRIDES[weaponHash]
  if nameKey then
    return (Config.Clipsets or {})[nameKey]
  end

  -- 1) Per-weapon override (if you use it)
  for k, key in pairs(Config.WeaponOverrides or {}) do
    local h = resolveWeaponHash(k)
    if h and h == weaponHash then
      return (Config.Clipsets or {})[key]
    end
  end

  -- 2) Native group
  local nativeGrp = GetWeapontypeGroup(weaponHash)
  local key = RESOLVED_GROUP_MAP[nativeGrp]
  if key then
    return (Config.Clipsets or {})[key]
  end

  -- 3) Fallback: known vanilla mapping table
  local fallbackGrp = WEAPON_GROUP_BY_HASH[weaponHash]
  if fallbackGrp then
    local fkey = RESOLVED_GROUP_MAP[fallbackGrp]
    if fkey then
      return (Config.Clipsets or {})[fkey]
    end
  end

  -- 4) Unmapped => no set
  return nil
end

-- ===============================
-- Main loop
-- ===============================
CreateThread(function()
  while true do
    Wait(Config.PollInterval or 100)

    local ped = PlayerPedId()
    if not ped or ped == 0 then goto continue end

    if IsEntityDead(ped) then
      hardReset(ped); pausedForAimShoot = false; lastDesiredSet = nil; lastWeaponHash = nil
      goto continue
    end

    local _, weaponHash = GetCurrentPedWeapon(ped, true)
    local armedOk = (weaponHash and weaponHash ~= 0 and weaponHash ~= WEAPON_UNARMED)

    local aiming    = armedOk and isAimingNow()
    local shooting  = armedOk and (IsPedShooting(ped) or IsControlPressed(0, INPUT_ATTACK))
    local reloading = armedOk and IsPedReloading(ped)
    local mustPause = (aiming or shooting or reloading)

    if mustPause then
      pauseSet(ped)
    else
      if armedOk then
        local desired = getDesiredSet(weaponHash)
        lastDesiredSet = desired
        if pausedForAimShoot then
          resumeSetIfReady(ped)
        else
          if desired and desired ~= '' then
            if currentSet ~= desired then applySet(ped, desired) end
          elseif currentSet then
            hardReset(ped)
          end
        end
      else
        if currentSet then hardReset(ped) end
        pausedForAimShoot = false
        lastDesiredSet = nil
      end
    end

    -- weapon swap (don’t reapply while ADS)
    if weaponHash ~= lastWeaponHash then
      lastWeaponHash = weaponHash
      pausedForAimShoot = false
      lastDesiredSet = getDesiredSet(weaponHash)
      if armedOk and not isAimingNow() then
        if lastDesiredSet and lastDesiredSet ~= '' then
          applySet(ped, lastDesiredSet)
        elseif currentSet then
          hardReset(ped)
        end
      end
    end

    ::continue::
  end
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then
    hardReset(PlayerPedId())
  end
end)


