// internal
#include "tracker.as"
#include "helpers.as"
#include "log.as"
//#include "announce_task.as"
#include "query_helpers.as"
#include "cabal_helpers.as"
// --------------------------------------------


// --------------------------------------------
class ItemDropHandler : Tracker {
	protected Cabal@ m_metagame;

    protected int m_playerCharacterId;
    protected float m_localPlayerCheckTimer;
    protected float LOCAL_PLAYER_CHECK_TIME = 5.0;

	// ----------------------------------------------------
	ItemDropHandler(Cabal@ metagame) {
		@m_metagame = @metagame;
	}

    protected void handleItemDropEvent(const XmlElement@ event) {
		// character_id             (character who dropped the item)
		// item_class               (3: carry_item)
        // item_key                 (e.g.: lighter.carry_item)
		// item_type_id             (lighter.carry_item: 12)
		// player_id                (not a player: -1)
		// position                 (xxx.xxx yy.yyy zzz.zzz)
        // target_container_type_id (0: ground, 1: armoury)

        _log("*** CABAL: handleItemDropEvent fired!", 1);
		// don't process if not properly started
		//if (!hasStarted()) return;
		// only check for items dropped on the ground
		if (event.getIntAttribute("target_container_type_id") != 0) {
			_log("*** CABAL: item was not dropped onto ground. Ignoring", 1);
			return;
		}

        _log("*** CABAL: store details of dropped item", 1);
        string itemKey = event.getStringAttribute("item_key");
        string itemClass = event.getIntAttribute("item_class");
        string dropPos = event.getStringAttribute("position");
        Vector3 v3dropPos = stringToVector3(dropPos);

        _log("*** CABAL: get player character location", 1);
        string sCharPosi = getCharacterInfo(m_metagame, m_playerCharacterId).getStringAttribute("position");
        Vector3 playerPos = stringToVector3(sCharPosi);
        float retX = v3dropPos.get_opIndex(0);
        float retY = playerPos.get_opIndex(1) + 2.0;
        float retZ = playerPos.get_opIndex(2);
        Vector3 redropPos = Vector3(retX, retY, retZ);

        _log("*** CABAL: remove dropped item from play", 1);

        _log("*** CABAL: placing a copy of dropped item at (X = positionX, Y = playerY + 2~3, Z = playerZ)",1);
        string creator = "<command class='create_instance' faction_id='0' position='" + redropPos.toString() + "' offset='0 0 0' character_id='0' instance_class='" + itemClass + "' instance_key='" + itemKey + "' ></command>";
        m_metagame.getComms().send(creator);
		_log("*** CABAL: item placed at" + redropPos.toString(),1);
        // ensure all dropped items have a short TTL e.g 5 seconds
        // ensure only rare weapons are dropped

	}

	// ----------------------------------------------------
    protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		_log("*** CABAL ItemDropHandler::handlePlayerSpawnEvent", 1);

		const XmlElement@ element = event.getFirstElementByTagName("player");
		string name = element.getStringAttribute("name");
		_log("player spawned: " + name + ", target username is " + m_metagame.getUserSettings().m_username, 1);
		if (name == m_metagame.getUserSettings().m_username) {
			_log("player is local", 1);
			m_playerCharacterId = element.getIntAttribute("character_id");
		}
	}

	// ----------------------------------------------------
	protected void ensureValidLocalPlayer(float time) {
		if (m_playerCharacterId < 0) {
			m_localPlayerCheckTimer -= time;
			if (m_localPlayerCheckTimer < 0.0) {
				_log("tracked player character id " + m_playerCharacterId, 1);
				const XmlElement@ player = m_metagame.queryLocalPlayer();
				if (player is null) {
					_log("WARNING, local player query failed", -1);
				}
				m_localPlayerCheckTimer = LOCAL_PLAYER_CHECK_TIME;
			}
		}
	}

    // ----------------------------------------------------
    void update(float time) {
        ensureValidLocalPlayer(time);
    }
}