/*
* This script implements a survival mode
* DelayBeforeStart seconds after more than ( MinPlayersRequired - 1 ) players are in the game, respawning is disabled
* Once all players are dead, after DelayBeforeEnd seconds, a vote is started to ask all players if they want to restart or go to the next map
* This vote lasts for VoteTime seconds
* Once the vote has ended, after DelayBeforeChangeLevel seconds, the map is changed
* If the server is empty, or has less than MinPlayersRequired, the script waits for more players before enabling itself
*/

#include "aom_checkpoint"

const int SURVIVAL_INFINITE_RETRIES = -1;

const string SURVIVAL_PERSIST_KEY = "survival";
const string SURVIVAL_PERSIST_RETRIES_KEY = "retries";

final class Survival
{
	//Whether survival mode is enabled
	private bool m_fIsEnabled = true;
	
	//Whether survival mode is active
	private bool m_fIsActive = false;
	
	//Minimum players required to enable survival mode
	private int m_iMinPlayersRequired;
	
	//Delay, in seconds, before survival mode starts after it is enabled
	private float m_flDelayBeforeStart;
	
	//Delay before the game starts the end vote
	private float m_flDelayBeforeEnd;
	
	//How much time is given for players to vote
	private float m_flVoteTime;
	
	//Time before changelevel if all players are dead and have voted
	private float m_flDelayBeforeChangeLevel;
	
	private CScheduledFunction@ m_pDisableRespawnFunc = null;
	private CScheduledFunction@ m_pCheckForLivingPlayersFunc = null;
	
	private bool m_fGameEnded = false;
	
	//Server cvar to control whether survival mode is enabled or disabled
	private CCVar@ m_pSurvivalEnabled;
	
	private CCVar@ m_pSurvivalRetries;
	
	private PersistID_t m_Persist = 0;
	
	private CCVar@ m_pNextSurvivalMap;
	
	bool IsEnabled
	{
		get const { return m_fIsEnabled; }
	}
	
	bool IsActive
	{
		get const { return m_fIsActive; }
	}
	
	int MinPlayersRequired
	{
		get const { return m_iMinPlayersRequired; }
		set { m_iMinPlayersRequired = value; }
	}
	
	float DelayBeforeStart
	{
		get const { return m_flDelayBeforeStart; }
		set { m_flDelayBeforeStart = value; }
	}
	
	float DelayBeforeEnd
	{
		get const { return m_flDelayBeforeEnd; }
		set { m_flDelayBeforeEnd = value; }
	}
	
	float VoteTime
	{
		get const { return m_flVoteTime; }
		set { m_flVoteTime = value; }
	}
	
	float DelayBeforeChangeLevel
	{
		get const { return m_flDelayBeforeChangeLevel; }
		set { m_flDelayBeforeChangeLevel = value; }
	}
	
	bool GameEnded
	{
		get const { return m_fGameEnded; }
	}
	
	Survival()
	{
		m_iMinPlayersRequired 		= 2;	//Default to 2 players needed to start survival mode
		m_flDelayBeforeStart 		= 120;	//Default to 2 minutes before survival mode starts
		m_flDelayBeforeEnd 			= 60;	//Delay between the last player dying and the end vote start
		m_flVoteTime 				= 15;	//How long the vote lasts
		m_flDelayBeforeChangeLevel 	= 10;	//How long between the vote ends and the map is changed
		
		@m_pSurvivalEnabled = CCVar( "survival_enabled", 1, "Controls whether survival mode is enabled or disabled", ConCommandFlag::None, CVarCallback( this.SurvivalEnabledCB ) );
		
		@m_pSurvivalRetries = CCVar( "survival_retries", 3, "Number of retries before a vote starts. -1 allows for infinite retries, without a vote.", ConCommandFlag::AdminOnly, CVarCallback( this.SurvivalRetriesCB ) );
		
		@m_pNextSurvivalMap = CCVar( "next_survival_map", "", "Sets the next survival map to switch to if next map is voted" );
	}
	
	void MapInit()
	{
		const array<string> current = { g_Engine.mapname };
	}
	
	void MapActivate()
	{
		m_Persist = g_Persistence.RegisterInstance( SURVIVAL_PERSIST_KEY );
		
		const bool bExists = g_Persistence.Exists( m_Persist, SURVIVAL_PERSIST_RETRIES_KEY );
		const int iLeft = g_Persistence.GetLong( m_Persist, SURVIVAL_PERSIST_RETRIES_KEY );
		const int iAllowed = GetRetriesAllowed();
		
		//Initialize setting
		if( !bExists || iLeft > iAllowed || iLeft < 0 )
			g_Persistence.Set( m_Persist, SURVIVAL_PERSIST_RETRIES_KEY, iAllowed );
	}
	
