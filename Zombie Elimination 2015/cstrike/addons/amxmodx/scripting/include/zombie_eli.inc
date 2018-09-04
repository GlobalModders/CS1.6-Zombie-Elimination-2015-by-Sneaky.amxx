enum
{
	TEAM_NONE = 0,
	TEAM_ZOMBIE,
	TEAM_HUMAN
}

enum
{
	WPN_MELEE = 1,
	WPN_SECONDARY,
	WPN_PRIMARY,
	WPN_NADES,
	WPN_BONUS
}

// Natives
native ZombieEli_RegisterClass(const Name[], Health, Armor, Float:Gravity, Float:Speed, const Model[], const ClawModel[], Team, VipOnly);
native ZombieEli_RegisterSkill(ClassID, const Name[], MaxPoint);

native ZombieEli_GetSP(id, SkillID); // Return the point of progress of the skill. Example: Enima Elish (2/3) -> return 2
native ZombieEli_GetLevel(id, ClassID); // Return level of a class

native ZombieEli_GetClass(id);
native ZombieEli_IsZombie(id);

native ZombieEli_GainExp(id, Exp, CheckLevelUp);
native ZombieEli_GetMaxHP(id); 
native ZombieEli_SetMaxHP(id, Health); 

native ZombieEli_GetBaseEnt(Team);
native ZombieEli_GainBaseHealth(Team, Health);

native ZombieEli_RegisterWeapon(ClassID, const Name[], WeaponType, Level, VipOnly);
native ZombieEli_GetClassID(const ClassName[]);

native ZombieEli_PowerSet(id, Power)
native ZombieEli_PowerGet(id)
native ZombieEli_SetFakeAttack(id)
native ZombieEli_SetPowerTime(id, Float:Time, Reset)

// Forwards
forward zeli_user_preinfect(id, ClassID);
forward zeli_user_infected(id, ClassID);
forward zeli_user_spawned(id, ClassID);
forward zeli_user_died(Victim, Attacker);
forward zeli_user_nvg(id, InOn);
forward zeli_class_unactive(id, ClassID);
forward zeli_class_active(id, ClassID);
forward zeli_round_new();
forward zeli_round_start();
forward zeli_game_start();
forward zeli_round_end(CsTeams:WinTeam);

forward zeli_levelup(id, ClassID, NewLevel);
forward zeli_skillup(id, SkillID, NewPoint); // Call when someone upgrades a skill

forward zeli_weapon_selected(id, ItemID, ClassID);
forward zeli_weapon_removed(id, ItemID, ClassID);
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3076\\ f0\\ fs16 \n\\ par }
*/
