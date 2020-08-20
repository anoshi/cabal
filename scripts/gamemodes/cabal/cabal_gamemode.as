// internal
#include "metagame.as"
#include "log.as"
#include "announce_task.as"
#include "query_helpers.as"

// cabal gamemode classes
#include "cabal_map_rotator.as"

// cabal helper functions
#include "cabal_helpers.as"

// cabal trackers
#include "player_tracker.as"
#include "cabal_spawner.as"

// --------------------------------------------
class CabalGameMode : Metagame {
	protected UserSettings@ m_userSettings;
	protected MapRotator@ m_mapRotator;

	protected bool trackPlayerDeaths = true;
	protected bool matchEndOverride = false; 	// boss levels aren't won under normal level win conditions

	protected uint numPlayers = 0;				// number of active players in the game

	protected array<int> trackedCharIds;		// Ids of characters being tracked against collisions with hitboxes
	protected array<Vector3> targetLocations;	// locations of interest in each level
	protected array<Vector3> extractionPoints;	// locations that player characters must reach to advance to the next level

	protected array<Faction@> m_factions;

	// --------------------------------------------
	CabalGameMode(UserSettings@ settings) {
		super(settings.m_startServerCommand);
		@m_userSettings = @settings;
	}

	// --------------------------------------------
	void init() {
		Metagame::init();

		// trigger map change right now
		_log("** CABABL: setupMapRotator", 1);
		setupMapRotator();
		_log("** CABABL: mapRotator init()", 1);
		m_mapRotator.init();
		_log("** CABABL: mapRotator startRotation()", 1);
		m_mapRotator.startRotation();

		//setupPlayerTracker();

		if (m_userSettings.m_continue) {
			// loading a saved game?
			load();
			preBeginMatch();
			postBeginMatch();

		} else {
			// no, it's not a save game
			sync();
			preBeginMatch();
			startMatch();
			postBeginMatch();
		}

	}

	// --------------------------------------------
	void uninit() {
		save();
	}

	// --------------------------------------------
	const UserSettings@ getUserSettings() const {
		return m_userSettings;
	}

	// --------------------------------------------
	void save() {
		_log("** CABAL: saves to cabal_save.xml!", 1);
	}

	// --------------------------------------------
	void load() {
		_log("** CABAL: loading metagame!", 1);
	}

	// --------------------------------------------
	protected void setupMapRotator() {
		@m_mapRotator = CabalMapRotator(this);
	}

	// // --------------------------------------------
	// protected void setupPlayerTracker() {
	// 	@m_playerTracker = PlayerTracker(this);
	// }

	// --------------------------------------------
	protected void startMatch() {
		// TODO: derive and implement
	}

	// --------------------------------------------
	void postBeginMatch() {
		Metagame::postBeginMatch();

		// Cabal handlers
		addTracker(PlayerTracker(this));
		_log("** CABAL: Metagame added PlayerTracker", 1);
		addTracker(CabalSpawner(this));
		_log("** CABAL: Metagame added CabalSpawner", 1);

		getUserSettings();
	}

	// --------------------------------------------
	void addRP(int cId, int rp) {
		//string charId = "" + cId + "";
		//m_playerTracker.addRP(cId, rp); // something like this for cabal?

		// if (pendingRPRewards.exists(charId)) {
			// int val = int(pendingRPRewards[charId]);
			// pendingRPRewards[charId] = val + rp;
		// } else {
			// pendingRPRewards.set(charId, rp);
		// }
	}

	// --------------------------------------------
	void addXP(int charId, float xp) {
		// nothing yet grants XP bonuses.
	}

	// --------------------------------------------
	void setTrackPlayerDeaths(bool pDeaths=true) {
		trackPlayerDeaths = pDeaths;
	}

	// --------------------------------------------
	bool getTrackPlayerDeaths() {
		_log("** Cabal: got trackPlayerDeaths: (" + trackPlayerDeaths + ")", 1);
		return trackPlayerDeaths;
	}

	// --------------------------------------------
	void setMatchEndOverride(bool enabled=true) {
		matchEndOverride = enabled;
	}

	// --------------------------------------------
	bool getMatchEndOverride() {
		_log("** Cabal: Match End requested. " + (matchEndOverride ? 'Blocked' : 'Allowed'), 1);
		return matchEndOverride;
	}

	// --------------------------------------------
	void addTrackedCharId(int charId) {
		// Trackers call this method to add a character ID to the list of tracked character IDs
		trackedCharIds.insertLast(charId);
		_log("** CABAL: CabalGameMode::addTrackedCharId " + charId, 1);
	}

	// --------------------------------------------
	void removeTrackedCharId(int charId) {
		// Trackers call this method to remove a character ID from the list of tracked character IDs
		_log("** CABAL: CabalGameMode::removeTrackedCharId " + charId, 1);
		int idx = trackedCharIds.find(charId);
		if (idx >= 0) {
			trackedCharIds.removeAt(idx);
			_log("\t charId: " + charId + " removed", 1);
		}
	}

	// --------------------------------------------
	array<int> getTrackedCharIds() {
		// Trackers call this method to retrieve the full list of tracked character IDs
		return trackedCharIds;
	}

