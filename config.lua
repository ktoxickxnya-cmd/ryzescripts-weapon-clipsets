Config = {}

-- Check interval (ms)
Config.PollInterval = 100

-- Apply weapon-movement + (optional) strafe only (never full-body movement).
Config.ApplyStrafeClipset = true

-- 
Config.Clipsets = {
  petrolcarry = 'move_ped_wpn_jerrycan_generic',
  pistolcarry = 'move_m@brave', 
  Ballistic = 'move_ballistic_2h',
  Tactical = 'move_action@p_m_zero@armed@2h@upper',
--clipsetname = 'addclipsetmotionhere',
}

-- Map weapon groups -> clipset key above.
-- Valid group names: "PISTOL","SMG","RIFLE","MG","SHOTGUN","SNIPER","HEAVY","THROWN","MELEE"
Config.GroupMap = {
  RIFLE   = 'petrolcarry',
  SHOTGUN = 'petrolcarry',
  SMG = 'petrolcarry'
  -- PISTOL = 'pistolcarry',
}

-- This will override weapons in GroupMap {DO NOT PLACE ADDON GUNS HERE}
Config.WeaponOverrides = {
--   ['weapon_specialcarbine'] = 'Tactical',
}

--Add all your Custom/Addon Weapons Here
Config.CustomWeaponNameOverrides = {
  ['WEAPON_ICEPOPUMP'] = 'petrolcarry',
}







