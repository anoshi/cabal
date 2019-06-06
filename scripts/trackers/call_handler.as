// internal
#include "tracker.as"
#include "helpers.as"
#include "log.as"
#include "announce_task.as"
#include "query_helpers.as"
#include "cabal_helpers.as"
// --------------------------------------------


// --------------------------------------------
class CallHandler : Tracker {
	protected GameMode@ m_metagame;

	protected bool hpActive = false; // only one Hot Potato allowed at a time
	protected int hpHolder; // id of character holding the hot potato
	protected bool empActive = false; // only one EMP allowed at a time
	protected array<int> empVeh; // array of vehicle ids affected by emp
	protected array<int> ppVeh; // array of vehicle ids spotted by pathping
	protected array<string> activeTimers; // stores the names of active timers

	// ----------------------------------------------------
	CallHandler(GameMode@ metagame) {
		@m_metagame = @metagame;
	}

	protected void handleCallEvent(const XmlElement@ event) {
	/* REMEMBER: Only calls that have notify_metagame="1" declared are sent here
	Calls that don't require script-side support will use '<command>' blocks in the call itself. */

	// variablise call attributes
		// since v1.70, calls now have phases ('queue', 'acknowledge', 'launch', 'end')
		string phase = event.getStringAttribute("phase");
		string sChar = event.getStringAttribute("character_id");
		int iChar = event.getIntAttribute("character_id");
		string sCall = event.getStringAttribute("call_key");
		string sPosi = event.getStringAttribute("target_position");
		Vector3 v3Posi = stringToVector3(event.getStringAttribute("target_position"));

		uint numFactions = getFactions(m_metagame).size();

		//if (iChar !is null) {
			string sCharPosi = getCharacterInfo(m_metagame, iChar).getStringAttribute("position");
			_log("*** CABAL: Call: " + sCall + " made from: " + sCharPosi + ", targeting: " + sPosi, 1);
			_log("*** CABAL: distance from source to target: " + getPositionDistance(stringToVector3(sCharPosi), v3Posi), 1);
			//_log("call effect area: " + area, 1);
		//}

	////////////////////////
	//   Common   Calls   //
	////////////////////////
		if (sCall == "bombing_run.call") {
			if (phase == "queue") {
				//if (sCharPosi !is null) {
					_log("Bombing run from " + sCharPosi + " to " + sPosi + " queued", 1);
				//} else { _log("Bombing run must be called by a character - requires caller pos to activate"); }
			} else if (phase == "launch") {
				// shouts to DoomMetal @ Discord RUNNING WITH RIFLES #modding
				//bombingRun(event, caller_position, number, instance_class, instance_key, height)
      			//if (sCharPosi !is null) {
					  bombingRun(event, sCharPosi, 15, "grenade", "grenadier_imp.projectile", 20.0);
				//} else { _log("Bombing run must be called by a character - requires caller pos to activate"); }
			}
		}
	////////////////////////
	//  Player  Calls  //
	////////////////////////
		// The Player Hot Potato drops a very heavy, timed explosive in the backpack of a nearby enemy. If not detected
		// in time, the recipient (and those in the blast radius) is blown apart rather vigorously
		else if (sCall == "player_hot_potato_1.call") {
			if (hpActive && phase == "queue") {
				string potatoComm = "<command class='chat' faction_id='0' text='Wait for next available, over' priority='1'></command>";
				m_metagame.getComms().send(potatoComm);
				_log("a hot potato is already in play", 1);
			} else if (phase == "launch") {
				_log("Player hot potato requested at: " + sPosi, 1);
				hpActive = true;
				array<const XmlElement@> targetChars;
				for (uint i = 0; i < numFactions; ++i) {
					array<const XmlElement@> tempTargetChars = getCharactersNearPosition(m_metagame, v3Posi, i, 10.00f);
					merge(targetChars, tempTargetChars);
				}
				_log(targetChars.size() + " potential characters to receive hot potato", 1);
				if (targetChars.size() > 0) {
					uint i = rand(0, targetChars.size() - 1);
					const XmlElement@ mrPotato = targetChars[i];
					hpHolder = mrPotato.getIntAttribute("id");
					_log("character id: " + hpHolder + " chosen to receive hot potato.", 1);
					string potatoComm = "<command class='update_inventory' character_id='" + hpHolder + "' container_type_class='backpack'>" + "<item class='grenade' key='hot_potato.projectile' />" + "</command>";
					m_metagame.getComms().send(potatoComm);
					//aka: addItemInBackpack(m_metagame, id, const Resource@ r);
					//const XmlElement@ qResult = getGenericObjectInfo(m_metagame, "character", hpHolder);
					//hpHolderPosi = qResult.getStringAttribute("position");
					_log("Player Hot Potato placed in backpack of character: " + hpHolder, 1);
					setHotPotPosi("init");
					activeTimers.push_back("hot potato");
				}
			} else if (phase == "end") {
				string hpPosition = getHotPotPosi();
				if (hpPosition == "init" && hpActive) {
					_log("Character id: " + hpHolder + " still has the hot potato. Good bye!", 1);
					const XmlElement@ qResult = getGenericObjectInfo(m_metagame, "character", hpHolder);
					hpPosition = qResult.getStringAttribute("position");
				}
				if (hpActive){
					string boomComm = "<command class='create_instance' position='" + hpPosition + "' instance_class='grenade' instance_key='hot_pot_boom.projectile' activated='1'></command>";
					m_metagame.getComms().send(boomComm);
					hpActive = false;
				}
			}
		}
	////////////////////////
	// Cabal Calls //
	////////////////////////
		// The armour-piercing rounds call was intended to grant armour-piercing qualities (kill_probability="[123].01")
		// to projectiles fired by Cabal sniper rifles for a period. This does not appear to be possible, so the call drops
		// a crate containing a Cabal-specific sniper rifle (that fires AP rounds) at the location requested by the caller

		// The explosive rounds call was intended to grant explosive qualities to projectiles fired by Cabal shotguns and sniper
		// rifles for a period. This does not appear to be possible, so the call drops a crate containing a Cabal-specific shotgun
		// (that fires explosive rounds) at the location requested by the caller.

		// The Probe call launches a stealth device that alerts the caller's faction when an enemy unit passes near it.
		// The probe emits a regular but infrequent visual 'blip' that enemies may notice and, after doing so, destroy the device.
		// The probe will likely be of a similar concept to the turrets (an immobile faction unit) but unarmed. Its primary purpose
		// will be to spot enemy vehicles so best to place these things near major (vehicular) thoroughfares.
		// Alternative solution is to use getChars/getVehiclesNearPosition and notify every so often. Show on map what we can.
		else if (sCall == "cabal_probe_1.call") {
			_log("Cabalprobe not implemented, yet", 1);
		}
		// The x-ray call advises the contents of crates as well as armoured and hidden devices in the game. It allows Cabal troops to make
		// a judgement call as to whether or not they should attempt to reach the location in the first place.
		else if (sCall == "cabal_x-ray_1.call") {
			if (phase == "launch") {
				array<const XmlElement@> xrayItem = getVehiclesNearPosition(m_metagame, v3Posi, 1, 15.00f);
				for (uint i = 0; i < xrayItem.size(); ++i) {
					const XmlElement@ info = xrayItem[i];
					int id = info.getIntAttribute("id");
					const XmlElement@ vehInfo = getVehicleInfo(m_metagame, id);
					string sKey = vehInfo.getStringAttribute("key");
					// if some sort of crate
					if (startsWith(sKey, 'special_cr') || endsWith(sKey, '_crate.vehicle')) {
						// confirm it's near the call target position
						Vector3 v3VehPosi = stringToVector3(vehInfo.getStringAttribute("position"));
						if (checkRange(v3Posi, v3VehPosi, 10.00f) ) {
						// get detailed info
						string sName = vehInfo.getStringAttribute("name");
						string sType = vehInfo.getStringAttribute("type_id");
						// advise (likely) contents of 'vehicle'
						_log("x-ray of " + sKey + " in progress...", 1);

						} else {
							_log("Vehicle " + sKey + " is outside the range of this call", 1);
						}
					} else {
						_log("x-ray call doesn't work on " + sKey + " vehicles", 1);
						xrayItem.erase(i);
						i--;
					}
				}
			} else if (phase == "end") {
				_log("ss x-ray completed");
			}
		}
	}

