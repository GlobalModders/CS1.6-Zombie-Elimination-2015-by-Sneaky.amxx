#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombie_eli>
#include <infinitygame>

#define PLUGIN "[ZD] Zombie Class: Light"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define GAME_FOLDER "zombie_elimination"

#define HEALTH 1500
#define ARMOR 50

#define SETTING_FILE "ZombieClass_Config.ini"
#define LANG_FILE "ZombieElimination.txt"

#define TIME_INTERVAL 0.25
#define TASK_CHECKTIME 3125365

#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

#define HUD_ADRENALINE_X -1.0
#define HUD_ADRENALINE_Y 0.83

new g_zombieclass
new zclass_name[16], zclass_desc[32]
new Float:zclass_speed, Float:zclass_gravity
new zclass_model[16], zclass_clawmodel[32]

new g_IsUserAlive, g_BotHamRegister, g_IsUserBot, g_ClawA
new Float:InvisibleTime, InvisibleDecPer015S, Invisible_ClawModel[64], Invisible_Sound[64]
new LeapPower, LeapHigh, LeapSound[64]

new g_InvisibleSkill, g_Leaping, Float:CheckTime[33], Float:CheckTime2[33], Float:CheckTime3[33], g_PlayerKey[33][2]
new g_MsgScreenFade, g_GameStart, g_SkillHud, g_InvisiblePercent[33]
new g_Pounce, g_Invisibility, g_PowerRegen

// Auto Skill
#define AUTO_TIME random_float(15.0, 30.0)
#define TASK_AUTO 4965

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("DeathMsg", "Event_Death", "a")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	g_SkillHud = CreateHudSyncObj(3)
	g_MsgScreenFade = get_user_msgid("ScreenFade")
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	
	Load_Class_Setting()
	g_zombieclass = ZombieEli_RegisterClass(zclass_name, HEALTH, ARMOR, zclass_gravity, zclass_speed, zclass_model, zclass_clawmodel, TEAM_ZOMBIE, 0)

	// Skill
	g_Pounce = ZombieEli_RegisterSkill(g_zombieclass, "Pounce", 3)
	g_Invisibility = ZombieEli_RegisterSkill(g_zombieclass, "Invisibility", 3)
	g_PowerRegen = ZombieEli_RegisterSkill(g_zombieclass, "Power Regeneration", 3)
}

public Load_Class_Setting()
{
	static Temp[8]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_PLAYER, "ZOMBIE_CLASS_LIGHT_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_PLAYER, "ZOMBIE_CLASS_LIGHT_DESC")
	
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_LIGHT_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_LIGHT_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)

	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_LIGHT_MODEL", zclass_model, sizeof(zclass_model))
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_LIGHT_CLAWMODEL", zclass_clawmodel, sizeof(zclass_clawmodel))
	// Skill
	Setting_Load_String(SETTING_FILE, "Zombie Light", "INVISIBLE_TIME", Temp, sizeof(Temp)); InvisibleTime = str_to_float(Temp)
	InvisibleDecPer015S = Setting_Load_Int(SETTING_FILE, "Zombie Light", "INVISIBLE_DECREASE_PER015SEC")
	Setting_Load_String(SETTING_FILE, "Zombie Light", "INVISIBLE_CLAWMODEL", Invisible_ClawModel, sizeof(Invisible_ClawModel))
	Setting_Load_String(SETTING_FILE, "Zombie Light", "INVISIBLE_SOUND", Invisible_Sound, sizeof(Invisible_Sound))
		
	LeapPower = Setting_Load_Int(SETTING_FILE, "Zombie Light", "LEAP_POWER")
	LeapHigh = Setting_Load_Int(SETTING_FILE, "Zombie Light", "LEAP_HIGH")
	Setting_Load_String(SETTING_FILE, "Zombie Light", "LEAP_SOUND", LeapSound, sizeof(LeapSound))
	
	// Precache 
	engfunc(EngFunc_PrecacheModel, Invisible_ClawModel)
	engfunc(EngFunc_PrecacheSound, Invisible_Sound)
	engfunc(EngFunc_PrecacheSound, LeapSound)
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
}

