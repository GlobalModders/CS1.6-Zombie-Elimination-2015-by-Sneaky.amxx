#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>
#include <zombie_eli>

#define PLUGIN "[ZE] Claw Hammer"
#define VERSION "1.0"
#define AUTHOR "author"

#define REPAIR_HP_HIT 20
#define DAMAGE_MULTI 5.0

#define MODEL_V "models/v_zsh_clawhammer.mdl"
#define MODEL_P "models/p_zsh_clawhammer.mdl"

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

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_ClawHammer
new g_HumanBase

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_EmitSound, "fw_EmitSound")
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage")
	
	register_clcmd("say /get", "Get_ClawHammer")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
}

public zeli_round_start()
{
	g_HumanBase = ZombieEli_GetBaseEnt(TEAM_HUMAN)
	if(pev_valid(g_HumanBase)) RegisterHamFromEntity(Ham_TakeDamage, g_HumanBase, "fw_Base_TakeDamage")
}

public fw_Base_TakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!is_user_alive(Attacker)) return HAM_IGNORED
	if(get_user_weapon(Attacker) != CSW_KNIFE || !Get_BitVar(g_Had_ClawHammer, Attacker)) return HAM_IGNORED
	
	ZombieEli_GainBaseHealth(TEAM_HUMAN, REPAIR_HP_HIT)
	client_print(Attacker, print_center, "Repairing...")
	
	return HAM_SUPERCEDE
}

public Get_ClawHammer(id)
{
	Set_BitVar(g_Had_ClawHammer, id)
	
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_P)
		
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
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
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
