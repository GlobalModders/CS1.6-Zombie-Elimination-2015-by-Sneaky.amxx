#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <zombie_eli>
#include <infinitygame>

#define PLUGIN "[ZELI] H-Class: Engineer"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

// Class Setting
#define CLASS_NAME "Engineer"
#define CLASS_MODEL "zeli_hm_engineer"
#define CLASS_CLAWMODEL ""
#define CLASS_TEAM TEAM_HUMAN

const CLASS_HEALTH = 100
const CLASS_ARMOR = 100
const Float:CLASS_GRAVITY = 1.0
const Float:CLASS_SPEED = 250.0

new g_Engineer
new g_BuildSentry, g_SentryHealth, g_SentryDamage

// Marcros
#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

// Flare
#define MODEL_V "models/v_smokegrenade.mdl"
#define MODEL_P "models/p_smokegrenade.mdl"
#define MODEL_W "models/w_flare.mdl"

#define MODEL_W_OLD "models/w_smokegrenade.mdl"

#define FLARE_LIVETIME 30
#define CSW_FLARE CSW_SMOKEGRENADE
#define weapon_flare "weapon_smokegrenade"

new g_Had_Flare, g_Trail_SprID
new const Float:NOVA_COLOR[3] = {255.0, 255.0, 255.0}

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

// Senshit
new g_CanBuild

#define SENTRY_DEFHEALTH 100
#define SENTRY_DEFDAMAGE 10

#define ENTITYCLASS "info_target"

stock Float:fpev(_index, _value)
{
	static Float:fl
	pev(_index, _value, fl)
	return fl
}

new const szClasses[][] =
{
	"sentrybase",
	"sentrygun",
	"sentryrocket"
}

new const Float:flSizes[][] =
{
	{-16.0, -16.0, 0.0},
	{16.0, 16.0, 16.0},
	{-16.0, -16.0, 0.0},
	{16.0, 16.0, 48.0},
	{0.0, 0.0, 0.0},
	{0.0, 0.0, 0.0}
}

new const Float:dmgGlow[3] = {0.0, 100.0, 240.0}

new const szModels[][] =
{
	"models/zombie_elimination/baseb.mdl",
	"models/zombie_elimination/sentry1b.mdl",
	"models/zombie_elimination/sentry2b.mdl",
	"models/zombie_elimination/sentry3b.mdl",
	"models/rpgrocket.mdl"
}

new const szSounds[][] =
{
	"zombie_elimination/sentry/turridle.wav",
	"zombie_elimination/sentry/turrset.wav",
	"zombie_elimination/sentry/turrspot.wav",
	"zombie_elimination/sentry/building.wav",
	"weapons/oicw-1.wav",
	"weapons/rocket1.wav",
	"weapons/debris1.wav",
	"weapons/debris2.wav",
	"weapons/debris3.wav"
}

new g_pCvars[13], Float:RocketShit[33]
new boom
new trail

new Float:g_bulletdmg[2], g_MySentry[33], g_Upgrade[33], g_Rocket[33]
new Float:g_rocketdelay
new g_rocketamount
new g_rockettracktarget

stock getHead(ent)					{ return pev(ent, pev_euser1); }
stock getBase(ent)					{ return pev(ent, pev_euser2); }
stock getOwner(ent)					{ return pev(ent, pev_euser3); }
stock getEnemy(ent)					{ return pev(ent, pev_enemy); }
stock setHead(ent, head)				{ set_pev(ent, pev_euser1, head); }
stock setBase(ent, base)				{ set_pev(ent, pev_euser2, base); }
stock setOwner(ent, owner)				{ set_pev(ent, pev_euser3, owner); }
stock setEnemy(ent, enemy)				{ set_pev(ent, pev_enemy, enemy); }
stock Float:getLastThinkTime(ent)			{ return fpev(ent, pev_fuser1); }
stock setLastThinkTime(ent, Float:lastThinkTime)	{ set_pev(ent, pev_fuser1, lastThinkTime); }
stock Float:getTurnRate(ent)				{ return fpev(ent, pev_fuser2); }
stock setTurnRate(ent, Float:turnRate)			{ set_pev(ent, pev_fuser2, turnRate); }
stock Float:getRadarAngle(ent)				{ return fpev(ent, pev_fuser3); }
stock setRadarAngle(ent, Float:radarAngle)		{ set_pev(ent, pev_fuser3, radarAngle); }
stock Float:getTargetLostTime(ent)			{ return fpev(ent, pev_fuser4); }
stock setTargetLostTime(ent, Float:lostTime)		{ set_pev(ent, pev_fuser4, lostTime); }
stock getBits(ent)					{ return pev(ent, pev_iuser1); }
stock setBits(ent, bits)				{ set_pev(ent, pev_iuser1, bits); }
stock getLevel(ent)					{ return pev(ent, pev_iuser2); }
stock setLevel(ent, level)				{ set_pev(ent, pev_iuser2, level); }
stock getTeam(ent)					{ return is_alive(ent)?get_user_team(ent):pev(ent, pev_team); }
stock setTeam(ent, team)				{ set_pev(ent, pev_team, team); }
stock getTurretAngles(ent, Float:angles[3])		{ pev(ent, pev_vuser1, angles); }
stock setTurretAngles(ent, Float:angles[3])		{ set_pev(ent, pev_vuser1, angles); }
stock getLastSight(ent, Float:last[3])			{ pev(ent, pev_vuser2, last); }
stock setLastSight(ent, Float:last[3])			{ set_pev(ent, pev_vuser2, last); }
stock getAnimFloats(ent, Float:animFloats[3])		{ pev(ent, pev_vuser3, animFloats); }
stock setAnimFloats(ent, Float:animFloats[3])		{ set_pev(ent, pev_vuser3, animFloats); }

new Float:CheckTime3[33], g_SkillHud

stock kill_entity(ent)
{
	set_pev(ent, pev_flags, pev(ent, pev_flags)|FL_KILLME)
}

/// Shitty

#define REPAIR_HP_HIT 20
#define DAMAGE_MULTI 5.0

#define MODEL_V2 "models/v_zsh_clawhammer.mdl"
#define MODEL_P2 "models/p_zsh_clawhammer.mdl"

new const WeaponSounds[7][] =
{
	"weapons/tomahawk_slash1.wav",
	"weapons/tomahawk_slash1_hit.wav",
	"weapons/tomahawk_slash2.wav",
	"weapons/tomahawk_slash2_hit.wav",
	"weapons/tomahawk_stab_hit.wav",
	"weapons/tomahawk_stab_miss.wav",
	"weapons/tomahawk_wall.wav",
}

new g_ClawHammer, g_Engineer2
new g_Had_ClawHammer
new g_HumanBase
new g_HamBase, g_HamSentry

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	Register_SafetyFunc()
	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	register_forward(FM_EmitSound, "fw_EmitSound")
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage")

	RegisterHam(Ham_Think, "grenade", "fw_GrenadeThink")
	
	// Sentry
	g_pCvars[0] = register_cvar("sentry_bulletdmg_min", "10.0")
	g_pCvars[1] = register_cvar("sentry_bulletdmg_max", "12.0")
	g_pCvars[2] = register_cvar("sentry_searchradius", "1800.0")
	g_pCvars[3] = register_cvar("sentry_health_lv1", "100.0") // NO Use
	g_pCvars[4] = register_cvar("sentry_health_lv2", "400.0") // NO use
	g_pCvars[5] = register_cvar("sentry_health_lv3", "400.0") // NO use
	g_pCvars[6] = register_cvar("sentry_detonation_dmg", "200.0")
	g_pCvars[7] = register_cvar("sentry_detonation_radius", "300.0")
	g_pCvars[8] = register_cvar("sentry_dmgtoken_multiplier", "0.5")
	g_pCvars[9] = register_cvar("sentry_rocketdmg", "150.0")
	g_pCvars[10] = register_cvar("sentry_rocket_lauchdelay", "3.0")
	g_pCvars[11] = register_cvar("sentry_rocket_lauchamount", "30") // NO use
	g_pCvars[12] = register_cvar("sentry_rocket_tracktarget", "1")
	
	g_SkillHud = CreateHudSyncObj(3)
	g_Engineer2 = ZombieEli_GetClassID("Engineer")
	g_ClawHammer = ZombieEli_RegisterWeapon(g_Engineer2, "CSO Claw Hammer", WPN_MELEE, 3, 0)
	
	register_forward(FM_Touch, "fwd_Touch", 1)
	register_forward(FM_Think, "sentryThink")
	RegisterHam(Ham_TakeDamage, ENTITYCLASS, "sentryTakeDamage")
}

