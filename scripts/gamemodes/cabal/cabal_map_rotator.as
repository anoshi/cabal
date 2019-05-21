#include "map_rotator_invasion.as"
// --------------------------------------------

class CabalMapRotator : MapRotatorInvasion {
	// --------------------------------------------
	CabalMapRotator(GameModeInvasion@ metagame) {
		super(metagame);

		setLoop(false);
	}

	// --------------------------------------------
	void startRotation(bool beginOnly = false) {
		MapRotatorInvasion::startRotation(beginOnly);

		if (beginOnly) {
			if (isStageCompleted(m_currentStageIndex)) {
				readyToAdvance();
			}
		}
	}

	// --------------------------------------------
	protected bool checkForCampaignCompletion() const {
		bool allStagesComplete = true;
		for (uint i = 0; i < m_stages.size(); ++i) {
			Stage@ stage = m_stages[i];
			if (!isStageCompleted(i)) {
				allStagesComplete = false;
				break;
			}
		}
		return allStagesComplete;
	}

	// --------------------------------------------
	protected void announceMapAdvance(int index) {
		// no commander map advance chat in Cabal
	}

	// --------------------------------------------
	protected void readyToAdvance() {
		if (checkForCampaignCompletion()) {
			m_metagame.getComms().send("<command class='set_campaign_status' key='default' />");
		} else {
			MapRotatorInvasion::readyToAdvance();
		}
	}

	// --------------------------------------------
	protected int getStageIndexFromMapPath(string path) const {
		int result = -1;
		for (uint i = 0; i < m_stages.size(); ++i) {
			Stage@ stage = m_stages[i];
			if (stage.m_mapInfo.m_path == path) {
				result = int(i);
				break;
			}
		}
		return result;
	}

	// --------------------------------------------
	void load(const XmlElement@ root) {
		MapRotatorInvasion::load(root);

		const XmlElement@ subroot = root.getFirstElementByTagName("map_rotator");
		if (subroot !is null) {
			{
				string mapPath = m_metagame.m_gameMapPath;
				int index = getStageIndexFromMapPath(mapPath);
				if (index < 0) {
					_log("ERROR, couldn't resolve stage index from map path, mapPath=" + mapPath);
					index = 0;
				}
				m_nextStageIndex = index;
				m_currentStageIndex = m_nextStageIndex;
				_log("current/next stage at load: " + m_currentStageIndex);
			}
		}
	}
}
