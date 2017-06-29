/*
* point_checkpoint
* This point entity represents a point in the world where players can trigger a checkpoint
* Dead players are revived
*/

/*
	Changed to fit AOM:DC atmosphere etc.
*/

enum AomPointCheckpointFlags
{
	AOM_CHECKPOINT_REUSABLE 		= 1 << 0,	//This checkpoint is reusable
}

class aom_checkpoint : ScriptBaseEntity
{
	private bool m_fActivated = false;
	private CSprite@ m_pSprite;
	private int m_iNextPlayerToRevive = 1;
	
	private float m_flDelayBeforeStart 			= 3; 	//How much time between being triggered and starting the revival of dead players
	private float m_flDelayBetweenRevive 		= 1; 	//Time between player revive
	
	private float m_flDelayBeforeReactivation 	= 60; 	//How much time before this checkpoint becomes active again, if AOM_CHECKPOINT_REUSABLE is set
	
	private float m_flRespawnStartTime;					//When we started a respawn
	
	private bool m_bEnabled = true;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if( szKey == "m_flDelayBeforeStart" )
		{
			m_flDelayBeforeStart = atof( szValue );
			return true;
		}
		else if( szKey == "m_flDelayBetweenRevive" )
		{
			m_flDelayBetweenRevive = atof( szValue );
			return true;
		}
		else if( szKey == "m_flDelayBeforeReactivation" )
		{
			m_flDelayBeforeReactivation = atof( szValue );
			return true;
		}
		else if( szKey == "minhullsize" )
		{
			g_Utility.StringToVector( self.pev.vuser1, szValue );
			return true;
		}
		else if( szKey == "maxhullsize" )
		{
			g_Utility.StringToVector( self.pev.vuser2, szValue );
			return true;
		}
		else
			return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Precache()
	{
		BaseClass.Precache();
		
		g_Game.PrecacheModel( "sprites/aomdc/muz1.spr" );
		
		g_SoundSystem.PrecacheSound( "aomdc/misc/checkpoint.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/misc/checkpoint_spawn.wav" );
		g_SoundSystem.PrecacheSound( self.pev.message );
		g_SoundSystem.PrecacheSound( "aomdc/misc/event.wav" );
	}
	
	void SetupModel()
	{
		if( string( self.pev.model ).IsEmpty() )
			g_Game.PrecacheModel( "models/aomdc/misc/checkpoint.mdl" );
		else
			g_Game.PrecacheModel( self.pev.model );
	}
	
	void Spawn()
	{
		self.pev.movetype 		= MOVETYPE_FLY;
		self.pev.solid 			= SOLID_TRIGGER;
		
		self.pev.framerate 		= 1.0f;
		
		//Precache the model first
		SetupModel();
		
		//Allow for custom models
		if( string( self.pev.model ).IsEmpty() )
			g_EntityFuncs.SetModel( self, "models/aomdc/misc/checkpoint.mdl" );
		else
			g_EntityFuncs.SetModel( self, self.pev.model );
			
		if( string( self.pev.message ).IsEmpty() )
			self.pev.message = "aomdc/monsters/devourer/bcl_die3.wav";
		
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
		
		//Custom hull size
		if( self.pev.vuser1 != g_vecZero && self.pev.vuser2 != g_vecZero )
			g_EntityFuncs.SetSize( self.pev, self.pev.vuser1, self.pev.vuser2 );
		else
			g_EntityFuncs.SetSize( self.pev, Vector( -64, -64, -36 ), Vector( 64, 64, 36 ) );
			
		self.Precache();
	}
	
