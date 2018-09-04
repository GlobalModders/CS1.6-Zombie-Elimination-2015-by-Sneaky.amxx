#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <infinitygame>
#include <zombie_eli>
#include <xs>
#include <fun>

#define PLUGIN "[ZELI] Zombie Class: Berserker"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define HEALTH 2000
#define ARMOR 100

#define SETTING_FILE "ZombieClass_Config.ini"
#define LANG_FILE "ZombieElimination.txt"

#define HUD_ADRENALINE_X -1.0
#define HUD_ADRENALINE_Y 0.83

new g_zombieclass
new zclass_name[64], zclass_desc[64]
new Float:zclass_speed, Float:zclass_gravity
new zclass_model[16], zclass_clawmodel[32]

// Skill: Berserk
#define TIME_INTERVAL 0.25
#define TASK_CHECKTIME 3125365

#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_IsUserAlive, g_BotHamRegister, g_IsUserBot, g_ClawA
new g_PlayerKey[33][2], g_SprintingSkill, Float:CheckTime[33], Float:CheckTime2[33], Float:CheckTime3[33]
new g_ClimbingSkill, g_ClimbHigh, g_ClimbPowerReq, g_ClimbSound[64]
new SprintSpeed, SprintPower015S, Array:SprintHeartSound
new g_MsgScreenFade, g_GameStart, g_SkillHud, Float:SprintDefense
new g_WallClimb, g_BerserkDuration, g_PowerRegen

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("DeathMsg", "Event_Death", "a")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
		
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
		
	g_MsgScreenFade = get_user_msgid("ScreenFade")
	g_SkillHud = CreateHudSyncObj(3)
	
	register_clcmd("say /shit", "CMD")
	
}

public CMD(id)
{
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_PLAYER, "ZOMBIE_CLASS_REGULAR_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_PLAYER, "ZOMBIE_CLASS_REGULAR_DESC")
	
	client_print(id, print_chat, "%s %s", zclass_name, zclass_desc)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	
	SprintHeartSound = ArrayCreate(64, 1)
	
	Load_Class_Setting()
	g_zombieclass = ZombieEli_RegisterClass(zclass_name, HEALTH, ARMOR, zclass_gravity, zclass_speed, zclass_model, zclass_clawmodel, TEAM_ZOMBIE, 0)

	// Skill
	g_WallClimb = ZombieEli_RegisterSkill(g_zombieclass, "Wall Climb", 3)
	g_BerserkDuration = ZombieEli_RegisterSkill(g_zombieclass, "Berserk Duration", 3)
	g_PowerRegen = ZombieEli_RegisterSkill(g_zombieclass, "Power Regeneration", 3)
}

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_PLAYER, "ZOMBIE_CLASS_REGULAR_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_PLAYER, "ZOMBIE_CLASS_REGULAR_DESC")
	
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_REGULAR_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_REGULAR_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)

	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_REGULAR_MODEL", zclass_model, sizeof(zclass_model))
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_REGULAR_CLAWMODEL", zclass_clawmodel, sizeof(zclass_clawmodel))

	formatex(Temp, sizeof(Temp), "models/player/%s/%s.mdl", zclass_model, zclass_model)
	engfunc(EngFunc_PrecacheModel, Temp)
	formatex(Temp, sizeof(Temp), "models/zombie_elimination/claw/%s", zclass_clawmodel)
	engfunc(EngFunc_PrecacheModel, Temp)
	
	// Skill
	SprintSpeed = Setting_Load_Int(SETTING_FILE, "Zombie Regular", "SPRINT_SPEED")
	SprintPower015S = Setting_Load_Int(SETTING_FILE, "Zombie Regular", "SPRINT_DECREASE_PER015SEC")
	Setting_Load_String(SETTING_FILE, "Zombie Regular", "SPRINT_DEFENSE", Temp, sizeof(Temp)); SprintDefense = str_to_float(Temp)
	Setting_Load_StringArray(SETTING_FILE, "Zombie Regular", "SPRINT_HEARTSOUND", SprintHeartSound);
	for(new i = 0; i < ArraySize(SprintHeartSound); i++)
	{
		ArrayGetString(SprintHeartSound, i, Temp, sizeof(Temp))
		engfunc(EngFunc_PrecacheSound, Temp)
	}
	
	g_ClimbHigh = Setting_Load_Int(SETTING_FILE, "Zombie Regular", "CLIMB_HIGH")
	g_ClimbPowerReq = Setting_Load_Int(SETTING_FILE, "Zombie Regular", "CLIMB_POWERREQ")
	Setting_Load_String(SETTING_FILE, "Zombie Regular", "CLIMB_SOUND", g_ClimbSound, sizeof(g_ClimbSound)); engfunc(EngFunc_PrecacheSound, g_ClimbSound)
}

