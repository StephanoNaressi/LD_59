extends RefCounted
class_name AudioLevels

#region ambient
const AMBIENT_VOLUME_DB: float = -20.0
#endregion

#region sfx
const SFX_DEFAULT_VOLUME_DB: float = -14.0
const SFX_PEW_VOLUME_DB: float = -40.0
const SFX_BREAK_VOLUME_DB: float = -10.0
const SFX_REPAIR_COMPLETE_VOLUME_DB: float = -12.0
#endregion

#region engine
const SHIP_ENGINE_OFF_DB: float = -80.0
const SHIP_ENGINE_MIN_DB: float = -50.0
const SHIP_ENGINE_MAX_DB: float = -45.0
const SHIP_ENGINE_MAX_DISTANCE: float = 900.0
const SHIP_ENGINE_UNIT_SIZE: float = 80.0
#endregion

#region radio
const RADIO_PING_DB: float = -26.0
const RADIO_PING_ECHO_QUIETER_DB: float = 3.0
const RADIO_STATIC_FAR_DB: float = -80.0
const RADIO_STATIC_NEAR_DB: float = -46.0
#endregion

#region broadcast
const ANTENNA_BROADCAST_VOLUME_DB: float = -22.0
#endregion
