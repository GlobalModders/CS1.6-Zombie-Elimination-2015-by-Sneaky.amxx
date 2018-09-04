#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <infinitygame>

#define PLUGIN "Zombie Elimination"
#define VERSION "6.2c Final"
#define AUTHOR "GlobalModders.net"

// =============== Game Config 
#define GAME_FOLDER "ZombieElimination"
#define BASE_CONFIG "BaseConfig"
#define LANG_FILE "ZombieElimination.txt"

#define VIP_FLAG ADMIN_LEVEL_H

#define MIN_PLAYER 2
#define COUNTDOWN_TIME 20 // 20 Seconds
#define ENV_LIGHT "f"
#define ENV_WEATHER 0 // 0 - Disable | 1 - Rain | 2 - Snow
#define ENV_FOG_DENSITY 10 // 0 ~ 100
#define ENV_FOG_COLOR "0 255 0"
#define ENV_SKY "neb6"

#define BASE_CLASSNAME "teambase"
#define HUMANBASE_HEALTH 4500.0
#define ZOMBIEBASE_HEALTH 35000.0

#define HEALTHBAR_SPR "sprites/zombie_elimination/healthbar.spr"

new const HumanBase_Model[] = "models/zombie_elimination/HumanBase.mdl"
new const ZombieBase_Model[] = "models/zombie_elimination/ZombieBase.mdl"

new const StartSound[] = "zombie_elimination/ZB4_Start.wav"
new const CountSound[] = "zombie_elimination/count/%i.wav"

new const ZombieBase_HitSound[3][] =
{
	"zombie_elimination/base/hive_hit1.wav",
	"zombie_elimination/base/hive_hit2.wav",
	"zombie_elimination/base/hive_hit3.wav"
}

new const ZombieBase_DeathSound[3][] = 
{
	"zombie_elimination/base/hive_death1.wav",
	"zombie_elimination/base/hive_death2.wav",
	"zombie_elimination/base/zombie_base_death.wav"
}

new const HumanBase_DeathSound1[] = "zombie_elimination/base/armory_death1.wav"
new const HumanBase_DeathSound2[] = "zombie_elimination/base/armory_death2.wav"

new const Human_WinSound[] = "zombie_elimination/win_human_2.wav"
new const Zombie_WinSound[] = "zombie_elimination/win_zombi_2.wav"

new const Zombie_DeathSpr[] = "sprites/zombie_elimination/zomb_death.spr"
new const Tutorial_MessageSound[] = "zombie_elimination/tutorial_message.wav"

new const LevelUpH_Sound[] = "zombie_elimination/h_levelup.wav"
new const LevelUpZ_Sound[] = "zombie_elimination/z_levelup.wav"

#define MAX_CLASS 16
#define MAX_LEVEL 10
new const Level_Experience[MAX_LEVEL+1] =
{
	50,
	150,
	250,
	350,
	450,
	550,
	675,
	775,
	950,
	1100,
	
	999999
}

#define LEVELUP_SP 1
#define KILL_EXP 10

#define MAX_SKILL 64
#define MAX_SP 9

const g_NVG_Alpha = 100
new const g_NVG_HumanColor[3] = {0, 200, 0}
new const g_NVG_ZombieColor[3] = {150, 150, 0}

#define RESPAWN_TIME 5

new const ZombiePain[2][] =
{
	"zombie_elimination/zombie/zombi_hurt_01.wav",
	"zombie_elimination/zombie/zombi_hurt_02.wav"
}

new const ZombieHit[3][] = 
{
	"zombie_elimination/zombie/zombi_attack_1.wav",
	"zombie_elimination/zombie/zombi_attack_2.wav",
	"zombie_elimination/zombie/zombi_attack_3.wav"
}

new const ZombieWall[3][] =
{
	"zombie_elimination/zombie/zombi_wall_1.wav",
	"zombie_elimination/zombie/zombi_wall_2.wav",
	"zombie_elimination/zombie/zombi_wall_3.wav"
}

new const ZombieMiss[3][] =
{
	"zombie_elimination/zombie/zombi_swing_1.wav",
	"zombie_elimination/zombie/zombi_swing_2.wav",
	"zombie_elimination/zombie/zombi_swing_3.wav"
}

new const ZombieDeath[2][] =
{
	"zombie_elimination/zombie/zombi_death_1.wav",
	"zombie_elimination/zombie/zombi_death_2.wav"
}

new const SkillSound[] = "zombie_elimination/skill_button.wav"

#define POWER_UPSPEED 0.5 // Default

#define HUD_ADRENALINE_X -1.0
#define HUD_ADRENALINE_Y 0.85

new const Human_Kill[2][] =
{
	"zombie_elimination/human_kill1.wav",
	"zombie_elimination/human_kill2.wav"
}

// =============== End of: Game Config
#define GAME_LANG LANG_PLAYER

#define HUD_WIN_X -1.0
#define HUD_WIN_Y 0.20

#define NOTICE_X -1.0
#define NOTICE_Y 0.25

new GameName[64] = "Zombie Elimination"

// Marcros
#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

// Task
#define TASK_COUNTDOWN 283151
#define TASK_BASEDEATH 283152
#define TASK_REVIVE 283153

// Block Round Event
new g_BlockedObj_Forward
new g_BlockedObj[15][32] =
{
        "func_bomb_target",
        "info_bomb_target",
        "info_vip_start",
        "func_vip_safetyzone",
        "func_escapezone",
        "hostage_entity",
        "monster_scientist",
        "func_hostage_rescue",
        "info_hostage_rescue",
        "env_fog",
        "env_rain",
        "env_snow",
        "item_longjump",
        "func_vehicle",
        "func_buyzone"
}

new const SoundNVG[2][] = { "items/nvg_off.wav", "items/nvg_on.wav"}
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

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
			
// Shared Code
#define PDATA_SAFE 2
const OFFSET_PLAYER_LINUX = 5
const OFFSET_WEAPON_LINUX = 4
const OFFSET_WEAPONOWNER = 41
			
// Vars
new g_GameAvailable, g_GameStart, g_GameEnd, g_Joined, g_DataLoad, g_CountTime, g_TeamScore[3], g_MaxHealth[33]
new g_HumanBase, g_ZombieBase, g_IsZombie, g_SkillPoint[33][MAX_CLASS], g_Level[33][MAX_CLASS], g_Experience[33][MAX_CLASS]
new Float:g_CTSpawn_Point[64][3], Float:g_TSpawn_Point[64][3], g_CTSpawn_Count, g_TSpawn_Count
new g_FogColor[3], g_MyClass[33], g_DefaultClass[3], g_TotalClass, g_Has_NightVision, g_UsingNVG
new g_MaxPlayers, g_BaseCreation, m_iBlood[2], g_iSprLightning, g_MsgScreenShake, g_Exp_SprID, 
g_GibModelID, g_ZombieDeath_SprId, g_Hud_Notice, g_MsgHideWeapon, g_Hud_Game, g_MsgScreenFade, g_TotalWeapon,
g_MsgBarTime, g_MyNextClass[33], g_fwResult, g_RespawnTime[33], g_TotalSkill, g_MySkillPoint[33][MAX_SKILL]
new g_Forward_Infected, g_Forward_Spawned, g_Forward_Died, g_Forward_NVG, g_Forward_ClassUnActive, 
g_Forward_ClassActive, g_Forward_PreInfect, g_Forward_RoundNew, g_Forward_RoundStart, g_Forward_Remove,
g_Forward_GameStart, g_Forward_RoundEnd, g_Forward_LevelUp, g_Forward_SkillUp, g_Forward_WeaponSelected
new g_BaseZombie, g_BaseHuman
new g_AdrenalinePower[33], Float:g_AdrenalineIncreaseTime[33], Float:g_MyIncTime[33]
new g_TempingAttack

new g_SelectedPri, g_SelectedSec, g_SelectedMelee, g_SelectedNades, g_SelectedBonus
new g_SelectedWeapon[33][6], g_Forward_BaseRegister

new Array:ClassName, Array:ClassHealth, Array:ClassArmor, Array:ClassGravity, Array:ClassSpeed, Array:ClassModel, Array:ClassClawModel, Array:ClassTeam, Array:ClassVip
new Array:SkillClass, Array:SkillName, Array:SkillPoint
new Array:WeaponClassID, Array:WeaponName, Array:WeaponType, Array:WeaponLevel, Array:WeaponVip
new Float:g_Knockback[33][3]