public plugin_precache()
{
	// Register Class
	g_Engineer = ZombieEli_RegisterClass(CLASS_NAME, CLASS_HEALTH, CLASS_ARMOR, CLASS_GRAVITY, CLASS_SPEED, CLASS_MODEL, CLASS_CLAWMODEL, CLASS_TEAM, 0)
	
	// Register Skill
	g_BuildSentry = ZombieEli_RegisterSkill(g_Engineer, "Build Sentry", 3)
	g_SentryHealth = ZombieEli_RegisterSkill(g_Engineer, "Sentry Health", 3)
	g_SentryDamage = ZombieEli_RegisterSkill(g_Engineer, "Sentry Damage", 3)
	
	// Extra Precache
	precache_model("models/player/zeli_hm_engineer/zeli_hm_engineerT.mdl")
	g_Trail_SprID = precache_model("sprites/laserbeam.spr")
	
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i=0;i<sizeof(szModels);i++)
		precache_model(szModels[i])
	for(new i=0;i<sizeof(szSounds);i++)
		precache_sound(szSounds[i])
	
	boom = precache_model("sprites/zerogxplode.spr")
	trail = precache_model("sprites/smoke.spr")
	
	precache_model(MODEL_V2)
	precache_model(MODEL_P2)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_ClawHammer) Get_ClawHammer(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_ClawHammer) Remove_ClawHammer(id)
}

public Remove_ClawHammer(id)
{
	UnSet_BitVar(g_Had_ClawHammer, id)
}

public plugin_cfg()
{
	g_bulletdmg[0] = get_pcvar_float(g_pCvars[0])
	g_bulletdmg[1] = get_pcvar_float(g_pCvars[1])
	g_rocketdelay = get_pcvar_float(g_pCvars[10])
	g_rocketamount = 30
	g_rockettracktarget = get_pcvar_num(g_pCvars[12])
}

public client_putinserver(id)
{
	Safety_Connected(id)
	
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_Register_HamBot", id)
	}
}

public Do_Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
	
	destroy_sentry(g_MySentry[id])
	UnSet_BitVar(g_Had_ClawHammer, id)
}

public zeli_round_new()
{
	remove_task(1000)
}

public zeli_round_start()
{
	g_HumanBase = ZombieEli_GetBaseEnt(TEAM_HUMAN)
	if(pev_valid(g_HumanBase) && !g_HamBase) 
	{
		g_HamBase = 1
		RegisterHamFromEntity(Ham_TakeDamage, g_HumanBase, "fw_Base_TakeDamage")
	}
}

public zeli_user_spawned(id, ClassID)
{
	UnSet_BitVar(g_CanBuild, id)
	destroy_sentry(g_MySentry[id])
	
	if(ClassID != g_Engineer)
		return
}

public zeli_class_active(id, ClassID)
{
	if(ClassID != g_Engineer)
		return
	
	Set_BitVar(g_Had_Flare, id)
	give_item(id, weapon_flare)
	
	Set_BitVar(g_CanBuild, id)
}

public zeli_class_unactive(id, ClassID)
{
	UnSet_BitVar(g_Had_Flare, id)
	UnSet_BitVar(g_CanBuild, id)
}

public zeli_user_infected(id, ClassID)
{
	UnSet_BitVar(g_Had_Flare, id)
	UnSet_BitVar(g_CanBuild, id)
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID != g_Engineer)
		return
	if(NewLevel == 10)
	{
		IG_ClientPrintColor(id, "!gYou reached Lv.10!n -> !tNow your sentry can shoot homing rocket!!n")
		
		// Rocket
		g_Rocket[id] = g_rocketamount
	}
}

public fw_SetModel(Ent, const Model[])
{
	static id; id = pev(Ent, pev_owner)
	if(!is_user_connected(id)) return FMRES_IGNORED
		
	static Float:DMGTime; pev(Ent, pev_dmgtime, DMGTime)
	if(DMGTime == 0.0) return FMRES_IGNORED
	
	if(equal(Model, MODEL_W_OLD) && Get_BitVar(g_Had_Flare, id))
	{
		static Team; Team = _:cs_get_user_team(id)
		static RGB[3]
		
		// Set Frostnade
		set_pev(Ent, pev_team, Team)
		set_pev(Ent, pev_flTimeStepSound, 1962)
		
		// Glow
		set_pev(Ent, pev_rendermode, kRenderNormal)
		set_pev(Ent, pev_renderfx, kRenderFxGlowShell)
		set_pev(Ent, pev_rendercolor, NOVA_COLOR)
		set_pev(Ent, pev_renderamt, 16.0)
		
		engfunc(EngFunc_SetModel, Ent, MODEL_W)
		
		FVecIVec(NOVA_COLOR, RGB)
		Create_Trail(Ent, 10, 5, RGB, 250)
		
		// Remove
		UnSet_BitVar(g_Had_Flare, id)
		
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return
	if(ZombieEli_IsZombie(id))
		return
	if(ZombieEli_GetClass(id) != g_Engineer)
		return
	if(!Get_BitVar(g_CanBuild, id))
		return
		
	static New, Old;
	New = get_uc(uc_handle, UC_Buttons)
	Old = pev(id, pev_oldbuttons)
	
	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		set_hudmessage(200, 200, 200, -1.0, 0.83 - 0.02, 0, 1.1, 1.1, 0.0, 0.0)
		ShowSyncHudMsg(id, g_SkillHud, "Ultimate Skill: Homing Rocket for Sentry")
		
		CheckTime3[id] = get_gametime()
	}	
	
	
	if((New & IN_USE) && !(Old & IN_USE))
	{
		static SP; SP = ZombieEli_GetSP(id, g_BuildSentry)
		if(SP <= 0) 
		{
			client_print(id, print_center, "You must upgrade skill point of 'Build Sentry' to build it!")
			return 
		}
		
		static Float:playerOrigin[3], Float:newOrigin[3], Float:tempOrigin[3], Float:flFraction, bool:freeSpace
		pev(id, pev_origin, playerOrigin)
		velocity_by_aim(id, 64, newOrigin)
		newOrigin[0] += playerOrigin[0]
		newOrigin[1] += playerOrigin[1]
		newOrigin[2] += playerOrigin[2]
		new tr = create_tr2()
		engfunc(EngFunc_TraceLine, playerOrigin, newOrigin, 0, id, tr)
		get_tr2(tr, TR_vecEndPos, newOrigin)
		newOrigin[2] = playerOrigin[2]
		tempOrigin[0] = newOrigin[0]
		tempOrigin[1] = newOrigin[1]
		tempOrigin[2] = -8192.0
		engfunc(EngFunc_TraceLine, newOrigin, tempOrigin, 0, id, tr)
		get_tr2(tr, TR_vecEndPos, tempOrigin)
		engfunc(EngFunc_TraceLine, playerOrigin, tempOrigin, 0, id, tr)
		get_tr2(tr, TR_flFraction, flFraction)
		get_tr2(tr, TR_vecEndPos, tempOrigin)
		
		if(flFraction != 1.0)
		{
			free_tr2(tr)
			client_print(id, print_center, "Cannot build sentry here")
			return 
		}
		
		if(vector_distance(playerOrigin, tempOrigin) > 96.0)
		{
			free_tr2(tr)
			client_print(id, print_center, "Cannot build sentry here")
			return 
		}
		
		engfunc(EngFunc_TraceHull, newOrigin, newOrigin, 0, HULL_HUMAN, 0, tr)
		freeSpace = (get_tr2(tr, TR_InOpen) && !get_tr2(tr, TR_AllSolid) && !get_tr2(tr, TR_StartSolid))
		free_tr2(tr)
		
		if(!freeSpace)
		{
			client_print(id, print_center, "Cannot build sentry here")
			return
		}
		
		set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0})

		new ent, Float:nOrigin[3], dropToGround, owner, team, level, instant
		
		nOrigin = newOrigin
		dropToGround = 1
		owner = id
		team = get_user_team(id)
		level = 1
		instant = 0
		ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, ENTITYCLASS))
		if(!pev_valid(ent))
			return
		dllfunc(DLLFunc_Spawn, ent)
		set_pev(ent, pev_classname, szClasses[0])
		engfunc(EngFunc_SetModel, ent, szModels[0])
		engfunc(EngFunc_SetSize, ent, flSizes[0], flSizes[1])
		setOwner(ent, owner)
		setTeam(ent, team)
		setLevel(ent, level)
		set_pev(ent, pev_takedamage, 0.0)
		set_pev(ent, pev_health, 0.0)
		if(dropToGround)
			nOrigin[2] -= distFromGround(nOrigin, ent)
		set_pev(ent, pev_origin, nOrigin)
		set_pev(ent, pev_solid, SOLID_SLIDEBOX)
		set_pev(ent, pev_movetype, MOVETYPE_FLY)
		set_pev(ent, pev_nextthink, halflife_time() + ((instant!=0)?0.0:2.0))
		emit_sound(ent, CHAN_AUTO, szSounds[3], 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		g_MySentry[id] = ent;
		
		UnSet_BitVar(g_CanBuild, id)
	}
}