	// --------------------------------------------
	void setNumPlayers(uint num) {
		// Trackers call this method to report the number of active players
		numPlayers = num;
	}

	// --------------------------------------------
	uint getNumPlayers() {
		_log("** CABAL: current players: " + numPlayers, 1);
		return numPlayers;
	}

	// --------------------------------------------
	const XmlElement@ getPlayerInventory(int characterId) {
		_log("** CABAL: Inspecting character " + characterId + "'s inventory", 1);
		XmlElement@ query = XmlElement(
			makeQuery(this, array<dictionary> = {
				dictionary = {
					{"TagName", "data"},
					{"class", "character"},
					{"id", characterId},
					{"include_equipment", 1}
				}
			})
		);
		const XmlElement@ doc = getComms().query(query);
		return doc.getFirstElementByTagName("character"); //.getElementsByTagName("item")

		// TagName=query_result query_id=22
		// TagName=character
		// block=11 17
		// dead=0
		// faction_id=0
		// id=3
		// leader=1
		// name=CT: 62
		// player_id=0
		// position=375.557 2.74557 609.995
		// rp=9400
		// soldier_group_name=default
		// squad_size=0
		// wounded=0
		// xp=0

		// TagName=item amount=1 index=17 key=steyr_aug.weapon slot=0
		// TagName=item amount=0 index=3 key=9x19mm_sidearm.weapon slot=1
		// TagName=item amount=1 index=3 key=hand_grenade.projectile slot=2
		// TagName=item amount=0 index=-1 key= slot=4
		// TagName=item amount=1 index=3 key=kevlar_plus_helmet.carry_item slot=5
	}

	// -----------------------------
	void setPlayerInventory(int characterId, bool newPlayer=false, string pri="", string sec="", string gren="", int grenNum=0, string arm="") {
		// container_type_ids (slot=[0-5])
		// 0 : primary weapon (cannot add directly, put in backpack instead)
		// 1 : secondary weapon
		// 2 : grenade
		// 3 : ?
		// 4 : armour
		// 5 : armour

		const XmlElement@ thisChar = getCharacterInfo(this, characterId);
		if (thisChar.getIntAttribute("id") != characterId) {
			_log("** CABAL: WARNING! getCharacterInfo returned a non-matching characterId. Character " + characterId + " will have no equipment this round!", 1);
			return;
		}

		int faction = thisChar.getIntAttribute("faction_id");

		// assign / override equipment to player character
		if (newPlayer) {
			// give the character appropriate starting kit for their faction
			_log("** CABAL: Equipping new player (id: " + characterId + ") with starting gear", 1);
			string equipNewPlayer = "<command class='update_inventory' character_id='" + characterId + "' container_type_class='backpack'><item class='weapon' key='player_ar.weapon' /></command>";
			getComms().send(equipNewPlayer);
		} else {
			_log("** CABAL: Updating inventory for player (character_id: " + characterId + ")", 1);
			// primary into backpack, cannot override slot
			if (startsWith(pri, 'player_')) {
				string addPri = "<command class='update_inventory' character_id='" + characterId + "' container_type_class='backpack'><item class='weapon' key='" + pri + "' /></command>";
				getComms().send(addPri);
			} else {
				// you always get an assault rifle if you aren't carrying a primary weapon
				_log("** CABAL: Character " + characterId + " has no primary weapon. Granting a free player_ar.weapon", 1);
				string addSec = "<command class='update_inventory' character_id='" + characterId + "' container_type_class='backpack'><item class='weapon' key='player_ar.weapon' /></command>";
				getComms().send(addSec);
			}
			if (sec != '') {
				string addSec = "<command class='update_inventory' character_id='" + characterId + "' container_type_class='backpack'><item class='weapon' key='" + sec + "' /></command>";
				getComms().send(addSec);
			}
			for (int gn = 0; gn < grenNum; ++gn) {
				string addGren = "<command class='update_inventory' character_id='" + characterId + "' container_type_id='2'><item class='grenade' key='" + gren + "' /></command>";
				getComms().send(addGren);
			}
			if (arm != '') {
				string addArm = "<command class='update_inventory' character_id='" + characterId + "' container_type_id='4'><item class='carry_item' key='" + arm + "' /></command>";
				getComms().send(addArm);
			}
		}
	}

	////////////////////////
	// Sync on first load //
	// --------------------------------------------
	protected void sync() {
		XmlElement@ query = XmlElement(makeQuery(this, array<dictionary> = {}));
		const XmlElement@ doc = getComms().query(query);
		getComms().clearQueue();
		resetTimer();
	}


	// --------------------------------------------
	void setFactions(array<Faction@> factions) {
		m_factions = factions;
	}

	// --------------------------------------------
	array<Faction@> getFactions() {
		return m_factions;
	}

	// --------------------------------------------
	void setMapInfo(MapInfo@ info) {
		m_mapInfo = info;
	}

	// --------------------------------------------
	// pos is an array of 3 elements, x,y,z
	string getRegion(Vector3@ pos) {
		return Metagame::getRegion(pos);
	}

}