// Map Configs
new Float:MyOrigin[3], Float:MyAngles[3], Float:g_HumanBar_Dis[33], Float:g_ZombieBar_Dis[33]
new g_HumanBar, g_ZombieBar
new Float:ZombieBase_Origin[3], Float:HumanBase_Origin[3]
new Float:ZombieBase_Angles[3], Float:HumanBase_Angles[3]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_dictionary(LANG_FILE)
	Register_SafetyFunc()
	
	// Event
	register_event("HLTV", "Event_CapitalTaipei", "a", "1=0", "2=0")
	register_event("TextMsg", "Event_CapitalSeoul", "a", "2=#Game_will_restart_in")	
	register_logevent("Event_CastleCamelot", 2, "1=Round_Start")
	register_logevent("Event_KingGilgamesh", 2, "1=Round_End")
	register_event("ResetHUD", "Event_KingArthur", "b")
	
	// Forward
	register_think("healthbar", "fw_MachuPicchu_Think")
	register_think(BASE_CLASSNAME, "fw_AldnoahZero_Think")
	register_forward(FM_GetGameDescription, "fw_SwordArtOnline")
	register_forward(FM_EmitSound, "fw_GuiltyCrown")
	//register_forward(FM_TraceLine, "fw_TraceLine")
	//register_forward(FM_TraceHull, "fw_TraceHull")
	unregister_forward(FM_Spawn, g_BlockedObj_Forward)
	register_forward(FM_AddToFullPack, "fw_CapitalSaigon_Post", 1)

	// Hamsandwich
	RegisterHam(Ham_Spawn, "player", "fw_CapitalTokyo_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_CapitalHanoi_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_CapitalBangkok")
	RegisterHam(Ham_TakeDamage, "player", "fw_CapitalBangkok_Post", 1)
	RegisterHam(Ham_TraceAttack, "player", "fw_CapitalJakarta")
	RegisterHam(Ham_Use, "func_tank", "fw_LoveTohkaChan")
	RegisterHam(Ham_Use, "func_tankmortar", "fw_LoveTohkaChan")
	RegisterHam(Ham_Use, "func_tankrocket", "fw_LoveTohkaChan")
	RegisterHam(Ham_Use, "func_tanklaser", "fw_LoveTohkaChan")
	RegisterHam(Ham_Use, "func_tank", "fw_LoveAkame_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_LoveAkame_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_LoveAkame_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_LoveAkame_Post", 1)
	RegisterHam(Ham_Touch, "weaponbox", "fw_TokyoGhoul")
	RegisterHam(Ham_Touch, "armoury_entity", "fw_TokyoGhoul")
	RegisterHam(Ham_Touch, "weapon_shield", "fw_TokyoGhoul")
	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_InfiniteStratos_Post", 1)
	
	// Message
	register_message(get_user_msgid("StatusIcon"), "Message_NoGameNoLife")
	register_message(get_user_msgid("TeamScore"), "Message_NoAnimeNoLove")
	register_message(get_user_msgid("ClCorpse"), "Message_SieSindDasEssen")
	register_message(g_MsgHideWeapon, "Message_WirSindDieJaeger")
	
	// CMD ?
	register_clcmd("nightvision", "CMD_NightVision")
	register_clcmd("radio1", "CMD_Radio") 
	register_clcmd("radio2", "CMD_Radio") 
	register_clcmd("radio3", "CMD_Radio")
	
	// Team Mananger
	register_clcmd("chooseteam", "CMD_JoinTeam")
	register_clcmd("jointeam", "CMD_JoinTeam")
	register_clcmd("joinclass", "CMD_JoinTeam")
	
	// Get Message
	g_MsgScreenFade = get_user_msgid("ScreenFade")
	g_MsgBarTime = get_user_msgid("BarTime")
	g_MsgScreenShake = get_user_msgid("ScreenShake")
	g_MsgHideWeapon = get_user_msgid("HideWeapon")
	g_MaxPlayers = get_maxplayers()
	g_Hud_Notice = CreateHudSyncObj(1)
	g_Hud_Game = CreateHudSyncObj(2) 
	
	// Forwards
	g_Forward_PreInfect = CreateMultiForward("zeli_user_preinfect", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forward_Infected = CreateMultiForward("zeli_user_infected", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forward_Spawned = CreateMultiForward("zeli_user_spawned", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forward_Died = CreateMultiForward("zeli_user_died", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forward_NVG = CreateMultiForward("zeli_user_nvg", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forward_ClassUnActive = CreateMultiForward("zeli_class_unactive", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forward_ClassActive = CreateMultiForward("zeli_class_active", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forward_RoundNew = CreateMultiForward("zeli_round_new", ET_IGNORE)
	g_Forward_RoundStart = CreateMultiForward("zeli_round_start", ET_IGNORE)
	g_Forward_GameStart = CreateMultiForward("zeli_game_start", ET_IGNORE)
	g_Forward_RoundEnd = CreateMultiForward("zeli_round_end", ET_IGNORE, FP_CELL)
	g_Forward_LevelUp = CreateMultiForward("zeli_levelup", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forward_SkillUp = CreateMultiForward("zeli_skillup", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forward_WeaponSelected = CreateMultiForward("zeli_weapon_selected", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forward_Remove = CreateMultiForward("zeli_weapon_removed", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forward_BaseRegister = CreateMultiForward("zeli_base_register", ET_IGNORE, FP_CELL, FP_CELL)
	
	// Collect Spawns Point
	Collect_SpawnPoint()

	formatex(GameName, sizeof(GameName), "%L", GAME_LANG, "GAME_NAME")
	IG_EndRound_Block(true, true)
	
	register_clcmd("say /test", "Test")
	register_clcmd("zeli_base_origin", "BaseOrigin_Handle", ADMIN_ADMIN)
	
	// Check Class
	if(g_DefaultClass[TEAM_HUMAN] == -1 || g_DefaultClass[TEAM_ZOMBIE] == -1)
	{
		set_fail_state("Error: Classes not found! %i %i", g_DefaultClass[TEAM_HUMAN], g_DefaultClass[TEAM_ZOMBIE])
		return
	}
}

public Test(id)
{
	Level_GainExp(id, 1000, 1)
}

public plugin_precache()
{
	// Array
	ClassName = ArrayCreate(64, 1)
	ClassHealth = ArrayCreate(1, 1)
	ClassArmor = ArrayCreate(1, 1)	
	ClassGravity = ArrayCreate(1, 1)
	ClassSpeed = ArrayCreate(1, 1)
	ClassModel = ArrayCreate(64, 1)
	ClassClawModel = ArrayCreate(64, 1)
	ClassTeam = ArrayCreate(1, 1)
	ClassVip = ArrayCreate(1, 1)
	
	SkillClass = ArrayCreate(1, 1)
	SkillName = ArrayCreate(64, 1)
	SkillPoint = ArrayCreate(1, 1)
	
	WeaponClassID = ArrayCreate(1, 1)
	WeaponName = ArrayCreate(64, 1)
	WeaponType = ArrayCreate(1, 1)
	WeaponLevel = ArrayCreate(1, 1)
	WeaponVip = ArrayCreate(1, 1)
	
	g_DefaultClass[TEAM_ZOMBIE] = -1
	g_DefaultClass[TEAM_HUMAN] = -1
	
	// Precache
	new BufferB[128], i
	
	precache_model(HumanBase_Model)
	precache_model(ZombieBase_Model)
	precache_model(HEALTHBAR_SPR)
	
	precache_sound(StartSound)
	for(i = 1; i <= 10; i++)
	{
		formatex(BufferB, charsmax(BufferB), CountSound, i); 
		precache_sound(BufferB); 
	}
	for(i = 0; i < sizeof(ZombieBase_HitSound); i++) precache_sound(ZombieBase_HitSound[i])
	for(i = 0; i < sizeof(ZombieBase_DeathSound); i++) precache_sound(ZombieBase_DeathSound[i])
	precache_sound(HumanBase_DeathSound1)
	precache_sound(HumanBase_DeathSound2)
	
	precache_sound(Human_WinSound)
	precache_sound(Zombie_WinSound)
	
	g_ZombieDeath_SprId = precache_model(Zombie_DeathSpr)
	precache_sound(Tutorial_MessageSound)
	
	precache_sound(LevelUpZ_Sound)
	precache_sound(LevelUpH_Sound)

	// Preache custom sky files
	formatex(BufferB, charsmax(BufferB), "gfx/env/%sbk.tga", ENV_SKY); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%sdn.tga", ENV_SKY); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%sft.tga", ENV_SKY); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%slf.tga", ENV_SKY); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%srt.tga", ENV_SKY); engfunc(EngFunc_PrecacheGeneric, BufferB)
	formatex(BufferB, charsmax(BufferB), "gfx/env/%sup.tga", ENV_SKY); engfunc(EngFunc_PrecacheGeneric, BufferB)		

	// Sound
	for(i = 0; i < sizeof(ZombiePain); i++)
		precache_sound(ZombiePain[i])
	for(i = 0; i < sizeof(ZombieHit); i++)
		precache_sound(ZombieHit[i])
	for(i = 0; i < sizeof(ZombieWall); i++)
		precache_sound(ZombieWall[i])
	for(i = 0; i < sizeof(ZombieMiss); i++)
		precache_sound(ZombieMiss[i])
	for(i = 0; i < sizeof(ZombieDeath); i++)
		precache_sound(ZombieDeath[i])
	
	precache_sound(SkillSound)
	
	for(i = 0; i < sizeof(Human_Kill); i++)
		precache_sound(Human_Kill[i])
	
	// Weather
	new Weather; Weather = ENV_WEATHER
	new Buffer2[16]
	
	if(Weather == 1) engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_rain"))
	else if(Weather == 2) engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_snow"))	
	
	parse(ENV_FOG_COLOR, Buffer2[0], 7, Buffer2[1], 7, Buffer2[2], 7)
	g_FogColor[0] = str_to_num(Buffer2[0])
	g_FogColor[1] = str_to_num(Buffer2[1])
	g_FogColor[2] = str_to_num(Buffer2[2])
	
	// Cache
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")	
	g_iSprLightning = precache_model("sprites/laserbeam.spr")
	g_Exp_SprID = precache_model("sprites/zombie_elimination/he_efx12.spr")
	g_GibModelID = precache_model("models/metalplategibs.mdl")
	
	// Register Forward
	g_BlockedObj_Forward = register_forward(FM_Spawn, "fw_BlockedObj_Spawn")	
	
	// Handle Map
	Read_MapConfig()
}

public plugin_cfg()
{
	// Default Cvars
	set_cvar_num("mp_limitteams", 1)
	set_cvar_num("mp_autoteambalance", 0)
	set_cvar_num("sv_maxspeed", 999)
	set_cvar_num("mp_freezetime", COUNTDOWN_TIME + 2)
	
	set_cvar_num("mp_flashlight", 1)
	
	set_cvar_num("sv_skycolor_r", 0)
	set_cvar_num("sv_skycolor_g", 0)
	set_cvar_num("sv_skycolor_b", 0)	
	
	// Exec
	server_exec()
	set_cvar_string("sv_skyname", ENV_SKY)
	
	// New Round
	Event_CapitalTaipei()

	set_task(2.0, "Create_Bot")
}

public plugin_natives()
{
	register_native("ZombieEli_RegisterClass", "Native_RegisterClass", 1)
	register_native("ZombieEli_RegisterSkill", "Native_RegisterSkill", 1)
	
	register_native("ZombieEli_GetSP", "Native_GetSP", 1)
	register_native("ZombieEli_GetLevel", "Native_GetLevel", 1)

	register_native("ZombieEli_GetClass", "Native_GetClass", 1)
	register_native("ZombieEli_IsZombie", "Native_IsZombie", 1)

	register_native("ZombieEli_GainExp", "Native_GainExp", 1)
	register_native("ZombieEli_GetMaxHP", "Native_GetMaxHP", 1)
	register_native("ZombieEli_SetMaxHP", "Native_SetMaxHP", 1)
	
	register_native("ZombieEli_GetBaseEnt", "Native_GetBaseEnt", 1)
	register_native("ZombieEli_GainBaseHealth", "Native_GainBaseHealth", 1)
	
	register_native("ZombieEli_RegisterWeapon", "Native_RegisterWeapon", 1)
	register_native("ZombieEli_GetClassID", "Native_GetClassID", 1)
	
	register_native("ZombieEli_PowerSet", "Native_SetPower", 1)
	register_native("ZombieEli_PowerGet", "Native_GetPower", 1)
	register_native("ZombieEli_SetFakeAttack", "Native_SetFakeAttack", 1)
	register_native("ZombieEli_SetPowerTime", "Native_SetPowerTime", 1)
}

public Create_Bot()
{
	g_BaseZombie = find_player("a", "Zombie Nest")
	if(!g_BaseZombie)
	{
		g_BaseZombie = engfunc(EngFunc_CreateFakeClient, "Zombie Nest")
		
		static Trace[128]
		dllfunc(DLLFunc_ClientConnect, g_BaseZombie, "Zombie Nest", "127.0.0.1", Trace)
		dllfunc(DLLFunc_ClientPutInServer, g_BaseZombie)
		
		cs_set_user_team(g_BaseZombie, CS_TEAM_SPECTATOR)
		dllfunc(DLLFunc_Spawn, g_BaseZombie);
		
		static Float:origin1[3]; origin1[0] = origin1[1] = origin1[2] = -800000.0
		
		set_pev(g_BaseZombie, pev_effects, (pev(g_BaseZombie, pev_effects) | 128) ); //set invisible
		set_pev(g_BaseZombie, pev_flags, FL_NOTARGET);
		set_pev(g_BaseZombie, pev_solid, 0);
		set_pev(g_BaseZombie, pev_origin, origin1);
		entity_set_float(g_BaseZombie, EV_FL_takedamage, 0.0 );
		entity_set_int(g_BaseZombie, EV_INT_solid, 0 );
		entity_set_int(g_BaseZombie, EV_INT_movetype, MOVETYPE_NOCLIP );
	}
	
	g_BaseHuman = find_player("a", "Millitary Base")
	if(!g_BaseHuman)
	{
		g_BaseHuman = engfunc(EngFunc_CreateFakeClient, "Millitary Base")
		
		static Trace[128]
		dllfunc(DLLFunc_ClientConnect, g_BaseHuman, "Millitary Base", "127.0.0.1", Trace)
		dllfunc(DLLFunc_ClientPutInServer, g_BaseHuman)
		
		cs_set_user_team(g_BaseHuman, CS_TEAM_SPECTATOR)
		dllfunc(DLLFunc_Spawn, g_BaseHuman);
		
		static Float:origin1[3]; origin1[0] = origin1[1] = origin1[2] = -800000.0
		
		set_pev(g_BaseHuman, pev_effects, (pev(g_BaseHuman, pev_effects) | 128) ); //set invisible
		set_pev(g_BaseHuman, pev_flags, FL_NOTARGET);
		set_pev(g_BaseHuman, pev_solid, 0);
		set_pev(g_BaseHuman, pev_origin, origin1);
		entity_set_float(g_BaseHuman, EV_FL_takedamage, 0.0 );
		entity_set_int(g_BaseHuman, EV_INT_solid, 0 );
		entity_set_int(g_BaseHuman, EV_INT_movetype, MOVETYPE_NOCLIP );
	}
}

public Native_RegisterClass(const Name[], Health, Armor, Float:Gravity, Float:Speed, const Model[], const ClawModel[], Team, VipOnly)
{
	param_convert(1)
	param_convert(6)
	param_convert(7)
	
	ArrayPushString(ClassName, Name)
	ArrayPushCell(ClassHealth, Health)
	ArrayPushCell(ClassArmor, Armor)
	ArrayPushCell(ClassGravity, Gravity)
	ArrayPushCell(ClassSpeed, Speed)
	ArrayPushString(ClassModel, Model)
	ArrayPushString(ClassClawModel, ClawModel)
	ArrayPushCell(ClassTeam, Team)
	ArrayPushCell(ClassVip, VipOnly)
	
	// Precache those shits... of course :)
	new BufferA[64]
	formatex(BufferA, sizeof(BufferA), "models/player/%s/%s.mdl", Model, Model)
	engfunc(EngFunc_PrecacheModel, BufferA); 
	
	if(Team == TEAM_ZOMBIE)
	{
		formatex(BufferA, sizeof(BufferA), "models/zombie_elimination/claw/%s", ClawModel)
		engfunc(EngFunc_PrecacheModel, BufferA);
	}
	
	if(Team == TEAM_ZOMBIE && g_DefaultClass[TEAM_ZOMBIE] == -1) g_DefaultClass[TEAM_ZOMBIE] = g_TotalClass
	else if(Team == TEAM_HUMAN && g_DefaultClass[TEAM_HUMAN] == -1) g_DefaultClass[TEAM_HUMAN] = g_TotalClass
	
	g_TotalClass++
	return g_TotalClass - 1
}

public Native_RegisterWeapon(ClassID, const Name[], Type, Level, VipOnly)
{
	param_convert(2)
	
	ArrayPushCell(WeaponClassID, ClassID)
	ArrayPushString(WeaponName, Name)
	ArrayPushCell(WeaponType, Type)
	ArrayPushCell(WeaponLevel, Level)
	ArrayPushCell(WeaponVip, VipOnly)
	
	g_TotalWeapon++
	return g_TotalWeapon - 1
}

public Native_RegisterSkill(ClassID, const Name[], MaxPoint)
{
	param_convert(2)
	
	ArrayPushCell(SkillClass, ClassID)
	ArrayPushString(SkillName, Name)
	ArrayPushCell(SkillPoint, MaxPoint)
	
	g_TotalSkill++
	return g_TotalSkill - 1
}

public Native_GetSP(id, SkillID)
{
	if(!is_connected(id))
		return 0
		
	return g_MySkillPoint[id][SkillID]
}

public Native_GetLevel(id, ClassID)
{
	if(!is_connected(id))
		return 0
		
	return g_Level[id][ClassID]
}

public Native_GetClass(id)
{
	if(!is_connected(id))
		return -1
		
	return g_MyClass[id]
}

public Native_IsZombie(id)
{
	if(!is_connected(id))
		return 0
	
	return Get_BitVar(g_IsZombie, id)
}

public Native_GainExp(id, Exp, CheckLvUp)
{
	if(!is_connected(id))
		return
		
	Level_GainExp(id, Exp, CheckLvUp)
}

public Native_GetMaxHP(id)
{
	if(!is_connected(id))
		return 0
		
	return g_MaxHealth[id]
}

public Native_SetMaxHP(id, Health)
{
	if(!is_connected(id))
		return
		
	g_MaxHealth[id] = Health
}

public Native_GetBaseEnt(Team)
{
	if(Team == TEAM_HUMAN) return g_HumanBase
	else if(Team == TEAM_ZOMBIE) return g_ZombieBase
	else return 0
}

public Native_GainBaseHealth(Team, Amount)
{
	static Float:Health, Float:CurHealth;
	if(Team == TEAM_HUMAN) 
	{
		pev(g_HumanBase, pev_health, CurHealth)
		CurHealth -= 10000.0
		Health = CurHealth + float(Amount)
		if(Health > HUMANBASE_HEALTH) Health = HUMANBASE_HEALTH

		set_pev(g_HumanBase, pev_health, 10000.0 + Health)
	} else if(Team == TEAM_ZOMBIE) {
		pev(g_ZombieBase, pev_health, CurHealth)
		CurHealth -= 10000.0
		Health = CurHealth + float(Amount)
		if(Health > ZOMBIEBASE_HEALTH) Health = ZOMBIEBASE_HEALTH
	
		set_pev(g_ZombieBase, pev_health, 10000.0 + Health)
	}
}

public Native_GetClassID(const Name[])
{
	param_convert(1)
	static CName[64], ClassID
	
	for(new i = 0; i < g_TotalClass; i++)
	{
		ArrayGetString(ClassName, i, CName, 63)
		if(equal(Name, CName))
		{
			ClassID = i
			break
		}
	}
	
	return ClassID
}

public GetClassID(const Name[])
{
	static CName[64], ClassID
	
	for(new i = 0; i < g_TotalClass; i++)
	{
		ArrayGetString(ClassName, i, CName, 63)
		if(equal(Name, CName))
		{
			ClassID = i
			break
		}
	}
	
	return ClassID
}


public Native_SetPower(id, Power)
{
	g_AdrenalinePower[id] = Power
}

public Native_GetPower(id)
{
	return g_AdrenalinePower[id]
}

public Native_SetFakeAttack(id)
{	
	static Ent; Ent = fm_get_user_weapon_entity(id, get_user_weapon(id))
	if(!pev_valid(Ent)) return 0
	
	static Float:NextAttack, Anim; NextAttack = get_pdata_float(id, 83, 5); Anim = pev(id, pev_weaponanim)
	Set_BitVar(g_TempingAttack, id)
	ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)	
	UnSet_BitVar(g_TempingAttack, id)
	set_pdata_float(id, 83, NextAttack, 5)
	if(pev(id, pev_weaponanim) != Anim) Set_WeaponAnim(id, Anim)
	
	return 1
}

public Native_SetPowerTime(id, Float:Time, Reset)
{
	if(!is_connected(id))
		return
		
	if(!Reset) g_MyIncTime[id] = Time 
	else g_MyIncTime[id] = POWER_UPSPEED
}

public fw_BlockedObj_Spawn(ent)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED
	
	static Ent_Classname[64]
	pev(ent, pev_classname, Ent_Classname, sizeof(Ent_Classname))
	
	for(new i = 0; i < sizeof g_BlockedObj; i++)
	{
		if (equal(Ent_Classname, g_BlockedObj[i]))
		{
			engfunc(EngFunc_RemoveEntity, ent)
			return FMRES_SUPERCEDE
		}
	}
	
	return FMRES_IGNORED
}

public Read_MapConfig()
{
	new Path[128]; get_configsdir(Path, charsmax(Path))
	new MapName[64]; get_mapname(MapName, 63)
	format(Path, 127, "%s/%s/%s/%s.base", Path, GAME_FOLDER, BASE_CONFIG, MapName)

	if(file_exists(Path))
	{
		new LineData[128], Line
		new File = fopen(Path, "rt")
		new Key[64], Value[64]
		new HandleData[3][48]
        
		if(!File) return
        
		while(!feof(File))
		{
			fgets(File, LineData, 127)
			replace(LineData, 127, "^n", "")
			
			if(LineData[0] == ';' || !LineData[0]) continue
           
			// Get key and value
			strtok(LineData, Key, 63, Value, 63, '=')
			
			// Trim spaces
			trim(Key)
			//trim(Value)
			
			// Base
			if(equal(Key, "HUMAN_BASE_ORIGIN"))
			{
				parse(Value, HandleData[0], 47, HandleData[1], 47, HandleData[2], 47)
				HumanBase_Origin[0] = str_to_float(HandleData[0])
				HumanBase_Origin[1] = str_to_float(HandleData[1])
				HumanBase_Origin[2] = str_to_float(HandleData[2])
			} else if(equal(Key, "HUMAN_BASE_ANGLES")) {
				parse(Value, HandleData[0], 47, HandleData[1], 47, HandleData[2], 47)
				HumanBase_Angles[0] = str_to_float(HandleData[0])
				HumanBase_Angles[1] = str_to_float(HandleData[1])
				HumanBase_Angles[2] = str_to_float(HandleData[2])
			} else if(equal(Key, "ZOMBIE_BASE_ORIGIN")) {
				parse(Value, HandleData[0], 47, HandleData[1], 47, HandleData[2], 47)
				ZombieBase_Origin[0] = str_to_float(HandleData[0])
				ZombieBase_Origin[1] = str_to_float(HandleData[1])
				ZombieBase_Origin[2] = str_to_float(HandleData[2])
			}else if(equal(Key, "ZOMBIE_BASE_ANGLES")) {
				parse(Value, HandleData[0], 47, HandleData[1], 47, HandleData[2], 47)
				ZombieBase_Angles[0] = str_to_float(HandleData[0])
				ZombieBase_Angles[1] = str_to_float(HandleData[1])
				ZombieBase_Angles[2] = str_to_float(HandleData[2])
			}
	  
			Line++
		}

		fclose(File)
		g_DataLoad = 1
	} else {
		g_DataLoad = 0
	}
}

public client_putinserver(id)
{
	Safety_Connected(id)
	set_task(0.25, "Set_ConnectInfo", id)
	
	Reset_Player(id, 1)
	/*
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Register_HamBot", id)
	}*/
}

public client_PostThink(id)
{
	if(!is_alive(id))
		return
	if(!is_zombie(id))
		return
		
	// Adrenaline Power
	static Float:Time; Time = get_gametime()
	if(Time - g_MyIncTime[id] > g_AdrenalineIncreaseTime[id])
	{
		Show_AdrenalinePower2(id, g_MyIncTime[id] + 0.1)
		
		if(g_AdrenalinePower[id] < 100)
		{
			g_AdrenalinePower[id]++
			Check_AdrenalinePower(id, g_AdrenalinePower[id])
		}
		
		g_AdrenalineIncreaseTime[id] = Time
	}		
}

public Show_AdrenalinePower2(id, Float:Time)
{
	new Power[42]
	for(new i = 0; i < (floatround(float(g_AdrenalinePower[id]) / 5.0, floatround_floor)); i++) formatex(Power, sizeof(Power), "%s|", Power)
	for(new i = 0; i < (20 - (floatround(float(g_AdrenalinePower[id]) / 5.0, floatround_floor))); i++) formatex(Power, sizeof(Power), "%s  ", Power)

	if(is_zombie(id))
	{
		set_dhudmessage(255, 255, 50, HUD_ADRENALINE_X, HUD_ADRENALINE_Y, 0, Time, Time, 0.0, 0.0)
		show_dhudmessage(id, "%i [%s]", g_AdrenalinePower[id], Power)
	} else {
		set_dhudmessage(50, 255, 50, HUD_ADRENALINE_X, HUD_ADRENALINE_Y, 0, Time, Time, 0.0, 0.0)
		show_dhudmessage(id, "%i [%s]", g_AdrenalinePower[id], Power)
	}
}

public Check_AdrenalinePower(id, Power)
{
	//if(Power >= 100) PlaySound(id, SkillSound)
}

public Set_ConnectInfo(id)
{
	if(!is_connected(id)) 
		return

	SetPlayerLight(id, ENV_LIGHT)
	IG_Fog(id, g_FogColor[0], g_FogColor[1], g_FogColor[2], ENV_FOG_DENSITY)
}

public Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
	
	RegisterHamFromEntity(Ham_Spawn, id, "fw_CapitalTokyo_Post", 1)
	RegisterHamFromEntity(Ham_Killed, id, "fw_CapitalHanoi_Post", 1)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_CapitalJakarta")
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_CapitalBangkok")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
	Reset_Player(id, 1)
	
	UnSet_BitVar(g_Joined, id)
}

public IG_RunningTime()
{
	if(g_GameAvailable && (Get_TotalInPlayer(2) < MIN_PLAYER))
	{
		g_GameAvailable = 0
		g_GameStart = 0
		g_GameEnd = 0
	} else if(!g_GameAvailable && (Get_TotalInPlayer(2) >= MIN_PLAYER) && Get_PlayerCount(2, 1) >= 1 && Get_PlayerCount(2, 2) >= 1) { // START GAME NOW :D
		g_GameAvailable = 1
		g_GameStart = 0
		g_GameEnd = 0
		
		Game_Ending(5.0, 1, CS_TEAM_UNASSIGNED)
	} else if(!g_GameAvailable  && Get_TotalInPlayer(2) < MIN_PLAYER) {
		client_print(0, print_center, "%L", GAME_LANG, "NOTICE_PLAYERREQUIRED", MIN_PLAYER)
	} else if(!g_DataLoad) {
		client_print(0, print_center, "%L", GAME_LANG, "NOTICE_CANTLOAD")
	}
	// Player
	Loop_Player()
	
	// Check Gameplay
	Check_Gameplay()
}

public Loop_Player()
{
	static PlayerClass[32];
	for(new id = 0; id < g_MaxPlayers; id++)
	{
		if(!is_alive(id))
			continue
			
		ArrayGetString(ClassName, g_MyClass[id], PlayerClass, 31)
			
		if(Get_BitVar(g_IsZombie, id)) 
		{
			set_hudmessage(255, 0, 0, 0.02, 0.925, 0, 1.25, 1.25)
			ShowSyncHudMsg(id, g_Hud_Game, "%L", GAME_LANG, "HUD_LAYOUT_ZOMBIE", get_user_health(id), get_user_armor(id), g_SkillPoint[id][g_MyClass[id]], PlayerClass, g_Level[id][g_MyClass[id]], g_Experience[id][g_MyClass[id]], Level_Experience[min(g_Level[id][g_MyClass[id]], MAX_LEVEL-1)])
		} else {
			set_hudmessage(0, 255, 0, 0.02, 0.925, 0, 1.25, 1.25)
			ShowSyncHudMsg(id, g_Hud_Game, "%L", GAME_LANG, "HUD_LAYOUT_HUMAN", get_user_health(id), get_user_armor(id), g_SkillPoint[id][g_MyClass[id]], PlayerClass, g_Level[id][g_MyClass[id]], g_Experience[id][g_MyClass[id]], Level_Experience[min(g_Level[id][g_MyClass[id]], MAX_LEVEL-1)])
		}
	}	
}

public Check_Gameplay()
{
	if(!g_GameAvailable || !g_GameStart || g_GameEnd)
		return
	
	if((Get_PlayerCount(1, 1) <= 0) && !pev_valid(g_ZombieBase)) // All zombies are dead
	{
		StopSound(0)
		Game_Ending(5.0, 0, CS_TEAM_CT)

		return
	} else if((Get_PlayerCount(1, 2) <= 0) && !pev_valid(g_HumanBase)) { // All humans are dead
		StopSound(0)
		Game_Ending(5.0, 0, CS_TEAM_T)
		
		return
	}
}

public Level_GainExp(id, Exp, CheckLvUp)
{
	if(g_Level[id][g_MyClass[id]] >= MAX_LEVEL)
		return
		
	static Plus; Plus = g_Experience[id][g_MyClass[id]]
	g_Experience[id][g_MyClass[id]] = min(Plus + Exp, Level_Experience[MAX_LEVEL-1])
	
	if(CheckLvUp) Level_CheckUp(id)
}

public Level_CheckUp(id)
{
	if(g_Level[id][g_MyClass[id]] >= MAX_LEVEL)
		return
	
	static HadLevelUp; HadLevelUp = 0
	static LevelUpTime; LevelUpTime = 0
	while(g_Experience[id][g_MyClass[id]] >= Level_Experience[g_Level[id][g_MyClass[id]]])
	{
		g_Level[id][g_MyClass[id]]++
		HadLevelUp = 1
		
		LevelUpTime++
	}

	if(HadLevelUp)
	{ // Player Level Up!
		PlaySound(id, Get_BitVar(g_IsZombie, id) ? LevelUpZ_Sound : LevelUpH_Sound)
		
		static Classname[32]; ArrayGetString(ClassName, g_MyClass[id], Classname, 31)
		
		set_hudmessage(0, 255, 0, NOTICE_X, NOTICE_Y, 0, 3.0, 3.0)
		ShowSyncHudMsg(id, g_Hud_Notice, "%L", GAME_LANG, "NOTICE_LEVELUP", Classname, g_Level[id][g_MyClass[id]])
	
		// Exec
		ExecuteForward(g_Forward_LevelUp, g_fwResult, id, g_MyClass[id], g_Level[id][g_MyClass[id]])
	
		// SP
		static Point; Point = (LEVELUP_SP * LevelUpTime)
		Skill_GainPoint(id, Point)
	}
}

public Event_CapitalTaipei()
{
	if(!g_DataLoad) return
	
	g_GameEnd = 0
	g_GameStart = 0

	if(pev_valid(g_HumanBase) == 2) 
	{
		set_pev(g_HumanBase, pev_nextthink, get_gametime() + 0.05)
		set_pev(g_HumanBase, pev_flags, FL_KILLME)
	}
	if(pev_valid(g_ZombieBase) == 2) 
	{
		set_pev(g_ZombieBase, pev_nextthink, get_gametime() + 0.05)
		set_pev(g_ZombieBase, pev_flags, FL_KILLME)
	}
	
	remove_task(TASK_COUNTDOWN)
	remove_task(TASK_BASEDEATH)
	
	StopSound(0)
	
	if(!g_GameAvailable || g_GameEnd)
		return
		
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_connected(i))
			continue
		if(cs_get_user_team(i) == CS_TEAM_CT) IG_TeamSet(i, CS_TEAM_T)
		else if(cs_get_user_team(i) == CS_TEAM_T) IG_TeamSet(i, CS_TEAM_CT)
	}

	PlaySound(0, StartSound)
	Start_Countdown()

	ExecuteForward(g_Forward_RoundNew, g_fwResult)
}

public Event_CastleCamelot()
{
	if(!g_DataLoad) return
	if(!g_GameAvailable || g_GameEnd)
		return
		
	g_GameStart = 1
	
	// Set Map time
	static MapTime; MapTime = get_timeleft()
	static Round; Round = MapTime / 60
	IG_RoundTime_Set(Round, clamp(MapTime - (Round * 60), 0, 60))
	
	// Initialize Base
	Create_TeamBase()
	
	// Update Speed
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
			
		IG_SpeedSet(i, ArrayGetCell(ClassSpeed, g_MyClass[i]), 1)
	}
	
	ExecuteForward(g_Forward_RoundStart, g_fwResult)
	ExecuteForward(g_Forward_GameStart, g_fwResult)
}

public Event_KingGilgamesh()
{
	g_GameEnd = 1
	g_GameStart = 0
}

public Event_CapitalSeoul() 
{
	Event_KingGilgamesh()
	ExecuteForward(g_Forward_RoundEnd, g_fwResult, CS_TEAM_UNASSIGNED)
}

public Event_KingArthur(id)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgHideWeapon, _, id)
	write_byte((1<<3))
	message_end()
}

