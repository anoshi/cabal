// internal
#include "tracker.as"
#include "cabal_helpers.as"
#include "gamemode_invasion.as"
// --------------------------------------------

// This tracker manages player and AI
// lifecycles in CAMPAIGN mode only

// --------------------------------------------
class ResourceLifecycleHandler : Tracker {
	GameModeInvasion@ m_metagame;

	protected int m_playerCharacterId;
	protected array<string> m_playersSpawned;			// stores the unique 'hash' for each active player
	protected array<int> m_playerLives = {3,3};			// players 1 and 2 have 3 lives each
	protected array<float> m_playerScore = {0.0, 0.0};	// players 1 and 2 start with no XP
	protected int playerCoins = 3; 						// coins on hand / restart level attempts left

    protected float m_localPlayerCheckTimer;
    protected float LOCAL_PLAYER_CHECK_TIME = 5.0;

	protected float MIN_SPAWN_X = 530.395; // Left-most X coord within player spawn area (see /maps/cabal/objects.svg)
	protected float MAX_SPAWN_X = 545.197; // Right-most X coord within player spawn area (see /maps/cabal/objects.svg)
	protected float MIN_GOAL_XP = 8.0;
	protected float MAX_GOAL_XP = 10.0;
	protected float goalXP = rand(MIN_GOAL_XP, MAX_GOAL_XP);
	protected float curXP = 0.0;

	protected bool levelComplete;

	// ---------------------------------------------------
	ResourceLifecycleHandler(GameModeInvasion@ metagame) {
		@m_metagame = @metagame;
		levelComplete = false;
		// enable character_kill tracking for cabal game mode (off by default)
		string trackCharKill = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(trackCharKill);
	}

	/////////////////////////////////
	// PLAYER CHARACTER LIFECYCLES //
	/////////////////////////////////
    protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		_log("*** CABAL: ResourceLifecycleHandler::handlePlayerSpawnEvent", 1);

		if (curXP < goalXP) {
			levelComplete = false;
			_log("*** CABAL: Player spawning on incomplete level.", 1);
		}

		// how can this be improved to support 2-player co-op play?
		// currently falls apart if a second player were to spawn.

		// when the player spawns, he spawns alone...
		XmlElement c("command");
		c.setStringAttribute("class", "set_soldier_spawn");
		c.setIntAttribute("faction_id", 0);
		c.setBoolAttribute("enabled", false);
		m_metagame.getComms().send(c);

