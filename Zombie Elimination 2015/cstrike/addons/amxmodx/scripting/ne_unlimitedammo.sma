#include <amxmodx>
#include <amxmisc>
#include <cstrike>

#define NO_BULLET_WEAPONS_BITSUM ((1<<CSW_C4)|(1<<CSW_KNIFE)|(1<<CSW_HEGRENADE)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_FLASHBANG))

new cvar_enable

native Are_You_A_Fucker(id)

public plugin_init() {
    register_plugin("New-Era_UnlimitedAmmo", "1.0.1", "New-Era Scripting Team")

    cvar_enable= register_cvar("ne_uammo_enable", "1")

    register_event("CurWeapon", "event_curweapon", "be", "1=1")
}

public event_curweapon(id) {
    if(!get_pcvar_num(cvar_enable))
        return
    if(Are_You_A_Fucker(id))
	return
    
    new weaponID=read_data(2)
    
    if( !(NO_BULLET_WEAPONS_BITSUM & (1<<weaponID)) ) {
        cs_set_user_bpammo(id, weaponID, 255)
    }
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