public Reset_Player(id, NewPlayer)
{
	if(NewPlayer)
	{
		UnSet_BitVar(g_Joined, id)
		
		for(new i = 0; i < MAX_CLASS; i++)
			g_SkillPoint[id][i] = g_Level[id][i] = g_Experience[id][i] = 0
		for(new i = 0; i < MAX_SKILL; i++)
			g_MySkillPoint[id][i] = 0
		
		g_MyClass[id] = -1
		g_MyNextClass[id] = -1
	}
	
	remove_task(id+TASK_REVIVE)
	
	UnSet_BitVar(g_Has_NightVision, id)
	UnSet_BitVar(g_UsingNVG, id)
	UnSet_BitVar(g_IsZombie, id)
	UnSet_BitVar(g_TempingAttack, id)
	
	g_RespawnTime[id] = 0
}

public Start_Countdown()
{
	g_CountTime = COUNTDOWN_TIME
	
	remove_task(TASK_COUNTDOWN)
	CountingDown()
}

public CountingDown()
{
	if(!g_GameAvailable || g_GameEnd)
		return
	if(g_CountTime  <= 0)
		return
	
	client_print(0, print_center, "%L", GAME_LANG, "NOTICE_COUNTDOWN", g_CountTime)
	
	switch(g_CountTime)
	{
		case 18: Send_Transcript(4.0, 0, "%L", GAME_LANG, "NOTICE_ROUNDSTART1")
		case 14: Send_Transcript(4.0, 0, "%L", GAME_LANG, "NOTICE_ROUNDSTART2")
		case 10: Send_Transcript(4.0, 0, "%L", GAME_LANG, "NOTICE_ROUNDSTART3")
	}
	
	if(g_CountTime <= 10)
	{
		static Sound[64]; format(Sound, charsmax(Sound), CountSound, g_CountTime)
		PlaySound(0, Sound)
	} 	
	
	g_CountTime--
	set_task(1.0, "CountingDown", TASK_COUNTDOWN)
}

public Send_Transcript(Float:Time, Emergency, const Text[], any:...)
{
	static szMsg[128]; vformat(szMsg, sizeof(szMsg) - 1, Text, 4)
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_connected(i))
			continue

		set_hudmessage(255, 42, 0, NOTICE_X, NOTICE_Y, Emergency, Time, Time)
		ShowSyncHudMsg(i, g_Hud_Notice, szMsg)
		
		PlaySound(i, Tutorial_MessageSound)
	}
}

