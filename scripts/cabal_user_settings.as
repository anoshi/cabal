#include "user_settings.as"

class CabalUserSettings : UserSettings {
	int m_difficulty = 0;
	bool m_permadeath = false;
	int m_maxPlayers = 2;

	// --------------------------------------------
	CabalUserSettings() {
		super();
	}

	// --------------------------------------------
	void fromXmlElement(const XmlElement@ settings) {
		if (settings.hasAttribute("continue")) {
			m_continue = settings.getBoolAttribute("continue");

		} else {
			m_savegame = settings.getStringAttribute("savegame");
			m_username = settings.getStringAttribute("username");
			m_difficulty = settings.getIntAttribute("difficulty");
			m_baseCaptureSystem = "single";

			if (m_difficulty == 0) {
				// Recruit
				m_fellowCapacityFactor = 0.99;
				m_fellowAiAccuracyFactor = 0.95;
				m_enemyCapacityFactor = 1.0;
				m_enemyAiAccuracyFactor = 0.94;
				m_xpFactor = 1.0;
				m_rpFactor = 1.0;
				m_fov = false;
				m_permadeath = false;
			} else if (m_difficulty == 1) {
				// Professional
				m_fellowCapacityFactor = 0.99;
				m_fellowAiAccuracyFactor = 0.95;
				m_enemyCapacityFactor = 1.0;
				m_enemyAiAccuracyFactor = 0.96;
				m_xpFactor = 1.0;
				m_rpFactor = 1.0;
				m_fov = false;
				m_permadeath = false;
			} else if (m_difficulty == 2) {
				// Veteran
				m_fellowCapacityFactor = 0.99;
				m_fellowAiAccuracyFactor = 0.95;
				m_enemyCapacityFactor = 1.0;
				m_enemyAiAccuracyFactor = 0.99;
				m_xpFactor = 1.0;
				m_rpFactor = 1.0;
				m_fov = false;
				m_permadeath = false;
			}
			if (settings.hasAttribute("continue_as_new_campaign") && settings.getIntAttribute("continue_as_new_campaign") != 0) {
				m_continueAsNewCampaign = true;
			}
		}
	}

	// --------------------------------------------
	XmlElement@ toXmlElement(string name) const {
		// NOTE, won't serialize continue keyword, it only works as input
		XmlElement settings(name);

		settings.setStringAttribute("savegame", m_savegame);
		settings.setStringAttribute("username", m_username);
		settings.setIntAttribute("difficulty", m_difficulty);

		return settings;
	}

	// --------------------------------------------
	void print() const {
		_log(" * using savegame name: " + m_savegame);
		_log(" * using username: " + m_username);
		_log(" * using difficulty: " + m_difficulty);
		_log(" * using fov: " + m_fov);
		_log(" * using faction choice: " + m_factionChoice);

		// we can use this to provide difficulty settings, user faction, etc
		_log(" * using fellow capacity: " + m_fellowCapacityFactor);
		_log(" * using fellow ai accuracy: " + m_fellowAiAccuracyFactor);
		_log(" * using enemy capacity: " + m_enemyCapacityFactor);
		_log(" * using enemy ai accuracy: " + m_enemyAiAccuracyFactor);
		_log(" * using xp factor: " + m_xpFactor);
		_log(" * using rp factor: " + m_rpFactor);

		_log(" * using initial xp: " + m_initialXp);
		_log(" * using initial rp: " + m_initialRp);
	}
}
