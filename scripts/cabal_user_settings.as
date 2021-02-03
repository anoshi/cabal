#include "helpers.as"

// --------------------------------------------
class UserSettings {
	int m_difficulty = 0;
	int m_maxPlayers = 4;

	bool m_continue = false;
	bool m_continueAsNewCampaign = false;

	string m_savegame = "";
	string m_username = "unknown player";
	int m_factionChoice = 0;

	string m_baseCaptureSystem = "single"; // only one enemy base available for capture at any given time

	bool m_fov = false;
	bool m_friendlyFire = false;

	float m_fellowCapacityFactor = 0.99;
	float m_fellowAiAccuracyFactor = 0.95;
	float m_enemyCapacityFactor = 1.0;
	float m_enemyAiAccuracyFactor = 0.99;
	float m_xpFactor = 1.0;
	float m_rpFactor = 1.0;

	float m_initialXp = 0.0;
	int m_initialRp = 0;

	array<string> m_overlayPaths;

	// cabal mode
	string m_startServerCommand = "";

	// // --------------------------------------------
	// UserSettings() {
	// }

	// --------------------------------------------
	void readSettings(const XmlElement@ settings) {
		if (settings.hasAttribute("continue")) {
			m_continue = settings.getBoolAttribute("continue");

		} else {
			m_savegame = settings.getStringAttribute("savegame");
			m_username = settings.getStringAttribute("username");

			if (settings.hasAttribute("difficulty")) {
				m_difficulty = settings.getIntAttribute("difficulty");
			}
			m_baseCaptureSystem = "single";

			if (m_difficulty == 0) {
				// Recruit
				m_fellowCapacityFactor = 1.0;
				m_fellowAiAccuracyFactor = 0.95;
				m_enemyCapacityFactor = 1.0;
				m_enemyAiAccuracyFactor = 0.96;
				m_xpFactor = 1.0;
				m_rpFactor = 1.0;
				m_fov = false;
			} else if (m_difficulty == 1) {
				// Professional
				m_fellowCapacityFactor = 1.0;
				m_fellowAiAccuracyFactor = 0.95;
				m_enemyCapacityFactor = 1.0;
				m_enemyAiAccuracyFactor = 0.98;
				m_xpFactor = 1.0;
				m_rpFactor = 1.0;
				m_fov = false;
			} else if (m_difficulty == 2) {
				// Veteran
				m_fellowCapacityFactor = 0.99;
				m_fellowAiAccuracyFactor = 0.95;
				m_enemyCapacityFactor = 1.0;
				m_enemyAiAccuracyFactor = 0.99;
				m_xpFactor = 1.0;
				m_rpFactor = 1.0;
				m_fov = false;
			}
			if (settings.hasAttribute("continue_as_new_campaign") && settings.getIntAttribute("continue_as_new_campaign") != 0) {
				m_continueAsNewCampaign = true;
			}
		}
	}

	// --------------------------------------------
	XmlElement@ toXmlElement(string name) const {
		XmlElement settings(name);

		settings.setStringAttribute("savegame", m_savegame);
		settings.setStringAttribute("username", m_username);
		settings.setIntAttribute("difficulty", m_difficulty);

		return settings;
	}

	// --------------------------------------------
	void print() const {
		_log("** CABAL: using savegame name: " + m_savegame);
		_log("** CABAL: using username: " + m_username);
		_log("** CABAL: using difficulty: " + m_difficulty);
		_log("** CABAL: using fov: " + m_fov);
		_log("** CABAL: using faction choice: " + m_factionChoice);

		// we can use this to provide difficulty settings, user faction, etc
		_log("** CABAL: using fellow capacity: " + m_fellowCapacityFactor);
		_log("** CABAL: using fellow ai accuracy: " + m_fellowAiAccuracyFactor);
		// _log(" ** CABAL: using fellow ai reduction: " + m_playerAiReduction);
		_log("** CABAL: using enemy capacity: " + m_enemyCapacityFactor);
		_log("** CABAL: using enemy ai accuracy: " + m_enemyAiAccuracyFactor);
		_log("** CABAL: using xp factor: " + m_xpFactor);
		_log("** CABAL: using rp factor: " + m_rpFactor);

		_log("** CABAL: using initial xp: " + m_initialXp);
		_log("** CABAL: using initial rp: " + m_initialRp);
	}
}