public Game_Ending(Float:EndTime, RoundDraw, CsTeams:Team)
// RoundDraw: Draw or Team Win
// Team: 1 - T | 2 - CT
{
	if(g_GameEnd) return
	if(RoundDraw) 
	{
		IG_TerminateRound(WIN_DRAW, EndTime, 0)
		ExecuteForward(g_Forward_RoundEnd, g_fwResult, CS_TEAM_UNASSIGNED)
		
		client_print(0, print_center, "%L", GAME_LANG, "NOTICE_GAMESTART")
	} else {
		if(Team == CS_TEAM_T) 
		{
			g_TeamScore[TEAM_ZOMBIE]++
			
			IG_TerminateRound(WIN_TERRORIST, EndTime, 0)
			ExecuteForward(g_Forward_RoundEnd, g_fwResult, CS_TEAM_T)
	
			PlaySound(0, Zombie_WinSound)
			
			set_dhudmessage(200, 0, 0, HUD_WIN_X, HUD_WIN_Y, 0, EndTime, EndTime, 0.0, 1.5)
			show_dhudmessage(0, "%L", GAME_LANG, "NOTICE_WIN_ZOMBIE")
		} else if(Team == CS_TEAM_CT) {
			g_TeamScore[TEAM_HUMAN]++
			
			IG_TerminateRound(WIN_CT, EndTime, 0)
			ExecuteForward(g_Forward_RoundEnd, g_fwResult, CS_TEAM_CT)

			PlaySound(0, Human_WinSound)
			
			set_dhudmessage(0, 200, 0, HUD_WIN_X, HUD_WIN_Y, 0, EndTime, EndTime, 0.0, 1.5)
			show_dhudmessage(0, "%L", GAME_LANG, "NOTICE_WIN_HUMAN")
		}
	}
	
	g_GameEnd = 1
}

public BaseOrigin_Handle(id)
{
	static MenuTitle[32]; formatex(MenuTitle, sizeof(MenuTitle), "\y%L\w", GAME_LANG, "MENU_BASEORIGIN")
	new MenuId; MenuId = menu_create(MenuTitle, "MenuHandle_BaseOrigin")
	
	static Data[64]; 

	formatex(Data, 63, "Current Origin \r[%i %i %i]\w", floatround(MyOrigin[0]), floatround(MyOrigin[1]), floatround(MyOrigin[2]))
	menu_additem(MenuId, Data, "geto")
	formatex(Data, 63, "Current Angles \r[%i %i %i]\w^n", floatround(MyAngles[0]), floatround(MyAngles[1]), floatround(MyAngles[2]))
	menu_additem(MenuId, Data, "geta")
	
	formatex(Data, 63, "\yUpdate Origin:\w Human Base \r[%i %i %i]\w", floatround(HumanBase_Origin[0]), floatround(HumanBase_Origin[1]), floatround(HumanBase_Origin[2]))
	menu_additem(MenuId, Data, "uphmo")
	formatex(Data, 63, "\yUpdate Origin:\w Zombie Base \r[%i %i %i]\w", floatround(ZombieBase_Origin[0]), floatround(ZombieBase_Origin[1]), floatround(ZombieBase_Origin[2]))
	menu_additem(MenuId, Data, "upzmo")
	
	formatex(Data, 63, "\yUpdate Angles:\w Human Base \r[%i %i %i]\w", floatround(HumanBase_Angles[0]), floatround(HumanBase_Angles[1]), floatround(HumanBase_Angles[2]))
	menu_additem(MenuId, Data, "uphma")
	formatex(Data, 63, "\yUpdate Angles:\w Zombie Base \r[%i %i %i]\w^n", floatround(ZombieBase_Angles[0]), floatround(ZombieBase_Angles[1]), floatround(ZombieBase_Angles[2]))
	menu_additem(MenuId, Data, "upzma")

	menu_additem(MenuId, "\rSave Data\w", "save")
	
	if(pev_valid(id) == 2) set_pdata_int(id, 205, 0, 5)
	menu_display(id, MenuId, 0)
}

public MenuHandle_BaseOrigin(id, Menu, Item)
{
	if((Item == MENU_EXIT) || !is_connected(id))
	{
		menu_destroy(Menu)
		
		MyOrigin[0] = MyOrigin[1] = MyOrigin[2] = 0.0
		MyAngles[0] = MyAngles[1] = MyAngles[2] = 0.0
		
		return
	}

	static Data[6], Name[64], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)
	
	if(equal(Data, "geto"))
	{
		pev(id, pev_origin, MyOrigin)
	} else if(equal(Data, "geta"))
	{
		pev(id, pev_v_angle, MyAngles)
		MyAngles[0] = 0.0
	} else if(equal(Data, "uphmo")) HumanBase_Origin = MyOrigin
	else if(equal(Data, "uphma")) HumanBase_Angles = MyAngles
	else if(equal(Data, "upzmo")) ZombieBase_Origin = MyOrigin
	else if(equal(Data, "upzma")) ZombieBase_Angles = MyAngles
	else if(equal(Data, "save"))
	{
		Save_MapData(id)
	} 
	
	menu_destroy(Menu)
	BaseOrigin_Handle(id)
}

public Save_MapData(id)
{
	new Path[128]; get_configsdir(Path, charsmax(Path))
	new MapName[64]; get_mapname(MapName, 63)
	format(Path, 127, "%s/%s/%s/%s.base", Path, GAME_FOLDER, BASE_CONFIG, MapName)

	static LineData[128]
	
	formatex(LineData, 127, "HUMAN_BASE_ORIGIN = %f %f %f", HumanBase_Origin[0], HumanBase_Origin[1], HumanBase_Origin[2])
	write_file(Path, LineData, 0)
	formatex(LineData, 127, "HUMAN_BASE_ANGLES = %f %f %f", HumanBase_Angles[0], HumanBase_Angles[1], HumanBase_Angles[2])
	write_file(Path, LineData, 1)
	
	formatex(LineData, 127, "ZOMBIE_BASE_ORIGIN = %f %f %f", ZombieBase_Origin[0], ZombieBase_Origin[1], ZombieBase_Origin[2])
	write_file(Path, LineData, 2)
	formatex(LineData, 127, "ZOMBIE_BASE_ANGLES = %f %f %f", ZombieBase_Angles[0], ZombieBase_Angles[1], ZombieBase_Angles[2])
	write_file(Path, LineData, 3)
	
	// Notice
	client_print(id, print_chat, "Map Config Updated!")
}

public Create_TeamBase()
{
	static Float:BarOrigin[3]
	
	// Human Base
	g_HumanBase = create_entity("info_target")
	
	set_pev(g_HumanBase, pev_origin, HumanBase_Origin)
	set_pev(g_HumanBase, pev_angles, HumanBase_Angles)
	
	set_pev(g_HumanBase, pev_classname, BASE_CLASSNAME)
	engfunc(EngFunc_SetModel, g_HumanBase, HumanBase_Model)
	set_pev(g_HumanBase, pev_modelindex, engfunc(EngFunc_ModelIndex, HumanBase_Model))
		
	set_pev(g_HumanBase, pev_gamestate, 1)
	set_pev(g_HumanBase, pev_solid, SOLID_BBOX)
	set_pev(g_HumanBase, pev_movetype, MOVETYPE_NONE)
	set_pev(g_HumanBase, pev_iuser1, 2) // Team
	set_pev(g_HumanBase, pev_iuser2, 0) // Death
	
	new Float:maxs[3] = {40.0, 40.0, 60.0}
	new Float:mins[3] = {-40.0, -40.0, 0.0}
	engfunc(EngFunc_SetSize, g_HumanBase, mins, maxs)
	
	set_pev(g_HumanBase, pev_takedamage, DAMAGE_YES)
	set_pev(g_HumanBase, pev_health, 10000.0 + HUMANBASE_HEALTH)
	
	set_pev(g_HumanBase, pev_animtime, get_gametime())
	set_pev(g_HumanBase, pev_framerate, 1.0)
	set_pev(g_HumanBase, pev_sequence, 0)
	
	set_pev(g_HumanBase, pev_nextthink, get_gametime() + 0.1)
	drop_to_floor(g_HumanBase)
	
	BarOrigin = HumanBase_Origin; BarOrigin[2] += 60
	Create_HealthBar(g_HumanBase, BarOrigin, 2)
	
	// Zombie Base
	g_ZombieBase = create_entity("info_target")
	
	set_pev(g_ZombieBase, pev_origin, ZombieBase_Origin)
	set_pev(g_ZombieBase, pev_angles, ZombieBase_Angles)
	set_pev(g_ZombieBase, pev_v_angle, ZombieBase_Angles)
	
	set_pev(g_ZombieBase, pev_classname, BASE_CLASSNAME)
	engfunc(EngFunc_SetModel, g_ZombieBase, ZombieBase_Model)
	set_pev(g_ZombieBase, pev_modelindex, engfunc(EngFunc_ModelIndex, ZombieBase_Model))
		
	set_pev(g_ZombieBase, pev_gamestate, 1)
	set_pev(g_ZombieBase, pev_solid, SOLID_BBOX)
	set_pev(g_ZombieBase, pev_movetype, MOVETYPE_NONE)
	set_pev(g_ZombieBase, pev_iuser1, 1) // Team
	set_pev(g_ZombieBase, pev_iuser2, 0) // Death
	
	new Float:maxs2[3] = {60.0, 60.0, 240.0}
	new Float:mins2[3] = {-60.0, -60.0, 0.0}
	engfunc(EngFunc_SetSize, g_ZombieBase, mins2, maxs2)
	
	set_pev(g_ZombieBase, pev_takedamage, DAMAGE_YES)
	set_pev(g_ZombieBase, pev_health, 10000.0 + ZOMBIEBASE_HEALTH)
	
	set_pev(g_ZombieBase, pev_animtime, get_gametime())
	set_pev(g_ZombieBase, pev_framerate, 1.0)
	set_pev(g_ZombieBase, pev_sequence, 1)
	
	set_pev(g_ZombieBase, pev_nextthink, get_gametime() + 0.1)
	drop_to_floor(g_ZombieBase)
	
	get_position(g_ZombieBase, 100.0, 0.0, 280.0, BarOrigin)
	Create_HealthBar(g_ZombieBase, BarOrigin, 1)
	
	// Base Creation
	if(!g_BaseCreation)
	{
		g_BaseCreation = 1
		RegisterHamFromEntity(Ham_TraceAttack, g_HumanBase, "fw_Base_TraceAttack_Post", 1)
		RegisterHamFromEntity(Ham_TraceAttack, g_ZombieBase, "fw_Base_TraceAttack_Post", 1)
		
		RegisterHamFromEntity(Ham_TraceAttack, g_HumanBase, "fw_Base_TraceAttack")
		RegisterHamFromEntity(Ham_TraceAttack, g_ZombieBase, "fw_Base_TraceAttack")
		
		ExecuteForward(g_Forward_BaseRegister, g_fwResult, g_HumanBase, TEAM_HUMAN)
		ExecuteForward(g_Forward_BaseRegister, g_fwResult, g_ZombieBase, TEAM_ZOMBIE)
	}
}

public Create_HealthBar(Ent, Float:Origin[3], Team)
{
	new Bar = create_entity("info_target")
	
	entity_set_string(Bar, EV_SZ_classname, "healthbar")

	entity_set_int(Bar, EV_INT_solid, SOLID_NOT)
	entity_set_int(Bar, EV_INT_movetype, MOVETYPE_NOCLIP)
	entity_set_edict(Bar, EV_ENT_owner, Ent)
	entity_set_float(Bar, EV_FL_scale, 0.0)
	entity_set_model(Bar, HEALTHBAR_SPR)

	entity_set_origin(Bar, Origin)
	entity_set_float(Bar, EV_FL_frame, 99.0)
	
	set_pev(Bar, pev_iuser1, Team)
	set_pev(Bar, pev_fuser1, Origin[0])
	set_pev(Bar, pev_fuser2, Origin[1])
	set_pev(Bar, pev_fuser3, Origin[2])
	
	entity_set_float(Bar, EV_FL_nextthink, halflife_time() + 0.01)
}

/* ===============================
------------ FAKEMETA ------------
=================================*/
public fw_MachuPicchu_Think(Ent)
{
	static Owner; Owner = entity_get_edict(Ent, EV_ENT_owner)
	if(!is_valid_ent(Owner))
	{
		remove_entity(Ent)
		return
	}
	
	static Float:Origin[3]; 
	pev(Ent, pev_fuser1, Origin[0])
	pev(Ent, pev_fuser2, Origin[1])
	pev(Ent, pev_fuser3, Origin[2])

	entity_set_origin(Ent, Origin)
	static Float:MaxHealth
	
	if(pev(Ent, pev_iuser1) == 1)
	{
		for(new i = 0; i <= g_MaxPlayers; i++)
		{
			if(!is_connected(i))
				continue
			g_ZombieBar_Dis[i] = entity_range(i, Ent)
		}
		
		MaxHealth = ZOMBIEBASE_HEALTH
		g_ZombieBar = Ent
	} else if(pev(Ent, pev_iuser1) == 2) {
		for(new i = 0; i <= g_MaxPlayers; i++)
		{
			if(!is_connected(i))
				continue
			g_HumanBar_Dis[i] = entity_range(i, Ent)
		}
		
		MaxHealth = HUMANBASE_HEALTH
		g_HumanBar = Ent
	}
	
	new Float:Health = entity_get_float(Owner, EV_FL_health) - 10000.0
	new Float:Frame = (Health / MaxHealth) * 99.0
	
	entity_set_float(Ent, EV_FL_frame, Frame)
	entity_set_float(Ent, EV_FL_nextthink, get_gametime() + 0.01)
}

public fw_AldnoahZero_Think(Ent)
{
	if(!pev_valid(Ent))
		return
	if(pev(Ent, pev_iuser2))
		return
	if((pev(Ent, pev_health) - 10000.0) <= 0.0)
	{
		if(pev(Ent, pev_iuser1) == 1) ZombieBase_Death(Ent)
		else if(pev(Ent, pev_iuser1) == 2) HumanBase_Death(Ent)

		return
	}
	
	entity_set_float(Ent, EV_FL_nextthink, get_gametime() + 0.01)
}

public fw_SwordArtOnline()
{
	forward_return(FMV_STRING, GameName)
	return FMRES_SUPERCEDE
}

