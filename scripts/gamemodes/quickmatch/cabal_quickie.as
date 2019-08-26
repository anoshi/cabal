// internal
#include "gamemode.as"
#include "user_settings.as"
#include "log.as"
#include "announce_task.as"
#include "query_helpers.as"

// generic trackers
//#include "basic_command_handler.as"
//#include "autosaver.as"

// cabal helpers
#include "cabal_helpers.as"

// cabal trackers
#include "resource_lifecycle_handler.as"
#include "cabal_spawner.as"

// --------------------------------------------
class Cabal : GameMode {
	protected UserSettings@ m_userSettings;
	protected ResourceLifecycleHandler@ m_resourceLifecycleHandler;

	string m_gameMapPath = "";

	// --------------------------------------------
	Cabal(UserSettings@ settings) {
		super(settings.m_startServerCommand); // this is passing the string 'm_startServerCommand'
		@m_userSettings = @settings;
	}

	// --------------------------------------------
	void init() {
		GameMode::init();

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

		// add local player as admin for easy testing, hacks, etc
		if (!getAdminManager().isAdmin(getUserSettings().m_username)) {
			getAdminManager().addAdmin(getUserSettings().m_username);
		}
	}

	// --------------------------------------------
	void uninit() {
		save();
		GameMode::uninit();
	}

	// --------------------------------------------
	protected void startMatch() {
		// TODO: derive and implement
	}

	// --------------------------------------------
	void postBeginMatch() {
		GameMode::postBeginMatch();

		updateGeneralInfo();

		//addTracker(BasicCommandHandler(this));

		// Cabal handlers
		addTracker(m_resourceLifecycleHandler);
		addTracker(CabalSpawner(this));

		getUserSettings();
	}

	// --------------------------------------------
	protected void updateGeneralInfo() {
		const XmlElement@ general = getGeneralInfo(this);
		if (general !is null) {
			m_gameMapPath = general.getStringAttribute("map");
		}
	}

	// --------------------------------------------
	const UserSettings@ getUserSettings() const {
		return m_userSettings;
	}

	// --------------------------------------------
	void save() {
		_log("** CABAL: (quickmatch) saving metagame", 1);

		XmlElement commandRoot("command");
		commandRoot.setStringAttribute("class", "save_data");

		XmlElement root("saved_metagame");
		XmlElement@ settings = m_userSettings.toXmlElement("settings");
		root.appendChild(settings);

		// append quickmatch data
		m_resourceLifecycleHandler.save(root);

		commandRoot.appendChild(root);

		// save through game
		getComms().send(commandRoot);
		_log("** CABAL: finished saving quickmatch settings and player data", 1);
	}

	// --------------------------------------------
	void load() {
		_log("** CABAL: (quickmatch) loading metagame", 1);

		XmlElement@ query = XmlElement(
			makeQuery(this, array<dictionary> = {
				dictionary = { {"TagName", "data"}, {"class", "saved_data"} } }));
		const XmlElement@ doc = getComms().query(query);

		if (doc !is null) {
			const XmlElement@ root = doc.getFirstChild();
			const XmlElement@ settings = root.getFirstElementByTagName("settings");
			if (settings !is null) {
				m_userSettings.fromXmlElement(settings);
				// set continue false now, so that complete restart (::init)
				// will properly execute start rather than load
				m_userSettings.m_continue = false;
			}

			m_userSettings.print();

			// load saved quickmatch data
			m_resourceLifecycleHandler.load(root);
			_log("loaded", 1);
		} else {
			_log("load failed");
		}
	}

	// --------------------------------------------
	protected void sync() {
		XmlElement@ query = XmlElement(makeQuery(this, array<dictionary> = {}));
		const XmlElement@ doc = getComms().query(query);
		getComms().clearQueue();
		resetTimer();
	}

	// --------------------------------------------
	const XmlElement@ queryLocalPlayer() const {
		array<const XmlElement@> players = getGenericObjectList(this, "players", "player");
		const XmlElement@ player = null;
		const XmlElement@ info = players[0];
		@player = @info;
		/*for (uint i = 0; i < players.size(); ++i) {
			const XmlElement@ info = players[i];

			string name = info.getStringAttribute("name");

			_log("player: " + name + ", target player is " + getUserSettings().m_username);
			if (name == m_userSettings.m_username) {
				_log("ok");
				@player = @info;
				break;
			} else {
				_log("no match");
			}
		}*/
		return player;
	}

	void setMapInfo(const MapInfo@ info) {
		m_mapInfo = info;
	}
}