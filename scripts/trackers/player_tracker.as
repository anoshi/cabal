#include "player_manager.as"

// --------------------------------------------
class PlayerTracker : Tracker {
	protected CabalGameMode@ m_metagame;

	protected bool m_started = false;               // true after this tracker has been added and its start() method has run

	protected dictionary cidTosid = {};				// maps player character_ids to SIDs

	protected string FILENAME = "cabal_save.xml";	// file name to store player data in
	protected PlayerStore@ m_activePlayers;			// active players in the server
	protected PlayerStore@ m_savedPlayers;			// stores inactive players' stats (in 'appdata'/FILENAME), allows drop in/out of server over time

	protected float playerCheckTimer = 15.0;		// initial delay at round start before starting player stat and inventory checks
	protected float CHECK_IN_INTERVAL = 5.0; 		// must be less than UserSettings.m_timeBetweenSubstages

	//protected int numPlayers = 0;					// the number of active players
	protected int sharedLivesCount = 2;				// all players share a pool of lives/respawns (+2 per player)
	protected int playerCoins = 0; 					// no continues / restarts in Cabal

	protected float MIN_SPAWN_X = 530.395; 			// Left-most X coord within player spawn area (see /maps/cabal/objects.svg)
	protected float MAX_SPAWN_X = 545.197; 			// Right-most X coord within player spawn area (see /maps/cabal/objects.svg)
	protected float MIN_GOAL_XP = 4.0; // 40.0;
	protected float MAX_GOAL_XP = 6.0; // 60.0;
	protected float goalXP = rand(MIN_GOAL_XP, MAX_GOAL_XP);
	protected float curXP = 0.0;

	protected bool levelComplete;
	protected bool gameOver;

	// --------------------------------------------
	PlayerTracker(CabalGameMode@ metagame) {
		@m_metagame = @metagame;
		@m_activePlayers = PlayerStore(this, "tracked");
		@m_savedPlayers = PlayerStore(this, "persistent");
		//m_metagame.load();
		levelComplete = false;
		gameOver = false;
    	// enable character_kill tracking for cabal game mode (off by default)
    	string trackCharKill = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(trackCharKill);
	}

    // --------------------------------------------
	void start() {
		_log("** CABAL: starting PlayerTracker tracker", 1);
        checkStartingPlayers();
        _log("** CABAL: checked starting players!", 1);
        m_started = true;
	}

	/////////////////////////////////
	// PLAYER CHARACTER LIFECYCLES //
	/////////////////////////////////

	///////////
	// START //
	///////////
	// because I can't code, we have an issue where players have spawned before this tracker is loaded and thus
	// players aren't identified and added to player_manager's PlayerStore.
	// So, when this tracker is started, we check who's already playing and make sure they're added to the dict
	protected void checkStartingPlayers() {
		array<const XmlElement@>@ startingPlayers = getPlayers(m_metagame);
		for (uint i = 0; i < startingPlayers.length(); ++i) {
			const XmlElement@ player = startingPlayers[i];
			if (player !is null) {
				string playerName = player.getStringAttribute("name");
				string playerHash = player.getStringAttribute("profile_hash");
				string playerSid = player.getStringAttribute("sid");
				int playerId = player.getIntAttribute("player_id");
				string playerIp = player.getStringAttribute("ip");

				if (int(m_activePlayers.size()) < m_metagame.getUserSettings().m_maxPlayers) {
					_log("** CABAL: Player " + playerName + " already joined. " + (m_metagame.getUserSettings().m_maxPlayers - int(m_activePlayers.size() + 1)) + " seats left in server", 1);

					if (playerSid != "ID0") { // local player receives ID0
						_log("** CABAL: we got a local player!", 1);
					}

					if (m_savedPlayers.exists(playerSid)) { // not actively playing prior to this spawn event
						Player@ aPlayer;
						@aPlayer = m_savedPlayers.get(playerSid);
						_log("** CABAL: known player " + aPlayer.m_username + " rejoining server", 1);
						// sanity check the known player's RP and XP
						_log("\t RP: " + aPlayer.m_rp, 1);
						_log("\t XP: " + aPlayer.m_xp, 1);
						aPlayer.m_username = playerName;
						aPlayer.m_ip = playerIp;
						aPlayer.m_playerId = playerId;
						m_activePlayers.add(aPlayer);
						m_savedPlayers.remove(aPlayer);
					} else {
						// assign stock starter kit
						Player@ aPlayer = Player(playerName, playerHash, playerSid, playerIp, playerId);
						_log("** CABAL: Unknown/new player " + aPlayer.m_username + " joining server", 1);
						// set RP and XP for new players
						aPlayer.m_rp = 0;
						aPlayer.m_xp = 0.0;
						m_activePlayers.add(aPlayer);
					}

					goalXP += goalXP;
					approachGoalXP(0.0);

					_log("** CABAL: setting player count to " + m_activePlayers.size(), 1);
					m_metagame.setNumPlayers(m_activePlayers.size());

					// } else {
					// 	_log("** CABAL: player with ID0 connected. Will not be tracked", 1);
					// }
				} else {
					_log("** CABAL: Player " + playerName + " (" + playerHash + ") is attempting to join, but no room left in server", 1);
				}
			}
		}
	}