// Emit Sound Forward
public fw_GuiltyCrown(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if (sample[0] == 'h' && sample[1] == 'o' && sample[2] == 's' && sample[3] == 't' && sample[4] == 'a' && sample[5] == 'g' && sample[6] == 'e')
		return FMRES_SUPERCEDE;
	if(Get_BitVar(g_IsZombie, id))
	{
		if(Get_BitVar(g_TempingAttack, id))
		{
			if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
			{
				if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
					return FMRES_SUPERCEDE
				if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
				{
					if (sample[17] == 'w')  return FMRES_SUPERCEDE
					else  return FMRES_SUPERCEDE
				}
				if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
					return FMRES_SUPERCEDE;
			}
		}
		
		// Zombie being hit
		if (sample[7] == 'b' && sample[8] == 'h' && sample[9] == 'i' && sample[10] == 't')
		{
			emit_sound(id, channel, ZombiePain[random_num(0, sizeof(ZombiePain) -1)], volume, attn, flags, pitch)
	
			return FMRES_SUPERCEDE;
		}
		
		// Zombie attacks with knife
		if (sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
		{
			if (sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a') // slash
			{
				emit_sound(id, channel, ZombieMiss[random_num(0, sizeof(ZombieMiss) -1)], volume, attn, flags, pitch)
				return FMRES_SUPERCEDE;
			}
			if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't') // hit
			{
				if (sample[17] == 'w') // wall
				{
					emit_sound(id, channel, ZombieWall[random_num(0, sizeof(ZombieWall) -1)], volume, attn, flags, pitch)
					return FMRES_SUPERCEDE;
				} else {
					emit_sound(id, channel, ZombieHit[random_num(0, sizeof(ZombieHit) -1)], volume, attn, flags, pitch)
					return FMRES_SUPERCEDE;
				}
			}
			if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a') // stab
			{
				emit_sound(id, channel, ZombieHit[random_num(0, sizeof(ZombieHit) -1)], volume, attn, flags, pitch)
				return FMRES_SUPERCEDE;
			}
		}
			
		// Zombie dies
		if (sample[7] == 'd' && ((sample[8] == 'i' && sample[9] == 'e') || (sample[8] == 'e' && sample[9] == 'a')))
		{
			emit_sound(id, channel, ZombieDeath[random_num(0, sizeof(ZombieDeath) -1)], volume, attn, flags, pitch)
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

public fw_CapitalSaigon_Post(es_handle,e,ent,host,hostflags,player,pSet)
{
	if(!is_connected(host))
		return
	
	if(ent == g_HumanBar)
	{
		static Float:Scale; Scale = g_HumanBar_Dis[host] / 750.0
		set_es(es_handle, ES_Scale, Scale)
	} else if(ent == g_ZombieBar) {
		static Float:Scale; Scale = g_ZombieBar_Dis[host] / 750.0
		set_es(es_handle, ES_Scale, Scale)
	}
}

public ZombieBase_Death(Ent)
{
	PlaySound(0, ZombieBase_DeathSound[random_num(0, sizeof(ZombieBase_DeathSound) - 1)])
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(entity_range(g_ZombieBase, i) > 640.0)
			continue
			
		Make_PlayerShake(i)
	}
	
	set_task(0.1, "ZombieBase_Effect", TASK_BASEDEATH)
	set_task(3.0, "ZombieBase_Death2", TASK_BASEDEATH)
}

public ZombieBase_Effect()
{
	if(!pev_valid(g_ZombieBase))
		return

	// Special Blood
	static Float:Origin[3]
	
	get_position(g_ZombieBase, 80.0, 0.0, 200.0, Origin);
	MakeBlood(Origin)
	
	get_position(g_ZombieBase, -80.0, 0.0, 200.0, Origin);
	MakeBlood(Origin)
	
	//get_position(g_ZombieBase, 0.0, 60.0, 170.0, Origin);
	//MakeBlood(Origin)
	
	//get_position(g_ZombieBase, 0.0, -60.0, 170.0, Origin);
	//MakeBlood(Origin)
	
	set_task(0.25, "ZombieBase_Effect", TASK_BASEDEATH)
}

public ZombieBase_Death2()
{
	if(!pev_valid(g_ZombieBase))
		return
	
	static Float:Origin[3]
	pev(g_ZombieBase, pev_origin, Origin); Origin[2] += 26.0
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 50.0)
	write_short(g_ZombieDeath_SprId)	// sprite index
	write_byte(35)	// scale in 0.1's
	write_byte(10)	// framerate
	write_byte(TE_EXPLFLAG_NOSOUND)	// flags
	message_end()	
	
	/*
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_BREAKMODEL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 100.0)
	write_coord(256); // size x
	write_coord(256); // size y
	write_coord(256); // size z
	write_coord(random_num(-128,128)); // velocity x
	write_coord(random_num(-128,128)); // velocity y
	write_coord(75); // velocity z
	write_byte(75); // random velocity
	write_short(g_GibModelID2); // model index that you want to break
	write_byte(128); // count
	write_byte(50); // life
	write_byte(0x01); // flags: BREAK_GLASS
	message_end();  */
	
	remove_entity(g_ZombieBase); g_ZombieBase = 0
}

public HumanBase_Death(Ent)
{

	emit_sound(Ent, CHAN_BODY, HumanBase_DeathSound1, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	set_task(0.1, "HumanBase_Effect", TASK_BASEDEATH)
	set_task(2.0, "HumanBase_Death2", TASK_BASEDEATH)
	
	// Game_Ending(7.0, 0, CS_TEAM_T)
}

public HumanBase_Effect()
{
	if(!pev_valid(g_HumanBase))
		return
		
	static Float:Origin[3], Float:Origin2[3]; 
	
	pev(g_HumanBase, pev_origin, Origin); Origin[2] += 26.0
	get_position(g_HumanBase, random_float(-360.0, 360.0), random_float(-360.0, 360.0), 0.0, Origin2)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin2[0])
	engfunc(EngFunc_WriteCoord, Origin2[1])
	engfunc(EngFunc_WriteCoord, Origin2[2])
	write_short(g_iSprLightning)
	write_byte(0)	// starting frame
	write_byte(0)	// frame rate in 0.1's
	write_byte(10)	// life in 0.1's
	write_byte(10)	// line width in 0.1's
	write_byte(100)	// noise amplitude in 0.01's
	write_byte(42)	// Red
	write_byte(85)	// Green
	write_byte(255)	// Blue
	write_byte(255)	// brightness
	write_byte(25)	// scroll speed in 0.1's
	message_end()
	
	set_task(0.1, "HumanBase_Effect", TASK_BASEDEATH)
}

public HumanBase_Death2()
{
	if(!pev_valid(g_HumanBase))
		return
		
	emit_sound(g_HumanBase, CHAN_STATIC, HumanBase_DeathSound2, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	static Float:Origin[3]; pev(g_HumanBase, pev_origin, Origin)
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(entity_range(g_HumanBase, i) > 640.0)
			continue
			
		Make_PlayerShake(i)
		ExecuteHamB(Ham_TakeDamage, i, 0, 0, 99.0, DMG_BLAST)
	}
	
	remove_entity(g_HumanBase); g_HumanBase = 0
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_Exp_SprID)	// sprite index
	write_byte(25)	// scale in 0.1's
	write_byte(30)	// framerate
	write_byte(TE_EXPLFLAG_NOSOUND)	// flags
	message_end()
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_BREAKMODEL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 26.0)
	write_coord(64); // size x
	write_coord(64); // size y
	write_coord(64); // size z
	write_coord(random_num(-64,64)); // velocity x
	write_coord(random_num(-64,64)); // velocity y
	write_coord(25); // velocity z
	write_byte(25); // random velocity
	write_short(g_GibModelID); // model index that you want to break
	write_byte(32); // count
	write_byte(25); // life
	write_byte(0x01); // flags: BREAK_GLASS
	message_end();  
}

public Make_PlayerShake(id)
{
	if(!id) 
	{
		message_begin(MSG_BROADCAST, g_MsgScreenShake)
		write_short(8<<12)
		write_short(5<<12)
		write_short(4<<12)
		message_end()
	} else {
		if(!is_user_connected(id))
			return
			
		message_begin(MSG_BROADCAST, g_MsgScreenShake, _, id)
		write_short(8<<12)
		write_short(5<<12)
		write_short(4<<12)
		message_end()
	}
}

/* ===============================
-------------- HAMS --------------
=================================*/
public fw_CapitalTokyo_Post(id)
{
	if(!is_connected(id)) return
	if(!Get_BitVar(g_Joined, id)) Set_BitVar(g_Joined, id)

	Reset_Player(id, 0)
	Spawn_PlayerRandom(id, cs_get_user_team(id) == CS_TEAM_T ? 1 : 0)
	if(g_MyClass[id] != -1) Reset_PlayerWeapon(id, g_MyClass[id])
	
	if(cs_get_user_team(id) == CS_TEAM_T) Set_BitVar(g_IsZombie, id)
	IG_SpeedReset(id)
	
	if(!is_zombie(id))
	{ // Is Human
		UnSet_BitVar(g_IsZombie, id)
		
		if(g_MyClass[id] == -1) 
		{
			g_MyClass[id] = g_DefaultClass[TEAM_HUMAN]
			ClassSelection_Menu(id)
		} else if(ArrayGetCell(ClassTeam, g_MyClass[id]) != TEAM_HUMAN) { 
			g_MyClass[id] = g_DefaultClass[TEAM_HUMAN]
			ClassSelection_Menu(id)
		} else if(g_MyNextClass[id] != -1) {
			g_MyClass[id] = g_MyNextClass[id]
			g_MyNextClass[id] = -1
		
			Show_WeaponMenu(id, WPN_PRIMARY, 0, g_MyClass[id])
		} else {
			Show_WeaponMenu(id, WPN_PRIMARY, 0, g_MyClass[id])
		}

		Set_PlayerNVG(id, 0, 0, 0, 1)
		fm_set_user_rendering(id)
		cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
		
		set_task(0.01, "Set_LightStart", id)
		IG_Fog(id, g_FogColor[0], g_FogColor[1], g_FogColor[2], ENV_FOG_DENSITY)
		
		Set_PlayerHealth(id, ArrayGetCell(ClassHealth, g_MyClass[id]), 1)
		cs_set_user_armor(id, ArrayGetCell(ClassArmor, g_MyClass[id]), CS_ARMOR_KEVLAR)
		
		g_MaxHealth[id] = ArrayGetCell(ClassHealth, g_MyClass[id])
		
		set_pev(id, pev_gravity, ArrayGetCell(ClassGravity, g_MyClass[id]))
		if(g_GameStart) IG_SpeedSet(id, ArrayGetCell(ClassSpeed, g_MyClass[id]), 1)
		
		fm_strip_user_weapons(id)
		fm_give_item(id, "weapon_knife")
		fm_give_item(id, "weapon_usp")
		give_ammo(id, 1, CSW_USP)
		give_ammo(id, 1, CSW_USP)
		
		static Model[64]; ArrayGetString(ClassModel, g_MyClass[id], Model, 63)
		IG_ModelSet(id, Model, 1)
		
		ExecuteForward(g_Forward_Spawned, g_fwResult, id, g_MyClass[id])
		ExecuteForward(g_Forward_ClassActive, g_fwResult, id, g_MyClass[id])
	} else { // Is Zombie
		Set_BitVar(g_IsZombie, id)
		
		if(g_MyClass[id] == -1) 
		{
			g_MyClass[id] = g_DefaultClass[TEAM_ZOMBIE]
			ClassSelection_Menu(id)
		} else if(ArrayGetCell(ClassTeam, g_MyClass[id]) != TEAM_ZOMBIE) { 
			g_MyClass[id] = g_DefaultClass[TEAM_ZOMBIE]
			ClassSelection_Menu(id)
		} else if(g_MyNextClass[id] != -1) {
			g_MyClass[id] = g_MyNextClass[id]
			g_MyNextClass[id] = -1
		}
		
		ExecuteForward(g_Forward_PreInfect, g_fwResult, id, g_MyClass[id])
		
		Set_PlayerNVG(id, 1, 0, 0, 1)
		fm_set_user_rendering(id)
		cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
		
		set_task(0.01, "Set_LightStart", id)
		IG_Fog(id, g_FogColor[0], g_FogColor[1], g_FogColor[2], ENV_FOG_DENSITY)
		
		Set_PlayerHealth(id, ArrayGetCell(ClassHealth, g_MyClass[id]), 1)
		cs_set_user_armor(id, ArrayGetCell(ClassArmor, g_MyClass[id]), CS_ARMOR_KEVLAR)
		
		g_MaxHealth[id] = ArrayGetCell(ClassHealth, g_MyClass[id])
		
		set_pev(id, pev_gravity, ArrayGetCell(ClassGravity, g_MyClass[id]))
		if(g_GameStart) IG_SpeedSet(id, ArrayGetCell(ClassSpeed, g_MyClass[id]), 1)
		
		fm_strip_user_weapons(id)
		fm_give_item(id, "weapon_knife")
		
		static Model[64]; ArrayGetString(ClassModel, g_MyClass[id], Model, 63)
		IG_ModelSet(id, Model, 1)
		
		// Turn Off the FlashLight
		if (pev(id, pev_effects) & EF_DIMLIGHT) set_pev(id, pev_impulse, 100)
		else set_pev(id, pev_impulse, 0)	
		
		g_AdrenalinePower[id] = 100
		g_MyIncTime[id] = POWER_UPSPEED
		
		ExecuteForward(g_Forward_Infected, g_fwResult, id, g_MyClass[id])
		ExecuteForward(g_Forward_ClassActive, g_fwResult, id, g_MyClass[id])
	}
}

public Reset_PlayerWeapon(id, ClassID)
{
	UnSet_BitVar(g_SelectedPri, id)
	UnSet_BitVar(g_SelectedSec, id)
	UnSet_BitVar(g_SelectedMelee, id)
	UnSet_BitVar(g_SelectedNades, id)
	UnSet_BitVar(g_SelectedBonus, id)
	
	ExecuteForward(g_Forward_Remove, g_fwResult, id, g_SelectedWeapon[id][WPN_PRIMARY], ClassID)
	ExecuteForward(g_Forward_Remove, g_fwResult, id, g_SelectedWeapon[id][WPN_SECONDARY], ClassID)
	ExecuteForward(g_Forward_Remove, g_fwResult, id, g_SelectedWeapon[id][WPN_MELEE], ClassID)
	ExecuteForward(g_Forward_Remove, g_fwResult, id, g_SelectedWeapon[id][WPN_NADES], ClassID)
	ExecuteForward(g_Forward_Remove, g_fwResult, id, g_SelectedWeapon[id][WPN_BONUS], ClassID)
}


public Show_WeaponMenu(id, WpnType, Page, ClassID)
{
	static MenuName[32]
	
	if(WpnType == WPN_PRIMARY) formatex(MenuName, sizeof(MenuName), "Select [Primary Weapon]")
	else if(WpnType == WPN_SECONDARY) formatex(MenuName, sizeof(MenuName), "Select [Secondary Weapon]")
	else if(WpnType == WPN_MELEE) formatex(MenuName, sizeof(MenuName), "Select [Melee Weapon]")
	else if(WpnType == WPN_NADES) formatex(MenuName, sizeof(MenuName), "Select [Grenades]")
	else if(WpnType == WPN_BONUS) formatex(MenuName, sizeof(MenuName), "Select [Bonus Item]")
	
	new Menu = menu_create(MenuName, "MenuHandle_Weapon")

	static WeaponTypeI, WeaponNameN[32], MenuItem[64], ItemID[4], WeaponLevelI
	for(new i = 0; i < g_TotalWeapon; i++)
	{
		WeaponTypeI = ArrayGetCell(WeaponType, i)
		if(WpnType != WeaponTypeI)
			continue
		WeaponTypeI = ArrayGetCell(WeaponClassID, i)
		if(WeaponTypeI != ClassID)
			continue
			
		WeaponLevelI = ArrayGetCell(WeaponLevel, i)
			
		if(!ArrayGetCell(WeaponVip, i))
		{
			ArrayGetString(WeaponName, i, WeaponNameN, sizeof(WeaponNameN))
			if(g_Level[id][g_MyClass[id]] >= WeaponLevelI) formatex(MenuItem, sizeof(MenuItem), "%s", WeaponNameN)
			else formatex(MenuItem, sizeof(MenuItem), "\d%s \r(Lv.%i Only)\w", WeaponNameN, WeaponLevelI)
		} else {
			if(get_user_flags(id) & VIP_FLAG)
			{
				ArrayGetString(WeaponName, i, WeaponNameN, sizeof(WeaponNameN))
				if(g_Level[id][g_MyClass[id]] >= WeaponLevelI) formatex(MenuItem, sizeof(MenuItem), "%s", WeaponNameN)
				else formatex(MenuItem, sizeof(MenuItem), "\d%s \r(Lv.%i Only)\w", WeaponNameN, WeaponLevelI)
			} else {
				ArrayGetString(WeaponName, i, WeaponNameN, sizeof(WeaponNameN))
				formatex(MenuItem, sizeof(MenuItem), "\d%s \r(VIP Only)\w", WeaponNameN)
			}
		}
		num_to_str(i, ItemID, sizeof(ItemID))
		menu_additem(Menu, MenuItem, ItemID)
	}
   
	menu_setprop(Menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, Menu, Page)
}