public fw_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	remove_task(id+TASK_AUTO)
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
	//if(is_user_bot(id)) set_task(AUTO_TIME, "AutoTime", id+TASK_AUTO)
	
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
		set_pev(id, pev_gravity, 0.4)
		IG_SpeedSet(id, zclass_speed + 95.0, 1)
	}
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID == g_zombieclass && NewLevel >= 10)
	{
		set_pev(id, pev_gravity, 0.6)
		IG_SpeedSet(id, zclass_speed + 95.0, 1)
	}
}

public zeli_class_unactive(id, ClassID) 
{
	if(ClassID != g_zombieclass)
		return
		
	Reset_Skill(id)
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

public Reset_Skill(id)
{
	UnSet_BitVar(g_InvisibleSkill, id)
	UnSet_BitVar(g_Leaping, id)
	g_InvisiblePercent[id] = 0
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
			
		static Float:STime; 
		static SP; SP = ZombieEli_GetSP(id, g_Invisibility)
		
		switch(SP)
		{
			case 1: STime = 0.20
			case 2: STime = 0.25
			case 3: STime = 0.30
			default: STime = 0.15
		}
			
		if(Get_BitVar(g_InvisibleSkill, id) && (get_gametime() - STime > CheckTime[id]))
		{
			if(zd_get_user_power(id) <= 0)
			{
				Deactive_InvisibleSkill(id)
				return
			}
			if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck) || !(pev(id, pev_flags) & FL_ONGROUND))
			{
				Deactive_InvisibleSkill(id)
				return
			}
			
			static Float:RenderAmt; pev(id, pev_renderamt, RenderAmt)
			if(RenderAmt > 0) 
			{
				RenderAmt -= ((255.0 / InvisibleTime) * STime)
				if(RenderAmt < 0.0) 
				{
					RenderAmt = 0.0
					set_pev(id, pev_viewmodel2, Invisible_ClawModel)
				}
				
				g_InvisiblePercent[id] = floatround(((255.0 - RenderAmt) / 255.0) * 100.0)
				set_pev(id, pev_renderamt, RenderAmt)
			}
			
			// Handle Other
			zd_set_user_power(id, zd_get_user_power(id) - InvisibleDecPer015S)
			
			CheckTime[id] = get_gametime()
		}	
			
		if(Get_BitVar(g_InvisibleSkill, id) && (get_gametime() - 0.675 > CheckTime2[id]))
		{
			zd_set_fakeattack(id)
			
			//set_pev(id, pev_framerate, 2.0)
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
			Deactive_InvisibleSkill(id)
		}
		
		return
	}
	
	if(equali(g_PlayerKey[id], "ww"))
	{
		Reset_Key(id)
		Active_InvisibleSkill(id)
	}

	return
}

