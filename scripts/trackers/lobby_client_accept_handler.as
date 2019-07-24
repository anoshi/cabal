#include "tracker.as"

// ----------------------------------------------------
interface LobbyClientAcceptHandlerListener {
	// --------------------------------------------
	void onLobbyClientAcceptHandlerCompleted();
}

// --------------------------------------------
class LobbyClientAcceptHandler : Tracker {
	protected GameModeInvasion@ m_metagame;
	protected int m_players;
	protected int m_maxPlayers;
	protected int m_playerCharacterId;
	protected array<string> m_trackedHitboxes;
	protected LobbyClientAcceptHandlerListener@ m_listener;

	// ----------------------------------------------------
	LobbyClientAcceptHandler(GameModeInvasion@ metagame, int maxPlayers, LobbyClientAcceptHandlerListener@ listener) {
		@m_metagame = @metagame;
		m_maxPlayers = maxPlayers;
		m_players = 0;
		m_playerCharacterId = -1;
		@m_listener = @listener;
	}

	// ----------------------------------------------------
	void gameContinuePreStart() {
		if (m_playerCharacterId < 0) {
			const XmlElement@ player = m_metagame.queryLocalPlayer();
			if (player !is null) {
				setupCharacterForTracking(player.getIntAttribute("character_id"));
			} else {
				_log("*** CABAL: WARNING, local player query failed", -1);
			}
		}
	}

	// --------------------------------------------
	protected void handlePlayerConnectEvent(const XmlElement@ event) {
		m_players = getPlayerCount(m_metagame);
		refreshExtractionPoints();
	}

	// --------------------------------------------
	protected void handlePlayerDisconnectEvent(const XmlElement@ event) {
		m_players = getPlayerCount(m_metagame);
		refreshExtractionPoints();
	}

	// -------------------------------------------------------
	protected array<const XmlElement@>@ getHitboxList() {
		XmlElement@ query = XmlElement(
			makeQuery(m_metagame, array<dictionary> = {
				dictionary = { {"TagName", "data"}, {"class", "hitboxes"} } }));

		const XmlElement@ doc = m_metagame.getComms().query(query);
		array<const XmlElement@> list = doc.getElementsByTagName("hitbox");

		// go through the list and only leave the ones we're interested in
		for (uint i = 0; i < list.size(); ++i) {
			const XmlElement@ hitboxNode = list[i];
			string id = hitboxNode.getStringAttribute("id");
			if (id.findFirst("proceed") >= 0) {
				_log("*** CABAL: including " + id, 1);
			} else {
				_log("*** CABAL: ruling out " + id, 1);
				// remove this
				list.erase(i);
				i--;
			}
		}
		_log("*** CABAL: * " + list.size() + " hitboxes found", 1);
		return list;
	}

	// --------------------------------------------------------
	protected void refreshHitboxes() {
		_log("*** CABAL: refreshHitboxes", 1);
		clearHitboxAssociations(m_metagame, "character", m_playerCharacterId, m_trackedHitboxes);

		const array<const XmlElement@> list = getHitboxList();
		if (list is null) return;

		array<string> addIds;
		associateHitboxesEx(m_metagame, list, "character", m_playerCharacterId, m_trackedHitboxes, addIds);
	}

	// --------------------------------------------
	protected void handleHitboxEvent(const XmlElement@ event) {
		_log("*** CABAL: handle_hitbox_event, type=" + event.getStringAttribute("instance_type") + ", id=" + event.getIntAttribute("instance_id") + ", hitbox=" + event.getStringAttribute("hitbox_id"), 1);

		if (areExtractionPointsActive()) {
			if (event.getStringAttribute("instance_type") == "character" && event.getIntAttribute("instance_id") == m_playerCharacterId) {
				string id = event.getStringAttribute("hitbox_id");
				if (id.findFirst("proceed") >= 0) {
					// clear hitbox checking now
					clearHitboxAssociations(m_metagame, "character", m_playerCharacterId, m_trackedHitboxes);
					proceed();
				}
			}
		}
	}

	// ----------------------------------------------------
	protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		_log("*** CABAL: LobbyClientAcceptHandler::handlePlayerSpawnEvent", 1);
		const XmlElement@ element = event.getFirstElementByTagName("player");
		if (element.getIntAttribute("player_id") == 0) {
			setupCharacterForTracking(element.getIntAttribute("character_id"));
		}
	}

	// ----------------------------------------------------
	protected void setupCharacterForTracking(int id) {
		// it's the local player, do stuff now
		clearHitboxAssociations(m_metagame, "character", m_playerCharacterId, m_trackedHitboxes);
		m_playerCharacterId = id;

		_log("*** CABAL: LobbyClientAcceptHandler::setting up tracking for character " + id, 1);
		refreshHitboxes();
	}

	// --------------------------------------------------------
	protected bool areExtractionPointsActive() {
		return m_players == m_maxPlayers;
	}

	// --------------------------------------------------------
	protected void refreshExtractionPoints() {
		unmarkExtractionPoints();
		markExtractionPoints();
	}

	// --------------------------------------------------------
	protected void markExtractionPoints() {
		const array<const XmlElement@> list = getHitboxList();
		if (list is null) return;

		bool active = areExtractionPointsActive();

		int offset = 3000;
		for (uint i = 0; i < list.size(); ++i) {
			const XmlElement@ hitboxNode = list[i];
			string id = hitboxNode.getStringAttribute("id");
			string text = active ? "Continue!" : "Waiting for players";
			int atlasIndex = 1;
			float size = 2.0f;
			string color = active ? "#FFFFFF" : "#FFFFFF";

			string position = hitboxNode.getStringAttribute("position");

			string command = "<command class='set_marker' id='" + offset + "' faction_id='0' atlas_index='" + atlasIndex + "' text='" + text + "' position='" + position + "' color='" + color + "' size='" + size + "' />";
			m_metagame.getComms().send(command);

			offset++;
		}
	}

	// --------------------------------------------------------
	protected void unmarkExtractionPoints() {
		const array<const XmlElement@> list = getHitboxList();
		if (list !is null) return;

		int offset = 3000;
		for (uint i = 0; i < list.size(); ++i) {
			string command = "<command class='set_marker' id='" + offset + "' enabled='0' />";
			m_metagame.getComms().send(command);
			offset++;
		}
	}

	// --------------------------------------------
	protected void proceed() {
		if (m_listener !is null) {
			m_listener.onLobbyClientAcceptHandlerCompleted();
		}
	}

	// ----------------------------------------------------
	bool hasStarted() const { return true; }
	// ----------------------------------------------------
	bool hasEnded() const { return false; }

	// --------------------------------------------
	void onAdd() {
		refreshHitboxes();
	}
}
