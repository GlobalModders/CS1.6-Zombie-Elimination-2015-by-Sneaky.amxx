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

#define PLUGIN "[ZELI] Zombie Class: Voodoo"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define HEALTH 2000
#define ARMOR 100

#define SETTING_FILE "ZombieClass_Config.ini"
#define LANG_FILE "ZombieElimination.txt"

#define HUD_ADRENALINE_X -1.0
#define HUD_ADRENALINE_Y 0.83

new g_zombieclass
new zclass_name[16], zclass_desc[32]
new Float:zclass_speed, Float:zclass_gravity
new zclass_model[32], zclass_clawmodel[32]

#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_IsUserAlive, g_BotHamRegister, g_IsUserBot
new Float:RegenTime[33], Float:TeamHealTime[33]
new g_SkillHud, Float:CheckTime3[33]
new g_HealSound[64], g_HealSpr[64]
new g_Sk_HealAmount, g_Sk_HealRate, g_Sk_Regeneration
new g_Casting, g_MsgBarTime, g_HealSprID, g_MaxPlayers

#define TASK_CASTING 64936

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("DeathMsg", "Event_Death", "a")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
		
	register_forward(FM_CmdStart, "fw_CmdStart")

	g_MsgBarTime = get_user_msgid("BarTime2")
	g_SkillHud = CreateHudSyncObj(3)
	g_MaxPlayers = get_maxplayers()
	
	// Cmd
	register_clcmd("drop", "CMD_Drop")
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)

	Load_Class_Setting()
	g_zombieclass = ZombieEli_RegisterClass(zclass_name, HEALTH, ARMOR, zclass_gravity, zclass_speed, zclass_model, zclass_clawmodel, TEAM_ZOMBIE, 0)

	// Skill
	g_Sk_HealAmount = ZombieEli_RegisterSkill(g_zombieclass, "Heal Amount", 3)
	g_Sk_HealRate = ZombieEli_RegisterSkill(g_zombieclass, "Heal Rate", 3)
	g_Sk_Regeneration = ZombieEli_RegisterSkill(g_zombieclass, "Health Regeneration", 3)
	
	// pre
	g_HealSprID = precache_model("sprites/zombie_elimination/heal.spr")
}

public Load_Class_Setting()
{
	new Temp[80]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_CLASS_HEAL_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_CLASS_HEAL_DESC")
	
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_HEAL_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_HEAL_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)

	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_HEAL_MODEL", zclass_model, sizeof(zclass_model))
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_HEAL_CLAWMODEL", zclass_clawmodel, sizeof(zclass_clawmodel))

	// Skill
	Setting_Load_String(SETTING_FILE, "Zombie Heal", "HEAL_SOUND", g_HealSound, sizeof(g_HealSound))
	Setting_Load_String(SETTING_FILE, "Zombie Heal", "HEAL_SPR", g_HealSpr, sizeof(g_HealSound))

	engfunc(EngFunc_PrecacheSound, g_HealSound)
	engfunc(EngFunc_PrecacheModel, g_HealSpr)

}

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
		
	TeamHealTime[id] = get_gametime() - 60.0
	Reset_Skill(id)
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID == g_zombieclass && NewLevel >= 10)
	{
		IG_ClientPrintColor(id, "!gYou reached Lv.10!n -> !tPress [G] to heal all yours teammates!!n")
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
	remove_task(id+TASK_CASTING)
}

