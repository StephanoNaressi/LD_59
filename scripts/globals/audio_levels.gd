extends RefCounted
class_name AudioLevels

#region Ambient
const AMBIENT_VOLUME_DB: float = -20.0
#endregion

#region SFX
const SFX_DEFAULT_VOLUME_DB: float = -14.0
const SFX_PEW_VOLUME_DB: float = -30.0
const SFX_BREAK_VOLUME_DB: float = -13.0
const SFX_REPAIR_COMPLETE_VOLUME_DB: float = -12.0
#endregion

#region Ship engine
const SHIP_ENGINE_OFF_DB: float = -80.0
const SHIP_ENGINE_MIN_DB: float = -50.0
const SHIP_ENGINE_MAX_DB: float = -45.0
const SHIP_ENGINE_MAX_DISTANCE: float = 900.0
const SHIP_ENGINE_UNIT_SIZE: float = 80.0
#endregion

#region Radio (ship — only volumes, all in dB)
const RADIO_PING_DB: float = -15.0
const RADIO_PING_ECHO_QUIETER_DB: float = -30.0
const RADIO_STATIC_FAR_DB: float = -80.0
const RADIO_STATIC_NEAR_DB: float = -40.0
#endregion

#region Tower broadcast
const TOWER_MUSIC_VOLUME_DB: float = -8.0
#endregion
