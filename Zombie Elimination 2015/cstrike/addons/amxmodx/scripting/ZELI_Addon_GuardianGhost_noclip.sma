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
#include <zombie_eli>

#define PLUGIN "[ZELI] Addon: Guardian Ghost"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define MAX_GHOST 10

#define DETECT_RANGE 640.0
#define GHOST_HEALTH 200.0
#define GHOST_CLASSNAME "ghost"
#define EFFECT_CLASSNAME "deathgod"

#define GHOST_MODEL "models/zombie_elimination/Ghost.mdl"
#define AURA_MODEL "models/zombie_elimination/Aura.mdl"

new const GhostVoice[2][] = 
{
	"zombie_elimination/near_zombie_base.wav",
	"zombie_elimination/ghost/imhere.wav"
}
new const GhostPain[2][] =
{
	"zombie_elimination/bullet_hit1.wav",
	"zombie_elimination/bullet_hit2.wav"
}
new const GhostDeath[] = "zombie_elimination/ghost/nc_death3.wav"
new const GhostAttack[] = "zombie_elimination/zombie/zombi_attack_1.wav"
	
new g_ZombieBase, g_GhostNum, Float:Shitty
new g_MaxPlayers, g_RegHam, m_iBlood[2]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_think(GHOST_CLASSNAME, "fw_Ghost_Think")
	register_think(EFFECT_CLASSNAME, "fw_EffectThink")
	
	g_MaxPlayers = get_maxplayers()
}

public plugin_precache()
{
	precache_model(GHOST_MODEL)
	precache_model(AURA_MODEL)
	
	for(new i = 0; i < sizeof(GhostVoice); i++)
		precache_sound(GhostVoice[i])
	for(new i = 0; i < sizeof(GhostPain); i++)
		precache_sound(GhostPain[i])
	precache_sound(GhostDeath)
	precache_sound(GhostAttack)
	
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")	
}

public zeli_round_new()
{
	remove_entity_name(GHOST_CLASSNAME)
	g_GhostNum = 0
}

public IG_RunningTime()
{
	g_ZombieBase = ZombieEli_GetBaseEnt(TEAM_ZOMBIE)
	if(pev_valid(g_ZombieBase) != 2)
		return
	
	if(get_gametime() - 5.0 > Shitty)
	{
		for(new i = 0; i < g_MaxPlayers; i++)
		{
			if(!is_user_alive(i))
				continue
			if(ZombieEli_IsZombie(i))
				continue
			if(entity_range(g_ZombieBase, i) > DETECT_RANGE)
				continue
			
			Create_Ghost()
			PlaySound(i, GhostVoice[random_num(0, sizeof(GhostVoice) - 1)])
		}
		
		Shitty = get_gametime()
	}
}

public Create_Ghost()
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return -1

	// Set Origin & Angles
	static Float:Origin[3]; 
	pev(g_ZombieBase, pev_origin, Origin); Origin[2] += 100.0
	set_pev(Ent, pev_origin, Origin)

	// Set Config
	set_pev(Ent, pev_classname, GHOST_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, GHOST_MODEL)
	set_pev(Ent, pev_modelindex, engfunc(EngFunc_ModelIndex, GHOST_MODEL))
		
	set_pev(Ent, pev_gamestate, 1)
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	set_pev(Ent, pev_movetype, MOVETYPE_NOCLIP)
	
	// Set Size
	new Float:maxs[3] = {16.0, 16.0, 36.0}
	new Float:mins[3] = {-16.0, -16.0, -36.0}
	engfunc(EngFunc_SetSize, Ent, mins, maxs)
	
	// Set Life
	set_pev(Ent, pev_takedamage, DAMAGE_YES)
	set_pev(Ent, pev_health, 10000.0 + GHOST_HEALTH)
	
	// Set Config 2
	Set_EntAnim(Ent, 0, 1.0, 1)
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	
	if(!g_RegHam)
	{
		g_RegHam = 1
		RegisterHamFromEntity(Ham_TraceAttack, Ent, "fw_Ghost_TraceAttack")
	}
	
	g_GhostNum++
	
	return Ent
}

