# ryzescripts-weapon-clipsets
- Discord - [https://discord.gg/myt3wq2u]

**What it does**  
Lightweight FiveM client script that applies a custom **weapon movement clipset** (e.g., petrol/jerrycan carry) whenever a player equips a weapon. It automatically **pauses** the clipset while aiming, shooting, or reloading, and **reapplies** it after, so combat animations aren’t broken. Supports group-wide rules (e.g., RIFLE/SHOTGUN) and per-weapon overrides by **name** (e.g., `WEAPON_M4A1`) or hash.

---

## Installation

1. Copy the resource folder into your server:
2. Add this to your `server.cfg`: ensure ryzescripts-weapon-clipsets
3. Make sure the resource contains:
- `fxmanifest.lua`
- `config.lua`
- `client.lua`

> After installing, open `config.lua` to set which clipset key (e.g., `petrolcarry`) each weapon group or custom weapon name should use.

https://cdn.discordapp.com/attachments/1327939421546217524/1419294095863582781/image.png?ex=68d13c21&is=68cfeaa1&hm=0e5af7b97cf0380719224d600bf463792a0e5b01d844a5b2da8b872dc4b6ae88&
