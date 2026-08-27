# Not in the original, which had no sound options at all: Slick's only volume
# control was the desktop mixer, and the port inherited that.
#
# Everything used to play on Master, which is why pausing the game -- the one
# thing that ever silenced anything -- muted the effects along with the music.
# Music and effects have a bus each now, both routed to Master, so the three
# controls are three separate things: mute one bus, mute the other, set the
# gain on the bus they both feed.
class_name AudioSettings
extends RefCounted

const SAVE_PATH := "user://audio.cfg"

const MASTER_BUS := &"Master"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"Sfx"

const VOLUME_STEP := 10
const VOLUME_MAX := 100

var music_on := true
var sound_on := true
var volume := 70          # percent of linear gain on Master, in steps of ten

# Pause silences the music without touching the preference, so that resuming
# does not turn the music back on for someone who switched it off.
var music_paused := false


# A project with no bus layout has only Master. The two buses are added here
# rather than shipped as a .tres so that their names live in the same file as
# the code that mutes them; call it before anything loads a stream, because a
# player assigned to a bus that does not exist falls back to Master.
static func install_buses() -> void:
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, MASTER_BUS)


func apply() -> void:
	_mute(MUSIC_BUS, not music_on or music_paused)
	_mute(SFX_BUS, not sound_on)

	var master := AudioServer.get_bus_index(MASTER_BUS)
	if master < 0:
		return
	# linear_to_db(0) is -inf. Silence is a mute instead, so that the mixer
	# never carries a value that reads as broken.
	AudioServer.set_bus_mute(master, volume <= 0)
	AudioServer.set_bus_volume_db(master,
		linear_to_db(maxf(float(volume) / float(VOLUME_MAX), 0.0001)))


# Wraps at the top: the menu has no left and right, every entry is picked the
# same way, so the only way round is to come back to where it started.
func step_volume() -> void:
	volume += VOLUME_STEP
	if volume > VOLUME_MAX:
		volume = 0
	apply()


func _mute(bus: StringName, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, muted)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sound", sound_on)
	cfg.set_value("audio", "volume", volume)
	cfg.save(SAVE_PATH)


func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	music_on = cfg.get_value("audio", "music", music_on)
	sound_on = cfg.get_value("audio", "sound", sound_on)
	volume = clampi(int(cfg.get_value("audio", "volume", volume)), 0, VOLUME_MAX)
	volume -= volume % VOLUME_STEP
