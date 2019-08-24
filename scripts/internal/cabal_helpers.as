// internal
#include "comms.as"
#include "metagame.as"
#include "resource.as"

/////////////////////////////////////
// ----- BEGIN CABAL HELPERS ----- //
/////////////////////////////////////

////////////////////////////////
// ----- GLOBAL METHODS ----- //
////////////////////////////////
array<const XmlElement@>@ getVehiclesNearPosition(const Metagame@ metagame, const Vector3@ position, int factionId, float range = 25.00f) {
	array<const XmlElement@> allVehicles;
	array<const XmlElement@> vehNearPos;

	_log("*** CABAL getVehiclesNearPosition running", 1);

	// querying 'vehicles' doesn't support a range variable, like 'characters' does.
	// Must grab all vehicles and check their proximity to event, in turn.

	XmlElement@ query = XmlElement(
		makeQuery(metagame, array<dictionary> = {
			dictionary = { {"TagName", "data"}, {"class", "vehicles"}, {"faction_id", factionId},
						   {"position", position.toString()} } }));

	const XmlElement@ doc = metagame.getComms().query(query);
	allVehicles = doc.getElementsByTagName("vehicle");

	for (uint i = 0; i < allVehicles.size(); ++i) {
		const XmlElement@ curVeh = allVehicles[i];
		int id = curVeh.getIntAttribute("id");
		const XmlElement@ vehInfo = getVehicleInfo(metagame, id);
		int vType = vehInfo.getIntAttribute("type_id");
		string sName = vehInfo.getStringAttribute("name");
		string sKey = vehInfo.getStringAttribute("key");
		Vector3 curVehPos = stringToVector3(vehInfo.getStringAttribute("position"));
		_log("*** CABAL: working on vehicle: " + id + " (" + sKey + ") ", 1);
		if (checkRange(position, curVehPos, range) ) {
			// we should never need to know where the decoration vehicles are.
			if ( startsWith(sKey, "deco_") || startsWith(sKey, "dumpster") ) {
				allVehicles.erase(i);
				i--;
				_log("*** CABAL: removed vehicle " + id + " (decoration) from list.", 1);
			} else {
				vehNearPos.insertLast(curVeh);
				_log("*** CABAL: vehicle: " + id + " (" + sName + ") is within desired range. Adding.", 1);
			}
		}
	}

	return vehNearPos;
}

void setPlayerInventory(const Metagame@ metagame, int characterId, string vest) {
	// assign / override equipment to player character
	_log("*** CABAL: Equipping player (id: " + characterId + ") with " + vest, 1);
	XmlElement charInv("command");
	charInv.setStringAttribute("class", "update_inventory");

	charInv.setIntAttribute("character_id", characterId);
	charInv.setIntAttribute("container_type_id", 4); // vest
	{
		XmlElement i("item");
		i.setStringAttribute("class", "carry_item");
		i.setStringAttribute("key", vest);
		charInv.appendChild(i);
	}
	metagame.getComms().send(charInv);
	_log("*** CABAL: " + vest + " equipped on character " + characterId, 1);
}

string curStage;

void whichStage(string stageNum) {
	// each stage reports its stage name e.g. "map1" in stage_invasion.as.
	string curStage = stageNum;
	_log("*** CABAL: Current stage is: " + curStage, 1);
}

string thisStage() {
	return curStage;
}

///////////////////////////////////
// ----- END CABAL HELPERS ----- //
///////////////////////////////////