public destroy_sentry(ent)
{
	if(!pev_valid(ent)) return
	if(is_sentrybase(ent)) ent = getHead(ent)
	if(!pev_valid(ent) || !is_sentrygun(ent)) return
	sentryKilled(ent)
	kill_entity(ent)
	kill_entity(getBase(ent))
}

public fw_GrenadeThink(Ent)
{
	if(!pev_valid(Ent) || pev(Ent, pev_flTimeStepSound) != 1962) 
		return HAM_IGNORED
	
	static Float:DMGTime; pev(Ent, pev_dmgtime, DMGTime)
	if(DMGTime > get_gametime()) 
		return HAM_IGNORED
	
	// Light up when it's stopped on ground
	if ((pev(Ent, pev_flags) & FL_ONGROUND) && fm_get_speed(Ent) < 10)
	{
		// Flare sound
		engfunc(EngFunc_EmitSound, Ent, CHAN_WEAPON, "items/nvg_on.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		// Our task params
		static params[2]
		params[0] = Ent // entity id
		params[1] = FLARE_LIVETIME // duration

		// Call our lighting task
		set_task(0.1, "flare_lighting", 1000, params, sizeof params)
	} else {
		// Delay the explosion until we hit ground
		set_pev(Ent, pev_dmgtime, get_gametime() + 0.5)
		return HAM_IGNORED;
	}

	return HAM_SUPERCEDE
}


// Flare Lighting
public flare_lighting(args[5])
{
	static FLARE_ENTITY; FLARE_ENTITY = args[0]
	
	// Unexistant flare entity?
	if (!pev_valid(FLARE_ENTITY))
		return;
	
	// Flare depleted -clean up the mess-
	if(args[1] <= 0)
	{
		engfunc(EngFunc_RemoveEntity, FLARE_ENTITY)
		return;
	}
	
	// Get origin
	static Float:originF[3]
	pev(FLARE_ENTITY, pev_origin, originF)
	
	// Lighting
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_DLIGHT) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	write_byte(30) // radius
	write_byte(255) // r
	write_byte(255) // g
	write_byte(255) // b
	write_byte(15) //life
	write_byte((args[1] < 2) ? 3 : 0) //decay rate
	message_end()
	
	// Sparks
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_SPARKS) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	message_end()
	
	// Decrease task cycle counter
	args[1] -= 1;
	
	// Keep sending flare messaegs
	set_task(1.0, "flare_lighting", 1000, args, sizeof args)
}

public Create_Trail(Ent, Life, Width, RGB[3], Brightness)
{
	Clear_Trail(Ent)

	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Ent)
	write_short(g_Trail_SprID); // sprite
	write_byte(Life); // life
	write_byte(Width); // width
	write_byte(RGB[0]); // red
	write_byte(RGB[1]); // green
	write_byte(RGB[2]); // blue
	write_byte(Brightness); // brightness
	message_end();
}

public Clear_Trail(Ent)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_KILLBEAM)
	write_short(Ent)
	message_end()
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

public is_alive(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	if(!Get_BitVar(g_IsAlive, id)) 
		return 0
	
	return 1
}

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	
	return 1
}

public get_player_weapon(id)
{
	if(!is_alive(id))
		return 0
	
	return g_PlayerWeapon[id]
}

/* ===============================
--------- End of SAFETY ----------
=================================*/


stock createSentryHead(Float:origin[3], owner, team, level, base)
{
	new ent
	ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, ENTITYCLASS))
	if(!pev_valid(ent))
		return 0
	dllfunc(DLLFunc_Spawn, ent)
	set_pev(ent, pev_classname, szClasses[1])
	level = clamp(level, 1, 3)
	setOwner(ent, owner)
	setTeam(ent, team)
	setLevel(ent, level)
	setBase(ent, base)
	switch(level)
	{
		case 1: engfunc(EngFunc_SetModel, ent, szModels[1])
		case 2: engfunc(EngFunc_SetModel, ent, szModels[2])
		case 3: engfunc(EngFunc_SetModel, ent, szModels[3])
	}
	engfunc(EngFunc_SetSize, ent, flSizes[2], flSizes[3])
	switch(team)
	{
		case 1: set_pev(ent, pev_colormap, 0|(0<<8))
		case 2: set_pev(ent, pev_colormap, 150|(160<<8))
		default: set_pev(ent, pev_colormap, 150|(160<<8))
	}
	
	set_pev(ent, pev_controller_1, 127)
	set_pev(ent, pev_controller_2, 127)
	set_pev(ent, pev_controller_3, 127)
	set_pev(ent, pev_takedamage, 1.0)
	set_pev(ent, pev_health, getLevelHealth(owner))
	set_pev(ent, pev_origin, origin)
	set_pev(ent, pev_solid, SOLID_SLIDEBOX)
	set_pev(ent, pev_movetype, MOVETYPE_FLY)
	set_pev(ent, pev_nextthink, halflife_time())
	emit_sound(ent, CHAN_AUTO, szSounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Rocket
	static id; id = getOwner(ent)
	if(!is_connected(id))
	{
		g_Rocket[id] = 0
	} else {
		static Level; Level = ZombieEli_GetLevel(id, ZombieEli_GetClass(id))
		if(Level >= 10) g_Rocket[id] = g_rocketamount
		else g_Rocket[id] = 0
	}
	
	if(!g_HamSentry)
	{
		g_HamSentry = 1
		RegisterHamFromEntity(Ham_TakeDamage, ent, "fw_Sentry_TakeDamage")
	}
	
	return ent
}

stock createHVRrocket(Float:origin[3], Float:vecForward[3], launcher, owner, team, Float:dmg)
{
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, ENTITYCLASS))
	if(!pev_valid(ent))
		return 0
	dllfunc(DLLFunc_Spawn, ent)
	set_pev(ent, pev_classname, szClasses[2])
	engfunc(EngFunc_SetModel, ent, szModels[4])
	engfunc(EngFunc_SetSize, ent, flSizes[4], flSizes[5])
	set_pev(ent, pev_movetype, MOVETYPE_FLY)
	set_pev(ent, pev_solid, SOLID_BBOX)
	
	new Float:angles[3]
	vector_to_angle(vecForward, angles)
	set_pev(ent, pev_angles, angles)
	set_pev(ent, pev_origin, origin)
	set_pev(ent, pev_vuser4, vecForward)
	set_pev(ent, pev_owner, launcher)
	setOwner(ent, owner)
	setTeam(ent, team)
	set_pev(ent, pev_dmg, dmg)
	
	set_pev(ent, pev_nextthink, halflife_time() + 0.1)
	return ent
}