	/////////////////////////////
	// ----- CALL METHODS -----//
	/////////////////////////////
	protected void bombingRun(const XmlElement@ event, string charPosi, int number, string instanceClass, string instanceKey, float height) {
		// Get the info we need
		int characterId = event.getIntAttribute("character_id");
		Vector3 senderPos = stringToVector3(charPosi);
		Vector3 targetPos = stringToVector3(event.getStringAttribute("target_position"));
		// Find the line perpendicular to caller-target
		Vector3 sightLine = senderPos.subtract(targetPos);
		// Get x and z coords
		float sx = sightLine.get_opIndex(0);
		float sz = sightLine.get_opIndex(2);
		// Flip x and z coords, make new z negative
		// Add height to y while we're at it
		Vector3 perpendicularLine = Vector3(sz, sightLine.get_opIndex(1) + height, -sx);
		_log("sightLine: " + sightLine.toString(), 1);
		for (int i = 0; i < number; i++) {
			int j = i - 20;
			Vector3 newPos = targetPos.subtract(perpendicularLine.scale(j * 0.05));
			string c = '<command class="create_instance" faction_id="0" instance_class="' + instanceClass + '" instance_key="' + instanceKey + '" position="' + newPos.toString() + '" offset="0 0 0" />';
			m_metagame.getComms().send(c);
		}
	}

	// ------------- Player Hot Potato tracking methods ------------- //
	protected void handleItemDropEvent(const XmlElement@ event) {
		// Player Hot Potato item tracker
		// we only need to know if the hot potato is dropped on the ground. Otherwise, it's still held by the target
		if ((event.getStringAttribute("item_key") == "hot_potato.projectile") && (event.getStringAttribute("target_container_type_id") == "0")) {
			string hpPosi = event.getStringAttribute("position");
			_log("Hot Potato has been dropped on the ground at " + hpPosi, 1);
			setHotPotPosi(hpPosi); // see cabal_helpers.as
		}
	}

	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		// tracking for the hot potato in case of being discovered and thrown as a grenade
		_log("*** CABAL: call_handler handleVehicleDestroyEvent running",1);
		if (event.getStringAttribute("vehicle_key") == "dummy_hot_potato.vehicle") {
			// stop tracking the hot potato. It's blown up!
			_log("*** CABAL: hot potato was used as grenade and detonated.");
			hpActive = false;
		}
	}

	// --------------------------------------------
	/*
	// --------------------------------------------
	void init() {
	}
	// --------------------------------------------
	void start() {
	}
	*/
	// --------------------------------------------
	bool hasEnded() const {
		// always on
		return false;
	}
	// --------------------------------------------
	bool hasStarted() const {
		// always on
		return true;
	}
	// --------------------------------------------
	void update(float time) {
	}
	// ----------------------------------------------------
}