public CMD_Drop(id)
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	if(!ZombieEli_IsZombie(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_GetClass(id) != g_zombieclass)
		return PLUGIN_CONTINUE	
	if(ZombieEli_GetLevel(id, ZombieEli_GetClass(id)) < 10)
		return PLUGIN_HANDLED
		
	if(get_gametime() - 5.0 > TeamHealTime[id])
	{
		//const Float:Radius = 200.0
		static MaxHealth, NewHealth; 
		
		for(new i = 0; i < g_MaxPlayers; i++)
		{
			if(!is_user_alive(id))
				continue
			if(!ZombieEli_IsZombie(i))
				continue
			//if(entity_range(i, id) > Radius)
			//	continue
			
			MaxHealth = ZombieEli_GetMaxHP(i)
			if(get_user_health(i) < MaxHealth)
			{
				static Health, SP;
				SP = ZombieEli_GetSP(id, g_Sk_HealAmount)
				
				switch(SP)
				{
					case 1: Health = 50
					case 2: Health = 100
					case 3: Health = 250
					default: Health = 0
				}
				
				NewHealth = min(MaxHealth, get_user_health(i) + Health)
				set_user_health(i, NewHealth)
				
				IG_PlayerAttachment(i, g_HealSpr, 1.5, 0.75, 10.0)
				PlaySound(i, g_HealSound)
			}
		}
		
		TeamHealTime[id] = get_gametime()
	} else {
		client_print(id, print_center, "Remaining time for healing team: %i second(s)!", floatround(TeamHealTime[id] - (get_gametime() - 60.0)))
	}
	
	return PLUGIN_HANDLED
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

	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		static Level; Level = ZombieEli_GetLevel(id, g_zombieclass)
		
		if(Level < 10)
		{
			set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.02, 0, 1.1, 1.1, 0.0, 0.0)
			ShowSyncHudMsg(id, g_SkillHud, "[Hold E] - Heal the base")
		} else {
			set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.04, 0, 1.1, 1.1, 0.0, 0.0)
			ShowSyncHudMsg(id, g_SkillHud, "[Hold E] - Heal the base^nUltimate Skill: Heal all teammates (Active - [G])")
		}
		
		CheckTime3[id] = get_gametime()
	}
	
	
	if(get_gametime() - 1.0 > RegenTime[id])
	{
		if(get_user_health(id) < HEALTH)
		{
			static Amount, SP; SP = ZombieEli_GetSP(id, g_Sk_Regeneration)
			if(!SP)
			{
				RegenTime[id] = get_gametime()
				return
			}
			
			switch(SP)
			{
				case 1: Amount = 30
				case 2: Amount = 60
				case 3: Amount = 80
				default: Amount = 0
			}
			
			static NewHealth; NewHealth = min(HEALTH, get_user_health(id) + Amount)
			set_user_health(id, NewHealth)
		}
		
		RegenTime[id] = get_gametime()
	}
	
	if(Get_BitVar(g_Casting, id))
	{
		static Float:Vel[3]; pev(id, pev_velocity, Vel)
		if(vector_length(Vel)) 
		{
			UnSet_BitVar(g_Casting, id)
			remove_task(id+TASK_CASTING)
			
			message_begin(MSG_ONE_UNRELIABLE, g_MsgBarTime, _, id)
			write_short(0) 
			write_short(0)
			message_end()
				
			return
		}
	}
		
	static New, Old;
	New = get_uc(UCHandle, UC_Buttons)
	Old = pev(id, pev_oldbuttons)
	
	if(New & IN_USE)
	{
		static Ent; Ent = ZombieEli_GetBaseEnt(TEAM_ZOMBIE)
		if(!pev_valid(Ent)) return 
		static Req; Req = ZombieEli_GetSP(id, g_Sk_HealAmount)
		static Float:Radius; Radius = entity_range(id, Ent)
		
		if(Radius > 115.0) client_print(id, print_center, "You must touch the base to heal it!")
		else {
			if(Req > 0)
			{
				if(!Get_BitVar(g_Casting, id))
				{
					const HealTime = 3; // do not modify
					
					Set_BitVar(g_Casting, id)
					static Faster, SP
					
					// Faster
					SP = ZombieEli_GetSP(id, g_Sk_HealRate)
					switch(SP)
					{
						case 1: Faster = 20
						case 2: Faster = 35
						case 3: Faster = 50
						default: Faster = 0
					}
					
					static Float:CastTime; CastTime = (float(HealTime) * float(100 - Faster)) / 100.0
					static Float:StartPercent; StartPercent = (CastTime / float(HealTime)) * 100
					
					message_begin(MSG_ONE_UNRELIABLE, g_MsgBarTime, _, id)
					write_short(HealTime) 
					write_short(100 - floatround(StartPercent))
					message_end()
					
					remove_task(id+TASK_CASTING)
					set_task(CastTime, "Cast_Magic", id+TASK_CASTING)
				}
			} else {
				if(!(Old & IN_USE))
				{
					client_print(id, print_center, "You need to train your [Heal Amount] skill to use this!")
				}
			}
		}
	} else {
		if(!(New & IN_USE) && (Old & IN_USE))
		{
			if(Get_BitVar(g_Casting, id))
			{
				UnSet_BitVar(g_Casting, id)
				remove_task(id+TASK_CASTING)
				
				message_begin(MSG_ONE_UNRELIABLE, g_MsgBarTime, _, id)
				write_short(0) 
				write_short(0)
				message_end()
			}
		}
	}
}

public Cast_Magic(id)
{
	id -= TASK_CASTING
	
	if(!Get_BitVar(g_IsUserAlive, id))
		return
	if(!zd_get_user_zombie(id))
		return
	if(zd_get_user_zombieclass(id) != g_zombieclass)
		return	
		
	ZombieEli_GainExp(id, 5, 1)
	emit_sound(id, CHAN_ITEM, g_HealSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

	static Health, SP;
	SP = ZombieEli_GetSP(id, g_Sk_HealAmount)
	
	switch(SP)
	{
		case 1: Health = 50
		case 2: Health = 100
		case 3: Health = 250
		default: Health = 0
	}
	
	ZombieEli_GainBaseHealth(TEAM_ZOMBIE, Health)
	
	// Effect
	static Ent; Ent = ZombieEli_GetBaseEnt(TEAM_ZOMBIE)
	if(!pev_valid(Ent)) return
	
	set_task(0.1, "Effect_Heal", Ent)
	set_task(1.5, "Remove_Effect", Ent)
}

public Effect_Heal(Ent)
{
	if(!pev_valid(Ent))
		return
	
	static Float:originF[3]
	pev(Ent, pev_origin, originF)
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_SPRITE)
	engfunc(EngFunc_WriteCoord, originF[0] + random_float(-100.0, 100.0))
	engfunc(EngFunc_WriteCoord, originF[1] + random_float(-100.0, 100.0))
	engfunc(EngFunc_WriteCoord, originF[2] + random_float(100.0, 200.0))
	write_short(g_HealSprID)
	write_byte(random_num(5, 10))
	write_byte(200)
	message_end()
	
	set_task(0.1, "Effect_Heal", Ent)
}

public Remove_Effect(Ent)
{
	if(!pev_valid(Ent))
		return
		
	remove_task(Ent)
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

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3076\\ f0\\ fs16 \n\\ par }
*/
