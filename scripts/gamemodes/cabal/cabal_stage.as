#include "stage_invasion.as"

// --------------------------------------------
class CabalStage : Stage {
	bool m_clearProfiles;

	// --------------------------------------------
	CabalStage(const UserSettings@ userSettings) {
		super(userSettings);

		m_clearProfiles = false;

		m_includeLayers.clear();
		m_includeLayers.insertLast("bases.default");
		m_includeLayers.insertLast("layer1.default");
		m_includeLayers.insertLast("layer2.default");
		m_includeLayers.insertLast("layer3.default");
	}

	// --------------------------------------------
	protected void appendResources(XmlElement@ mapConfig) const {
		{ XmlElement e("weapon");		e.setStringAttribute("file", "all_weapons.xml"); mapConfig.appendChild(e); }
		{ XmlElement e("projectile");	e.setStringAttribute("file", "all_throwables.xml"); mapConfig.appendChild(e); }
		{ XmlElement e("carry_item");	e.setStringAttribute("file", "all_carry_items.xml"); mapConfig.appendChild(e); }
		{ XmlElement e("call");			e.setStringAttribute("file", "all_calls.xml"); mapConfig.appendChild(e); }
		{ XmlElement e("vehicle");		e.setStringAttribute("file", "all_vehicles.xml"); mapConfig.appendChild(e); }

		const CabalUserSettings@ cabalSettings = cast<const CabalUserSettings>(m_userSettings);
		if (cabalSettings !is null) {
			if (cabalSettings.m_difficulty == 0) {
				{ XmlElement e("weapon");		e.setStringAttribute("file", "diff_0_rec_weapons.xml"); mapConfig.appendChild(e); }
			} else if (cabalSettings.m_difficulty == 1) {
				{ XmlElement e("weapon");		e.setStringAttribute("file", "diff_1_pro_weapons.xml"); mapConfig.appendChild(e); }
			} else if (cabalSettings.m_difficulty == 2) {
				{ XmlElement e("weapon");		e.setStringAttribute("file", "diff_2_vet_weapons.xml"); mapConfig.appendChild(e); }
			}
		}
	}

	// --------------------------------------------
	const XmlElement@ getStartGameCommand(GameModeInvasion@ metagame, float completionPercentage = 0.5) const {
		XmlElement command(Stage::getStartGameCommand(metagame, completionPercentage).toDictionary());

		command.setBoolAttribute("lose_last_base_without_spawnpoints", false);
		command.setBoolAttribute("randomize_base_owner_faction_index", false);

		command.setIntAttribute("clear_profiles_at_start", m_clearProfiles ? 1 : -1);
		command.setBoolAttribute("ensure_alive_local_player_for_save", true);

		return command;
	}
}