public zeli_round_start() g_GameStart = 1
public zeli_round_end() g_GameStart = 0

public zeli_user_spawned(id) Reset_Skill(id)
public zeli_user_infected(id) Reset_Skill(id)

public client_disconnect(id) UnSet_BitVar(g_IsUserAlive, id)
public client_putinserver(id)
{
	UnSet_BitVar(g_IsUserBot, id)
	if(!g_BotHamRegister && is_user_bot(id))
	{
		g_BotHamRegister = 1
		set_task(0.1, "Bot_RegisterHam", id)
	}
	
	if(is_user_bot(id)) Set_BitVar(g_IsUserBot, id)
	
	UnSet_BitVar(g_IsUserAlive, id)
}

public Bot_RegisterHam(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_PlayerSpawn_Post", 1)
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_TakeDamage")
}

public fw_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_IsUserAlive, id)
}

public Event_Death()
{
	static Victim; Victim = read_data(2); UnSet_BitVar(g_IsUserAlive, Victim)
}

public zeli_class_active(id, ClassID)
{
	if(ClassID != g_zombieclass)
		return
		
	Reset_Skill(id)
	
	// Check 
	static SP; SP = ZombieEli_GetSP(id, g_PowerRegen)
	switch(SP)
	{
		case 1: ZombieEli_SetPowerTime(id, 0.4, 0)
		case 2: ZombieEli_SetPowerTime(id, 0.3, 0)
		case 3: ZombieEli_SetPowerTime(id, 0.25, 0)
		default: ZombieEli_SetPowerTime(id, 0.5, 1)
	}
	
	// Check 2
	static Level; Level = ZombieEli_GetLevel(id, g_zombieclass)
	if(Level >= 10)
	{
		set_user_health(id, get_user_health(id) + 600)
		ZombieEli_SetMaxHP(id, get_user_health(id))
		
		set_pev(id, pev_gravity, 0.6)
		IG_SpeedSet(id, zclass_speed + 75.0, 1)
	}
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID == g_zombieclass && NewLevel >= 10)
	{
		set_user_health(id, get_user_health(id) + 600)
		ZombieEli_SetMaxHP(id, get_user_health(id))
		
		set_pev(id, pev_gravity, 0.6)
		IG_SpeedSet(id, zclass_speed + 75.0, 1)
	}
}

public zeli_skillup(id, SkillID, NewPoint)
{
	if(SkillID == g_PowerRegen)
	{
		switch(NewPoint)
		{
			case 1: ZombieEli_SetPowerTime(id, 0.4, 0)
			case 2: ZombieEli_SetPowerTime(id, 0.3, 0)
			case 3: ZombieEli_SetPowerTime(id, 0.25, 0)
			default: ZombieEli_SetPowerTime(id, 0.5, 1)
		}
	}
}

public zeli_class_unactive(id, ClassID) 
{
	if(ClassID != g_zombieclass)
		return
		
	Reset_Skill(id)
}