	/////////////
	// CONNECT //
	/////////////
	protected void handlePlayerConnectEvent(const XmlElement@ event) {
		// TagName=player_connect_event
		// TagName=player
		// color=0.595 0.476 0 1
		// faction_id=0
		// ip=123.120.169.132
		// name=ANOSHI
		// player_id=2
		// port=30664
		// profile_hash=ID<10_numbers>
		// sid=ID<8_numbers>

		_log("** CABAL: Processing Player connect request", 1);

		const XmlElement@ conn = event.getFirstElementByTagName("player");
		if (conn !is null) {
			string connName = conn.getStringAttribute("name");
			string connHash = conn.getStringAttribute("profile_hash");
			string connSid = conn.getStringAttribute("sid");
			int connId = conn.getIntAttribute("player_id");
			string connIp = conn.getStringAttribute("ip");

			if (int(m_activePlayers.size()) < m_metagame.getUserSettings().m_maxPlayers) {
				_log("** CABAL: Player " + connName + " has joined. " + (m_metagame.getUserSettings().m_maxPlayers - int(m_activePlayers.size() + 1)) + " seats left in server", 1);

				// if (connSid != "ID0") { // local player receives ID0
				if (m_savedPlayers.exists(connSid)) { // not actively playing prior to this spawn event
					Player@ aPlayer;
					@aPlayer = m_savedPlayers.get(connSid);
					_log("** CABAL: known player " + aPlayer.m_username + " rejoining server", 1);
					// sanity check the known player's RP and XP
					_log("\t RP: " + aPlayer.m_rp, 1);
					_log("\t XP: " + aPlayer.m_xp, 1);
					aPlayer.m_username = connName;
					aPlayer.m_ip = connIp;
					aPlayer.m_playerId = connId;
					m_activePlayers.add(aPlayer);
					m_savedPlayers.remove(aPlayer);
				} else {
					// assign stock starter kit
					Player@ aPlayer = Player(connName, connHash, connSid, connIp, connId);
					_log("** CABAL: Unknown/new player " + aPlayer.m_username + " joining server", 1);
					// set RP and XP for new players
					aPlayer.m_rp = 0;
					aPlayer.m_xp = 0.0;
					m_activePlayers.add(aPlayer);
				}

				goalXP += goalXP;
				approachGoalXP(0.0);

				// } else {
				// 	_log("** CABAL: player with ID0 connected. Will not be tracked", 1);
				// }
			} else {
				_log("** CABAL: Player " + connName + " (" + connHash + ") is attempting to join, but no room left in server", 1);
			}
		}
	}

