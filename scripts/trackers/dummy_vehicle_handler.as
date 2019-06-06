// internal
#include "tracker.as"
#include "helpers.as"
#include "log.as"
//#include "announce_task.as"
#include "query_helpers.as"
#include "cabal_helpers.as"
// --------------------------------------------


// --------------------------------------------
class DummyVehicleHandler : Tracker {
	protected GameMode@ m_metagame;

	protected bool empActive = false; // only one EMP allowed at a time
	protected array<int> empVeh; // array of vehicle ids affected by emp
	protected array<int> termTurrets; // array of turrets to be controlled by terminal interaction

	// ----------------------------------------------------
	DummyVehicleHandler(GameMode@ metagame) {
		@m_metagame = @metagame;
	}

    protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		// we are only interested in the destruction of dummy vehicles
        if (startsWith(event.getStringAttribute("vehicle_key"), "dummy_")) {
            _log("*** CABAL: DummyVehicleHandler going to work!", 1);

            // variablise attributes
            int factionId = event.getIntAttribute("owner_id");
            string sPosi = event.getStringAttribute("position");
            Vector3 v3Posi = stringToVector3(sPosi);
            string vKey = event.getStringAttribute("vehicle_key");
            uint numFactions = getFactions(m_metagame).size();

            if (vKey == "dummy_terminal.vehicle") {
                _log("*** CABAL: Terminal at " + sPosi + " has been activated... Locating nearby equipment", 1);
                // improve to detect hostile active turrets (enemy soldier 'turret') as well as offline turrets
                array<const XmlElement@> foundEquip;
                // start with the offline turrets (vehicles)
                for (uint i = 0; i < numFactions; ++i) {
                    array<const XmlElement@> offlineTurrets = getVehiclesNearPosition(m_metagame, v3Posi, i, 10.00f);
                    merge(foundEquip, offlineTurrets);
                }
                for (uint i = 0; i < foundEquip.size(); ++i) {
                    const XmlElement@ info = foundEquip[i];
                    int id = info.getIntAttribute("id");
                    _log("*** CABAL: vehicle id: " + id, 1);
                    const XmlElement@ vehInfo = getVehicleInfo(m_metagame, id);
                    string vehPosi = vehInfo.getStringAttribute("position");
                    Vector3 v3VehPosi = stringToVector3(vehPosi);
                    string sKey = vehInfo.getStringAttribute("key");
                    if (startsWith(sKey, "veh_empl_turret")) {
                        _log("*** CABAL: found a turret at: " + vehPosi + ". (Re)Activating...", 1);
                        termTurrets.push_back(id);
                    } else {
                        foundEquip.erase(i);
                        i--;
                    }
                }
                // now find the online turrets (soldiers) ahhh balls can't find a character's class without consulting saved data.
                /*
                for (uint i = 0; i < numFactions; ++i) {
                    array<const XmlElement@> onlineTurrets = getCharactersNearPosition(m_metagame, v3Posi, i, 10.00f);
                }
                for (uint i = 0; i < onlineTurrets.size(); ++i) {
                    const XmlElement@ info = onlineTurrets[i];
                    int id = info.getIntAttribute("id");
                    const XmlElement@ charInfo = getCharacterInfo(m_metagame, id);
                    string charPosi = charInfo.getStringAttribute("position");
                    Vector3 v3CharPosi = stringToVector3(charPosi);
                    HERE NEEDS FIXING: string sClass = charInfo.getStringAttribute("key");
                    if (startsWith(sKey, "veh_empl_turret")) {
                        _log("found a hostile turret at: " + charPosi + ". Repurposing...", 1);
                        termTurrets.push_back(id);
                    } else {
                        onlineTurrets.erase(i);
                        i--;
                    }
                }
                // join the offline and online turret arrays
                merge(foundEquip, onlineTurets);
                */
                for (uint i = 0; i < termTurrets.size(); ++i) {
                    uint turretID = termTurrets[i];
                    const XmlElement@ turretInfo = getVehicleInfo(m_metagame, turretID);
                    string turretPosi = turretInfo.getStringAttribute("position");
                    // remove turret vehicle/mesh from location
                    string remComm = "<command class='remove_vehicle' id='" + turretID + "'></command>";
                    //string remComm = "<command class='update_vehicle' id='" + turretID + " health='-1''></command>";
                    m_metagame.getComms().send(remComm);
                    // place static turret char at location
                    string spawnComm = "<command class='create_instance' instance_class='character' faction_id='0' position='" + turretPosi + "' instance_key='empl_turret' /></command>";
                    m_metagame.getComms().send(spawnComm);
                }
                if (termTurrets.size() >= 1) {
                    termTurrets.resize(0);
                }
            } // else if () { // next dummy vehicle }
        }
    }
}