public Reset_Skill(id)
{
	UnSet_BitVar(g_SprintingSkill, id)
	UnSet_BitVar(g_ClimbingSkill, id)
	
	Reset_Key(id)
}

public client_PreThink(id)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return
		
	static CurButton; CurButton = pev(id, pev_button)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	
	if((CurButton & IN_FORWARD)) 
	{
		if(!g_GameStart)
			return 
		if(!zd_get_user_zombie(id))
			return
		if(zd_get_user_zombieclass(id) != g_zombieclass)
			return
		//if(zd_get_zombie_stun(id) || zd_get_zombie_slowdown(id))
		//	return
		if(Get_BitVar(g_SprintingSkill, id))
		{
			static Float:STime; 
			static SP; SP = ZombieEli_GetSP(id, g_BerserkDuration)
			
			switch(SP)
			{
				case 1: STime = 0.20
				case 2: STime = 0.25
				case 3: STime = 0.30
				default: STime = 0.15
			}
			
			if(get_gametime() - STime > CheckTime[id])
			{
				if(zd_get_user_power(id) <= 0)
				{
					Deactive_SprintSkill(id)
					return
				}
				if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck) || !(pev(id, pev_flags) & FL_ONGROUND))
				{
					Deactive_SprintSkill(id)
					return
				}
				
				// Handle Other
				zd_set_user_power(id, zd_get_user_power(id) - SprintPower015S)
				CheckTime[id] = get_gametime()
			}
		}	
			
		if(Get_BitVar(g_SprintingSkill, id) && (get_gametime() - 0.5 > CheckTime2[id]))
		{
			static String[128]; ArrayGetString(SprintHeartSound, Get_RandomArray(SprintHeartSound), String, sizeof(String))
			emit_sound(id, CHAN_VOICE, String, 1.0, ATTN_NORM, 0, PITCH_NORM)

			zd_set_fakeattack(id)
			
			set_pev(id, pev_framerate, 2.0)
			set_pev(id, pev_sequence, 111)
			
			CheckTime2[id] = get_gametime()
		}
		
		if(OldButton & IN_FORWARD)
			return
		
		if(!task_exists(id+TASK_CHECKTIME))
		{
			g_PlayerKey[id][0] = 'w'
			
			remove_task(id+TASK_CHECKTIME)
			set_task(TIME_INTERVAL, "Recheck_Key", id+TASK_CHECKTIME)
		} else {
			g_PlayerKey[id][1] = 'w'
		}
	} else {
		if(OldButton & IN_FORWARD)
		{
			Deactive_SprintSkill(id)
		}
		
		return
	}
	
	if(equali(g_PlayerKey[id], "ww"))
	{
		Reset_Key(id)
		Active_SprintSkill(id)
	}

	return
}