public fw_Ghost_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_valid_ent(Ent)) 
		return HAM_IGNORED
     
	static Classname[32]
	pev(Ent, pev_classname, Classname, charsmax(Classname)) 
	     
	if(!equal(Classname, GHOST_CLASSNAME)) 
		return HAM_IGNORED
		 
	static Float:EndPos[3] 
	get_tr2(ptr, TR_vecEndPos, EndPos)

	create_blood(EndPos)
	emit_sound(Ent, CHAN_BODY, GhostPain[random_num(0, sizeof(GhostPain) -1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	return HAM_IGNORED
}

public fw_Ghost_Think(Ent)
{
	if(!pev_valid(Ent)) return
	if((pev(Ent, pev_health) - 10000.0) <= 0.0)
	{
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		static Float:Vel[3]
		Send_EffectModel(Origin, Vel, AURA_MODEL, 0.5, 0)
		
		emit_sound(Ent, CHAN_BODY, GhostDeath, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		g_GhostNum--
		
		return
	}
	
	if(!pev_valid(g_ZombieBase))
	{
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		static Float:Vel[3]
		Send_EffectModel(Origin, Vel, AURA_MODEL, 0.5, 0)
		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		g_GhostNum--
		
		return
	}
	//if(entity_range(g_ZombieBase, Ent) >= 100.0 && pev(Ent, pev_solid) != SOLID_SLIDEBOX)
		//set_pev(Ent, pev_solid, SOLID_SLIDEBOX)

	static Enemy; 
	Enemy = FindClosetEnemy(Ent, 0)
	if(!is_user_alive(Enemy)) Enemy = pev(Ent, pev_enemy)
	static Float:EnemyOrigin[3]
	
	if(is_user_alive(Enemy))
	{
		if(entity_range(g_ZombieBase, Enemy) > DETECT_RANGE)
		{
			if(entity_range(g_ZombieBase, Ent) <= 60.0)
			{
				static Float:Origin[3]; pev(Ent, pev_origin, Origin)
				static Float:Vel[3]
				Send_EffectModel(Origin, Vel, AURA_MODEL, 0.5, 0)
				
				set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
				set_pev(Ent, pev_flags, FL_KILLME)
				
				g_GhostNum--
				
				return
			} else {
				pev(g_ZombieBase, pev_origin, EnemyOrigin)
				Aim_To2(Ent, EnemyOrigin) 
				hook_ent2(Ent, EnemyOrigin, 200.0)
				
				Set_EntAnim(Ent, 0, 1.0, 0)
				set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
				
				return
			}
		}
		
		pev(Enemy, pev_origin, EnemyOrigin)
		if(entity_range(Enemy, Ent) <= 60.0)
		{
			Aim_To2(Ent, EnemyOrigin) 
			static Float:Angles[3]; pev(Ent, pev_angles, Angles)
			Angles[1] -= 45.0
			set_pev(Ent, pev_angles, Angles)
			set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
			
			static Float:Time; pev(Ent, pev_fuser3, Time)
			if(get_gametime() - 1.5 > Time)
			{
				Set_EntAnim(Ent, 76, 1.0, 1)
				
				ExecuteHam(Ham_TakeDamage, Enemy, 0, Enemy, 10.0, DMG_BLAST)
				emit_sound(Ent, CHAN_WEAPON, GhostAttack, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				
				EnemyOrigin[2] += 16.0
				create_blood(EnemyOrigin)
				set_pev(Ent, pev_fuser3, get_gametime())
			}
		} else {
			Aim_To2(Ent, EnemyOrigin) 
			hook_ent2(Ent, EnemyOrigin, 150.0)
			
			Set_EntAnim(Ent, 0, 1.0, 0)
		}
	} else {
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		static Float:Vel[3]
		Send_EffectModel(Origin, Vel, AURA_MODEL, 0.5, 0)
		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		g_GhostNum--
		
		return
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_EffectThink(Ent)
{
	if(!pev_valid(Ent))
		return
		
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01)
	set_pev(Ent, pev_flags, FL_KILLME)
}

public Aim_To2(iEnt, Float:vTargetOrigin[3])
{
	if(!pev_valid(iEnt))	
		return
		
	static Float:Vec[3], Float:Angles[3]
	pev(iEnt, pev_origin, Vec)
	
	Vec[0] = vTargetOrigin[0] - Vec[0]
	Vec[1] = vTargetOrigin[1] - Vec[1]
	Vec[2] = vTargetOrigin[2] - Vec[2]
	engfunc(EngFunc_VecToAngles, Vec, Angles)
	//Angles[0] = Angles[2] = 0.0 
	
	set_pev(iEnt, pev_v_angle, Angles)
	set_pev(iEnt, pev_angles, Angles)
}

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

stock Set_EntAnim(ent, anim, Float:framerate, resetframe)
{
	if(!pev_valid(ent))
		return
	
	if(!resetframe)
	{
		if(pev(ent, pev_sequence) != anim)
		{
			set_pev(ent, pev_animtime, get_gametime())
			set_pev(ent, pev_framerate, framerate)
			set_pev(ent, pev_sequence, anim)
		}
	} else {
		set_pev(ent, pev_animtime, get_gametime())
		set_pev(ent, pev_framerate, framerate)
		set_pev(ent, pev_sequence, anim)
	}
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

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed)
{
	if(!pev_valid(ent))
		return
	
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / speed
		
	fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time
	fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time
	fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time

	set_pev(ent, pev_velocity, fl_Velocity)
}

stock Send_EffectModel(Float:Origin[3], Float:Velocity[3], const Model[], Float:Time, Anim)
{
	static Ent; Ent = create_entity("info_target")
	if(!pev_valid(Ent)) return 
	
	// Set Properties
	set_pev(Ent, pev_takedamage, DAMAGE_NO)
	set_pev(Ent, pev_solid, SOLID_NOT)
	set_pev(Ent, pev_movetype, MOVETYPE_FLY)
	
	// Set Sprite
	set_pev(Ent, pev_classname, EFFECT_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, Model)
	
	// Set Rendering
	set_pev(Ent, pev_renderfx, kRenderFxNone)
	set_pev(Ent, pev_rendermode, kRenderTransAdd)
	set_pev(Ent, pev_renderamt, 255.0)
	
	// Set other & Origin
	engfunc(EngFunc_SetOrigin, Ent, Origin)
	set_pev(Ent, pev_velocity, Velocity)
	
	// Animation
	set_pev(Ent, pev_animtime, get_gametime())
	set_pev(Ent, pev_framerate, 1.0)
	set_pev(Ent, pev_sequence, Anim)
		
	// Force Think
	set_pev(Ent, pev_nextthink, get_gametime() + Time)
}

stock create_blood(const Float:origin[3])
{
	// Show some blood :)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_BLOODSPRITE)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	write_short(m_iBlood[1])
	write_short(m_iBlood[0])
	write_byte(75)
	write_byte(5)
	message_end()
}

public FindClosetEnemy(ent, can_see)
{
	new Float:maxdistance = 4960.0
	new indexid = 0	
	new Float:current_dis = maxdistance

	for(new i = 1 ;i <= g_MaxPlayers; i++)
	{
		if(can_see)
		{
			if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT && can_see_fm(ent, i) && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}
		} else {
			if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}			
		}
	}	
	
	return indexid
}

public bool:can_see_fm(entindex1, entindex2)
{
	if (!entindex1 || !entindex2)
		return false

	if (pev_valid(entindex1) && pev_valid(entindex1))
	{
		new flags = pev(entindex1, pev_flags)
		if (flags & EF_NODRAW || flags & FL_NOTARGET)
		{
			return false
		}

		new Float:lookerOrig[3]
		new Float:targetBaseOrig[3]
		new Float:targetOrig[3]
		new Float:temp[3]

		pev(entindex1, pev_origin, lookerOrig)
		pev(entindex1, pev_view_ofs, temp)
		lookerOrig[0] += temp[0]
		lookerOrig[1] += temp[1]
		lookerOrig[2] += temp[2]

		pev(entindex2, pev_origin, targetBaseOrig)
		pev(entindex2, pev_view_ofs, temp)
		targetOrig[0] = targetBaseOrig [0] + temp[0]
		targetOrig[1] = targetBaseOrig [1] + temp[1]
		targetOrig[2] = targetBaseOrig [2] + temp[2]

		engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the had of seen player
		if (get_tr2(0, TraceResult:TR_InOpen) && get_tr2(0, TraceResult:TR_InWater))
		{
			return false
		} 
		else 
		{
			new Float:flFraction
			get_tr2(0, TraceResult:TR_flFraction, flFraction)
			if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
			{
				return true
			}
			else
			{
				targetOrig[0] = targetBaseOrig [0]
				targetOrig[1] = targetBaseOrig [1]
				targetOrig[2] = targetBaseOrig [2]
				engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the body of seen player
				get_tr2(0, TraceResult:TR_flFraction, flFraction)
				if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
				{
					return true
				}
				else
				{
					targetOrig[0] = targetBaseOrig [0]
					targetOrig[1] = targetBaseOrig [1]
					targetOrig[2] = targetBaseOrig [2] - 17.0
					engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the legs of seen player
					get_tr2(0, TraceResult:TR_flFraction, flFraction)
					if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
					{
						return true
					}
				}
			}
		}
	}
	return false
}
