// internal
#include "tracker.as"
#include "log.as"

// --------------------------------------------


// --------------------------------------------
class CabalSpawner : Tracker {
	protected Cabal@ m_metagame;

	protected bool m_started = false;

    protected float SPAWN_DELAY_MAX = 10.00; // make this a dynamic value. Shorter as map increases in duration and at higher levels.
    protected float SPAWN_DELAY_MIN = 5.00;
	protected float spawnDelay; // randomise time between enemy spawns

	protected array<string> playerHashes;
	protected array<int> playerCharIds;

	// ----------------------------------------------------
	CabalSpawner(Cabal@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void start() {
		_log("** CABAL: starting cabal_spawner tracker", 1);
		queueCabalSpawn();
		m_started = true;
	}

	// --------------------------------------------
	protected void queueCabalSpawn() {
		spawnDelay = rand(SPAWN_DELAY_MIN, SPAWN_DELAY_MAX);
		_log("** CABAL: Enemy units queued to spawn in: " + spawnDelay + " seconds." ,1);
	}

	// --------------------------------------------
	protected void spawnCabalUnits() {
		// What is the player character's id? (get hashes for multiplayer support)
		array<const XmlElement@> allPlayersInfo = getPlayers(m_metagame);
	 	for (uint i = 0; i < allPlayersInfo.size(); ++i) {
			int playerCharacterId = allPlayersInfo[i].getIntAttribute("character_id");
			const XmlElement@ playerCharacterInfo = getCharacterInfo(m_metagame, playerCharacterId);
			if (playerCharacterInfo is null || playerCharacterInfo.getIntAttribute("wounded") == 1 || playerCharacterInfo.getIntAttribute("dead") == 1) {
				_log("** CABAL: No enemies were spawned! At least one player character is waiting to spawn" , 1);
				return; // break out of method
			}
		 }
		_log("** CABAL: player is alive, ok to spawn enemies", 1);
		// start enemy spawning from specific locations (as per passed map layer name, for level)
		// after player character has spawned. i.e. no enemy spawn until player is on the map
		int m_spawnCount = playerHashes.size() * 4;
		string m_genericNodeTag = "cabal_spawn";
		string layerName = thisStage();
		array<const XmlElement@>@ nodes = getGenericNodes(m_metagame, layerName, m_genericNodeTag);
		_log("** CABAL: Spawning " + m_spawnCount + " enemies at " + nodes.size() + " " + m_genericNodeTag + " points.", 1);
		string randKey = ''; // random character 'Key' name
		for (int j = 0; j < m_spawnCount && nodes.size() > 0; ++j) {
			switch( rand(0, 5) ) { // 5 types of enemy units, weighted to return more base level soldiers
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
			XmlElement command("command");
			command.setStringAttribute("class", "create_instance");
			command.setIntAttribute("faction_id", 1);
			command.setStringAttribute("instance_class", "character");
			command.setStringAttribute("instance_key", randKey);

			// logic to use each generic_node only once
			int index = rand(0, nodes.size() - 1);
			const XmlElement@ node = nodes[index];
			nodes.erase(index);

			// location and bearing of spawnpoint
			command.setStringAttribute("position", node.getStringAttribute("position"));
			command.setStringAttribute("orientation", node.getStringAttribute("orientation"));
			m_metagame.getComms().send(command);
		}
	}

	// /////////////////////// //
	// Get player character ID //
	// /////////////////////// //
	protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		_log("** CABAL: CabalSpawner::handlePlayerSpawnEvent", 1);

		const XmlElement@ player = event.getFirstElementByTagName("player");
		if (player !is null) {
			string playerHash = player.getStringAttribute("profile_hash");
			int characterId = player.getIntAttribute("character_id");
			if (playerHashes.find(playerHash) < 0) {
				_log("** CABAL: Player hash " + playerHash + " not found in playerHashes array.", 1);
				if (int(playerHashes.size()) < 2) { // max players is 2, maybe make it a public const
					string name = player.getStringAttribute("name");
					playerHashes.insertLast(playerHash);
					playerCharIds.insertLast(characterId);
					_log("** CABAL: player " + name + " (" + playerCharIds[int(playerCharIds.size() -1)] + ") spawned as player" + int(playerHashes.size()), 1);
				}
				_log("** CABAL: playerHashes[" + int(playerHashes.size() - 1) + "] now stores: " + playerHashes[int(playerHashes.size() -1)] + " for Player" + playerCharIds.size(), 1);
			} else {
				// existing player.
			}
		} else {
			_log("** CABAL: CRITICAL WARNING, player not found in Player Spawn Event");
		}
	}



	// --------------------------------------------
	bool hasEnded() const {
		// always on
		return false;
	}

	// --------------------------------------------
	bool hasStarted() const {
		return m_started;
	}

	// --------------------------------------------
	void update(float time) {
		spawnDelay -= time;
		if (spawnDelay <= 0.0) {
			_log("** CABAL: enemy units spawning!", 1);
			spawnCabalUnits();
			queueCabalSpawn();
		}
	}
	// ----------------------------------------------------
}