public fw_CmdStart(id, UCHandle, Seed)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return
	if(Get_BitVar(g_IsUserBot, id))
		return
	if(!zd_get_user_zombie(id))
		return
	if(zd_get_user_zombieclass(id) != g_zombieclass)
		return	
	
	static CurButton; CurButton = get_uc(UCHandle, UC_Buttons)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	
	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		static SP; SP = ZombieEli_GetSP(id, g_WallClimb)
		static Reduce;
		switch(SP)
		{
			case 1: Reduce = 1
			case 2: Reduce = 2
			case 3: Reduce = 5
			default: Reduce = 0
		}
		
		static Power; Power = g_ClimbPowerReq - Reduce
		
		static Time; Time = zd_get_user_power(id) / Power
		static Level; Level = ZombieEli_GetLevel(id, g_zombieclass)
		
		if(Level < 10)
		{
			if(Time >= 1)
			{
				static SkillName[16]; formatex(SkillName, sizeof(SkillName), "%L", LANG_PLAYER, "ZOMBIE_CLASS_REGULAR_SKILL")
				
				set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.02, 0, 1.1, 1.1, 0.0, 0.0)
				ShowSyncHudMsg(id, g_SkillHud, "%L", LANG_PLAYER, "HUD_ZOMBIESKILL", SkillName, Time)
			}
		} else {
			if(Time >= 1)
			{
				static SkillName[16]; formatex(SkillName, sizeof(SkillName), "%L", LANG_PLAYER, "ZOMBIE_CLASS_REGULAR_SKILL")
				
				set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.04, 0, 1.1, 1.1, 0.0, 0.0)
				ShowSyncHudMsg(id, g_SkillHud, "%L^nUltimate Skill: Undead Potential (Passive)", LANG_PLAYER, "HUD_ZOMBIESKILL", SkillName, Time)
			} else {
				set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.02, 0, 1.1, 1.1, 0.0, 0.0)
				ShowSyncHudMsg(id, g_SkillHud, "Ultimate Skill: Undead Potential (Passive)")
			}
		}
		
		CheckTime3[id] = get_gametime()
	}	
	
	if((CurButton & IN_JUMP) && !(pev(id, pev_oldbuttons) & IN_JUMP))
	{
		if(Get_BitVar(g_SprintingSkill, id)) Deactive_SprintSkill(id)
	}	
	
	if((CurButton & IN_ATTACK2))
	{
		CurButton &= ~IN_ATTACK2
		set_uc(UCHandle, UC_Buttons, CurButton)
		
		set_pdata_float(id, 83, 1.0, 5)
		if(!g_GameStart)
			return 

		if(get_gametime() - 0.5 > CheckTime[id])
		{
			static SP; SP = ZombieEli_GetSP(id, g_WallClimb)
			static Reduce;
			switch(SP)
			{
				case 1: Reduce = 1
				case 2: Reduce = 2
				case 3: Reduce = 5
				default: Reduce = 0
			}
			
			static Power; Power = g_ClimbPowerReq - Reduce
	
			if(zd_get_user_power(id) < Power)
			{
				if(Get_BitVar(g_ClimbingSkill, id)) Deactive_ClimbSkill(id, 1)
				
				CheckTime[id] = get_gametime()
				return
			}
			
			ClimbHandle(id, Power)
			
			CheckTime[id] = get_gametime()
		}
	} else {
		if(OldButton & IN_ATTACK2)
		{
			if(Get_BitVar(g_ClimbingSkill, id)) Deactive_ClimbSkill(id, 1)
		}
	}
}

// Emit Sound Forward
public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if (sample[0] == 'h' && sample[1] == 'o' && sample[2] == 's' && sample[3] == 't' && sample[4] == 'a' && sample[5] == 'g' && sample[6] == 'e')
		return FMRES_SUPERCEDE;
	if(ZombieEli_IsZombie(id) && ZombieEli_GetClass(id) == g_zombieclass)
	{
		// Zombie attacks with knife
		if (sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
		{
			if (sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a') // slash
			{
				if(!Get_BitVar(g_ClawA, id))
				{
					Set_WeaponAnim(id, 1)
					Set_BitVar(g_ClawA, id)
				} else {
					Set_WeaponAnim(id, 2)
					UnSet_BitVar(g_ClawA, id)
				}
			}
			if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't') // hit
			{
				if (sample[17] == 'w') // wall
				{
					if(!Get_BitVar(g_ClawA, id))
					{
						Set_WeaponAnim(id, 1)
						Set_BitVar(g_ClawA, id)
					} else {
						Set_WeaponAnim(id, 2)
						UnSet_BitVar(g_ClawA, id)
					}
				} else {
					if(!Get_BitVar(g_ClawA, id))
					{
						Set_WeaponAnim(id, 1)
						Set_BitVar(g_ClawA, id)
					} else {
						Set_WeaponAnim(id, 2)
						UnSet_BitVar(g_ClawA, id)
					}
				}
			}
			
		}
	}

	return FMRES_IGNORED;
}