	private void SurvivalEnabledCB( CCVar@ cvar, const string& in szOldValue, float flOldValue )
	{
		if( int( flOldValue ) != cvar.GetInt() )
		{
			switch( cvar.GetInt() )
			{
			case 0: Disable(); break;
			case 1:
			default: Enable(); break;
			}
		}
	}
	
	private void SurvivalRetriesCB( CCVar@ cvar, const string& in szOldValue, float flOldValue )
	{
		//Clamp all negative values to -1.
		if( cvar.GetInt() < SURVIVAL_INFINITE_RETRIES )
			cvar.SetInt( SURVIVAL_INFINITE_RETRIES );
	}
	
	void Enable()
	{
		if( m_fIsEnabled )
			return;
			
		m_fIsEnabled = true;
		
		CheckIfActivationNeeded();
		
		UpdateCheckpoints( true );
	}
	
	void Disable()
	{
		if( !m_fIsEnabled )
			return;
			
		m_fIsEnabled = false;
		
		Reset();
		
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "Disabling survival mode." );
		
		UpdateCheckpoints( false );
	}
	
	void Toggle()
	{
		if( m_fIsEnabled )
			Disable();
		else
			Enable();
	}
	
	private void UpdateCheckpoints( const bool bEnable )
	{
		CBaseEntity@ pEnt = null;
		
		while( ( @pEnt = g_EntityFuncs.FindEntityByClassname( pEnt, "aom_checkpoint" ) ) !is null )
		{
			aom_checkpoint@ pCheckpoint = cast<aom_checkpoint@>( CastToScriptClass( pEnt ) );
			
			if( pCheckpoint !is null )
			{
				pCheckpoint.SetEnabled( bEnable );
			}
		}
	}
	
	bool HasInfiniteRetries() const
	{
		return m_pSurvivalRetries.GetInt() == SURVIVAL_INFINITE_RETRIES;
	}
	
	int GetRetriesAllowed() const
	{
		return HasInfiniteRetries() ? Math.INT32_MAX : m_pSurvivalRetries.GetInt();
	}
	
	int GetRetriesLeft() const
	{
		return g_Persistence.GetLong( m_Persist, SURVIVAL_PERSIST_RETRIES_KEY );
	}
	
	void RetryUsed()
	{
		const int iLeft = GetRetriesLeft();
		
		if( iLeft > 0 )
			g_Persistence.Set( m_Persist, SURVIVAL_PERSIST_RETRIES_KEY, iLeft - 1 );
	}
	
	//Resets survival mode to wait for players
	void Reset()
	{
		g_EngineFuncs.CVarSetFloat( "mp_observer_mode", 0 );
		g_EngineFuncs.CVarSetFloat( "mp_observer_cyclic", 0 );
		
		//Remove the respawn disabler
		if( m_pDisableRespawnFunc !is null )
		{
			g_Scheduler.RemoveTimer( m_pDisableRespawnFunc );
			@m_pDisableRespawnFunc = null;
		}
		
		if( m_pCheckForLivingPlayersFunc !is null )
		{
			g_Scheduler.RemoveTimer( m_pCheckForLivingPlayersFunc );
			@m_pCheckForLivingPlayersFunc = null;
		}
		
		m_fIsActive = false;
		
		/*
		* Respawn any dead players; disabling observer mode should do this, but we'll make sure of it here
		*/
		g_PlayerFuncs.RespawnAllPlayers( false, true );
	}
	
	void DisableRespawn()
	{
		g_EngineFuncs.CVarSetFloat( "mp_observer_mode", 1 );
		g_EngineFuncs.CVarSetFloat( "mp_observer_cyclic", 1 );
		
		@m_pDisableRespawnFunc = null;
		
		m_fIsActive = true;
		
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "Survival mode now enabled. No more respawning allowed." );
		
		//All players may already be dead
		CheckEndConditions();
	}
	
	int GetLivingPlayersCount()
	{
		int iLivingPlayers = 0;
		
		for( int iIndex = 1; iIndex <= g_Engine.maxClients; ++iIndex )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iIndex );
			
			if( pPlayer !is null && pPlayer.IsAlive() == true )
				++iLivingPlayers;
		}
		
		return iLivingPlayers;
	}
	
	void CheckForLivingPlayers()
	{
		@m_pCheckForLivingPlayersFunc = null;
		
		//Check again, players might have been revived by a monster
		int iLivingPlayers = GetLivingPlayersCount();
		
		if( iLivingPlayers == 0 )
		{
			m_fGameEnded = true;
			
			if( !HasInfiniteRetries() && GetRetriesLeft() == 0 )
				StartEndVote();
			else
			{
				RetryUsed();
				TriggerLevelChange( true, g_Engine.mapname );
			}
		}
	}

	void StartEndVote()
	{
		Vote vote( "HLSP end map vote", "Choose to restart the map or go to the next one.", m_flVoteTime, 50 );
		
		vote.SetYesText( "Restart map" );
		vote.SetNoText( "Go to next map" );
		
		vote.SetVoteBlockedCallback( VoteBlocked( this.VoteBlocked ) );
		vote.SetVoteEndCallback( VoteEnd( this.VoteEnd ) );
		
		vote.Start();
	}
	
	void VoteBlocked( Vote@ pVote, float flTime )
	{
		//Schedule to vote again after the current vote has finished
		g_Scheduler.SetTimeout( @this, "StartEndVote", flTime - g_Engine.time );
	}
	
	void VoteEnd( Vote@ pVote, bool bResult, int iVoters )
	{
		string szMapName;

		if( bResult )
			szMapName = g_Engine.mapname;
		else
		{
			const string szNext = m_pNextSurvivalMap.GetString();
			
			szMapName = szNext.IsEmpty() ? g_MapCycle.GetNextMap() : szNext;
		}
		
		TriggerLevelChange( bResult, szMapName );
	}
	
	private void TriggerLevelChange( const bool bRestart, const string& in szMapName )
	{
		const int iDelay = int( m_flDelayBeforeChangeLevel );
		
		string szText;
		
		if( bRestart )
		{
			snprintf( szText, "Restarting the map in %1 seconds.", iDelay );
			
			//If 0 retries are allowed, don't print the number.
			if( !HasInfiniteRetries() &&  GetRetriesAllowed() > 0 )
			{
				string szAppend;
				
				snprintf( szAppend, " %1 %2 left.", GetRetriesLeft(), GetRetriesLeft() == 1 ? "retry" : "retries" );
				szText += szAppend;
			}
		}
		else
		{
			szText = "Changing map to \"" + szMapName + "\" in " + iDelay + " seconds.";
		}
		
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, szText );
		g_Scheduler.SetTimeout( @this, "PerformChangeLevel", m_flDelayBeforeChangeLevel, szMapName );
	}
	
	void PerformChangeLevel( string& in szMapName )
	{
		g_EngineFuncs.ChangeLevel( szMapName );
	}
	
	void CheckIfActivationNeeded()
	{
		if( m_fIsEnabled && !m_fIsActive && g_PlayerFuncs.GetNumPlayers() >= m_iMinPlayersRequired && m_pDisableRespawnFunc is null )
		{
			@m_pDisableRespawnFunc = g_Scheduler.SetTimeout( @this, "DisableRespawn", m_flDelayBeforeStart );
			
			const string szText = "Survival mode starting in " + int( m_flDelayBeforeStart ) + " seconds";
			
			//PRINTTALK won't work here, probably because it's too soon after joining
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTCENTER, szText );
		}
	}

	void ClientPutInServer()
	{
		CheckIfActivationNeeded();
	}

	void ClientDisconnect()
	{
		if( g_PlayerFuncs.GetNumPlayers() < m_iMinPlayersRequired )
		{
			Reset();
		}
		else
		{
			//Make sure game ends if nobody is alive anymore
			CheckEndConditions();
		}
	}
	
	void CheckEndConditions()
	{
		if( m_fIsActive && !m_fGameEnded && m_pCheckForLivingPlayersFunc is null && GetLivingPlayersCount() == 0 )
		{
			string szText = "No living players left";
			
			if( !HasInfiniteRetries() && GetRetriesLeft() == 0 )
				szText += "; starting end vote in " + int( m_flDelayBeforeEnd ) + " seconds";
			
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, szText );
			
			@m_pCheckForLivingPlayersFunc = g_Scheduler.SetTimeout( @this, "CheckForLivingPlayers", m_flDelayBeforeEnd );
		}
	}
	
	void PlayerKilled()
	{
		CheckEndConditions();
	}
}