enum glock_e
{
	GLOCK_LONGIDLE = 0,
	GLOCK_IDLE1,
	GLOCK_IDLE2,
	GLOCK_FIRE1,
	GLOCK_FIRE2,
	GLOCK_RELOAD,
	GLOCK_RELOAD_EMPTY,
	GLOCK_DEPLOY,
};

const int GLOCK_DEFAULT_GIVE 	= 51;
const int GLOCK_MAX_AMMO		= 170;
const int GLOCK_MAX_CLIP 		= 17;
const int GLOCK_WEIGHT 			= 5;

class weapon_aomglock : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	float m_flNextAnimTime;
	int m_iShell;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/aomdc/weapons/glock/w_glock.mdl" );

		self.m_iDefaultAmmo = GLOCK_DEFAULT_GIVE;

		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/aomdc/weapons/glock/v_glock.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/glock/w_glock.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/glock/p_glock.mdl" );

		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" );

		g_Game.PrecacheModel( "models/w_9mmARclip.mdl" );
		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );              

		//These are played by the model, needs changing there
		g_SoundSystem.PrecacheSound( "aomdc/weapons/glock/glock_magin.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/glock/glock_magout.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/glock/glock_magplace.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/glock/glock_slideforward.wav" );

		g_SoundSystem.PrecacheSound( "aomdc/weapons/glock/glock_fire.wav" );

		g_SoundSystem.PrecacheSound( "hl/weapons/357_cock1.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= GLOCK_MAX_AMMO;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= GLOCK_MAX_CLIP;
		info.iSlot 		= 1;
		info.iPosition 	= 8;
		info.iFlags 	= 0;
		info.iWeight 	= GLOCK_WEIGHT;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		@m_pPlayer = pPlayer;
			
		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( self.m_iId );
		message.End();

		return true;
	}
	
	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hl/weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
		}
		
		return false;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( "models/aomdc/weapons/glock/v_glock.mdl" ), self.GetP_Model( "models/aomdc/weapons/glock/p_glock.mdl" ), GLOCK_DEPLOY, "onehanded" );
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time; //g_WeaponFuncs.WeaponTimeBase();
	}
	
	void PrimaryAttack()
	{
		if( self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			return;
		}

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		--self.m_iClip;
		
		switch ( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 0, 1 ) )
		{
			case 0: self.SendWeaponAnim( GLOCK_FIRE1, 0, 0 ); break;
			case 1: self.SendWeaponAnim( GLOCK_FIRE2, 0, 0 ); break;
		}
		
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/glock/glock_fire.wav", 1.0, ATTN_NORM, 0, 95 + Math.RandomLong( 0, 10 ) );

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		// JonnyBoy0719: Added custom bullet damage.
		int m_iBulletDamage = 25;
		// JonnyBoy0719: End
		
		// optimized multiplayer. Widened to make it easier to hit a moving player
		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_2DEGREES, 8192, BULLET_PLAYER_CUSTOMDAMAGE, 2, m_iBulletDamage );

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
			
		m_pPlayer.pev.punchangle.x = Math.RandomLong( -2, 2 );

		self.m_flNextPrimaryAttack = self.m_flNextPrimaryAttack + 0.30;
		if( self.m_flNextPrimaryAttack < WeaponTimeBase() )
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.30;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed,  10, 15 );
		
		TraceResult tr;
		
		float x, y;
		
		g_Utility.GetCircularGaussianSpread( x, y );
		
		Vector vecDir = vecAiming 
						+ x * VECTOR_CONE_2DEGREES.x * g_Engine.v_right 
						+ y * VECTOR_CONE_2DEGREES.y * g_Engine.v_up;

		Vector vecEnd	= vecSrc + vecDir * 4096;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );
		
		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				
				if( pHit is null || pHit.IsBSPModel() == true )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_MP5 );
			}
		}
	}
	
	void Reload()
	{
		self.DefaultReload( GLOCK_MAX_CLIP, GLOCK_RELOAD, 1.5, 0 );

		//Set 3rd person reloading animation -Sniper
		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		int iAnim;
		switch( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed,  0, 1 ) )
		{
		case 0:	
			iAnim = GLOCK_LONGIDLE;	
			break;
		
		case 1:
			iAnim = GLOCK_IDLE1;
			break;
			
		default:
			iAnim = GLOCK_IDLE1;
			break;
		}

		self.SendWeaponAnim( iAnim );

		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed,  10, 15 );// how long till we do this again.
	}
}

string GetWeaponName_AOMGLOCK()
{
	return "weapon_aomglock";
}

void Registerweapon_GLOCK()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_aomglock", GetWeaponName_AOMGLOCK() );
	g_ItemRegistry.RegisterWeapon( GetWeaponName_AOMGLOCK(), "aom_weapons", "9mm" );
}