public fw_TakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!g_GameStart)
		return HAM_IGNORED
	if(!zd_get_user_zombie(Victim) || zd_get_user_zombie(Attacker))
		return HAM_IGNORED
	if(zd_get_user_zombieclass(Victim) != g_zombieclass)
		return HAM_IGNORED
	if(!Get_BitVar(g_SprintingSkill, Victim))
		return HAM_IGNORED
		
	Damage /= SprintDefense
	SetHamParamFloat(4, Damage)
		
	return HAM_HANDLED
}

public ClimbHandle(id, Power)
{
	static Float:Origin1[3], Float:Origin2[3], Float:Distance
	pev(id, pev_origin, Origin1)
	fm_get_aim_origin(id, Origin2)
	Distance = get_distance_f(Origin1, Origin2)
	
	if(Distance > 48.0) return
	
	zd_set_user_power(id, zd_get_user_power(id) - Power)
	
	// Climb Action
	if(!Get_BitVar(g_ClimbingSkill, id))
	{
		Set_WeaponAnim(id, 6)
		Set_BitVar(g_ClimbingSkill, id)
	} else {
		Set_WeaponAnim(id, 8)
	}
	
	zd_set_fakeattack(id)
	set_pev(id, pev_framerate, 0.25)
	set_pev(id, pev_sequence, 113)
	
	Origin2 = Origin1; Origin2[2] += float(g_ClimbHigh)
	static Float:Velocity[3]; Get_SpeedVector(Origin1, Origin2, 500.0, Velocity)
	
	set_pev(id, pev_velocity, Velocity)
	emit_sound(id, CHAN_STATIC, g_ClimbSound, 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public Deactive_ClimbSkill(id, Alive)
{
	zd_set_fakeattack(id)
	Set_WeaponAnim(id, 7)
	
	UnSet_BitVar(g_ClimbingSkill, id)
}

public Recheck_Key(id)
{
	id -= TASK_CHECKTIME
	
	if(!is_user_connected(id))
		return
		
	Reset_Key(id)
}

public Reset_Key(id)
{
	g_PlayerKey[id][0] = 0
	g_PlayerKey[id][1] = 0
}

public Active_SprintSkill(id)
{
	Set_BitVar(g_SprintingSkill, id)
	
	// ScreenFade
	message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
	write_short(0) // duration
	write_short(0) // hold time
	write_short(0x0004) // fade type
	write_byte(255) // r
	write_byte(0) // g
	write_byte(0) // b
	write_byte(35) // alpha
	message_end()

	// Set Speed
	IG_SpeedSet(id, float(SprintSpeed), 1)
}

public Deactive_SprintSkill(id)
{
	if(!Get_BitVar(g_SprintingSkill, id))
		return
	
	UnSet_BitVar(g_SprintingSkill, id)
	
	// Reset
	message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
	write_short(0) // duration
	write_short(0) // hold time
	write_short(0x0000) // fade type
	write_byte(0) // r
	write_byte(0) // g
	write_byte(0) // b
	write_byte(0) // alpha
	message_end()
	
	// Speed
	IG_SpeedSet(id, zclass_speed, 1)
}

stock Setting_Load_Int(const filename[], const setting_section[], setting_key[])
{
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty filename")
		return false;
	}
	
	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty section/key")
		return false;
	}
	
	// Build customization file path
	new path[128]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/ZombieElimination/%s", path, filename)
	
	// File not present
	if (!file_exists(path))
	{
		static DataA[128]; formatex(DataA, sizeof(DataA), "[ZD] Can't load: %s", path)
		set_fail_state(DataA)
		
		return false;
	}
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	// File can't be opened
	if (!file)
		return false;
	
	// Set up some vars to hold parsing info
	new linedata[1024], section[64]
	
	// Seek to setting's section
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				break;
		}
	}
	
	// Section not found
	if (!equal(section, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Set up some vars to hold parsing info
	new key[64], current_value[32]
	
	// Seek to setting's key
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key and value
		strtok(linedata, key, charsmax(key), current_value, charsmax(current_value), '=')
		
		// Trim spaces
		trim(key)
		trim(current_value)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
		{
			static return_value
			// Return int by reference
			return_value = str_to_num(current_value)
			
			// Values succesfully retrieved
			fclose(file)
			return return_value
		}
	}
	
	// Key not found
	fclose(file)
	return false;
}