public MenuHandle_Weapon(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(!is_user_alive(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	static Name[64], Data[16], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	new ItemId = str_to_num(Data)
	new WeaponNameN[32]; ArrayGetString(WeaponName, ItemId, WeaponNameN, sizeof(WeaponNameN))
	new WeaponTypeI, WeaponClassI, WeaponLevelI;
	
	WeaponTypeI = ArrayGetCell(WeaponType, ItemId)
	WeaponClassI = ArrayGetCell(WeaponClassID, ItemId)
	WeaponLevelI = ArrayGetCell(WeaponLevel, ItemId)
	
	if(ArrayGetCell(WeaponVip, ItemId))
	{
		if(!(get_user_flags(id) & VIP_FLAG))
		{
			IG_ClientPrintColor(id, "!tThis weapon is for VIP Only!!n")
			
			menu_destroy(Menu)
			Show_WeaponMenu(id, WeaponTypeI, 0, g_MyClass[id])
		
			return PLUGIN_CONTINUE
		}
	} 
	
	if(WeaponClassI != g_MyClass[id])
	{
		menu_destroy(Menu)
		Show_WeaponMenu(id, WeaponTypeI, 0, g_MyClass[id])
		
		return PLUGIN_CONTINUE
	}
	
	if(g_Level[id][g_MyClass[id]] >= WeaponLevelI)
	{
		Activate_Weapon(id, WeaponTypeI, ItemId)
		Recheck_Weapon(id, g_MyClass[id])
	} else {
		IG_ClientPrintColor(id, "!t%L!n", GAME_LANG, "NOTICE_REQUIRE_LEVEL", WeaponLevelI)
		
		menu_destroy(Menu)
		Show_WeaponMenu(id, WeaponTypeI, 0, g_MyClass[id])
		
		return PLUGIN_CONTINUE
	}

	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public Activate_Weapon(id, WeaponType, ItemID)
{
	if(WeaponType == WPN_PRIMARY) 
	{
		Set_BitVar(g_SelectedPri, id)
		g_SelectedWeapon[id][WPN_PRIMARY] = ItemID
		
		drop_weapons(id, 1)
	} else if(WeaponType == WPN_SECONDARY) {
		Set_BitVar(g_SelectedSec, id)
		g_SelectedWeapon[id][WPN_SECONDARY] = ItemID
		
		drop_weapons(id, 2)
	} else if(WeaponType == WPN_MELEE) {
		Set_BitVar(g_SelectedMelee, id)
		g_SelectedWeapon[id][WPN_MELEE] = ItemID
		
	} else if(WeaponType == WPN_NADES) {
		Set_BitVar(g_SelectedNades, id)
		g_SelectedWeapon[id][WPN_NADES] = ItemID

	} else if(WeaponType == WPN_BONUS) {
		Set_BitVar(g_SelectedBonus, id)
		g_SelectedWeapon[id][WPN_BONUS] = ItemID
	}	
	ExecuteForward(g_Forward_WeaponSelected, g_fwResult, id, ItemID, g_MyClass[id])
}

public Recheck_Weapon(id, ClassID)
{
	if(!Get_BitVar(g_SelectedPri, id)) Show_WeaponMenu(id, WPN_PRIMARY, 0, ClassID)
	else if(!Get_BitVar(g_SelectedSec, id)) Show_WeaponMenu(id, WPN_SECONDARY, 0, ClassID)
	else if(!Get_BitVar(g_SelectedMelee, id)) Show_WeaponMenu(id, WPN_MELEE, 0, ClassID)
	else if(!Get_BitVar(g_SelectedNades, id)) Show_WeaponMenu(id, WPN_NADES, 0, ClassID)
	else if(!Get_BitVar(g_SelectedBonus, id)) Show_WeaponMenu(id, WPN_BONUS, 0, ClassID)
}

public Set_PlayerHealth(id, Health, FullHealth)
{
	set_user_health(id, Health)
	if(FullHealth) set_pev(id, pev_max_health, float(Health))
}

public Set_LightStart(id) SetPlayerLight(id, ENV_LIGHT)

public fw_CapitalJakarta(Victim, Attacker, Float:Damage, Float:Direction[3], Trace, DamageBits)
{
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return HAM_SUPERCEDE
	if(Victim == Attacker)
		return HAM_SUPERCEDE
		
	return HAM_HANDLED
}

public fw_CapitalBangkok(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return HAM_SUPERCEDE
	if(Victim == Attacker)
		return HAM_SUPERCEDE
		
	pev(Victim, pev_velocity, g_Knockback[Victim])
	
	return HAM_HANDLED
}

public fw_CapitalBangkok_Post(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return HAM_SUPERCEDE
	if(Victim == Attacker)
		return HAM_SUPERCEDE
		
	if(is_zombie(Victim) && !is_zombie(Attacker))
	{
		/*
		if(!Inflictor || DamageBits == DMG_GRENADE) return HAM_IGNORED
		
		static Float:push[3]
		pev(Victim, pev_velocity, push)
	
		xs_vec_sub(push, g_Knockback[Victim], push)
		xs_vec_mul_scalar(push, 0.0, push)
		xs_vec_add(push, g_Knockback[Victim], push)
		set_pev(Victim, pev_velocity, push)*/
	}
	
	return HAM_HANDLED
}

public fw_Base_TraceAttack(Victim, Attacker, Float:Damage, Float:Direction[3], Trace, DamageBits)
{
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return HAM_SUPERCEDE
	if(Victim == Attacker)
		return HAM_SUPERCEDE
	//if(g_BaseOver)
	//	return HAM_SUPERCEDE
		
	static Classname[32]; pev(Victim, pev_classname, Classname, 31)
	if(!equal(Classname, BASE_CLASSNAME))
		return HAM_IGNORED
		
	if(pev(Victim, pev_iuser1) == 1)
	{ // Zombie Base
		if(is_alive(Attacker) && Get_BitVar(g_IsZombie, Attacker))
			return HAM_SUPERCEDE
	} else if(pev(Victim, pev_iuser1) == 2) { // Human Base
		if(is_alive(Attacker) && !Get_BitVar(g_IsZombie, Attacker))
			return HAM_SUPERCEDE
	}
		
	return HAM_HANDLED
}

public fw_Base_TraceAttack_Post(Victim, Attacker, Float:Damage, Float:Direction[3], Trace, DamageBits)
{
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return HAM_SUPERCEDE
	if(Victim == Attacker)
		return HAM_SUPERCEDE
		
	static Classname[32]; pev(Victim, pev_classname, Classname, 31)
	if(!equal(Classname, BASE_CLASSNAME))
		return HAM_IGNORED
	if(pev(Victim, pev_health) - 10000.0 <= 0.0)
		return HAM_SUPERCEDE
		
	if(pev(Victim, pev_iuser1) == 1)
	{ // Zombie Base
		// Special Blood
		static Float:Origin[3], Float:EndPoint[3]
		get_tr2(Trace, TR_vecEndPos, EndPoint)
		
		get_position(Victim, 80.0, 0.0, 200.0, Origin); Origin[2] = EndPoint[2]
		MakeBlood(Origin)
		
		get_position(Victim, -80.0, 0.0, 200.0, Origin); Origin[2] = EndPoint[2]
		MakeBlood(Origin)
		
		get_position(Victim, 0.0, 60.0, 170.0, Origin); Origin[2] = EndPoint[2]
		MakeBlood(Origin)
		
		get_position(Victim, 0.0, -60.0, 170.0, Origin); Origin[2] = EndPoint[2]
		MakeBlood(Origin)
		
		emit_sound(Victim, CHAN_BODY, ZombieBase_HitSound[random_num(0, sizeof(ZombieBase_HitSound) - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
		// Is dead?
		if((pev(Victim, pev_health) - 10000.0) - Damage <= 0.0)
		{
			cs_set_user_team(g_BaseZombie, CS_TEAM_T)
			message_begin(MSG_ALL, get_user_msgid("DeathMsg"))
			write_byte(Attacker)
			write_byte(g_BaseZombie)
			write_byte(0)
			write_string("weapon_knife")
			message_end()
			cs_set_user_team(g_BaseZombie, CS_TEAM_SPECTATOR)
			
			Level_GainExp(Attacker, 50, 1)
			
			set_pev(Victim, pev_health, 1000.0)
		}
	} else if(pev(Victim, pev_iuser1) == 2) { // Human Base
		// Is dead?
		if((pev(Victim, pev_health) - 10000.0) - Damage <= 0.0)
		{
			cs_set_user_team(g_BaseHuman, CS_TEAM_CT)
			message_begin(MSG_ALL, get_user_msgid("DeathMsg"))
			write_byte(Attacker)
			write_byte(g_BaseHuman)
			write_byte(0)
			write_string("weapon_knife")
			message_end()
			cs_set_user_team(g_BaseHuman, CS_TEAM_SPECTATOR)
			
			Level_GainExp(Attacker, 50, 1)
			
			set_pev(Victim, pev_health, 1000.0)
		}
	}
		
	return HAM_HANDLED
}

public fw_LoveTohkaChan(entity, caller, activator, use_type)
{
	if (use_type == 2 && is_connected(caller) && is_zombie(caller))
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public fw_LoveAkame_Post(entity, caller, activator, use_type)
{
	if(use_type == 0 && is_connected(caller) && is_zombie(caller))
	{
		static Hand[32], Hand2[64]; ArrayGetString(ClassClawModel, g_MyClass[caller], Hand, sizeof(Hand))
		formatex(Hand2, sizeof(Hand2), "models/zombie_elimination/claw/%s", Hand)
		
		set_pev(caller, pev_viewmodel2, Hand2)
	}
}

public fw_TokyoGhoul(weapon, id)
{
	if(!is_connected(id))
		return HAM_IGNORED
	if(is_zombie(id))
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public fw_InfiniteStratos_Post(weapon_ent)
{
	new owner = fm_cs_get_weapon_ent_owner(weapon_ent)
	if (!is_alive(owner))
		return;
	
	new CSWID; CSWID = cs_get_weapon_id(weapon_ent)
	if(is_zombie(owner))
	{
		if(CSWID == CSW_KNIFE)
		{
			static Hand[32], Hand2[64]; ArrayGetString(ClassClawModel, g_MyClass[owner], Hand, sizeof(Hand))
			formatex(Hand2, sizeof(Hand2), "models/zombie_elimination/claw/%s", Hand)
			
			set_pev(owner, pev_viewmodel2, Hand2)
			set_pev(owner, pev_weaponmodel2, "")
		} else {
			strip_user_weapons(owner)
			give_item(owner, "weapon_knife")
			
			engclient_cmd(owner, "weapon_knife")
		}
	}
}

public fw_CapitalHanoi_Post(Victim, Attacker)
{
	set_task(0.5, "Check_PlayerDeath", Victim+TASK_REVIVE)
	
	if(is_connected(Victim) && is_connected(Attacker))
	{
		if(is_zombie(Victim) && !is_zombie(Attacker)) // Human kills Zombie
		{
			static Sun; Sun = GetClassID("Sun Wukong")
			if(Sun != g_MyClass[Attacker])
				PlaySound(Attacker, Human_Kill[random_num(0, sizeof(Human_Kill) - 1)])
				
			Level_GainExp(Attacker, 10, 1)
		} else if(!is_zombie(Victim) && is_zombie(Attacker)) { // Zombie Kills Human
			Level_GainExp(Attacker, 10, 1)
		}
	}
	
	ExecuteForward(g_Forward_Died, g_fwResult, Victim, Attacker)
		
	// Check Gameplay
	Check_Gameplay()
}

public Check_PlayerDeath(id)
{
	id -= TASK_REVIVE
	
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return
	if(!is_connected(id) || is_alive(id))
		return
	if(!is_zombie(id))
	{
		if(!pev_valid(g_HumanBase)) return
	} else {
		if(!pev_valid(g_ZombieBase)) return
	}
	if(pev(id, pev_deadflag) != 2)
	{
		set_task(0.5, "Check_PlayerDeath", id+TASK_REVIVE)
		return
	}

	// Do Handle Respawn
	set_user_nightvision(id, 0, 0, 1)

	g_RespawnTime[id] = RESPAWN_TIME

	// Check Respawn
	Start_Revive(id+TASK_REVIVE)

	// Show Bar
	message_begin(MSG_ONE_UNRELIABLE, g_MsgBarTime, .player=id)
	write_short(g_RespawnTime[id]+1)
	message_end()
}

public Start_Revive(id)
{
	id -= TASK_REVIVE
	
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return
	if(!is_connected(id) || is_alive(id))
		return
	if(!is_zombie(id))
	{
		if(!pev_valid(g_HumanBase)) return
	} else {
		if(!pev_valid(g_ZombieBase)) return
	}
	if(g_RespawnTime[id] <= 0.0)
	{
		Revive_Now(id+TASK_REVIVE)
		return
	}
		
	client_print(id, print_center, "%L", GAME_LANG, "NOTICE_REVIVING", g_RespawnTime[id])
	
	g_RespawnTime[id]--
	set_task(1.0, "Start_Revive", id+TASK_REVIVE)
}

public Revive_Now(id)
{
	id -= TASK_REVIVE
	
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return
	if(!is_connected(id) || is_alive(id))
		return
		
	// Remove Task
	set_pev(id, pev_deadflag, DEAD_RESPAWNABLE)
	ExecuteHamB(Ham_CS_RoundRespawn, id)
}

public MakeBlood(const Float:Origin[3])
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_BLOODSPRITE)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(m_iBlood[1])
	write_short(m_iBlood[0])
	write_byte(75)
	write_byte(25)
	message_end()
}

public Spawn_PlayerRandom(id, TERRORIST) // TERRORIST = 1, CT = 0
{
	if(TERRORIST)
	{
		if(!g_TSpawn_Count)
			return
		
		static hull, sp_index, i
		
		hull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
		sp_index = random_num(0, g_TSpawn_Count - 1)
		
		for (i = sp_index + 1; /*no condition*/; i++)
		{
			if(i >= g_TSpawn_Count) i = 0
			
			if(is_hull_vacant(g_TSpawn_Point[i], hull))
			{
				engfunc(EngFunc_SetOrigin, id, g_TSpawn_Point[i])
				break
			}
	
			if (i == sp_index) break
		}
	} else {
		if(!g_CTSpawn_Count)
			return
		
		static hull, sp_index, i
		
		hull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
		sp_index = random_num(0, g_CTSpawn_Count - 1)
		
		for (i = sp_index + 1; /*no condition*/; i++)
		{
			if(i >= g_CTSpawn_Count) i = 0
			
			if(is_hull_vacant(g_CTSpawn_Point[i], hull))
			{
				engfunc(EngFunc_SetOrigin, id, g_CTSpawn_Point[i])
				break
			}
	
			if (i == sp_index) break
		}
	}
}

public Collect_SpawnPoint()
{
	static ent; ent = -1
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_start")) != 0)
	{
		// get origin
		static Float:originF[3]
		pev(ent, pev_origin, originF)
		
		g_CTSpawn_Point[g_CTSpawn_Count][0] = originF[0]
		g_CTSpawn_Point[g_CTSpawn_Count][1] = originF[1]
		g_CTSpawn_Point[g_CTSpawn_Count][2] = originF[2]
		
		// increase spawn count
		g_CTSpawn_Count++
		if(g_CTSpawn_Count >= sizeof g_CTSpawn_Point) break;
	}
	
	ent = 1;
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_deathmatch")) != 0)
	{
		// get origin
		static Float:originF[3]
		pev(ent, pev_origin, originF)
		
		g_TSpawn_Point[g_TSpawn_Count][0] = originF[0]
		g_TSpawn_Point[g_TSpawn_Count][1] = originF[1]
		g_TSpawn_Point[g_TSpawn_Count][2] = originF[2]
		
		// increase spawn count
		g_TSpawn_Count++
		if(g_CTSpawn_Count >= sizeof g_TSpawn_Point) break;
	}
}

public Set_PlayerNVG(id, Give, On, OnSound, Ignored_HadNVG)
{
	if(Give) Set_BitVar(g_Has_NightVision, id)
	set_user_nightvision(id, On, OnSound, Ignored_HadNVG)
}

public set_user_nightvision(id, On, OnSound, Ignored_HadNVG)
{
	if(!Ignored_HadNVG)
	{
		if(!Get_BitVar(g_Has_NightVision, id))
			return
	}

	if(On) Set_BitVar(g_UsingNVG, id)
	else UnSet_BitVar(g_UsingNVG, id)
	
	if(OnSound) PlaySound(id, SoundNVG[On])
	set_user_nvision(id)
	
	ExecuteForward(g_Forward_NVG, g_fwResult, id, On)

	return
}

public set_user_nvision(id)
{	
	static Alpha
	if(Get_BitVar(g_UsingNVG, id)) Alpha = g_NVG_Alpha
	else Alpha = 0
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
	write_short(0) // duration
	write_short(0) // hold time
	write_short(0x0004) // fade type
	if(is_zombie(id))
	{
		write_byte(g_NVG_ZombieColor[0]) // r
		write_byte(g_NVG_ZombieColor[1]) // g
		write_byte(g_NVG_ZombieColor[2]) // b
	} else {
		write_byte(g_NVG_HumanColor[0]) // r
		write_byte(g_NVG_HumanColor[1]) // g
		write_byte(g_NVG_HumanColor[2]) // b
	}
	write_byte(Alpha) // alpha
	message_end()
	
	if(Get_BitVar(g_UsingNVG, id)) SetPlayerLight(id, "#")
	else SetPlayerLight(id, ENV_LIGHT)
}

public give_ammo(id, silent, CSWID)
{
	static Amount, Name[32]
		
	switch(CSWID)
	{
		case CSW_P228: {Amount = 13; formatex(Name, sizeof(Name), "357sig");}
		case CSW_SCOUT: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_XM1014: {Amount = 8; formatex(Name, sizeof(Name), "buckshot");}
		case CSW_MAC10: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_AUG: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_ELITE: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_FIVESEVEN: {Amount = 50; formatex(Name, sizeof(Name), "57mm");}
		case CSW_UMP45: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_SG550: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_GALIL: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_FAMAS: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_USP: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_GLOCK18: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_AWP: {Amount = 10; formatex(Name, sizeof(Name), "338magnum");}
		case CSW_MP5NAVY: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_M249: {Amount = 30; formatex(Name, sizeof(Name), "556natobox");}
		case CSW_M3: {Amount = 8; formatex(Name, sizeof(Name), "buckshot");}
		case CSW_M4A1: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_TMP: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_G3SG1: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_DEAGLE: {Amount = 7; formatex(Name, sizeof(Name), "50ae");}
		case CSW_SG552: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_AK47: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_P90: {Amount = 50; formatex(Name, sizeof(Name), "57mm");}
	}
	
	if(!silent) emit_sound(id, CHAN_ITEM, "items/9mmclip1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	ExecuteHamB(Ham_GiveAmmo, id, Amount, Name, 254)
}

public ClassSelection_Menu(id)
{
	static MenuTitle[32]; formatex(MenuTitle, sizeof(MenuTitle), "\y%L\w", GAME_LANG, "MENU_CLASS_SELECTION")
	new MenuId; MenuId = menu_create(MenuTitle, "MenuHandle_ClassSeleciton")
	static Classname[16], MenuItem[64], ClassID[4]

	if(!is_zombie(id))
	{
		for(new i = 0; i < g_TotalClass; i++)
		{
			if(ArrayGetCell(ClassTeam, i) != TEAM_HUMAN)
				continue
				
			if(!ArrayGetCell(ClassVip, i))
			{
				ArrayGetString(ClassName, i, Classname, 15)
				if(g_MyClass[id] != i) formatex(MenuItem, 63, "%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
				else formatex(MenuItem, 63, "\d%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
				
				num_to_str(i, ClassID, 3)
				menu_additem(MenuId, MenuItem, ClassID)
			} else {
				if(get_user_flags(id) & VIP_FLAG)
				{
					ArrayGetString(ClassName, i, Classname, 15)
					if(g_MyClass[id] != i) formatex(MenuItem, 63, "%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
					else formatex(MenuItem, 63, "\d%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
					
					num_to_str(i, ClassID, 3)
					menu_additem(MenuId, MenuItem, ClassID)
				} else {
					ArrayGetString(ClassName, i, Classname, 15)
					if(g_MyClass[id] != i) formatex(MenuItem, 63, "\d%s \r(VIP Only)\w", Classname)
					else formatex(MenuItem, 63, "\d%s \r(VIP Only)\w", Classname)
					
					num_to_str(i, ClassID, 3)
					menu_additem(MenuId, MenuItem, ClassID)
				}
			}
		}
	} else {
		for(new i = 0; i < g_TotalClass; i++)
		{
			if(ArrayGetCell(ClassTeam, i) != TEAM_ZOMBIE)
				continue
			
			if(!ArrayGetCell(ClassVip, i))
			{
				ArrayGetString(ClassName, i, Classname, 15)
				if(g_MyClass[id] != i) formatex(MenuItem, 63, "%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
				else formatex(MenuItem, 63, "\d%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
				
				num_to_str(i, ClassID, 3)
				menu_additem(MenuId, MenuItem, ClassID)
			} else {
				if(get_user_flags(id) & VIP_FLAG)
				{
					ArrayGetString(ClassName, i, Classname, 15)
					if(g_MyClass[id] != i) formatex(MenuItem, 63, "%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
					else formatex(MenuItem, 63, "\d%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
					
					num_to_str(i, ClassID, 3)
					menu_additem(MenuId, MenuItem, ClassID)
				} else {
					ArrayGetString(ClassName, i, Classname, 15)
					if(g_MyClass[id] != i) formatex(MenuItem, 63, "\d%s \r(VIP Only)\w", Classname)
					else formatex(MenuItem, 63, "\d%s \r(VIP Only)\w", Classname)
					
					num_to_str(i, ClassID, 3)
					menu_additem(MenuId, MenuItem, ClassID)
				}
			}
		}
	}
	
	if(pev_valid(id) == PDATA_SAFE) set_pdata_int(id, 205, 0, OFFSET_PLAYER_LINUX)
	menu_display(id, MenuId, 0)
}

public MenuHandle_ClassSeleciton(id, Menu, Item)
{
	if((Item == MENU_EXIT) || !is_alive(id))
	{
		menu_destroy(Menu)
		return
	}

	static Data[6], Name[64], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)
	
	static ClassID; ClassID = str_to_num(Data)
	
	if(ArrayGetCell(ClassVip, ClassID))
	{
		if(!(get_user_flags(id) & VIP_FLAG))
		{
			static Classname[32]; ArrayGetString(ClassName, g_MyClass[id], Classname, 31)
			IG_ClientPrintColor(id, "!t%s is for VIP Only!!n", Classname)
			
			ClassSelection_Menu(id)
			return
		}
	}
	
	if(g_MyClass[id] == ClassID) 
	{
		Show_WeaponMenu(id, WPN_PRIMARY, 0, ClassID)
		return
	}
	
	static ShouldChange; ShouldChange = 0
	
	if(is_zombie(id) && ArrayGetCell(ClassTeam, ClassID) == TEAM_ZOMBIE) ShouldChange = 1
	else if(!is_zombie(id) && ArrayGetCell(ClassTeam, ClassID) == TEAM_HUMAN) ShouldChange = 1
	
	if(!ShouldChange) 
		return
	
	ExecuteForward(g_Forward_ClassUnActive, g_fwResult, id, g_MyClass[id])
	
	g_MyClass[id] = ClassID
	g_MyNextClass[id] = -1
	Player_Reborn(id)
	
	ExecuteForward(g_Forward_ClassActive, g_fwResult, id, ClassID)
	
	// Notice
	static Classname[32]; ArrayGetString(ClassName, g_MyClass[id], Classname, 31)
	IG_ClientPrintColor(id, "!t%L!n", GAME_LANG, "NOTICE_CHANGECLASS", Classname)
}

public Player_Reborn(id)
{
	if(!is_zombie(id))
	{
		Set_PlayerNVG(id, 0, 0, 0, 1)
		fm_set_user_rendering(id)
		
		Set_PlayerHealth(id, ArrayGetCell(ClassHealth, g_MyClass[id]), 1)
		cs_set_user_armor(id, ArrayGetCell(ClassArmor, g_MyClass[id]), CS_ARMOR_KEVLAR)
		
		set_pev(id, pev_gravity, ArrayGetCell(ClassGravity, g_MyClass[id]))
		if(g_GameStart) IG_SpeedSet(id, ArrayGetCell(ClassSpeed, g_MyClass[id]), 1)
		
		static Model[64]; ArrayGetString(ClassModel, g_MyClass[id], Model, 63)
		IG_ModelSet(id, Model, 1)
		
		Show_WeaponMenu(id, WPN_PRIMARY, 0, g_MyClass[id])
	} else {
		ExecuteForward(g_Forward_PreInfect, g_fwResult, id, g_MyClass[id])
		
		Set_PlayerNVG(id, 1, 0, 0, 1)
		fm_set_user_rendering(id)
		cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
		
		Set_PlayerHealth(id, ArrayGetCell(ClassHealth, g_MyClass[id]), 1)
		cs_set_user_armor(id, ArrayGetCell(ClassArmor, g_MyClass[id]), CS_ARMOR_KEVLAR)
		
		set_pev(id, pev_gravity, ArrayGetCell(ClassGravity, g_MyClass[id]))
		if(g_GameStart) IG_SpeedSet(id, ArrayGetCell(ClassSpeed, g_MyClass[id]), 1)
		
		fm_strip_user_weapons(id)
		fm_give_item(id, "weapon_knife")
		
		static Model[64]; ArrayGetString(ClassModel, g_MyClass[id], Model, 63)
		IG_ModelSet(id, Model, 1)
		
		// Turn Off the FlashLight
		if (pev(id, pev_effects) & EF_DIMLIGHT) set_pev(id, pev_impulse, 100)
		else set_pev(id, pev_impulse, 0)	

		ExecuteForward(g_Forward_Infected, g_fwResult, id, g_MyClass[id])
	}
}

/* ===============================
----------- CMD & MSG ------------
=================================*/
public CMD_Radio(id)
{
	if(!is_alive(id))
		return PLUGIN_CONTINUE
	if(is_zombie(id))
		return PLUGIN_HANDLED
		
	return PLUGIN_CONTINUE
}

public CMD_JoinTeam(id)
{
	if(!Get_BitVar(g_Joined, id))
		return PLUGIN_CONTINUE
		
	Open_GameMenu(id)
		
	return PLUGIN_HANDLED
}

public CMD_NightVision(id)
{
	if(!is_zombie(id))
		return PLUGIN_HANDLED
	if(!Get_BitVar(g_Has_NightVision, id))
		return PLUGIN_HANDLED

	if(!Get_BitVar(g_UsingNVG, id)) set_user_nightvision(id, 1, 1, 0)
	else set_user_nightvision(id, 0, 1, 0)

	return PLUGIN_HANDLED;
}

public Message_NoGameNoLife(msg_id, msg_dest, msg_entity)
{
	static szMsg[8];
	get_msg_arg_string(2, szMsg ,7)
	
	if(equal(szMsg, "buyzone") && get_msg_arg_int(1))
	{
		if(pev_valid(msg_entity) != PDATA_SAFE)
			return  PLUGIN_CONTINUE;
	
		set_pdata_int(msg_entity, 235, get_pdata_int(msg_entity, 235) & ~(1<<0))
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public Message_NoAnimeNoLove()
{
	static Team[2]
	get_msg_arg_string(1, Team, charsmax(Team))
	
	switch(Team[0])
	{
		case 'C': set_msg_arg_int(2, get_msg_argtype(2), g_TeamScore[TEAM_HUMAN])
		case 'T': set_msg_arg_int(2, get_msg_argtype(2), g_TeamScore[TEAM_ZOMBIE])
	}
}

public Message_SieSindDasEssen()
{
	return PLUGIN_HANDLED
}

public Message_WirSindDieJaeger()
{
	set_msg_arg_int(1, ARG_BYTE, get_msg_arg_int(1) | (1<<3))
}

public Open_GameMenu(id)
{
	static LangText[64]; formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "GAME_MENU_NAME")
	static Menu; Menu = menu_create(LangText, "MenuHandle_GameMenu")
	
	// 1. Class
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "GAME_MENU_CLASS")
	menu_additem(Menu, LangText, "class")
	
	// 2. Skill
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "GAME_MENU_SKILL")
	menu_additem(Menu, LangText, "skill")
	
	// 3. Help
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "GAME_MENU_HELP")
	menu_additem(Menu, LangText, "help")
	
	menu_setprop(Menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, Menu, 0)
}

public MenuHandle_GameMenu(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(!is_user_connected(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	new Name[64], Data[16], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	if(equal(Data, "class"))
	{
		ClassSelection_Menu2(id)
	} else if(equal(Data, "skill")) {
		Skill_Menu(id)
	} else if(equal(Data, "help")) {
		Open_HelpMenu(id)
	}
	
	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public Open_HelpMenu(id)
{
	static LangText[64]; formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "GAME_MENU_HELP")
	static Menu; Menu = menu_create(LangText, "MenuHandle_HelpMenu")
	
	// 1. Class
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "GAME_HELP_GAMEPLAY")
	menu_additem(Menu, LangText, "gp")
	
	// 2. Skill
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "GAME_HELP_HUMAN")
	menu_additem(Menu, LangText, "hm")
	
	// 3. Help
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "GAME_HELP_ZOMBIE")
	menu_additem(Menu, LangText, "zm")
	
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "GAME_HELP_VIP")
	menu_additem(Menu, LangText, "vip")
	
	menu_setprop(Menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, Menu, 0)
}

public MenuHandle_HelpMenu(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(!is_user_connected(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	new Name[64], Data[16], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	static Motd[2048], Title[32]
	
	if(equal(Data, "gp"))
	{
		formatex(Title, sizeof(Title), "%L", GAME_LANG, "GAME_HELP_TITLE")
		formatex(Motd, sizeof(Motd), "MOTD_GAMEPLAY.txt")//%L", GAME_LANG, "GAME_MOTD_GAMEPLAY")
	} else if(equal(Data, "hm")) {
		formatex(Title, sizeof(Title), "%L", GAME_LANG, "GAME_HELP_TITLE")
		formatex(Motd, sizeof(Motd), "MOTD_HUMAN.txt")//%L", GAME_LANG, "GAME_MOTD_HUMAN")
	} else if(equal(Data, "zm")) {
		formatex(Title, sizeof(Title), "%L", GAME_LANG, "GAME_HELP_TITLE")
		formatex(Motd, sizeof(Motd), "MOTD_ZOMBIE.txt")//%L", GAME_LANG, "GAME_MOTD_ZOMBIE")
	} else if(equal(Data, "vip")) {
		formatex(Title, sizeof(Title), "%L", GAME_LANG, "GAME_HELP_TITLE")
		formatex(Motd, sizeof(Motd), "MOTD_VIP.txt")//%L", GAME_LANG, "GAME_MOTD_VIP")
	}
	
	replace(Motd, sizeof(Motd), "#VERSION#", VERSION)
	replace(Motd, sizeof(Motd), "#AUTHOR#", AUTHOR)
	
	show_motd(id, Motd, Title)
	
	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public ClassSelection_Menu2(id)
{
	static MenuTitle[32]; formatex(MenuTitle, sizeof(MenuTitle), "\y%L\w", GAME_LANG, "MENU_CLASS_SELECTION")
	new MenuId; MenuId = menu_create(MenuTitle, "MenuHandle_ClassSeleciton2")
	static Classname[16], MenuItem[64], ClassID[4]

	if(!is_zombie(id))
	{
		for(new i = 0; i < g_TotalClass; i++)
		{
			if(ArrayGetCell(ClassTeam, i) != TEAM_HUMAN)
				continue
			
			if(!ArrayGetCell(ClassVip, i))
			{
				ArrayGetString(ClassName, i, Classname, 15)
				if(g_MyClass[id] != i) formatex(MenuItem, 63, "%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
				else formatex(MenuItem, 63, "\d%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
				
				num_to_str(i, ClassID, 3)
				menu_additem(MenuId, MenuItem, ClassID)
			} else {
				if(get_user_flags(id) & VIP_FLAG)
				{
					ArrayGetString(ClassName, i, Classname, 15)
					if(g_MyClass[id] != i) formatex(MenuItem, 63, "%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
					else formatex(MenuItem, 63, "\d%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
					
					num_to_str(i, ClassID, 3)
					menu_additem(MenuId, MenuItem, ClassID)
				} else {
					ArrayGetString(ClassName, i, Classname, 15)
					if(g_MyClass[id] != i) formatex(MenuItem, 63, "\d%s \r(VIP Only)\w", Classname)
					else formatex(MenuItem, 63, "\d%s \r(VIP Only)\w", Classname)
					
					num_to_str(i, ClassID, 3)
					menu_additem(MenuId, MenuItem, ClassID)
				}
			}
		}
	} else {
		for(new i = 0; i < g_TotalClass; i++)
		{
			if(ArrayGetCell(ClassTeam, i) != TEAM_ZOMBIE)
				continue
			
			if(!ArrayGetCell(ClassVip, i))
			{
				ArrayGetString(ClassName, i, Classname, 15)
				if(g_MyClass[id] != i) formatex(MenuItem, 63, "%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
				else formatex(MenuItem, 63, "\d%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
				
				num_to_str(i, ClassID, 3)
				menu_additem(MenuId, MenuItem, ClassID)
			} else {
				if(get_user_flags(id) & VIP_FLAG)
				{
					ArrayGetString(ClassName, i, Classname, 15)
					if(g_MyClass[id] != i) formatex(MenuItem, 63, "%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
					else formatex(MenuItem, 63, "\d%s \y(Lv.%i - Exp.%i)\w", Classname, g_Level[id][i], g_Experience[id][i])
					
					num_to_str(i, ClassID, 3)
					menu_additem(MenuId, MenuItem, ClassID)
				} else {
					ArrayGetString(ClassName, i, Classname, 15)
					if(g_MyClass[id] != i) formatex(MenuItem, 63, "\d%s \r(VIP Only)\w", Classname)
					else formatex(MenuItem, 63, "\d%s \r(VIP Only)\w", Classname)
					
					num_to_str(i, ClassID, 3)
					menu_additem(MenuId, MenuItem, ClassID)
				}
			}
		}
	}
	
	if(pev_valid(id) == PDATA_SAFE) set_pdata_int(id, 205, 0, OFFSET_PLAYER_LINUX)
	menu_display(id, MenuId, 0)
}

public MenuHandle_ClassSeleciton2(id, Menu, Item)
{
	if((Item == MENU_EXIT) || !is_alive(id))
	{
		menu_destroy(Menu)
		return
	}

	static Data[6], Name[64], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)
	
	static ClassID; ClassID = str_to_num(Data)
	
	if(ArrayGetCell(ClassVip, ClassID))
	{
		if(!(get_user_flags(id) & VIP_FLAG))
		{
			static Classname[32]; ArrayGetString(ClassName, ClassID, Classname, 31)
			IG_ClientPrintColor(id, "!t%s is for VIP Only!!n", Classname)
			
			ClassSelection_Menu2(id)
			return
		}
	} 
	
	if(g_MyClass[id] == ClassID) return
	
	static ShouldChange; ShouldChange = 0
	
	if(is_zombie(id) && ArrayGetCell(ClassTeam, ClassID) == TEAM_ZOMBIE) ShouldChange = 1
	else if(!is_zombie(id) && ArrayGetCell(ClassTeam, ClassID) == TEAM_HUMAN) ShouldChange = 1
	
	if(!ShouldChange) return
	
	g_MyNextClass[id] = ClassID
	
	static Classname[32]; ArrayGetString(ClassName, ClassID, Classname, 31)
	IG_ClientPrintColor(id, "!t%L!n", GAME_LANG, "NOTICE_CHANGECLASS_NEXT", Classname)
}

public Skill_Menu(id)
{
	static MenuTitle[32]; formatex(MenuTitle, sizeof(MenuTitle), "\y%L\w", GAME_LANG, "MENU_CLASS_SKILL")
	new MenuId; MenuId = menu_create(MenuTitle, "MenuHandle_Skill")
	static Classname[64], MenuItem[64], ClassID[4]
	static Have; Have = 0
	
	for(new i = 0; i < g_TotalSkill; i++)
	{
		if(ArrayGetCell(SkillClass, i) != g_MyClass[id])
			continue
		
		Have = 1
		
		ArrayGetString(SkillName, i, Classname, 63)
		formatex(MenuItem, 63, "%s \y[%i/%i]\w", Classname, g_MySkillPoint[id][i], ArrayGetCell(SkillPoint, i))
		
		num_to_str(i, ClassID, 3)
		menu_additem(MenuId, MenuItem, ClassID)
	}
		
	if(pev_valid(id) == PDATA_SAFE) set_pdata_int(id, 205, 0, OFFSET_PLAYER_LINUX)
	if(Have) menu_display(id, MenuId, 0)
	else {
		menu_destroy(MenuId)
		IG_ClientPrintColor(id, "!t%L!n", GAME_LANG, "NOTICE_NOSKILL")
	}
}

public MenuHandle_Skill(id, Menu, Item)
{
	if((Item == MENU_EXIT) || !is_alive(id))
	{
		menu_destroy(Menu)
		return
	}

	static Data[6], Name[64], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)
	
	static SkillID; SkillID = str_to_num(Data)
	static MaxSP; MaxSP = ArrayGetCell(SkillPoint, SkillID)
	
	if(g_MySkillPoint[id][SkillID] >= MaxSP)
	{
		IG_ClientPrintColor(id, "!t%L!n", GAME_LANG, "NOTICE_MAXSKILL")
		
		menu_destroy(Menu)
		Skill_Menu(id)
		
		return
	}
	
	if(g_SkillPoint[id][g_MyClass[id]] <= 0)
	{
		IG_ClientPrintColor(id, "!t%L!n", GAME_LANG, "NOTICE_NOSP")
		
		menu_destroy(Menu)
		Skill_Menu(id)
		
		return
	}
	
	g_MySkillPoint[id][SkillID]++
	g_SkillPoint[id][g_MyClass[id]]--
	
	ExecuteForward(g_Forward_SkillUp, g_fwResult, id, SkillID, g_MySkillPoint[id][SkillID])
	
	static SkillNamae[32]; ArrayGetString(SkillName, SkillID, SkillNamae, 31)
	IG_ClientPrintColor(id, "!t%L!n", GAME_LANG, "NOTICE_SKILLUP", SkillNamae, g_MySkillPoint[id][SkillID], MaxSP)
	
	PlaySound(id, SkillSound)
	
	menu_destroy(Menu)
	Skill_Menu(id)
}

public Skill_GainPoint(id, Point)
{
	if(g_SkillPoint[id][g_MyClass[id]] >= MAX_SP)
		return
		
	static Plus; Plus = g_SkillPoint[id][g_MyClass[id]]
	g_SkillPoint[id][g_MyClass[id]] = min(Plus + Point, MAX_SP)
}

/* ===============================
------------- SAFETY -------------
=================================*/
public Register_SafetyFunc()
{
	register_event("CurWeapon", "Safety_CurWeapon", "be", "1=1")
	
	RegisterHam(Ham_Spawn, "player", "fw_Safety_Spawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_Safety_Killed_Post", 1)
}

public Register_SafetyFuncBot(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_Safety_Spawn_Post", 1)
	RegisterHamFromEntity(Ham_Killed, id, "fw_Safety_Killed_Post", 1)
}

public Safety_Connected(id)
{
	Set_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_Disconnected(id)
{
	UnSet_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_CurWeapon(id)
{
	if(!is_alive(id))
		return
		
	static CSW; CSW = read_data(2)
	if(g_PlayerWeapon[id] != CSW) g_PlayerWeapon[id] = CSW
}

public fw_Safety_Spawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_IsAlive, id)
}

public fw_Safety_Killed_Post(id)
{
	UnSet_BitVar(g_IsAlive, id)
}

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0

	return 1
}

public is_alive(id)
{
	if(!is_connected(id))
		return 0
	if(!Get_BitVar(g_IsAlive, id))
		return 0
		
	return 1
}

public get_player_weapon(id)
{
	if(!is_alive(id))
		return 0
	
	return g_PlayerWeapon[id]
}


// ===================== STOCK... =======================
// ======================================================
public is_zombie(id)
{
	return Get_BitVar(g_IsZombie, id)
}

stock Get_RandomArray(Array:ArrayName)
{
	return random_num(0, ArraySize(ArrayName) - 1)
}

stock Get_PlayerCount(Alive, Team)
// Alive: 0 - Dead | 1 - Alive | 2 - Both
// Team: 1 - T | 2 - CT
{
	new Flag[4], Flag2[12]
	new Players[32], PlayerNum

	if(!Alive) formatex(Flag, sizeof(Flag), "%sb", Flag)
	else if(Alive == 1) formatex(Flag, sizeof(Flag), "%sa", Flag)
	
	if(Team == 1) 
	{
		formatex(Flag, sizeof(Flag), "%se", Flag)
		formatex(Flag2, sizeof(Flag2), "TERRORIST", Flag)
	} else if(Team == 2) 
	{
		formatex(Flag, sizeof(Flag), "%se", Flag)
		formatex(Flag2, sizeof(Flag2), "CT", Flag)
	}
	
	get_players(Players, PlayerNum, Flag, Flag2)
	
	return PlayerNum
}

stock Get_TotalInPlayer(Alive)
{
	return Get_PlayerCount(Alive, 1) + Get_PlayerCount(Alive, 2)
}


stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}
stock StopSound(id) client_cmd(id, "mp3 stop; stopsound")
stock EmitSound(id, Channel, const Sound[]) emit_sound(id, Channel, Sound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

stock is_hull_vacant(Float:Origin[3], hull)
{
	engfunc(EngFunc_TraceHull, Origin, Origin, 0, hull, 0, 0)
	
	if (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true
	
	return false
}

stock SetPlayerLight(id, const LightStyle[])
{
	if(id != 0)
	{
		message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, .player = id)
		write_byte(0)
		write_string(LightStyle)
		message_end()		
	} else {
		message_begin(MSG_BROADCAST, SVC_LIGHTSTYLE)
		write_byte(0)
		write_string(LightStyle)
		message_end()	
	}
}

stock FixedUnsigned16(Float:flValue, iScale)
{
	new iOutput;

	iOutput = floatround(flValue * iScale);

	if ( iOutput < 0 )
		iOutput = 0;

	if ( iOutput > 0xFFFF )
		iOutput = 0xFFFF;

	return iOutput;
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	// Prevent server crash if entity's private data not initalized
	if (pev_valid(ent) != PDATA_SAFE)
		return -1;
	
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_WEAPON_LINUX);
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(0)
	message_end()	
}

stock Set_Player_NextAttack(id, Float:Time)
{
	if(pev_valid(id) != PDATA_SAFE)
		return
		
	set_pdata_float(id, 83, Time, 5)
}

stock get_position(ent, Float:forw, Float:right, Float:up, Float:vStart[])
{
	if(!pev_valid(ent))
		return
		
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(ent, pev_origin, vOrigin)
	pev(ent, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(ent, pev_angles, vAngle) // if normal entity ,use pev_angles
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

// Drop primary/secondary weapons
stock drop_weapons(id, dropwhat)
{
	// Get user weapons
	static weapons[32], num, i, weaponid
	num = 0 // reset passed weapons count (bugfix)
	get_user_weapons(id, weapons, num)
	
	const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
	const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)
	
	// Loop through them and drop primaries or secondaries
	for (i = 0; i < num; i++)
	{
		// Prevent re-indexing the array
		weaponid = weapons[i]
		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			// Get weapon entity
			static wname[32]; get_weaponname(weaponid, wname, charsmax(wname))

			// Player drops the weapon and looses his bpammo
			engclient_cmd(id, "drop", wname)
		}
	}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