		// now, work with the spawned player character
		const XmlElement@ player = event.getFirstElementByTagName("player");
		if (player !is null) {
			string playerHash = player.getStringAttribute("profile_hash");
			int characterId = player.getIntAttribute("character_id");
			if (m_playersSpawned.find(playerHash) < 0) {
				_log("*** CABAL: Player hash " + playerHash + " not found in m_playersSpawned array.", 1);
				if (int(m_playersSpawned.size()) < m_metagame.getUserSettings().m_maxPlayers) {
					string name = player.getStringAttribute("name");
					m_playerCharacterId = characterId;
					m_playersSpawned.insertLast(playerHash);
					_log("*** CABAL: player " + name + " (" + m_playerCharacterId + ") spawned as player" + int(m_playersSpawned.size()), 1);
				} else {
					kickPlayer(player.getIntAttribute("player_id"), "Only " + m_metagame.getUserSettings().m_maxPlayers + " players allowed");
				}
				_log("*** CABAL: m_playersSpawned now stores: " + m_playersSpawned[0] + " for player1.", 1);
			} else {
				// existing player.
				_log("*** CABAL: existing player spawned. Equipping coloured vest", 1);
			}

			_log("*** CABAL: Equipping spawned player with appropriately-coloured vest", 1);
			// TEST PURPOSES: if cheat enabled, add cheat vest
			//if (cheatMode) {
			//	setPlayerInventory(m_metagame, characterId, "player_impervavest.carry_item");
			//}
			switch (m_playersSpawned.find(playerHash)) {
				case 0:
					setPlayerInventory(m_metagame, characterId, "player_blue.carry_item");
					break;
				case 1:
					setPlayerInventory(m_metagame, characterId, "player_red.carry_item");
					break;
				default: // shouldn't ever get here, but sanity
					_log("*** CABAL: WARNING existing player spanwed but profile hash not stored in m_playersSpawned array", 1);
			}
		} else {
			_log("*** CABAL: CRITICAL WARNING, player not found in Player Spawn Event");
		}
	}

	// -----------------------------------------------------------
	protected void handlePlayerDieEvent(const XmlElement@ event) {
		_log("*** CABAL: ResourceLifecycleHandler::handlePlayerDieEvent", 1);

		// skip die event processing if disconnected
		if (event.getBoolAttribute("combat") == false) return;

		// level already won/lost? bug out
		if (levelComplete) {
			_log("*** CABAL: Level already won or lost. Dropping out of method", 1);
			return;
		}

		const XmlElement@ deadPlayer = event.getFirstElementByTagName("target");
		// use profile_hash stored in m_playersSpawned array to id which char died
		int playerCharId = deadPlayer.getIntAttribute("character_id");
		string playerHash = deadPlayer.getStringAttribute("profile_hash");
		int playerNum = m_playersSpawned.find(playerHash); // should return the index or negative if not found

		// lose a life
		switch (playerNum) {
			case 0 :
			case 1 :
				_log("*** CABAL: Player " + (playerNum + 1) + " lost a life!", 1);
				m_playerLives[playerNum] -= 1;
				_log("*** CABAL: Player " + (playerNum + 1) + " still has " + (playerNum > 0 ? m_playerLives[1] : m_playerLives[0]) + " lives available.", 1);
				break;
			default :
				_log("*** CABAL: Can't match profile_hash to a dead player character. No lives lost...");
				// profile_hash listed in event doesn't exist as an active player. Silently fail to do anything.
		}

		// check if any player has any lives remaining
		for (uint i = 0; i < m_playersSpawned.size(); ++ i) {
			if (m_playerLives[i] <= 0) {
				_log("*** CABAL: GAME OVER for Player " + (i+1), 1); // can't actually stop them from respawning. All or nothing
			}
		}
		if ((m_playersSpawned.size() == 1) && (m_playerLives[0] <= 0)) {
			_log("*** GAME OVER!", 1);
			processGameOver();
			return;
		} else if ((m_playersSpawned.size() == 2) && (m_playerLives[0] <= 0 && m_playerLives[1] <= 0)) {
			_log("*** GAME OVER!", 1);
			processGameOver();
			return;
		} else {
			_log("*** CABAL: Saving Game", 1);
			m_metagame.save();
		}

		// player can't respawn if enemies are within ~70.0 units of the intended base. Need to forcibly remove enemy
		// units from player's base area...
		// We're about to kill a lot of people. Stop character_kill tracking for the moment
		string trackCharKillOff = "<command class='set_metagame_event' name='character_kill' enabled='0' />";
		m_metagame.getComms().send(trackCharKillOff);
		// kill enemies anywhere near player to allow respawn
		const XmlElement@ characterInfo = getCharacterInfo(m_metagame, playerCharId);
		if (characterInfo !is null) {
			_log("*** CABAL: Killing enemies near dead player character", 1);
			Vector3 position = stringToVector3(characterInfo.getStringAttribute("position"));

			// make an array of Xml Elements that stores affected enemy unit stats
			// TagName =character, id=xx (99)
			array<const XmlElement@> exchEnemies = getCharactersNearPosition(m_metagame, position, 1, 80.0f);
			int exchEnemiesCount = exchEnemies.size();
			// rewrite as new array where the position of each enemy has +70 to Z axis
			// or just get the size of the array, then queue that many random enemy respawns shortly

			// improve?: apply invisi-vest to characters in the kill zone to make them disappear, then kill them
			killCharactersNearPosition(m_metagame, position, 1, 80.0f); // kill faction 1 (cabal)

			// spawn enemies to replace the exchEnemies
			_log("*** CABAL: Respawning " + exchEnemiesCount + " replacement enemy units.", 1);
			string randKey = ''; // random character 'Key' name

			float retX = position.get_opIndex(0);
			float retY = position.get_opIndex(1);
			float retZ = position.get_opIndex(2) - 90.0;
			string randPos = Vector3(retX, retY, retZ).toString(); // spawns all replacements in same place...
			for (int k = 0; k < exchEnemiesCount; ++k) {
				switch( rand(0, 5) )
					{ // 5 types of enemy units, weighted to return more base level soldiers
					case 0 :
					case 1 :
						randKey = "rifleman";
						break;
					case 2 :
					case 3 :
						randKey = "grenadier";
						break;
					case 4 :
						randKey = "covert_ops";
						break;
					case 5 :
						randKey = "commando";
						break;
					default:
						randKey = "rifleman";
					}
				string spawnReps = "<command class='create_instance' faction_id='1' position='" + randPos + "' instance_class='character' instance_key='" + randKey + "' /></command>";
				m_metagame.getComms().send(spawnReps);
				_log("*** CABAL: Spawned a character at " + randPos, 1);
			}
		}
		// Reenable character_kill tracking
		string trackCharKillOn = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(trackCharKillOn);

		// allow player to respawn
		XmlElement allowSpawn("command");
		allowSpawn.setStringAttribute("class", "set_soldier_spawn");
		allowSpawn.setIntAttribute("faction_id", 0);
		allowSpawn.setBoolAttribute("enabled", true);
		m_metagame.getComms().send(allowSpawn);
	}

	// --------------------------------------------
	protected void processGameOver() {
		_log("*** CABAL: Running processGameOver", 1);
		if (levelComplete) return;
		// stop cabal spawning
		m_metagame.removeTracker(CabalSpawner(m_metagame));
		// no more respawning allowed
		{
			XmlElement c("command");
			c.setStringAttribute("class", "set_soldier_spawn");
			c.setIntAttribute("faction_id", 0);
			c.setBoolAttribute("enabled", false);
			m_metagame.getComms().send(c);
		}

		sleep(2.0f); // brief pause before delivering the bad news

		// check if players still have some coins/continues? If so, can restart level
		if (playerCoins > 0) {
			playerCoins --;
			m_metagame.getComms().send("<command class='set_match_status' lose='1' faction_id='0' />");
			m_metagame.getComms().send("<command class='set_match_status' win='1' faction_id='1' />");
			_log("*** CABAL: USING COIN / CONTINUE. " + playerCoins + " CONTINUES REMAINING!", 1);
			// prep for restart
			resetLevelStats();
		}
		else { // no coins / continues left, campaign lost / game over
			_log("*** CABAL: no more coins / continues. GAME OVER", 1);
			XmlElement c("command");
			c.setStringAttribute("class", "set_campaign_status");
			c.setStringAttribute("key", "lose");
			m_metagame.getComms().send(c);
			levelComplete = true;
		}
	}

	// ----------------------------------------------------
	protected void resetLevelStats() {
		// player lives to 3
		for (uint i = 0; i < m_playersSpawned.size(); ++ i) {
			m_playerLives[i] = 3;
		}
		// reset level complete %
		curXP = 0.0;
		approachGoalXP(0.0);
		// level is not complete
		levelComplete = false;
	}

	// ----------------------------------------------------
	protected void ensureValidLocalPlayer(float time) {
		if (m_playerCharacterId < 0) {
			m_localPlayerCheckTimer -= time;
			_log("*** CABAL: m_local_PlayerCheckTimer: " + m_localPlayerCheckTimer,1);
			if (m_localPlayerCheckTimer < 0.0) {
				_log("*** CABAL: tracked player character id " + m_playerCharacterId, 1);
				const XmlElement@ player = m_metagame.queryLocalPlayer();
				if (player !is null) {
					//setupCharacterForTracking
				} else {
					_log("WARNING, local player query failed", -1);
				}
				m_localPlayerCheckTimer = LOCAL_PLAYER_CHECK_TIME;
			}
		}
	}

	// --------------------------------------------
	protected void kickPlayer(int playerId, string text = "") {
		sendPrivateMessage(m_metagame, playerId, text);
		kickPlayerImpl(playerId);
	}

	// --------------------------------------------
	protected void kickPlayerImpl(int playerId) {
		string command = "<command class='kick_player' player_id='" + playerId + "' />";
		m_metagame.getComms().send(command);
	}

	//////////////////////////////
	// ALL CHARACTER LIFECYCLES //
	//////////////////////////////
	protected void handleCharacterKillEvent(const XmlElement@ event) {
		// When enabled, fires whenever an AI character is killed. Manually enabled via class constructor

		// TagName=character_kill
		// key= method_hint=blast

		// TagName=killer
		// block=15 18
		// dead=0
		// faction_id=0
		// id=1
		// leader=1
		// name=Player
		// player_id=0
		// position=538.973 14.7059 623.567
		// rp=0
		// soldier_group_name=default
		// wounded=0
		// xp=0 (real/float)

		// TagName=target
		// block=15 17
		// dead=0
		// faction_id=1
		// id=8
		// leader=0
		// name=Enemy
		// player_id=-1
		// position=537.541 14.7059 610.689
		// rp=0
		// soldier_group_name=rifleman
		// wounded=0
		// xp=0 (real/float)

		_log("*** CABAL: ResourceLifecycleHandler::handleCharacterKillEvent", 1);

		const XmlElement@ killerInfo = event.getFirstElementByTagName("killer");
		if (killerInfo is null) {
			_log("*** CABAL: Can't determine killer. Ignoring death", 1);
			return;
		}
		const XmlElement@ targetInfo = event.getFirstElementByTagName("target");
		if (targetInfo is null) {
			_log("*** CABAL: Can't determine killed unit. Ignoring death", 1);
			return;
		}

		// if a player character has died, don't process any further
		if (targetInfo.getIntAttribute("player_id") >= 0) {
			_log("*** CABAL: dead character id is a player character. Handled separately", 1);
			return;
		}

		// if faction 0 (player), don't process further
		if (targetInfo.getIntAttribute("faction_id") == 0) {
			_log("*** CABAL: dead character id is from friendly faction. Ignoring", 1);
			return;
		}

        // _log("*** CABAL: store details of dead character " + charId, 1);
		int charId = targetInfo.getIntAttribute("id");
		string charName = targetInfo.getStringAttribute("name");

        string charPos = targetInfo.getStringAttribute("position");
		Vector3 v3charPos = stringToVector3(charPos);

		string charBlock = targetInfo.getStringAttribute("block");
		int charFactionId = targetInfo.getIntAttribute("faction_id");

		float charXP = targetInfo.getFloatAttribute("xp");
		int charRP = targetInfo.getIntAttribute("rp");
		int charLeader = targetInfo.getIntAttribute("leader");
		string charGroup = targetInfo.getStringAttribute("soldier_group_name");

		_log("*** CABAL: Character " + charId + " (" + charName + charGroup + "), with " + charXP + " XP, has died.", 1);

		// TODO commando to be carted off the field by medics

		// Run an alive/dead check on Player character(s)
		int playerCharId = killerInfo.getIntAttribute("id");
		const XmlElement@ playerCharInfo = getCharacterInfo(m_metagame, playerCharId);
		int playerCharIsDead = playerCharInfo.getIntAttribute("dead");
		if (playerCharIsDead == 1) {
			_log("*** CABAL: Player character is dead. No rewards given");
			return;
		}
		// Player is alive and well. Add enemy's XP to total score for level
		approachGoalXP(charXP);

		// Increase player's score
		if (killerInfo.getStringAttribute("name") == "Player ") { // trailing space intentional
			int playerKiller = killerInfo.getIntAttribute("player_id");
			_log("*** CABAL: playerKiller id: " + playerKiller, 1);
			float xp = targetInfo.getFloatAttribute("xp");
			if ((playerKiller >= 0) && (playerKiller < m_metagame.getUserSettings().m_maxPlayers)) {
				awardXP(playerKiller, xp);
			}
		} else { _log("*** CABAL: killer name is " + killerInfo.getStringAttribute("name")); }

		string playerPos = playerCharInfo.getStringAttribute("position");
        _log("*** CABAL: Player Character id: " + m_playerCharacterId + " is at: " + playerPos);
		Vector3 v3playerPos = stringToVector3(playerPos);

		// create a new Vector3 as (enemyX, playerY +2, playerZ)
		float retX = v3charPos.get_opIndex(0);
		// if enemy X outside player spawn area X...
		if (retX < MIN_SPAWN_X) {
			retX = MIN_SPAWN_X + rand(1, 6);
		} else if (retX > MIN_SPAWN_X) {
			retX = MAX_SPAWN_X - rand(1, 6);
		}
        float retY = v3playerPos.get_opIndex(1) + 2.0;
        float retZ = v3playerPos.get_opIndex(2);
        Vector3 dropPos = Vector3(retX, retY, retZ);

		// based on these details, set a probability for a weapon/power-up/etc. to spawn
		if (charLeader == 1) { // artificially bump XP for greater chance of drop and reward when a squad leader dies
			charXP += 0.1;
		}

if (rand(1, 100) > 80) {
			// Group-based drop logic (enemies may drop specific equipment on death)
			if (charXP > 0.5) {
				dropPowerUp(dropPos.toString(), "weapon", "player_mg.weapon"); // drop minigun
			} else if (charXP > 0.3) {
				dropPowerUp(dropPos.toString(), "weapon", "player_mp.weapon"); // drop machine pistol
			} else if (charXP > 0.2) {
				dropPowerUp(dropPos.toString(), "weapon", "player_sg.weapon"); // drop shotgun
			} else if (charGroup == "rifleman") {
				dropPowerUp(dropPos.toString(), "weapon", "player_lr.weapon"); // drop laser rifle
			} else if (charGroup == "commando") {
				dropPowerUp(dropPos.toString(), "grenade", "player_grenade.projectile"); // drop grenade
			} // revert to default weapon after X seconds have elapsed...
			else {
				_log("*** CABAL: XP too low, Nothing dropped", 1);
			}
		}
	}

	// -----------------------------------------------------------
	protected void awardXP(int playerKiller, float xp) {
		// match playerKiller's ID to the appropriate player
		m_playerScore[playerKiller] += xp;
		_log("*** CABAL: Player " + (playerKiller + 1) + " XP now at " + int(m_playerScore[playerKiller]), 1);
	}

	///////////////////////
	// POWERUP LIFECYCLE //
	///////////////////////
	protected void dropPowerUp(string position, string instanceClass, string instanceKey) {
		// between the invisible walls the the player character is locked within (enemyX, playerY+2, playerZ)
		if (levelComplete) {
			return;
		}
        _log("*** CABAL: dropping a " + instanceKey + " at " + position, 1);
        string creator = "<command class='create_instance' faction_id='0' position='" + position + "' instance_class='" + instanceClass + "' instance_key='" + instanceKey + "' activated='0' />";
        m_metagame.getComms().send(creator);
		_log("*** CABAL: item placed at " + position, 1);

		// ensure all dropped items have a short TTL e.g 5 seconds
        // ensure only player weapons are dropped
	}

	///////////////////
	// MAP LIFECYCLE //
	///////////////////
	protected void approachGoalXP(float charXP) {
		if (levelComplete) {
			return;
		}
		curXP += charXP;
		int levelCompletePercent = int(curXP / goalXP * 100);
		_log("*** CABAL: current XP is: " + int(curXP) + " of " + int(goalXP), 1);
		if (levelCompletePercent > 100) { levelCompletePercent = 100; }
		_log("*** CABAL: Level completion: " + levelCompletePercent + "%", 1);

		// notify text
		if (levelCompletePercent > 0) {
			string statusReport = "<command class='notify' text='" + "Level completion: " + levelCompletePercent + "%' />";
			m_metagame.getComms().send(statusReport);
		}

		// scoreboard text
		string levelCompleteText = "";
		for (int i = 0; i < levelCompletePercent / 3; ++i) {
			levelCompleteText += "\u0023"; // #
		}
		for (int j = levelCompletePercent / 3; j < 33; ++j) {
			levelCompleteText += "\u002D"; // -
		}
		string scoreBoardText = "<command class='update_score_display' id='0' text='ENEMY: " + levelCompleteText + "'></command>";
		m_metagame.getComms().send(scoreBoardText);

		if (curXP >= goalXP) {
			_log("*** CABAL: LEVEL COMPLETE!", 1);
			curXP = 0.0; // ready to start next level
			m_metagame.getComms().send("<command class='set_match_status' faction_id='1' lose='1' />");
			m_metagame.getComms().send("<command class='set_match_status' faction_id='0' win='1' />");
			levelComplete = true;
		}
	}

	////////////////////////
	// VEHICLE LIFECYCLES //
	////////////////////////
	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		// in this game mode, all vehicles spawn a dummy vehicle (with 0 ttl) when destroyed
		// this allows us to group large numbers of vehicles into sets, and issue rewards according to the vehicle's difficulty

		// we are only interested in the destruction of dummy vehicles
        if (startsWith(event.getStringAttribute("vehicle_key"), "dummy_")) {
            _log("*** CABAL: DummyVehicleHandler going to work!", 1);
			if (event.getIntAttribute("owner_id") == 0) { return; } // don't care about player's faction vehicles.
			// variablise attributes
			string vehKey = event.getStringAttribute("vehicle_key");
			string vehPosi = event.getStringAttribute("position");
            Vector3 v3Posi = stringToVector3(vehPosi);

			// identify the dummy vehicle and process accordingly
            if (vehKey == "dummy_next.vehicle") {
				// do stuff
			} // etc.
        }
    }

	// --------------------------------------------
	bool hasStarted() const { return true; }

	// --------------------------------------------
	bool hasEnded() const { return false; }

    // --------------------------------------------
    void update(float time) {
        ensureValidLocalPlayer(time);
    }

	// --------------------------------------------
	void onRemove() {
		// clear spawn counting when removing tracker - happens at map change or restart
		m_playersSpawned.clear();
	}

	// --------------------------------------------
	void save(XmlElement@ root) {
		// called by /scripts/gamemodes/campaign/cabal_campaign.as
		XmlElement@ parent = root;

		XmlElement campaignData("campaignData");
		saveCampaignData(campaignData); // see protected method, below
		parent.appendChild(campaignData);
	}

	// --------------------------------------------
	protected void saveCampaignData(XmlElement@ campaignData) {
		// writes <campaignData> section to savegames/campaign[0-999].save/metagame_invasion.xml
		bool doSave = true;
		_log("*** CABAL: saving campaignData to metagame_invasion.xml", 1);

		// level-specific info
		XmlElement level("level");
		level.setFloatAttribute("progress", curXP);

		// save player hashes and lives
		if (m_playersSpawned.size() > 0) {
			XmlElement players("players");
			players.setIntAttribute("continues", playerCoins);
			for (uint i = 0; i < m_playersSpawned.size(); ++i) {
				if (m_playersSpawned[i] == "") {
					// if any spawned player doesn't have an associated hash, we're not in a position to save data
					_log("*** CABAL: Player " + i + " has no hash recorded. Skipping save.", 1);
					doSave = false;
					continue;
				} else {
					string pNum = "player" + (i + 1);
					XmlElement playerData(pNum);
					playerData.setStringAttribute("hash", m_playersSpawned[i]);
					playerData.setIntAttribute("lives", m_playerLives[i]);
					playerData.setFloatAttribute("score", m_playerScore[i]);
					players.appendChild(playerData);
				}
			}
			if (doSave) {
				campaignData.appendChild(level);
				campaignData.appendChild(players);
				_log("*** CABAL: Player data saved to metagame_invasion.xml", 1);
			}
		} else {
			_log("*** CABAL: no data in m_playersSpawned. No character info to save.", 1);
		}


		// any more info to add here? Create and populate another XmlElement and append to the campaignData XmlElement
		// campaignData.appendChild(another_XmlElement);
		_log("*** CABAL: RLH::saveCampaignData() done", 1);
	}

	// --------------------------------------------
	void load(const XmlElement@ root) {
		_log("*** CABAL: Loading Data", 1);
		m_playersSpawned.clear();
		m_playerLives.clear();
		m_playerScore.clear();

		const XmlElement@ campaignData = root.getFirstElementByTagName("campaignData");
		if (campaignData !is null) {
			_log("*** CABAL: loading level data", 1);
			const XmlElement@ levelData = campaignData.getFirstElementByTagName("level");
			float levelProgress = levelData.getFloatAttribute("progress");
			approachGoalXP(levelProgress);
			_log("*** CABAL: loading player data", 1); // tag elements (one element per saved player)
			array<const XmlElement@> playerData = campaignData.getElementsByTagName("players");
			for (uint i = 0; i < playerData.size(); ++ i) {
				_log("*** CABAL: player" + (i + 1), 1); // load player[1..999] tag elements
				array<const XmlElement@> curPlayer = playerData[i].getElementsByTagName("player" + (i + 1));

				for (uint j = 0; j < curPlayer.size(); ++j) {
					const XmlElement@ pData = curPlayer[i];
					string hash = pData.getStringAttribute("hash");
					m_playersSpawned.insertLast(hash);
					int lives = pData.getIntAttribute("lives");
					m_playerLives.insertLast(lives);
					float score = pData.getFloatAttribute("score");
					m_playerScore.insertLast(score);
				}
			}
		}
	}
}