stock Setting_Load_StringArray(const filename[], const setting_section[], setting_key[], Array:array_handle)
{
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty filename")
		return false;
	}

	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty section/key")
		return false;
	}
	
	if (array_handle == Invalid_Array)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Array not initialized")
		return false;
	}
	
	// Build customization file path
	new path[128]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/ZombieElimination/%s", path, filename)
	
	// File not present
	if (!file_exists(path))
	{
		static DataA[128]; formatex(DataA, sizeof(DataA), "[ZD] Can't load: %s", path)
		set_fail_state(DataA)
		
		return false;
	}
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	// File can't be opened
	if (!file)
		return false;
	
	// Set up some vars to hold parsing info
	new linedata[1024], section[64]
	
	// Seek to setting's section
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				break;
		}
	}
	
	// Section not found
	if (!equal(section, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Set up some vars to hold parsing info
	new key[64], values[1024], current_value[128]
	
	// Seek to setting's key
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key and values
		strtok(linedata, key, charsmax(key), values, charsmax(values), '=')
		
		// Trim spaces
		trim(key)
		trim(values)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
		{
			// Parse values
			while (values[0] != 0 && strtok(values, current_value, charsmax(current_value), values, charsmax(values), ','))
			{
				// Trim spaces
				trim(current_value)
				trim(values)
				
				// Add to array
				ArrayPushString(array_handle, current_value)
			}
			
			// Values succesfully retrieved
			fclose(file)
			return true;
		}
	}
	
	// Key not found
	fclose(file)
	return false;
}

stock Setting_Load_String(const filename[], const setting_section[], setting_key[], return_string[], string_size)
{
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty filename")
		return false;
	}

	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty section/key")
		return false;
	}
	
	// Build customization file path
	new path[128]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/ZombieElimination/%s", path, filename)
	
	// File not present
	if (!file_exists(path))
	{
		static DataA[128]; formatex(DataA, sizeof(DataA), "[ZD] Can't load: %s", path)
		set_fail_state(DataA)
		
		return false;
	}
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	// File can't be opened
	if (!file)
		return false;
	
	// Set up some vars to hold parsing info
	new linedata[1024], section[64]
	
	// Seek to setting's section
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				break;
		}
	}
	
	// Section not found
	if (!equal(section, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Set up some vars to hold parsing info
	new key[64], current_value[128]
	
	// Seek to setting's key
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key and value
		strtok(linedata, key, charsmax(key), current_value, charsmax(current_value), '=')
		
		// Trim spaces
		trim(key)
		trim(current_value)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
		{
			formatex(return_string, string_size, "%s", current_value)
			
			// Values succesfully retrieved
			fclose(file)
			return true;
		}
	}
	
	// Key not found
	fclose(file)
	return false;
}

stock Get_RandomArray(Array:ArrayName)
{
	return random_num(0, ArraySize(ArrayName) - 1)
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(0)
	message_end()	
}

stock Get_SpeedVector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= (num * 2.0)
	new_velocity[1] *= (num * 2.0)
	new_velocity[2] *= (num / 2.0)
}  

public zd_get_user_zombie(id)
{
	return ZombieEli_IsZombie(id)
}

public zd_get_user_zombieclass(id)
{
	return ZombieEli_GetClass(id)
}

public zd_get_user_power(id)
{
	return ZombieEli_PowerGet(id)
}

public zd_set_user_power(id, Power)
{
	ZombieEli_PowerSet(id, Power)
}

public zd_set_fakeattack(id) ZombieEli_SetFakeAttack(id)
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3076\\ f0\\ fs16 \n\\ par }
*/