stock Float:distFromGround(Float:start[3], pSkip)
{
	static tr, Float:end[3]
	tr = create_tr2()
	end[0] = start[0]
	end[1] = start[1]
	end[2] = -8192.0
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, pSkip, tr)
	get_tr2(tr, TR_vecEndPos, end)
	free_tr2(tr)
	return vector_distance(start, end)
}

public sentryThink(ent)
{
	if(!pev_valid(ent))
		return FMRES_IGNORED
	static classname[32]
	pev(ent, pev_classname, classname, 31)
	if(equal(classname, szClasses[0]))
	{
		new head
		head = getHead(ent)
		if(head == 0)
		{
			new Float:origin[3]
			pev(ent, pev_origin, origin)
			origin[2] += 16.0// + 1.0
			head = createSentryHead(origin, getOwner(ent), getTeam(ent), getLevel(ent), ent)
			if(head != 0)
			{
				setOwner(ent, 0)
				setTeam(ent, 0)
				setLevel(ent, 0)
				setHead(ent, head)
				
				static i, num, ret
				num = get_pluginsnum()
				for(i=0;i<num;i++)
				{
					ret = get_func_id("sentry_buildingDone", i)
					if(ret == -1)
						continue
					if(callfunc_begin_i(ret, i) !=1)
						continue
					callfunc_push_int(head)
					ret = callfunc_end()
				}
			}
		}
		if(head == 0)
			kill_entity(ent)
			
		return FMRES_SUPERCEDE
	}
	else if(equal(classname, szClasses[1]))
	{
		static Float:gameTime, Float:deltaTime, enemy
		gameTime = halflife_time()
		deltaTime = gameTime - getLastThinkTime(ent)
		enemy = getEnemy(ent)
		setLastThinkTime(ent, gameTime)
		set_pev(ent, pev_nextthink, gameTime)
		
		switch(getLevel(ent))
		{
			case 1: changeModel(ent, szModels[1])
			case 2: changeModel(ent, szModels[2])
			case 3: changeModel(ent, szModels[3])
		}
		
		static Float:rc[3]
		pev(ent, pev_rendercolor, rc)
		rc[0] -= dmgGlow[0] * deltaTime
		rc[1] -= dmgGlow[1] * deltaTime
		rc[2] -= dmgGlow[2] * deltaTime
		rc[0] = floatclamp(rc[0], 0.0, 255.0)
		rc[1] = floatclamp(rc[1], 0.0, 255.0)
		rc[2] = floatclamp(rc[2], 0.0, 255.0)
		set_pev(ent, pev_renderfx, ((rc[0]+rc[1]+rc[2])==0.0)?kRenderFxNone:kRenderFxGlowShell)
		set_pev(ent, pev_rendercolor, rc)
		set_pev(ent, pev_rendermode, kRenderNormal )
		set_pev(ent, pev_renderamt, 255.0)
		
		AnimEvents(ent, deltaTime)
		
		static Float:sentryOrigin[3], Float:targetOrigin[3]
		pev(ent, pev_origin, sentryOrigin)
		sentryOrigin[2] += 20.0
		
		static base
		base = getBase(ent)
		
		if(fpev(ent, pev_health) <= 0.0 || !pev_valid(base))
		{
			create_explosion(sentryOrigin, get_pcvar_float(g_pCvars[6]), get_pcvar_float(g_pCvars[7]), ent, getOwner(ent))
			
			sentryKilled(ent)
			kill_entity(ent)
			if(pev_valid(base))
				kill_entity(base)
			
			return FMRES_SUPERCEDE
		}
		
		set_pev(base, pev_renderfx, ((rc[0]+rc[1]+rc[2])==0.0)?kRenderFxNone:kRenderFxGlowShell)
		set_pev(base, pev_rendercolor, rc)
		set_pev(base, pev_rendermode, kRenderNormal )
		set_pev(base, pev_renderamt, 255.0)
		
		if(enemy != 0)
		{
			if(!pev_valid(enemy))
				enemy = 0
			if(!is_alive(enemy))
				enemy = 0
		}
		if(enemy != 0)
		{
			if(FBoxVisible(sentryOrigin, enemy, ent, 0.0, targetOrigin))
			{
				setLastSight(ent, targetOrigin)
				static Float:track[3]
				track[0] = targetOrigin[0] - sentryOrigin[0]
				track[1] = targetOrigin[1] - sentryOrigin[1]
				track[2] = targetOrigin[2] - sentryOrigin[2]
				vector_to_angle(track, track)
				
				if(MoveTurret(ent, track, deltaTime, true))
					setSequence(ent, 1)
				
				setTargetLostTime(ent, gameTime + 3.0)
			}
			else if(gameTime >= getTargetLostTime(ent)) // target lost
				enemy = 0
			else // target isnt in sight
			{
				setSequence(ent, 0)
				static tmp
				tmp = BestVisibleEnemy(ent, get_pcvar_float(g_pCvars[2]))
				if(tmp != 0 && tmp != enemy) // but we got another target in sight
				{
					enemy = tmp
				}
				else
				{
					getLastSight(ent, targetOrigin)
					static Float:track[3]
					track[0] = targetOrigin[0] - sentryOrigin[0]
					track[1] = targetOrigin[1] - sentryOrigin[1]
					track[2] = targetOrigin[2] - sentryOrigin[2]
					vector_to_angle(track, track)
					
					MoveTurret(ent, track, deltaTime, true)
				}
			}
		}
		if(enemy == 0)
		{
			setSequence(ent, 0)
			enemy = BestVisibleEnemy(ent, get_pcvar_float(g_pCvars[2]))
			if(enemy != 0)
			{
				if(gameTime >= getTargetLostTime(ent))
				{
					emit_sound(ent, CHAN_AUTO, szSounds[2], 0.8, ATTN_NORM, 0, PITCH_NORM)
					setTargetLostTime(ent, gameTime + 3.0)
				}
			}
			else
			{
				if (random_num(0, 99999) < 120)
					emit_sound(ent, CHAN_AUTO, szSounds[0], 0.5, ATTN_NORM, 0, PITCH_NORM)
				static Float:targetAngles[3]
				getTurretAngles(ent, targetAngles)
				targetAngles[0] = 0.0
				targetAngles[1] -= 45.0
				MoveTurret(ent, targetAngles, deltaTime, false)
			}
		}
		setEnemy(ent, enemy)
		
		if(getLevel(ent) == 3)
		{
			static Float:radarAngle, bits
			radarAngle = getRadarAngle(ent)
			bits = getBits(ent)
			if(bits & (1<<0))
			{
				radarAngle -= 255.0 * deltaTime
				if(radarAngle < 0.0)
				{
					radarAngle = 0.0
					bits &= ~(1<<0)
				}
			}
			else
			{
				radarAngle += 255.0 * deltaTime
				if(radarAngle > 255.0)
				{
					radarAngle = 255.0
					bits |= (1<<0)
				}
			}
			set_pev(ent, pev_controller_3, floatround(radarAngle))
			setRadarAngle(ent, radarAngle)
			setBits(ent, bits)
		}
		
		return FMRES_SUPERCEDE
	}
	else if(equal(classname, szClasses[2]))
	{
		switch(pev(ent, pev_iuser4))
		{
			case 0:
			{
				set_pev(ent, pev_effects, pev(ent, pev_effects)|EF_LIGHT)
				emit_sound(ent, CHAN_VOICE, szSounds[5], 1.0, 0.5, 0, PITCH_NORM)
				
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
				write_byte(TE_BEAMFOLLOW)
				write_short(ent)
				write_short(trail)
				write_byte(15)
				write_byte(5)
				write_byte(224)
				write_byte(224)
				write_byte(255)
				write_byte(255)
				message_end()
				
				set_pev(ent, pev_iuser4, 1)
			}
			case 1:
			{
				static Float:origin[3], Float:angles[3], Float:velocity[3], Float:vecForward[3], Float:len
				pev(ent, pev_origin, origin)
				pev(ent, pev_velocity, velocity)
				pev(ent, pev_vuser4, vecForward)
				
				if(origin[0] < -4096.0 || origin[0] > 4096.0 || origin[1] < -4096.0 || origin[1] > 4096.0 || origin[2] < - 4096.0 || origin[2] > 4096.0)
				{
					kill_entity(ent)
					return FMRES_IGNORED
				}
				
				if(g_rockettracktarget)
				{
					static target
					target = BestVisibleEnemy(ent, 1800.0, true)
					if(target && distToEnt(origin, target) >= 200.0)
					{
						BodyTarget(target, angles)
						vecForward[0] = angles[0] - origin[0]
						vecForward[1] = angles[1] - origin[1]
						vecForward[2] = angles[2] - origin[2]
						len = vector_length(vecForward)
						vecForward[0] = vecForward[0] / len
						vecForward[1] = vecForward[1] / len
						vecForward[2] = vecForward[2] / len
					}
				}
				
				len = vector_length(velocity)
				if(len < 2400.0)
				{
					velocity[0] = vecForward[0]*(500.0+len)
					velocity[1] = vecForward[1]*(500.0+len)
					velocity[2] = vecForward[2]*(500.0+len)
				}
				
				vector_to_angle(velocity, angles)
				
				set_pev(ent, pev_angles, angles)
				set_pev(ent, pev_velocity, velocity)
				set_pev(ent, pev_vuser4, vecForward)
			}
		}
		set_pev(ent, pev_nextthink, halflife_time() + 0.1)
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public sentryTakeDamage(this, pevInflictor, pevAttacker, Float:flDamage, iDamageBits)
{
	if(!pev_valid(this))
		return HAM_IGNORED
	static classname[32], Float:health
	pev(this, pev_classname, classname, 31)
	pev(this, pev_health, health)
	if(equal(classname, szClasses[0]))
	{
		return HAM_SUPERCEDE
	}
	else if(equal(classname, szClasses[1]))
	{
		if(iDamageBits & (DMG_FALL|DMG_DROWN|DMG_FREEZE|DMG_NERVEGAS|DMG_POISON|DMG_RADIATION))
			return HAM_SUPERCEDE
			
		if(!is_alive(pevAttacker))
			return HAM_SUPERCEDE
		if(!ZombieEli_IsZombie(pevAttacker))
		{
			if(get_user_weapon(pevAttacker) == CSW_KNIFE)
			{
				static Owner; Owner = getOwner(this)
				if(!is_connected(Owner)) return HAM_SUPERCEDE
				
				static SP; SP = ZombieEli_GetSP(Owner, g_BuildSentry)
			
				if(pev(this, pev_iuser2) < 2)
				{ // Up to Level 2
					if(SP >= 2)
					{
						if(g_Upgrade[pevAttacker] < 1)
						{
							g_Upgrade[pevAttacker]++
						} else {
							new ent, level, playsound, sethealth
							ent = g_MySentry[Owner]
							level = 2
							playsound = 1
							sethealth = 1
							if(!pev_valid(ent)) return HAM_SUPERCEDE
							if(is_sentrybase(ent)) ent = getHead(ent)
							if(!pev_valid(ent) || !is_sentrygun(ent)) return HAM_SUPERCEDE
							setLevel(ent, level)
							set_pev(this, pev_iuser2, 2)
							
							if(playsound)
								emit_sound(ent, CHAN_AUTO, szSounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
							if(sethealth)
								set_pev(ent, pev_health, getLevelHealth(Owner))
						
							g_Upgrade[pevAttacker] = 0
						}
					}
				} else if(pev(this, pev_iuser2) < 3)
				{ // Up to Level 3
					if(SP >= 3)
					{
						if(g_Upgrade[pevAttacker] < 1)
						{
							g_Upgrade[pevAttacker]++
						} else {
							new ent, level, playsound, sethealth
							ent = g_MySentry[Owner]
							level = 3
							playsound = 1
							sethealth = 1
							if(!pev_valid(ent)) return HAM_SUPERCEDE
							if(is_sentrybase(ent)) ent = getHead(ent)
							if(!pev_valid(ent) || !is_sentrygun(ent)) return HAM_SUPERCEDE
							setLevel(ent, level)
							set_pev(this, pev_iuser2, 3)
							
							if(playsound)
								emit_sound(ent, CHAN_AUTO, szSounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
							if(sethealth)
								set_pev(ent, pev_health, getLevelHealth(Owner))
						
							g_Upgrade[pevAttacker] = 0
						}
					}
				}
					
			}
			
			return HAM_SUPERCEDE
		}
			
		new Float:tmp = floatclamp(flDamage/50.0, 0.3, 1.0)
		new Float:tmp2[3]
		tmp2[0] = dmgGlow[0] * tmp
		tmp2[1] = dmgGlow[1] * tmp
		tmp2[2] = dmgGlow[2] * tmp
		set_pev(this, pev_renderfx, kRenderFxGlowShell)
		set_pev(this, pev_rendercolor, tmp2)
		set_pev(this, pev_rendermode, kRenderNormal)
		set_pev(this, pev_renderamt, 255.0)
		
		if(fpev(this, pev_takedamage) == 0.0)
			return HAM_SUPERCEDE
		
		health -= flDamage*get_pcvar_float(g_pCvars[8])
		set_pev(this, pev_health, health)
		set_pev(this, pev_nextthink, halflife_time())
		
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public bool:MoveTurret(sentry, Float:targetAngles[3], Float:deltaTime, bool:Boost)
{
	if(targetAngles[0] > 180.0)
		targetAngles[0] -= 360.0
	if(targetAngles[1] < 0)
		targetAngles[1] += 360.0
	else if(targetAngles[1] > 360.0)
		targetAngles[1] -= 360.0
	static Float:curAngles[3], Float:TurnRate, Float:dir[2]
	getTurretAngles(sentry, curAngles)
	TurnRate = getTurnRate(sentry)
	dir[0] = targetAngles[0] > curAngles[0] ? 1.0 : -1.0
	dir[1] = targetAngles[1] > curAngles[1] ? 1.0 : -1.0
	if(curAngles[0] != targetAngles[0])
	{
		curAngles[0] += deltaTime * 80.0 * dir[0]
		if(dir[0] == 1.0)
		{
			if(curAngles[0] > targetAngles[0])
				curAngles[0] = targetAngles[0]
		}
		else
		{
			if(curAngles[0] < targetAngles[0])
				curAngles[0] = targetAngles[0]
		}
	}
	if(curAngles[1] != targetAngles[1])
	{
		static Float:flDist
		flDist = fabs(targetAngles[1] - curAngles[1])
		if(flDist > 180.0)
		{
			flDist = 360 - flDist
			dir[1] = -dir[1]
		}
		if(Boost)
		{
			if(flDist > 30.0)
			{
				if(TurnRate < 120.0)
				{
					TurnRate += 25.0
				}
			}
			else if(TurnRate > 80.0)
			{
				TurnRate -= 25.0
			}
			else
			{
				TurnRate += 25.0
			}
		}
		else
			TurnRate = 25.0
		curAngles[1] += deltaTime * TurnRate * dir[1]
		if(curAngles[1] < 0.0)
			curAngles[1] += 360.0
		else if(curAngles[1] >= 360.0)
			curAngles[1] -= 360.0
		if(flDist < 1.5)
			curAngles[1] = targetAngles[1]
	}
	setTurretAngles(sentry, curAngles)
	setTurnRate(sentry, TurnRate)
	
	new Float:tmpAngle[3]
	tmpAngle[0] = 0.0
	tmpAngle[1] = curAngles[1]
	set_pev(sentry, pev_angles, tmpAngle)
	
	new Float:tmp
	tmp = curAngles[0]
	tmp = -floatclamp(tmp, -45.0, 45.0) + 45.0
	tmp = 255.0 * (tmp/90.0)
	tmp = floatclamp(tmp, 0.0, 255.0)
	set_pev(sentry, pev_controller_1, floatround(tmp))
	
	return (((curAngles[0] == targetAngles[0]) && (curAngles[1] == targetAngles[1])) || TrackSentryAim(sentry)==getEnemy(sentry))?true:false
}

TrackSentryAim(sentry)
{
	static Float:vecSrc[3], Float:vecAngles[3], Float:vecDirShooting[3]
	pev(sentry, pev_origin, vecSrc)
	vecSrc[2] += 20.0
	getTurretAngles(sentry, vecAngles)
	vecAngles[0] *= -1.0
	angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecDirShooting)
	static tr, Float:vecEnd[3], pHit, Float:vecEndPos[3]
	tr = create_tr2()
	vecEnd[0] = vecSrc[0] + vecDirShooting[0] * 8192.0
	vecEnd[1] = vecSrc[1] + vecDirShooting[1] * 8192.0
	vecEnd[2] = vecSrc[2] + vecDirShooting[2] * 8192.0
	engfunc(EngFunc_TraceLine, vecSrc, vecEnd, 0, sentry, tr)
	pHit = get_tr2(tr, TR_pHit)
	get_tr2(tr, TR_vecEndPos, vecEndPos)
	while(pHit != -1)
	{
		if(is_sentrygun(sentry) && ((pHit == sentry) || (pHit == getBase(sentry))))
		{
			vecEndPos[0] += vecDirShooting[0] * 5.0
			vecEndPos[1] += vecDirShooting[1] * 5.0
			vecEndPos[2] += vecDirShooting[2] * 5.0
			engfunc(EngFunc_TraceLine, vecEndPos, vecEnd, 0, pHit, tr)
			pHit = get_tr2(tr, TR_pHit)
			get_tr2(tr, TR_vecEndPos, vecEndPos)
			continue
		}
		break
	}
	free_tr2(tr)
	return (pHit!=-1)?pHit:0
}

public AnimEvents(ent, Float:deltaTime)
{
	static Float:AnimFloats[3], seq, level
	getAnimFloats(ent, AnimFloats)
	seq = pev(ent, pev_sequence)
	level = getLevel(ent)
	
	if(seq == 1)
	{
		AnimFloats[1] = AnimFloats[0]
		AnimFloats[0] += 33.0 * deltaTime
		if(AnimFloats[0] > 11.0)
			AnimFloats[0] -= 11.0
		
		if(level == 3)
			AnimFloats[2] += deltaTime
		
		switch(level)
		{
			case 1:
			{
				if(AnimFloats[1] > AnimFloats[0])
					sentryShoot(ent)
			}
			case 2:
			{
				if(AnimFloats[1] > AnimFloats[0])
					sentryShoot(ent)
				else if(AnimFloats[1] < 8.0 && AnimFloats[0] >= 8.0)
					sentryShoot(ent)
			}
			case 3:
			{
				static Rocket; Rocket = 0
				
				static id; id = getOwner(ent)
				if(!is_connected(id))
				{
					Rocket = 0
				} else {
					static Level; Level = ZombieEli_GetLevel(id, ZombieEli_GetClass(id))
					if(Level >= 10) Rocket = 1
					else Rocket = 0
				}
				
				if(!Rocket)
				{
					if(AnimFloats[1] > AnimFloats[0])
						sentryShoot(ent)
					else if(AnimFloats[1] < 4.0 && AnimFloats[0] >= 4.0)
						sentryShoot(ent)
					else if(AnimFloats[1] < 5.0 && AnimFloats[0] >= 5.0)
						sentryShoot(ent)
					else if(AnimFloats[1] < 8.0 && AnimFloats[0] >= 8.0)
						sentryShoot(ent)
				} else {
					static rockets; rockets = g_Rocket[id]
					if(rockets)
					{
						if(get_gametime() - 3.0 > RocketShit[id])
						{
							rockets--
							sentryLaunch(ent)
							g_Rocket[id] = rockets
							
							RocketShit[id] = get_gametime()
						} else {
							if(AnimFloats[1] > AnimFloats[0])
								sentryShoot(ent)
							else if(AnimFloats[1] < 4.0 && AnimFloats[0] >= 4.0)
								sentryShoot(ent)
							else if(AnimFloats[1] < 5.0 && AnimFloats[0] >= 5.0)
								sentryShoot(ent)
							else if(AnimFloats[1] < 8.0 && AnimFloats[0] >= 8.0)
								sentryShoot(ent)
						}
					} else {
						if(AnimFloats[1] > AnimFloats[0])
							sentryShoot(ent)
						else if(AnimFloats[1] < 4.0 && AnimFloats[0] >= 4.0)
							sentryShoot(ent)
						else if(AnimFloats[1] < 5.0 && AnimFloats[0] >= 5.0)
							sentryShoot(ent)
						else if(AnimFloats[1] < 8.0 && AnimFloats[0] >= 8.0)
							sentryShoot(ent)
					}
						
					
				}
			}
		}
	}else
	{ 
		AnimFloats[0] = 0.0
		AnimFloats[1] = 0.0
		AnimFloats[2] = 0.0
	}
	
	setAnimFloats(ent, AnimFloats)
}

stock bool:is_breakable(ent)
{
	if((fpev(ent, pev_health)>0.0) && (fpev(ent, pev_takedamage)>0.0) && !(pev(ent, pev_spawnflags)&SF_BREAK_TRIGGER_ONLY))
		return true
	return false
}

stock bool:is_rocket(ent)
{
	static classname[32]
	pev(ent, pev_classname, classname, 31)
	if(equal(classname, szClasses[2]))
		return true
	return false
}


stock bool:is_sentrygun(ent)
{
	static classname[32]
	pev(ent, pev_classname, classname, 31)
	if(equal(classname, szClasses[1]))
		return true
	return false
}

stock bool:is_sentrybase(ent)
{
	static classname[32]
	pev(ent, pev_classname, classname, 31)
	if(equal(classname, szClasses[0]))
		return true
	return false
}

stock Float:getLevelHealth(id)
{
	static SP; SP = ZombieEli_GetSP(id, g_SentryHealth)
	static Health; Health = 0
	
	switch(SP)
	{
		case 1: Health = SENTRY_DEFHEALTH + (80 * 1)
		case 2: Health = SENTRY_DEFHEALTH + (80 * 2)
		case 3: Health = SENTRY_DEFHEALTH + (80 * 3)
		default: Health = SENTRY_DEFHEALTH
	}
	
	return float(Health)
}

stock changeModel(ent, model[])
{
	static s[256]
	pev(ent, pev_model, s, 255)
	if(!equal(s, model))
	{
		engfunc(EngFunc_SetModel, ent, model)
		engfunc(EngFunc_SetSize, ent, flSizes[2], flSizes[3])
	}
}

stock setSequence(ent, sequence)
{
	if(pev(ent, pev_sequence) != sequence)
	{
		set_pev(ent, pev_framerate, 1.0)
		set_pev(ent, pev_sequence, sequence)
	}
}

stock Float:fabs(Float:a) { return a>0.0?a:-a; }

stock Float:distToEnt(Float:src[3], ent)
{
	static Float:origin[3]
	pev(ent, pev_origin, origin)
	return vector_distance(origin, src)
}

stock BodyTarget(ent, Float:vecTarget[3])
{
	static Float:absmin[3], Float:absmax[3]
	pev(ent, pev_absmin, absmin)
	pev(ent, pev_absmax, absmax)
	vecTarget[0] = (absmin[0] + absmax[0]) * 0.5
	vecTarget[1] = (absmin[1] + absmax[1]) * 0.5
	vecTarget[2] = (absmin[2] + absmax[2]) * 0.5
}

stock bool:FVisible(Float:vecSrc[3], pTarget, pSkip)
{
	static tr, Float:vecTarget[3], Float:flFraction
	tr = create_tr2()
	BodyTarget(pTarget, vecTarget)
	engfunc(EngFunc_TraceLine, vecSrc, vecTarget, (1 | 0x100), pSkip, tr)
	get_tr2(tr, TR_flFraction, flFraction)
	free_tr2(tr)
	return (flFraction == 1.0)
}

stock bool:FBoxVisible(Float:vecSrc[3], pTarget, pSkip, Float:flSize, Float:vecTargetOrigin[3])
{
	static tr, Float:vecTarget[3], Float:mins[3], Float:maxs[3], Float:flFraction
	tr = create_tr2()
	for (new i = 0; i < 5; i++)
	{
		pev(pTarget, pev_origin, vecTarget)
		pev(pTarget, pev_mins, mins)
		pev(pTarget, pev_maxs, maxs)
		vecTarget[0] += random_float( mins[0] + flSize, maxs[0] - flSize )
		vecTarget[1] += random_float( mins[1] + flSize, maxs[1] - flSize )
		vecTarget[2] += random_float( mins[2] + flSize, maxs[2] - flSize )
		
		engfunc(EngFunc_TraceLine, vecSrc, vecTarget, (1 | 0x100), pSkip, tr)
		
		get_tr2(tr, TR_flFraction, flFraction)

		if (flFraction == 1.0)
		{
			vecTargetOrigin[0] = vecTarget[0]
			vecTargetOrigin[1] = vecTarget[1]
			vecTargetOrigin[2] = vecTarget[2]
			free_tr2(tr)
			return true // line of sight is valid.
		}
	}
	free_tr2(tr)
	return false
}

stock bool:FInViewCone(this, Float:vecTarget[3])
{
	static Float:angles[3], Float:v_forward[3], Float:vec2LOS[2], Float:flDot, Float:flLen
	pev(this, pev_angles, angles)
	
	pev(this, pev_origin, v_forward)
	vec2LOS[0] = vecTarget[0] - v_forward[0]
	vec2LOS[1] = vecTarget[1] - v_forward[1]
	
	flLen = floatsqroot((vec2LOS[0]*vec2LOS[0])+(vec2LOS[1]*vec2LOS[1]))
	if(flLen == 0)
	{
		vec2LOS[0] = 0.0
		vec2LOS[1] = 0.0
	}
	else
	{
		flLen = 1/flLen
		vec2LOS[0] = vec2LOS[0]*flLen
		vec2LOS[1] = vec2LOS[1]*flLen
	}
	
	angle_vector(angles, ANGLEVECTOR_FORWARD, v_forward)
	
	flDot = vec2LOS[0]*v_forward[0] + vec2LOS[1]*v_forward[1]
	
	if(flDot > 0.5)
		return true
	return false
}

stock BestVisibleEnemy(this, Float:range, bool:CheckViewCone=false)
{
	static Float:vecSrc[3], Float:vecTarget[3]
	pev(this, pev_origin, vecSrc)
	pev(this, pev_view_ofs, vecTarget)
	vecSrc[0] += vecTarget[0]
	vecSrc[1] += vecTarget[1]
	vecSrc[2] += vecTarget[2]
	
	static Best, Float:bestDist
	Best = 0
	bestDist = range
	new ent = -1
	while((ent = engfunc(EngFunc_FindEntityInSphere, ent, vecSrc, range)) != 0)
	{
		if(!pev_valid(ent))
			continue
		if(!is_alive(ent))
			continue
		if(!couldBeTarget(ent, this))
			continue
		BodyTarget(ent, vecTarget)
		if(CheckViewCone && !FInViewCone(this, vecTarget))
			continue
		if(!FVisible(vecSrc, ent, this))
			continue
		static Float:dist
		dist = distToEnt(vecSrc, ent)
		if(dist <= bestDist)
		{
			Best = ent
			bestDist = dist
		}
	}
	return Best
}

stock create_explosion(Float:origin[3], Float:dmg, Float:range, inflictor, attacker)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	write_short(boom)
	write_byte(floatround((dmg - 50.0)*0.6))
	write_byte(15)
	write_byte(TE_EXPLFLAG_NONE)
	message_end()
	
	damageRadius(origin, dmg, (1<<24), range, 1, inflictor, attacker)
}

stock damageRadius(Float:origin[3], Float:dmg, damagebits, Float:radius, mode, inflictor, attacker)
{
	if(attacker == 0)
		attacker = inflictor
	new ent = -1, Float:vecTarget[3], Float:ndmg
	while((ent = engfunc(EngFunc_FindEntityInSphere, ent, origin, radius)) != 0)
	{
		if(!pev_valid(ent))
			continue
		if(ent == inflictor)
			continue
		if(!is_breakable(ent))
			continue
		if(!FBoxVisible(origin, ent, inflictor, 0.0, vecTarget))
			continue
		ndmg = (mode==1)?(((radius-distToEnt(origin, ent))/radius)*dmg):dmg
		if(ndmg < 0.1)
			ndmg = 0.1
		set_pev(ent, pev_dmg_inflictor, inflictor)
		ExecuteHamB(Ham_TakeDamage, ent, 0, attacker, ndmg, damagebits)
	}
}

tracer(Float:start[3], Float:end[3]) {
	//new start_[3]
	new start_[3], end_[3]
	FVecIVec(start, start_)
	FVecIVec(end, end_)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) //  MSG_PAS MSG_BROADCAST
	write_byte(TE_TRACER)
	write_coord(start_[0])
	write_coord(start_[1])
	write_coord(start_[2])
	write_coord(end_[0])
	write_coord(end_[1])
	write_coord(end_[2])
	message_end()
}

gunshot(Float:origin[3], hit) {
	if(!pev_valid(hit))
		hit = 0
	if(!ExecuteHam(Ham_IsBSPModel, hit))
		return
	new origin_[3]
	FVecIVec(origin,origin_)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_GUNSHOT)
	write_coord(origin_[0])
	write_coord(origin_[1])
	write_coord(origin_[2])
	message_end()
}


public FireBullets(iShots, Float:vecSrc[3], Float:vecDirShooting[3], Float:flDamage, pevAttacker, pevInflictor)
{
	if(pevInflictor == 0)
		pevInflictor = pevAttacker
	static tr, Float:vecEnd[3], pHit, Float:vecEndPos[3]
	tr = create_tr2()
	vecEnd[0] = vecSrc[0] + vecDirShooting[0] * 8192.0
	vecEnd[1] = vecSrc[1] + vecDirShooting[1] * 8192.0
	vecEnd[2] = vecSrc[2] + vecDirShooting[2] * 8192.0
	engfunc(EngFunc_TraceLine, vecSrc, vecEnd, 0, pevInflictor, tr)
	pHit = get_tr2(tr, TR_pHit)
	get_tr2(tr, TR_vecEndPos, vecEndPos)
	while(pHit != -1)
	{
		if(is_sentrygun(pevInflictor) && ((pHit == pevInflictor) || (pHit == getBase(pevInflictor))))
		{
			vecEndPos[0] += vecDirShooting[0] * 5.0
			vecEndPos[1] += vecDirShooting[1] * 5.0
			vecEndPos[2] += vecDirShooting[2] * 5.0
			engfunc(EngFunc_TraceLine, vecEndPos, vecEnd, 0, pHit, tr)
			pHit = get_tr2(tr, TR_pHit)
			get_tr2(tr, TR_vecEndPos, vecEndPos)
			continue
		}
		if(is_breakable(pHit) && is_alive(pHit))
		{
			//ExecuteHamB(Ham_TraceAttack, pHit, pevAttacker, flDamage, vecDirShooting, tr, DMG_BULLET)
			ExecuteHamB(Ham_TakeDamage, pHit, 0, pevAttacker, flDamage, DMG_GRENADE)
			// ExecuteHamB(Ham_TraceBleed, pHit, 0, vecDirShooting, tr, DMG_BULLET)
			
			//set_pdata_float(pHit, 108, 1.0)
		}
		if(--iShots)
		{
			flDamage *= 0.7
			vecEndPos[0] += vecDirShooting[0] * 5.0
			vecEndPos[1] += vecDirShooting[1] * 5.0
			vecEndPos[2] += vecDirShooting[2] * 5.0
			engfunc(EngFunc_TraceLine, vecEndPos, vecEnd, 0, pHit, tr)
			pHit = get_tr2(tr, TR_pHit)
			get_tr2(tr, TR_vecEndPos, vecEndPos)
			continue
		}
		break
	}
	tracer(vecSrc, vecEndPos)
	gunshot(vecEndPos, pHit)
	free_tr2(tr)
}

stock sentryShoot(ent)
{
	static Float:sentryOrigin[3],Float:sentryAngle[3],Float:v_forward[3]
	pev(ent, pev_origin, sentryOrigin)
	sentryOrigin[2] += 20.0
	getTurretAngles(ent, sentryAngle)
	sentryAngle[0] *= -1.0
	angle_vector(sentryAngle, ANGLEVECTOR_FORWARD, v_forward)
	
	static Float:Damage;
	
	static Owner; Owner = getOwner(ent)
	if(!is_connected(Owner)) Damage = float(SENTRY_DEFDAMAGE)
	else {
		static SP; SP = ZombieEli_GetSP(Owner, g_SentryDamage)
		Damage = float(SENTRY_DEFDAMAGE)
		switch(SP)
		{
			case 1: Damage += 2.0
			case 2: Damage += 4.0
			case 3: Damage += 6.0
		}
	}
	
	FireBullets(1, sentryOrigin, v_forward, Damage, getOwner(ent), ent)
	emit_sound(ent, CHAN_WEAPON, szSounds[4], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	set_pev(ent, pev_effects, pev(ent, pev_effects) | EF_MUZZLEFLASH)
}

stock sentryLaunch(ent)
{
	static Float:sentryOrigin[3],Float:sentryAngle[3],Float:v_forward[3]
	pev(ent, pev_origin, sentryOrigin)
	sentryOrigin[2] += 25.0
	getTurretAngles(ent, sentryAngle)
	sentryAngle[0] *= -1.0
	angle_vector(sentryAngle, ANGLEVECTOR_FORWARD, v_forward)
	
	static i, num, ret
	num = get_pluginsnum()
	for(i=0;i<num;i++)
	{
		ret = get_func_id("sentry_launch", i)
		if(ret == -1)
			continue
		if(callfunc_begin_i(ret, i) !=1 )
			continue
		callfunc_push_int(ent)
		ret = callfunc_end()
		if(ret != PLUGIN_CONTINUE) return
	}
	
	createHVRrocket(sentryOrigin, v_forward, ent, getOwner(ent), getTeam(ent), get_pcvar_float(g_pCvars[9]))
}

stock couldBeTarget(ent, sentry)
{
	if(!pev_valid(ent))
		return false
	static i, num, ret
	num = get_pluginsnum()
	for(i=0;i<num;i++)
	{
		ret = get_func_id("sentry_couldBeTarget", i)
		if(ret == -1)
			continue
		if(callfunc_begin_i(ret, i) !=1 )
			continue
		callfunc_push_int(ent)
		callfunc_push_int(sentry)
		ret = callfunc_end()
		if(ret != -1) return (ret!=0)
	}
	return is_breakable(ent) && (ent != sentry) && (ent != getOwner(sentry)) && ((getTeam(sentry) == 0) || getTeam(sentry) != getTeam(ent))
}

stock sentryKilled(ent)
{
	static i, num, ret
	num = get_pluginsnum()
	for(i=0;i<num;i++)
	{
		ret = get_func_id("sentry_killed", i)
		if(ret == -1)
			continue
		if(callfunc_begin_i(ret, i) !=1 )
			continue
		callfunc_push_int(ent)
		ret = callfunc_end()
	}
}


public fwd_Touch(ptd, ptr)
{
	if(!pev_valid(ptd) || !is_rocket(ptd))
		return
	new Float:origin[3], Float:dmg
	pev(ptd, pev_origin, origin)
	dmg = fpev(ptd, pev_dmg)
	create_explosion(origin, dmg, dmg*1.5, ptd, getOwner(ptd))
	switch(random_num(1,3))
	{
		case 1: emit_sound(ptd, CHAN_VOICE, szSounds[6], 0.55, ATTN_NORM, 0, PITCH_NORM)
		case 2: emit_sound(ptd, CHAN_VOICE, szSounds[7], 0.55, ATTN_NORM, 0, PITCH_NORM)
		case 3: emit_sound(ptd, CHAN_VOICE, szSounds[8], 0.55, ATTN_NORM, 0, PITCH_NORM)
	}
	kill_entity(ptd)
}


public fw_Base_TakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!is_user_alive(Attacker)) return HAM_IGNORED
	if(get_user_weapon(Attacker) != CSW_KNIFE || !Get_BitVar(g_Had_ClawHammer, Attacker)) return HAM_IGNORED
	
	ZombieEli_GainBaseHealth(TEAM_HUMAN, REPAIR_HP_HIT)
	client_print(Attacker, print_center, "Repairing...")
	
	return HAM_SUPERCEDE
}

public fw_Sentry_TakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!is_user_alive(Attacker)) return HAM_IGNORED
	if(get_user_weapon(Attacker) != CSW_KNIFE || !Get_BitVar(g_Had_ClawHammer, Attacker)) return HAM_IGNORED
	
	if(pev(Victim, pev_health) < getLevelHealth(Attacker))
	{
		set_pev(Victim, pev_health, pev(Victim, pev_health) + float(REPAIR_HP_HIT))
		client_print(Attacker, print_center, "Repairing...")
	}
	
	return HAM_SUPERCEDE
}

