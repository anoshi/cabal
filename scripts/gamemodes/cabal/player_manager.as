// internal
#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "cabal_helpers.as"

//////////////////////////////////
// Each player is a game object //
//////////////////////////////////
// --------------------------------------------
class Player {
	string m_username = "";
	string m_hash = "";
	string m_sid = "ID0";
	string m_ip = "";

	int m_playerId = -1;	// the 'player_id'. Value positive only when player is in-game
	int m_charId = -1;		// the 'character_id' of the player. Value positive only when player is in-game
	int m_playerNum = -1;	// given a positive int when actively playing

	string m_primary = "";
	string m_secondary = "";
	string m_grenade = "";
	int m_grenNum = 0;

	int m_rp;
	float m_xp;

	// --------------------------------------------
	Player(string username, string hash, string sid, string ip, int id=-1, int pNum=-1, string pri="", string sec="", string gren="", int grenNum=0) {
		m_username = username;
		m_hash = hash;
		m_sid = sid;
		m_ip = ip;
		m_playerNum = pNum;
		m_playerId = id;
		m_primary = pri;
		m_secondary = sec;
		m_grenade = gren;
		m_grenNum = grenNum;
	}

	// --------------------------------------------
	string getKey() const {
		return m_sid;
	}
}

// --------------------------------------------
// Store all player objects in dictionaries
// PlayerTracker (below) defines two PlayerStores,
// one for current players (m_activePlayers)
// the other for saved players (m_savedPlayers)
// to allow persistent character stats
// --------------------------------------------
class PlayerStore {
	protected PlayerTracker@ m_playerTracker;
	protected string m_name; 					// name of the storage container e.g. 'goodGuys', 'faction3'...
	protected dictionary m_players;

	// --------------------------------------------
	PlayerStore(PlayerTracker@ playerTracker, string name) {
		@m_playerTracker = @playerTracker;
		m_name = name;
	}

	// --------------------------------------------
	array<string> getKeys() const {
		return m_players.getKeys();
	}

	// --------------------------------------------
	bool exists(string key) const {
		return m_players.exists(key);
	}

	// --------------------------------------------
	Player@ get(string key) const {
		Player@ player;
		m_players.get(key, @player);
		return player;
	}

	// --------------------------------------------
	void add(Player@ player) {
		_log("** CABAL: PlayerTracker, " + m_name + ": add, player=" + player.m_username + ", hash=" + player.m_hash + ", player count before=" + m_players.size() + ", sid=" + player.m_sid);
		m_players.set(player.m_sid, @player);
	}

	// --------------------------------------------
	void remove(Player@ player) {
		int s = size();
		m_players.erase(player.m_sid);
		if (size() != s) {
			_log("** CABAL: PlayerTracker, " + m_name + ": remove, player=" + player.m_username + ", sid=" + player.m_sid);
		}
	}

	// --------------------------------------------
	void addPlayersToSave(XmlElement@ root) {
		for (uint i = 0; i < m_players.size(); ++i) {
			string sid = m_players.getKeys()[i];
			_log("** CABAL: Saving player " + sid, 1);
			Player@ player = get(sid);
			XmlElement savedPlayer("player");
			savedPlayer.setStringAttribute("username", player.m_username);
			savedPlayer.setStringAttribute("hash", player.m_hash);
			savedPlayer.setStringAttribute("sid", player.m_sid);
			savedPlayer.setStringAttribute("ip", player.m_ip);
			savedPlayer.setIntAttribute("rp", player.m_rp);
			savedPlayer.setFloatAttribute("xp", player.m_xp);
			savedPlayer.setStringAttribute("primary", player.m_primary);
			savedPlayer.setStringAttribute("secondary", player.m_secondary);
			savedPlayer.setStringAttribute("grenade", player.m_grenade);
			savedPlayer.setIntAttribute("gren_num", player.m_grenNum);
			root.appendChild(savedPlayer);
			_log("** CABAL: Saved player " + i + " " + player.m_username, 1);
		}
	}

	// --------------------------------------------
	int size() const {
		return m_players.size();
	}

	// --------------------------------------------
	void clear() {
		m_players = dictionary();
	}
}
