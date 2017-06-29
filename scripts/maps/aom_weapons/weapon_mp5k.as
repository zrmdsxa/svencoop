enum Mp5Animation
{
	MP5_LONGIDLE = 0,
	MP5_IDLE1,
	MP5_LAUNCH,
	MP5_RELOAD,
	MP5_DEPLOY,
	MP5_FIRE1,
	MP5_FIRE2,
	MP5_FIRE3,
};

const int MP5_DEFAULT_GIVE 	= 150;
const int MP5_MAX_AMMO		= 250;
const int MP5_MAX_CLIP 		= 50;
const int MP5_WEIGHT 		= 5;

class weapon_mp5k : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	float m_flNextAnimTime;
	int m_iShell;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/aomdc/weapons/mp5k/w_mp5k.mdl" );

		self.m_iDefaultAmmo = MP5_DEFAULT_GIVE;

		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/aomdc/weapons/mp5k/v_mp5k.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/mp5k/w_mp5k.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/mp5k/p_mp5k.mdl" );

		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" );

		g_Game.PrecacheModel( "models/w_9mmARclip.mdl" );
		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );              

		//These are played by the model, needs changing there
		g_SoundSystem.PrecacheSound( "aomdc/weapons/mp5k/mp5k_boltback.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/mp5k/mp5k_boltforward.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/mp5k/mp5k_magin.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/mp5k/mp5k_magout.wav" );

		g_SoundSystem.PrecacheSound( "aomdc/weapons/mp5k/mp5k_fire.wav" );

		g_SoundSystem.PrecacheSound( "hl/weapons/357_cock1.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= MP5_MAX_AMMO;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= MP5_MAX_CLIP;
		info.iSlot 		= 2;
		info.iPosition 	= 6;
		info.iFlags 	= 0;
		info.iWeight 	= MP5_WEIGHT;

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
		return self.DefaultDeploy( self.GetV_Model( "models/aomdc/weapons/mp5k/v_mp5k.mdl" ), self.GetP_Model( "models/aomdc/weapons/mp5k/p_mp5k.mdl" ), MP5_DEPLOY, "mp5" );
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time; //g_WeaponFuncs.WeaponTimeBase();
	}

	void PrimaryAttack()
	{
		// don't fire underwater
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound( );
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			return;
		}

		if( self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			return;
		}

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		--self.m_iClip;
		
		switch ( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 0, 2 ) )
		{
		case 0: self.SendWeaponAnim( MP5_FIRE1, 0, 0 ); break;
		case 1: self.SendWeaponAnim( MP5_FIRE2, 0, 0 ); break;
		case 2: self.SendWeaponAnim( MP5_FIRE3, 0, 0 ); break;
		}
		
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/mp5k/mp5k_fire.wav", 1.0, ATTN_NORM, 0, 95 + Math.RandomLong( 0, 10 ) );

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		// JonnyBoy0719: Added custom bullet damage.
		int m_iBulletDamage = 19;
		// JonnyBoy0719: End
		
		// optimized multiplayer. Widened to make it easier to hit a moving player
		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_6DEGREES, 8192, BULLET_PLAYER_CUSTOMDAMAGE, 2, m_iBulletDamage/*, ( (ShouldGib) ? DMG_ALWAYSGIB : DMG_NEVERGIB ) */);

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
			
		m_pPlayer.pev.punchangle.x = Math.RandomLong( -2, 2 );

		self.m_flNextPrimaryAttack = self.m_flNextPrimaryAttack + 0.1;
		if( self.m_flNextPrimaryAttack < WeaponTimeBase() )
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.1;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed,  10, 15 );
		
		TraceResult tr;
		
		float x, y;
		
		g_Utility.GetCircularGaussianSpread( x, y );
		
		Vector vecDir = vecAiming 
						+ x * VECTOR_CONE_6DEGREES.x * g_Engine.v_right 
						+ y * VECTOR_CONE_6DEGREES.y * g_Engine.v_up;

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
		self.DefaultReload( MP5_MAX_CLIP, MP5_RELOAD, 1.5, 0 );

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
			iAnim = MP5_LONGIDLE;	
			break;
		
		case 1:
			iAnim = MP5_IDLE1;
			break;
			
		default:
			iAnim = MP5_IDLE1;
			break;
		}

		self.SendWeaponAnim( iAnim );

		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed,  10, 15 );// how long till we do this again.
	}
}

string GetWeaponName_AOMMP5K()
{
	return "weapon_mp5k";
}

void RegisterWeapon_MP5K()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_mp5k", GetWeaponName_AOMMP5K() );
	g_ItemRegistry.RegisterWeapon( GetWeaponName_AOMMP5K(), "aom_weapons", "9mmar" );
}
