// special deathmatch shotgun spreads
const Vector VECTOR_CONE_DM_SHOTGUN( 0.08716, 0.04362, 0.00  );		// 10 degrees by 5 degrees
const Vector VECTOR_CONE_DM_DOUBLESHOTGUN( 0.17365, 0.04362, 0.00 ); 	// 20 degrees by 5 degrees

const int SHOTGUN_DEFAULT_AMMO 	= 12;
const int SHOTGUN_MAX_CARRY 	= 125;
const int SHOTGUN_MAX_CLIP 		= 8;
const int SHOTGUN_WEIGHT 		= 15;

const uint SHOTGUN_SINGLE_PELLETCOUNT = 4;
const uint SHOTGUN_DOUBLE_PELLETCOUNT = SHOTGUN_SINGLE_PELLETCOUNT * 2;

enum ShotgunAnimation
{
	SHOTGUN_IDLE = 0,
	SHOTGUN_FIRE,
	SHOTGUN_FIRE2,
	SHOTGUN_RELOAD,
	SHOTGUN_PUMP,
	SHOTGUN_START_RELOAD,
	SHOTGUN_DRAW,
	SHOTGUN_HOLSTER,
	SHOTGUN_IDLE4,
	SHOTGUN_IDLE_DEEP
};

class weapon_aomshotgun : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	float m_flNextReload;
	int m_iShell;
	float m_flPumpTime;
	bool m_fPlayPumpSound;
	bool m_fShotgunReload;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/aomdc/weapons/shotgun/w_shotgun.mdl" );
		
		self.m_iDefaultAmmo = SHOTGUN_DEFAULT_AMMO;

		self.FallInit();// get ready to fall
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/aomdc/weapons/shotgun/v_shotgun.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/shotgun/w_shotgun.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/shotgun/p_shotgun.mdl" );

		m_iShell = g_Game.PrecacheModel( "models/shotgunshell.mdl" );// shotgun shell

		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );              

		g_SoundSystem.PrecacheSound( "aomdc/weapons/shotgun/shotgun_fire_dbl.wav" );//shotgun
		g_SoundSystem.PrecacheSound( "aomdc/weapons/shotgun/shotgun_fire.wav" );//shotgun

		g_SoundSystem.PrecacheSound( "aomdc/weapons/shotgun/shotgun_insert.wav" );	// shotgun reload

		g_SoundSystem.PrecacheSound( "aomdc/weapons/shotgun/sshell1.wav" );	// shotgun reload
		g_SoundSystem.PrecacheSound( "aomdc/weapons/shotgun/sshell2.wav" );	// shotgun reload
		g_SoundSystem.PrecacheSound( "aomdc/weapons/shotgun/sshell3.wav" );	// shotgun reload
		
		g_SoundSystem.PrecacheSound( "aomdc/weapons/shotgun/shotgun_pump.wav" );	// cock gun
		g_SoundSystem.PrecacheSound( "hl/weapons/357_cock1.wav" );
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
	
	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= SHOTGUN_MAX_CARRY;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= SHOTGUN_MAX_CLIP;
		info.iSlot 		= 2;
		info.iPosition 	= 8;
		info.iFlags 	= 0;
		info.iWeight 	= SHOTGUN_WEIGHT;

		return true;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( "models/aomdc/weapons/shotgun/v_shotgun.mdl" ), self.GetP_Model( "models/aomdc/weapons/shotgun/p_shotgun.mdl" ), SHOTGUN_DRAW, "shotgun" );
	}
	
	void Holster( int skipLocal = 0 )
	{
		m_fShotgunReload = false;
		
		BaseClass.Holster( skipLocal );
	}

	void ItemPostFrame()
	{
		if( m_flPumpTime != 0 && m_flPumpTime < g_Engine.time && m_fPlayPumpSound )
		{
			// play pumping sound
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "aomdc/weapons/shotgun/shotgun_pump.wav", 1, ATTN_NORM, 0, 95 + Math.RandomLong( 0,0x1f ) );

			m_fPlayPumpSound = false;
		}

		BaseClass.ItemPostFrame();
	}
	
	void CreatePelletDecals( const Vector& in vecSrc, const Vector& in vecAiming, const Vector& in vecSpread, const uint uiPelletCount )
	{
		TraceResult tr;
		
		float x, y;
		
		for( uint uiPellet = 0; uiPellet < uiPelletCount; ++uiPellet )
		{
			g_Utility.GetCircularGaussianSpread( x, y );
			
			Vector vecDir = vecAiming 
							+ x * vecSpread.x * g_Engine.v_right 
							+ y * vecSpread.y * g_Engine.v_up;

			Vector vecEnd	= vecSrc + vecDir * 2048;
			
			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );
			
			if( tr.flFraction < 1.0 )
			{
				if( tr.pHit !is null )
				{
					CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
					
					if( pHit is null || pHit.IsBSPModel() == true )
						g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_BUCKSHOT );
				}
			}
		}
	}

	void PrimaryAttack()
	{
		// don't fire underwater
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + 0.15;
			return;
		}

		if( self.m_iClip <= 0 )
		{
			self.m_flNextPrimaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 0.75;
			self.Reload();
			self.PlayEmptySound();
			return;
		}

		self.SendWeaponAnim( SHOTGUN_FIRE, 0, 0 );
		
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/shotgun/shotgun_fire.wav", Math.RandomFloat( 0.95, 1.0 ), ATTN_NORM, 0, 93 + Math.RandomLong( 0, 0x1f ) );
		
		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		--self.m_iClip;

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		// JonnyBoy0719: Added custom bullet damage.
		int m_iBulletDamage = 15;
		// JonnyBoy0719: End

		m_pPlayer.FireBullets( 4, vecSrc, vecAiming, VECTOR_CONE_DM_SHOTGUN, 2048, BULLET_PLAYER_CUSTOMDAMAGE, 0, m_iBulletDamage );

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		if( self.m_iClip != 0 )
			m_flPumpTime = g_Engine.time + 0.5;
			
		m_pPlayer.pev.punchangle.x = -5.0;

		self.m_flNextPrimaryAttack = g_Engine.time + 0.85;
		self.m_flNextSecondaryAttack = g_Engine.time + 0.85;

		if( self.m_iClip != 0 )
			self.m_flTimeWeaponIdle = g_Engine.time + 5.0;
		else
			self.m_flNextPrimaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 0.75;

		m_fShotgunReload = false;
		m_fPlayPumpSound = true;
		
		CreatePelletDecals( vecSrc, vecAiming, VECTOR_CONE_DM_SHOTGUN, SHOTGUN_SINGLE_PELLETCOUNT );
	}

	void SecondaryAttack()
	{
		// don't fire underwater
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + 0.15;
			return;
		}

		if( self.m_iClip <= 1 )
		{
			self.Reload();
			self.PlayEmptySound();
			return;
		}
		
		self.SendWeaponAnim( SHOTGUN_FIRE2, 0, 0 );
		
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/shotgun/shotgun_fire_dbl.wav", Math.RandomFloat( 0.98, 1.0 ), ATTN_NORM, 0, 85 + Math.RandomLong( 0, 0x1f ) );

		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		self.m_iClip -= 2;

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		// JonnyBoy0719: Added custom bullet damage.
		int m_iBulletDamage = 28;
		// JonnyBoy0719: End
		
		m_pPlayer.FireBullets( 8, vecSrc, vecAiming, VECTOR_CONE_DM_DOUBLESHOTGUN, 2048, BULLET_PLAYER_CUSTOMDAMAGE, 0, m_iBulletDamage );

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		//if (m_iClip != 0)
			m_flPumpTime = g_Engine.time + 0.95;

		self.m_flNextPrimaryAttack = g_Engine.time + 1.5;
		self.m_flNextSecondaryAttack = g_Engine.time + 1.5;
		
		if( self.m_iClip != 0 )
			self.m_flTimeWeaponIdle = g_Engine.time + 6.0;
		else
			self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
			
		m_pPlayer.pev.punchangle.x = -10.0;

		m_fShotgunReload = false;
		m_fPlayPumpSound = true;
		
		CreatePelletDecals( vecSrc, vecAiming, VECTOR_CONE_DM_DOUBLESHOTGUN, SHOTGUN_DOUBLE_PELLETCOUNT );
	}

	void Reload()
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 || self.m_iClip == SHOTGUN_MAX_CLIP )
			return;

		if( m_flNextReload > g_Engine.time )
			return;

		// don't reload until recoil is done
		if( self.m_flNextPrimaryAttack > g_Engine.time && !m_fShotgunReload )
			return;

		// check to see if we're ready to reload
		if( !m_fShotgunReload )
		{
			self.SendWeaponAnim( SHOTGUN_START_RELOAD, 0, 0 );
			m_pPlayer.m_flNextAttack 	= 0.6;	//Always uses a relative time due to prediction
			self.m_flTimeWeaponIdle			= g_Engine.time + 0.6;
			self.m_flNextPrimaryAttack 		= g_Engine.time + 1.0;
			self.m_flNextSecondaryAttack	= g_Engine.time + 1.0;
			m_fShotgunReload = true;
			return;
		}
		else if( m_fShotgunReload )
		{
			if( self.m_flTimeWeaponIdle > g_Engine.time )
				return;

			if( self.m_iClip == SHOTGUN_MAX_CLIP )
			{
				m_fShotgunReload = false;
				return;
			}

			self.SendWeaponAnim( SHOTGUN_RELOAD, 0 );
			m_flNextReload 					= g_Engine.time + 0.5;
			self.m_flNextPrimaryAttack 		= g_Engine.time + 0.5;
			self.m_flNextSecondaryAttack 	= g_Engine.time + 0.5;
			self.m_flTimeWeaponIdle 		= g_Engine.time + 0.5;
				
			// Add them to the clip
			self.m_iClip += 1;
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
			
			switch( Math.RandomLong( 0, 1 ) )
			{
			case 0:
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "aomdc/weapons/shotgun/shotgun_insert.wav", 1, ATTN_NORM, 0, 85 + Math.RandomLong( 0, 0x1f ) );
				break;
			case 1:
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "aomdc/weapons/shotgun/shotgun_insert.wav", 1, ATTN_NORM, 0, 85 + Math.RandomLong( 0, 0x1f ) );
				break;
			}
		}

		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		if( self.m_flTimeWeaponIdle < g_Engine.time )
		{
			if( self.m_iClip == 0 && !m_fShotgunReload && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) != 0 )
			{
				self.Reload();
			}
			else if( m_fShotgunReload )
			{
				if( self.m_iClip != SHOTGUN_MAX_CLIP && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 )
				{
					self.Reload();
				}
				else
				{
					// reload debounce has timed out
					self.SendWeaponAnim( SHOTGUN_PUMP, 0, 0 );

					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "aomdc/weapons/shotgun/shotgun_pump.wav", 1, ATTN_NORM, 0, 95 + Math.RandomLong( 0,0x1f ) );
					m_fShotgunReload = false;
					self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
				}
			}
			else
			{
				int iAnim;
				float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0, 1 );
				if( flRand <= 0.8 )
				{
					iAnim = SHOTGUN_IDLE_DEEP;
					self.m_flTimeWeaponIdle = g_Engine.time + (60.0/12.0);// * RANDOM_LONG(2, 5);
				}
				else if( flRand <= 0.95 )
				{
					iAnim = SHOTGUN_IDLE;
					self.m_flTimeWeaponIdle = g_Engine.time + (20.0/9.0);
				}
				else
				{
					iAnim = SHOTGUN_IDLE4;
					self.m_flTimeWeaponIdle = g_Engine.time+ (20.0/9.0);
				}
				self.SendWeaponAnim( iAnim, 1, 0 );
			}
		}
	}
}

string GetWeaponName_AOMSHOTGUN()
{
	return "weapon_aomshotgun";
}

void RegisterWeapon_SHOTGUN()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_aomshotgun", GetWeaponName_AOMSHOTGUN() );
	g_ItemRegistry.RegisterWeapon( GetWeaponName_AOMSHOTGUN(), "aom_weapons", "buckshot" );
}
