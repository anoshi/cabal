#include "tracker.as"

// --------------------------------------------
class PlayerManager : Tracker {
	protected GameMode@ m_metagame;
	protected array<string> m_acceptedPlayers;

	// ----------------------------------------------------
	PlayerManager(GameMode@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void setupFromCurrentState() {
		m_acceptedPlayers.clear();
		array<const XmlElement@> players = getPlayers(m_metagame);
		for (uint i = 0; i < players.size(); ++i) {
			const XmlElement@ player = players[i];
			string hash = player.getStringAttribute("profile_hash");
			m_acceptedPlayers.insertLast(hash);
		}
	}

	// --------------------------------------------
	protected void handlePlayerConnectEvent(const XmlElement@ event) {
		if (m_acceptedPlayers.empty()) {
			// don't manage until setup
			return;
		}

		const XmlElement@ player = event.getFirstElementByTagName("player");
		if (player !is null) {
			string hash = player.getStringAttribute("profile_hash");
			if (m_acceptedPlayers.find(hash) < 0) {
				// not found, kick
				kickPlayer(player.getIntAttribute("player_id"), "Profile not accepted");
			}
		}
	}

	// ----------------------------------------------------
	bool hasStarted() const { return true; }
	// ----------------------------------------------------
	bool hasEnded() const { return false; }

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
	
	// ----------------------------------------------------
	void save(XmlElement@ root) {
		XmlElement@ parent = root;

		XmlElement subroot("player_manager");

		for (uint i = 0; i < m_acceptedPlayers.size(); ++i) {
			XmlElement p("player");
			p.setStringAttribute("hash", m_acceptedPlayers[i]);
			subroot.appendChild(p);
		}
		
		parent.appendChild(subroot);
	}

	// ----------------------------------------------------
	void load(const XmlElement@ root) {
		m_acceptedPlayers.clear();
		const XmlElement@ subroot = root.getFirstElementByTagName("player_manager");
		if (subroot !is null) {
			array<const XmlElement@> list = subroot.getElementsByTagName("player");
			for (uint i = 0; i < list.size(); ++i) {
				const XmlElement@ p = list[i];

				string hash = p.getStringAttribute("hash");

				m_acceptedPlayers.insertLast(hash);
			}
		}
	}

}