public client_PostThink(id)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return
	if(!Get_BitVar(g_Leaping, id))
		return
	if(!zd_get_user_zombie(id))
		return
		
	static Float:flFallVelocity; flFallVelocity = get_pdata_float(id, 251, 5)
        
	if(flFallVelocity && pev(id, pev_flags) & FL_ONGROUND)
	{
		Set_WeaponAnim(id, 7)
		UnSet_BitVar(g_Leaping, id)
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
	
	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		static SP; SP = ZombieEli_GetSP(id, g_Pounce)
		static Reduce;
		switch(SP)
		{
			case 1: Reduce = 10
			case 2: Reduce = 20
			case 3: Reduce = 30
			default: Reduce = 0
		}
		
		static Power; Power = LeapPower - Reduce
		
		static Time; Time = zd_get_user_power(id) / Power
		static Hud[128], SkillName[16]; 
		static Level; Level = ZombieEli_GetLevel(id, g_zombieclass)
		
		formatex(SkillName, sizeof(SkillName), "%L", LANG_PLAYER, "ZOMBIE_CLASS_LIGHT_SKILL")
		formatex(Hud, sizeof(Hud), "%L", LANG_PLAYER, "HUD_ZOMBIESKILL_INV", g_InvisiblePercent[id])
		
		if(Time >= 1) formatex(Hud, sizeof(Hud), "%s^n%L", Hud, LANG_PLAYER, "HUD_ZOMBIESKILL", SkillName, Time)

		if(Level >= 10)
		{
			formatex(Hud, sizeof(Hud), "%s^nUltimate Skill: Light on the feet (Passive)", Hud)
			
			set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.06, 0, 1.1, 1.1, 0.0, 0.0)
			ShowSyncHudMsg(id, g_SkillHud, Hud)
		} else {
			formatex(Hud, sizeof(Hud), "%s", Hud)
			
			set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.04, 0, 1.1, 1.1, 0.0, 0.0)
			ShowSyncHudMsg(id, g_SkillHud, Hud)
		}
		
		CheckTime3[id] = get_gametime()
	}	
	
	if((CurButton & IN_ATTACK2))
	{
		CurButton &= ~IN_ATTACK2
		set_uc(UCHandle, UC_Buttons, CurButton)

		if(!g_GameStart)
		{
			set_pdata_float(id, 83, 0.5, 5)
			return 	
		}
		if(Get_BitVar(g_InvisibleSkill, id))
		{
			set_pdata_float(id, 83, 0.5, 5)
			return	
		}
		
		static SP; SP = ZombieEli_GetSP(id, g_Pounce)
		static Reduce;
		switch(SP)
		{
			case 1: Reduce = 10
			case 2: Reduce = 20
			case 3: Reduce = 30
			default: Reduce = 0
		}
		
		static Power; Power = LeapPower - Reduce
		
		if(zd_get_user_power(id) < Power)
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck) || !(pev(id, pev_flags) & FL_ONGROUND))
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		if(get_pdata_float(id, 83, 5) > 0.0)
			return

		Active_Leap(id, Power)
	} 
	
}

public Reset_Key(id)
{
	g_PlayerKey[id][0] = 0
	g_PlayerKey[id][1] = 0
}

public Recheck_Key(id)
{
	id -= TASK_CHECKTIME
	
	if(!is_user_connected(id))
		return
		
	Reset_Key(id)
}

public Active_InvisibleSkill(id)
{
	Set_BitVar(g_InvisibleSkill, id)
	emit_sound(id, CHAN_VOICE, Invisible_Sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
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
	
	set_pev(id, pev_rendermode, kRenderTransAlpha)
	set_pev(id, pev_renderfx, kRenderFxNone)
	set_pev(id, pev_renderamt, 255.0)
}

public Deactive_InvisibleSkill(id)
{
	if(!Get_BitVar(g_InvisibleSkill, id))
		return
	
	UnSet_BitVar(g_InvisibleSkill, id)
	g_InvisiblePercent[id] = 0
	
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

	set_pev(id, pev_rendermode, kRenderNormal)
	
	static ClawModel[64]; formatex(ClawModel, sizeof(ClawModel), "models/%s/claw/%s", GAME_FOLDER, zclass_clawmodel)
	set_pev(id, pev_viewmodel2, ClawModel)
}

public Active_Leap(id, Power)
{
	static Float:Origin1[3], Float:Origin2[3]
	pev(id, pev_origin, Origin1)

	Set_BitVar(g_Leaping, id)
	
	zd_set_user_power(id, zd_get_user_power(id) - Power)
	zd_set_fakeattack(id)
	
	// Climb Action
	Set_WeaponAnim(id, 6)
	set_pev(id, pev_framerate, 0.5)
	set_pev(id, pev_sequence, 113)
	
	set_pdata_float(id, 83, 3.0, 5)
	
	get_position(id, 180.0, 0.0, 650.0, Origin2)
	static Float:Velocity[3]; Get_SpeedVector(Origin1, Origin2, float(LeapHigh), Velocity)
	
	set_pev(id, pev_velocity, Velocity)
	emit_sound(id, CHAN_STATIC, LeapSound, 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public zd_user_nvg(id, On, Zombie)
{
	if(!Zombie) return
	if(!Get_BitVar(g_InvisibleSkill, id))
		return
	
	if(!On)
	{
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
	}
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

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs, vUp) //for player
	xs_vec_add(vOrigin, vUp, vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
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