	void Touch( CBaseEntity@ pOther )
	{
		if( m_bEnabled && !m_fActivated && pOther.IsPlayer() == true )
		{
			m_fActivated = true;
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_STATIC, "aomdc/misc/checkpoint.wav", 1.0f, ATTN_NONE );
				
			SetThink( ThinkFunction( this.RespawnStartThink ) );
			self.pev.nextthink = g_Engine.time + m_flDelayBeforeStart;
			
			m_flRespawnStartTime = g_Engine.time;
			
			//Make this entity invisible
			self.pev.effects |= EF_NODRAW;
			
			//Trigger targets
			self.SUB_UseTargets( pOther, USE_TOGGLE, 0 );
		}
	}
	
	bool IsEnabled() const { return m_bEnabled; }
	
	void SetEnabled( const bool bEnabled )
	{
		if( m_bEnabled != bEnabled )
		{
			if( bEnabled )
			{
				self.pev.effects &= ~EF_NODRAW;
			}
			else
			{
				self.pev.effects |= EF_NODRAW;
			}
			
			m_bEnabled = bEnabled;
		}
	}
	
	void RespawnStartThink()
	{
		//Clean up the old sprite if needed
		if( m_pSprite !is null )
			g_EntityFuncs.Remove( m_pSprite );
		
		m_iNextPlayerToRevive = 1;
		
		@m_pSprite = g_EntityFuncs.CreateSprite( "sprites/aomdc/muz1.spr", self.pev.origin, true, 10 );
		m_pSprite.TurnOn();
		m_pSprite.pev.rendermode = kRenderTransAdd;
		m_pSprite.pev.renderamt = 128;
	
		g_SoundSystem.EmitSound( self.edict(), CHAN_STATIC, "debris/aomdc/player/heartbeat.wav", 1.0f, ATTN_NORM );
		
		SetThink( ThinkFunction( this.RespawnThink ) );
		self.pev.nextthink = g_Engine.time + 0.1f;
	}
	
	//Revives 1 player every m_flDelayBetweenRevive seconds, if any players need reviving.
	void RespawnThink()
	{
		CBasePlayer@ pPlayer;
		
		for( ; m_iNextPlayerToRevive <= g_Engine.maxClients; ++m_iNextPlayerToRevive )
		{
			@pPlayer = g_PlayerFuncs.FindPlayerByIndex( m_iNextPlayerToRevive );
			
			//Only respawn if the player died before this checkpoint was activated
			//Prevents exploitation
			if( pPlayer !is null && pPlayer.IsAlive() == false && pPlayer.m_fDeadTime < m_flRespawnStartTime )
			{
				//Revive player and move to this checkpoint
				pPlayer.GetObserver().RemoveDeadBody();
				pPlayer.SetOrigin( self.pev.origin );
				pPlayer.Revive();
				
				//Congratulations, and celebrations, YOU'RE ALIVE!
				g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_ITEM, self.pev.message, 1.0f, ATTN_NORM );
				
				++m_iNextPlayerToRevive; //Make sure to increment this to avoid unneeded loop
				break;
			}
		}
		
		//All players have been checked, close portal after 5 seconds.
		if( m_iNextPlayerToRevive > g_Engine.maxClients )
		{
			SetThink( ThinkFunction( this.StartKillSpriteThink ) );
			
			self.pev.nextthink = g_Engine.time + 5.0f;
		}
		else //Another player could require reviving
			self.pev.nextthink = g_Engine.time + m_flDelayBetweenRevive;
	}
	
	void StartKillSpriteThink()
	{
		g_SoundSystem.EmitSound( self.edict(), CHAN_STATIC, "aomdc/misc/event.wav", 1.0f, ATTN_NORM );
		
		SetThink( ThinkFunction( this.KillSpriteThink ) );
		self.pev.nextthink = g_Engine.time + 3.0f;
	}
	
	void CheckReusable()
	{
		if( self.pev.SpawnFlagBitSet( AOM_CHECKPOINT_REUSABLE ) )
		{
			SetThink( ThinkFunction( this.ReenableThink ) );
			self.pev.nextthink = g_Engine.time + m_flDelayBeforeReactivation;
		}
		else
			SetThink( null );
	}
	
	void KillSpriteThink()
	{
		if( m_pSprite !is null )
		{
			g_EntityFuncs.Remove( m_pSprite );
			@m_pSprite = null;
		}
		
		CheckReusable();
	}
	
	void ReenableThink()
	{
		//Make visible again
		self.pev.effects &= ~EF_NODRAW;
		
		m_fActivated = false;
		
		SetThink( null );
	}
}

void RegisterAomPointCheckPointEntity()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "aom_checkpoint", "aom_checkpoint" );
}