public Get_ClawHammer(id)
{
	Set_BitVar(g_Had_ClawHammer, id)
	
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		set_pev(id, pev_viewmodel2, MODEL_V2)
		set_pev(id, pev_weaponmodel2, MODEL_P2)
		
		Set_PlayerNextAttack(id, 0.75)
		Set_WeaponAnim(id, 3)
	}
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_user_connected(id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_Had_ClawHammer, id))
		return FMRES_IGNORED
		
	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
		{
			emit_sound(id, channel, WeaponSounds[0], volume, attn, flags, pitch)
			Set_PlayerNextAttack(id, 0.75)
			
			return FMRES_SUPERCEDE
		}
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
		{
			if (sample[17] == 'w') // wall
			{
				Set_PlayerNextAttack(id, 0.75)
				emit_sound(id, channel, WeaponSounds[6], volume, attn, flags, pitch)
				return FMRES_SUPERCEDE
			} else {
				Set_PlayerNextAttack(id, 0.5)
				emit_sound(id, channel, WeaponSounds[1], volume, attn, flags, pitch)
				return FMRES_SUPERCEDE
			}
		}
		if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
		{
			Set_PlayerNextAttack(id, 1.0)
			emit_sound(id, channel, WeaponSounds[5], volume, attn, flags, pitch)
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_ClawHammer, Id))
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V2)
	set_pev(Id, pev_weaponmodel2, MODEL_P2)
}

public fw_PlayerTakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!is_user_connected(Attacker)) return
	if(get_user_weapon(Attacker) != CSW_KNIFE || !Get_BitVar(g_Had_ClawHammer, Attacker)) return

	SetHamParamFloat(3, DAMAGE_MULTI)
}

stock Set_WeaponIdleTime(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock Set_PlayerNextAttack(id, Float:nexttime)
{
	set_pdata_float(id, 83, nexttime, 5)
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}