	///////////
	// SPAWN //
	///////////
	// -----------------------------------------------------------
	protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		// TagName=player_spawn

		// TagName=player
		// aim_target=0 0 0
		// character_id=74
		// color=0.595 0.476 0 1
		// faction_id=0
		// ip=117.20.69.32
		// name=ANOSHI
		// player_id=2
		// port=30664
		// profile_hash=ID<10_numbers>
		// sid=ID<8_numbers>

		_log("** CABAL: PlayerTracker::handlePlayerSpawnEvent", 1);


		if (curXP < goalXP && !gameOver) {
			levelComplete = false;
		}

		// when the player spawns, he spawns alone...
		//letPlayerSpawn(false);

		const XmlElement@ player = event.getFirstElementByTagName("player");

		if (player !is null) {
			string sid = player.getStringAttribute("sid");
			string hash = player.getStringAttribute("profile_hash");
			string playerCharId = player.getStringAttribute("character_id");
			int pcIdint = player.getIntAttribute("character_id");

			// In some cases, getCharacterInfo queries return a negative int for a character's id:
			// When this occurs, the commands to update RP and XP as well as the setPlayerInventory method
			// will fail and the metagame will throw an index out of bounds exception. Terminal!
			// before we go too far, let's make sure the spawned player's reported character ID matches that stored by the metagame.
			const XmlElement@ thisChar = getCharacterInfo(m_metagame, pcIdint);

			// one way to know we have an issue is if the returned Character XML Element doesn't have a 'faction_id' attribute.
			if (!thisChar.hasAttribute("faction_id")) {
				_log("** CABAL: WARNING! Failed to lookup Character ID " + pcIdint + ". giving up on getCharacterInfo...", 1);
				// Remove player from m_activePlayers and put back into m_savedPlayers
				// we will notice additional connect and spawn events for this player shortly...
				if (m_activePlayers.exists(sid)) {
					Player@ noGoPlayer;
					@noGoPlayer = m_activePlayers.get(sid);
					m_savedPlayers.add(noGoPlayer);
					m_activePlayers.remove(noGoPlayer);
					return; // break out - the PlayerSpawnEvent has been recorded or handled incorrectly
				}
			}

			if (m_activePlayers.exists(sid)) { // must have connected and have valid CharacterInfo to be in this dict at this stage
				// increment live player count
				_log("** CABAL: setting player count to " + m_activePlayers.size(), 1);
				m_metagame.setNumPlayers(m_activePlayers.size());

				Player@ spawnedPlayer;
				@spawnedPlayer = m_activePlayers.get(sid);
				spawnedPlayer.m_playerNum = m_activePlayers.size();
				// associate player's dynamic character_id with their sid.
				cidTosid.set(playerCharId, sid);
				spawnedPlayer.m_charId = pcIdint;
				_log("** CABAL: spawned player cidTosid check: " + spawnedPlayer.m_sid + ": " + spawnedPlayer.m_charId + ", character_id: " + playerCharId);
				// boost charcter's RP and XP to fall in line with saved stats
				_log("** CABAL: Grant " + spawnedPlayer.m_rp + " RP and " + spawnedPlayer.m_xp + " XP to " + spawnedPlayer.m_username, 1);
				string setCharRP = "<command class='rp_reward' character_id='" + playerCharId + "' reward='" + spawnedPlayer.m_rp + "'></command>";
				m_metagame.getComms().send(setCharRP);
				string setCharXP = "<command class='xp_reward' character_id='" + playerCharId + "' reward='" + spawnedPlayer.m_xp + "'></command>";
				m_metagame.getComms().send(setCharXP);
				// load up saved inventory
				m_metagame.setPlayerInventory(pcIdint, false, spawnedPlayer.m_primary, spawnedPlayer.m_secondary, spawnedPlayer.m_grenade, spawnedPlayer.m_grenNum);

				// ensure correct armour / suit colour is applied
				_log("** CABAL: Equipping spawned player with appropriately-coloured vest", 1);
				// replace player's vest with a blank item first to stop stacking on existing player vests
				setPlayerInventory(m_metagame, pcIdint, "player_blank.carry_item", 1);
				// player 1 is blue, player 2 is red
				setPlayerInventory(m_metagame, pcIdint, "player_" + (m_metagame.getNumPlayers() == 1 ? "blue" : "red") + ".carry_item", sharedLivesCount);

				// TEST PURPOSES: if cheat enabled, add cheat vest
				//if (m_metagame.cheatModeEnabled()) {
				//	setPlayerInventory(m_metagame, pcIdint, "player_impervavest.carry_item");
				//}

				// sometimes the player is spawning without a primary weapon.
				const XmlElement@ pSpawned = getCharacterInfo(m_metagame, pcIdint);
				string pPos = pSpawned.getStringAttribute("position");
				_log("** CABAL: Player Character id: " + pcIdint + " spawned at: " + pPos + ". Checking Inventory", 1);
				// get spawned player's inventory
				const XmlElement@ allInv = getPlayerInventory(m_metagame, pcIdint);
				// if no primary weapon (slot=0)
				array<const XmlElement@> pInv = allInv.getElementsByTagName("item");
				for (uint slot = 0; slot < pInv.size(); ++slot) {
					if (pInv[slot].getIntAttribute("slot") == 0) {
						if (pInv[slot].getStringAttribute("key") == "") {
							_log("** CABAL: Player spawned without a weapon. Spawning an assault rifle next to player", 1);
							Vector3 v3playerPos = stringToVector3(pPos);
							float retX = v3playerPos.get_opIndex(0) + 2.0;
							float retY = v3playerPos.get_opIndex(1) + 1.0;
							float retZ = v3playerPos.get_opIndex(2);
							Vector3 dropPos = Vector3(retX, retY, retZ);
							dropPowerUp(dropPos, "weapon", "player_ar.weapon");
						}
					}
				}
			} else {
				_log("** CABAL: Player spawned, but not registered as having connected. Doing nothing...", 1);
			}
		}
	}

	////////////////
	// DISCONNECT //
	////////////////
	// --------------------------------------------
	protected void handlePlayerDisconnectEvent(const XmlElement@ event) {
		_log("** CABAL: PlayerTracker Handling player disconnection!");
		const XmlElement@ disconn = event.getFirstElementByTagName("player");
		if (disconn !is null) {
			string sid = disconn.getStringAttribute("sid");
			if (sid != "ID0") {
				handlePlayerDisconnect(sid);
			}
		}
		// which faction were they playing as?
		int dcPlayerFaction = disconn.getIntAttribute("faction_id");
		// decrement live player count for faction
		m_metagame.setNumPlayers(m_activePlayers.size());
	}

	// ----------------------------------------------------
	protected void handlePlayerDisconnect(string sid) {
		if (m_activePlayers.exists(sid)) {
			Player@ dcPlayer = m_activePlayers.get(sid);
			_log("** CABAL: PlayerTracker tracked player disconnected, player=" + dcPlayer.m_username);
			m_savedPlayers.add(dcPlayer);
			m_activePlayers.remove(dcPlayer);

			dcPlayer.m_playerId = -1;
			dcPlayer.m_charId = -1;
			dcPlayer.m_playerNum = -1;
		}
	}

	/////////
	// DIE //
	/////////
	// -----------------------------------------------------------
	protected void handlePlayerDieEvent(const XmlElement@ event) {
		// TagName=player_die
		// combat=1

		// TagName=target
		// aim_target=557.315 7.54902 551.681
		// character_id=5
		// color=0.68 0.85 0 1
		// faction_id=0
		// ip=
		// name=Host
		// player_id=0
		// port=0
		// profile_hash=ID<10_numbers>
		// sid=ID0

		_log("** CABAL: PlayerTracker::handlePlayerDieEvent", 1);

		// skip die event processing if disconnected
		if (event.getBoolAttribute("combat") == false) return;

		// level already won/lost? bug out
		if (levelComplete) {
			_log("** CABAL: Level already won or lost. Player deaths not currently tracked", 1);
			return;
		}

		const XmlElement@ deadPlayer = event.getFirstElementByTagName("target");

		int playerCharId = deadPlayer.getIntAttribute("character_id");
		string key = deadPlayer.getStringAttribute("sid");

		if (m_activePlayers.exists(key)) {
			Player@ deadPlayerObj = m_activePlayers.get(key);
			_log("** CABAL: Player " + deadPlayerObj.m_username + " has died", 1);
			// empty that player's inventory
			deadPlayerObj.m_primary = "";
			deadPlayerObj.m_secondary = "";
			deadPlayerObj.m_grenade = "";
			deadPlayerObj.m_grenNum = 0;

			sharedLivesCount -= 1;
			_log("** CABAL: Lives remaining: " + sharedLivesCount, 1);
		}

		if (sharedLivesCount <= 0) {
			sharedLivesCount = 0;
			_log("** CABAL: GAME OVER ", 1);
			processGameOver();
			return;
		} else {
			_log("** CABAL: Saving Game", 1);
			m_metagame.save();
		}
	}

	// --------------------------------------------
	protected void processGameOver() {
		_log("** CABAL: Running processGameOver", 1);
		if (levelComplete) return;
		// stop cabal spawning
		m_metagame.removeTracker(CabalSpawner(m_metagame));
		// no more respawning allowed
		// letPlayerSpawn(false);

		sleep(2.0f); // brief pause before delivering the bad news

		XmlElement comm("command");
		comm.setStringAttribute("class", "set_match_status");
		comm.setIntAttribute("lose", 1);
		comm.setIntAttribute("faction_id", 0);
		m_metagame.getComms().send(comm);
		gameOver = true;
	}

	// // --------------------------------------------
	// protected void letPlayerSpawn(bool spawnAllowed) {
	// 	XmlElement c("command");
	// 	c.setStringAttribute("class", "set_soldier_spawn");
	// 	c.setIntAttribute("faction_id", 0);
	// 	c.setBoolAttribute("enabled", spawnAllowed);
	// 	m_metagame.getComms().send(c);
	// }

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

		_log("** CABAL: ResourceLifecycleHandler::handleCharacterKillEvent", 1);

		const XmlElement@ killerInfo = event.getFirstElementByTagName("killer");
		if (killerInfo is null) {
			_log("** CABAL: Can't determine killer. Ignoring death", 1);
			return;
		}
		const XmlElement@ targetInfo = event.getFirstElementByTagName("target");
		if (targetInfo is null) {
			_log("** CABAL: Can't determine killed unit. Ignoring death", 1);
			return;
		}

		// if a player character has died, don't process any further
		if (targetInfo.getIntAttribute("player_id") >= 0) {
			_log("** CABAL: dead character id is a player character. Handled separately", 1);
			return;
		}
		// if faction 0 (player), don't process further
		if (targetInfo.getIntAttribute("faction_id") == 0) {
			_log("** CABAL: dead character id is from friendly faction. Ignoring", 1);
			return;
		}

		// _log("** CABAL: store details of dead character " + charId, 1);
		int charId = targetInfo.getIntAttribute("id");
		string charName = targetInfo.getStringAttribute("name");
		string charPos = targetInfo.getStringAttribute("position");
		Vector3 v3charPos = stringToVector3(charPos);
		int charFactionId = targetInfo.getIntAttribute("faction_id");
		float charXP = targetInfo.getFloatAttribute("xp");
		int charRP = targetInfo.getIntAttribute("rp");
		int charLeader = targetInfo.getIntAttribute("leader");
		string charGroup = targetInfo.getStringAttribute("soldier_group_name");

		_log("** CABAL: Character " + charId + " (" + charName + charGroup + "), with " + charXP + " XP, has died.", 1);

		// Run an alive/dead check on Player character(s)
		int playerCharId = killerInfo.getIntAttribute("id");
		const XmlElement@ playerCharInfo = getCharacterInfo(m_metagame, playerCharId);
		int playerCharIsDead = playerCharInfo.getIntAttribute("dead");
		if (playerCharIsDead == 1) {
			_log("** CABAL: Player character (killer) is dead. No rewards given");
			return;
		}
		// Player is alive and well. Add enemy's XP to total score for level
		approachGoalXP(charXP);
		// Increase player's score
		if (killerInfo.getStringAttribute("name") == "Player ") { // trailing space intentional
			int playerKiller = killerInfo.getIntAttribute("player_id");
			_log("** CABAL: playerKiller ID is: " + playerKiller, 1);
			float xp = targetInfo.getFloatAttribute("xp");
			if ((playerKiller >= 0) && (playerKiller < 2)) {
				//awardXP(playerKiller, xp);
			}
		} else { _log("** CABAL: killer name is " + killerInfo.getStringAttribute("name")); }

		// based on these details, set a probability for a weapon/power-up/etc. to spawn
		if (charLeader == 1) { // artificially bump XP for greater chance of drop and reward when a squad leader dies
			charXP += 0.1;
		}
		if (rand(1, 100) > 80) {
			// Group-based drop logic (enemies may drop specific equipment on death)
			if (charGroup == "rifleman") {
				// stock guys never drop gear
				return;
			} else if (charGroup == "commando") {
				dropPowerUp(v3charPos, "grenade", "player_grenade.projectile"); // drop grenade
			} else if (charXP > 0.5) {
				dropPowerUp(v3charPos, "weapon", "player_mg.weapon"); // drop minigun
			} else if (charXP > 0.3) {
				dropPowerUp(v3charPos, "weapon", "player_mp.weapon"); // drop machine pistol
			} else if (charXP > 0.2) {
				dropPowerUp(v3charPos, "weapon", "player_sg.weapon"); // drop shotgun
			}
			else {
				_log("** CABAL: XP too low, Nothing dropped", 1);
			}
		}
	}

	///////////////////////
	// POWERUP LIFECYCLE //
	///////////////////////
	protected void dropPowerUp(Vector3 position, string instanceClass, string instanceKey) {
		if (levelComplete) {
			return;
		}
        _log("** CABAL: dropping a " + instanceKey + " at " + position.toString(), 1);
        string creator = "<command class='create_instance' faction_id='0' position='" + position.toString() + "' instance_class='" + instanceClass + "' instance_key='" + instanceKey + "' activated='0' />";
        m_metagame.getComms().send(creator);
		_log("** CABAL: item placed at " + position.toString(), 1);
	}

	///////////////////
	// MAP LIFECYCLE //
	///////////////////
	protected void approachGoalXP(float xp) {
		if (levelComplete) {
			return;
		}
		curXP += xp;
		int levelCompletePercent = int(curXP / goalXP * 100);
		_log("** CABAL: current XP is: " + int(curXP) + " of " + int(goalXP), 1);
		if (levelCompletePercent > 100) { levelCompletePercent = 100; }
		_log("** CABAL: Level completion: " + levelCompletePercent + "%", 1);

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
			_log("** CABAL: LEVEL COMPLETE!", 1);
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
		// TagName=vehicle_destroyed_event
		// character_id=75
		// faction_id=0
		// owner_id=0
		// position=559.322 14.6788 618.121
		// vehicle_key=env_building_1_1_1.vehicle

		// in this game mode, all vehicles spawn a dummy vehicle (with 0 ttl) when destroyed
		// this allows us to group large numbers of vehicles into sets, and issue rewards according to the vehicle's difficulty

		// we are only interested in the destruction of 'env_building_*' buildings
        if (!startsWith(event.getStringAttribute("vehicle_key"), "env_building_")) {
			return;
		}
        _log("** CABAL: VehicleHandler going to work!", 1);
		// variablise attributes
		string vehKey = event.getStringAttribute("vehicle_key");
		int playerCharId = event.getIntAttribute("character_id");
		int playerKiller;

		array<const XmlElement@> players = getPlayers(m_metagame);
		for (uint i = 0; i < players.size(); ++i) {
			const XmlElement@ player = players[i];
			int characterId = player.getIntAttribute("character_id");
			if (characterId == playerCharId) {
				playerKiller = player.getIntAttribute("player_id");
				break;
			}
		}

		// env_block_1_.5_1.mesh
		// env_block_1_.75_1.mesh
		// env_block_1_1_1.mesh
		// env_block_1_1.5_1.mesh
		// env_cabwall_0-5_1_0-5.mesh
		// env_cabwall_0-5_1_0-75.mesh
		// env_cabwall_0-5_1_1-5.mesh
		// env_cabwall_0-5_1_1.mesh
		// env_cabwall_1-5_1_0-5.mesh
		// env_cabwall_1-5_1_0-75.mesh
		// env_cabwall_1-5_1_1-5.mesh
		// env_cabwall_1-5_1_1.mesh
		// env_cabwall_1_1_0-5.mesh
		// env_cabwall_1_1_0-75.mesh
		// env_cabwall_1_1_1-5.mesh
		// env_cabwall_1_1_1.mesh
		// env_cabwall_2_1_0-5.mesh
		// env_cabwall_2_1_0-75.mesh
		// env_cabwall_2_1_1-5.mesh
		// env_cabwall_2_1_1.mesh

		// identify the vehicle (building) and process accordingly
		// x_x_x Length-Height-Depth
		if (vehKey == "env_building_1_1_1.vehicle") {
			_log("** CABAL: 1x1x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.025);
			//awardXP(playerKiller, 0.025);
		} else if (vehKey == "env_building_1_2_1.vehicle") {
			_log("** CABAL: 1x2x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.035);
			//awardXP(playerKiller, 0.035);
		} else if (vehKey == "env_building_2_1_1.vehicle") {
			_log("** CABAL: 2x1x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.12);
			//awardXP(playerKiller, 0.12);
		} else if (vehKey == "env_building_2_2_1.vehicle") {
			_log("** CABAL: 2x2x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.13);
			//awardXP(playerKiller, 0.13);
		} else if (vehKey == "env_building_3_1_1.vehicle") {
			_log("** CABAL: 3x1x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.16);
			//awardXP(playerKiller, 0.16);
		} else if (vehKey == "env_building_3_1_3.vehicle") {
			_log("** CABAL: 3x1x3 building destroyed. Awarding XP", 1);
			approachGoalXP(0.18);
			//awardXP(playerKiller, 0.18);
		} else if (vehKey == "env_building_3_2_1.vehicle") {
			_log("** CABAL: 3x2x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.20);
			//awardXP(playerKiller, 0.20);
		} else if (vehKey == "env_building_3_2_3.vehicle") {
			_log("** CABAL: 3x2x3 building destroyed. Awarding XP", 1);
			approachGoalXP(0.22);
			//awardXP(playerKiller, 0.22);
		} else if (vehKey == "env_wall_1_1_1.vehicle") {
			_log("** CABAL: 1x1x1 wall destroyed. Awarding XP", 1);
			approachGoalXP(0.02);
			//awardXP(playerKiller, 0.02);
		}
    }

	// --------------------------------------------
	bool hasStarted() const { return m_started; }

	// --------------------------------------------
	bool hasEnded() const { return false; }

	// --------------------------------------------
	void update(float time) {
	// TODO: anything we want to track on a schedule, here?
	}

	// --------------------------------------------
	void onRemove() {
		// clear spawn counting when removing tracker - happens at map change or restart
	}

	// --------------------------------------------
	void save() {
		// TODO: taken from SND. Adjust to suit Cabal.
		// _log("** CABAL: PlayerTracker finalising this round's RP rewards", 1);
		// flushPendingRewards();
		// _log("** CABAL: Round ended. PlayerTracker now updating player inventories", 1);
		// flushPendingDropEvents();
		// for (uint i=0; i < m_activePlayers.size(); ++i) {
		// 	string sid = m_activePlayers.getKeys()[i];
		// 	_log("** CABAL: Working with player " + sid, 1);
		// 	array<const XmlElement@> allPlayers = getPlayers(m_metagame);
		// 	// TagName=player character_id=3 name=LC1A player_id=0 sid=ID0 (among others)
		// 	for (uint j=0; j < allPlayers.length(); ++j) {
		// 		int characterId = allPlayers[j].getIntAttribute("character_id");
		// 		updateSavedInventory(characterId);
		// 	}
		// }
		_log("** CABAL: PlayerTracker now saving player stats", 1);
		savePlayerStats();
	}

	// --------------------------------------------
	protected void savePlayerStats() {
		// saves to FILENAME in app_data.
		XmlElement root("cabal");

		m_savedPlayers.addPlayersToSave(root);
		m_activePlayers.addPlayersToSave(root);

		XmlElement command("command");
		command.setStringAttribute("class", "save_data");
		command.setStringAttribute("filename", FILENAME);
		command.setStringAttribute("location", "app_data");
		command.appendChild(root);

		m_metagame.getComms().send(command);

		_log("** CABAL: PlayerTracker " + m_activePlayers.size() + " active players saved", 1);
		_log("** CABAL: PlayerTracker " + m_savedPlayers.size() + " inactive players saved", 1);
	}

	// --------------------------------------------
	protected void load() {
		_log("** CABAL: Loading Saved Player Data", 1);
		// initialise object storage
		m_savedPlayers.clear();
		m_activePlayers.clear();

		// retrieve saved data
		XmlElement@ query = XmlElement(
			makeQuery(m_metagame, array<dictionary> = {
				dictionary = { {"TagName", "data"}, {"class", "saved_data"}, {"filename", FILENAME}, {"location", "app_data"} } }));
		const XmlElement@ doc = m_metagame.getComms().query(query);

		if (doc !is null) {
			const XmlElement@ root = doc.getFirstChild();
			if (root !is null) {
				_log("** CABAL: load() iterating over saved players", 1);
				array<const XmlElement@> loadedPlayers = root.getElementsByTagName("player");
				for (uint i = 0; i < loadedPlayers.size(); ++i) {
					_log("\t player" + (i + 1), 1); // load player[1..999] tag elements
					const XmlElement@ loadPlayer = loadedPlayers[i];
					string username = loadPlayer.getStringAttribute("username");
					string hash = loadPlayer.getStringAttribute("hash");
					string sid = loadPlayer.getStringAttribute("sid");
					string ip = loadPlayer.getStringAttribute("ip");
					// int id = loadPlayer.getIntAttribute("id"); // character ID is set per level. We query it later
					// int pNum = loadPlayer.getIntAttribute("pNum"); // playerNumber is set per level. We query it later
					string primary = loadPlayer.getStringAttribute("primary");
					string secondary = loadPlayer.getStringAttribute("secondary");
					string grenade = loadPlayer.getStringAttribute("grenade");
					int grenNum = loadPlayer.getIntAttribute("gren_num");

					Player player(username, hash, sid, ip, -1, -1, primary, secondary, grenade, grenNum);
					player.m_rp = loadPlayer.getIntAttribute("rp");
					player.m_xp = loadPlayer.getFloatAttribute("xp");

					m_savedPlayers.add(player);
				}
			}
		}
		_log("** CABAL: PlayerTracker load(): " + m_savedPlayers.size() + " players loaded");
	}

}
