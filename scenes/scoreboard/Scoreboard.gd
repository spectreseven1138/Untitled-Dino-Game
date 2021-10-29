extends PanelContainer

const PLAYERS_TO_TRACK: int = 10

onready var score_container: VBoxContainer = $MarginContainer/ScoreContainer
onready var score_template: Control = $MarginContainer/ScoreContainer/Score

var score_nodes: Array = []
var game: Game
var tracked_players: Dictionary = {}

func _input(event: InputEvent):
	if event.is_action_pressed("toggle_scoreboard"):
		visible = !visible

func init(_game: Game):
	game = _game
	game.connect("player_joined", self, "_on_player_joined")
	game.connect("player_left", self, "_on_player_left")

func _ready():
	score_template.get_parent().remove_child(score_template)
	
	for i in PLAYERS_TO_TRACK:
		var score: Control = score_template.duplicate()
		score.get_node("Rank").text = str(i + 1).pad_zeros(len(str(PLAYERS_TO_TRACK))) + ": "
		score.visible = false
		score_nodes.append(score)
		score_container.add_child(score)

func _on_player_joined(player: Player):
	if len(tracked_players) >= PLAYERS_TO_TRACK:
		return
	var score: Control = score_nodes[len(tracked_players)]
	tracked_players[player] = score
	player.connect("distance_travelled_changed", self, "_on_player_distance_travelled_changed")
	score.get_node("HSplitContainer/Score").text = "0k"
	
	if not player.is_network_master():
		yield(player, "puppet_initialised")
	
	score.get_node("HSplitContainer/Username").text = player.username
	score.visible = true

func _on_player_left(player: Player):
	if not player in tracked_players:
		return
	tracked_players.erase(player)
	
	for score in score_nodes:
		score.visible = false
	
	for i in len(tracked_players):
		tracked_players[tracked_players.keys()[i]] = score_nodes[i]
		score_nodes[i].visible = true
	
	player.disconnect("distance_travelled_changed", self, "_on_player_distance_travelled_changed")

func _on_player_distance_travelled_changed(distance_travelled: float, player: Player):
	var score: Control = tracked_players[player]
	score.get_node("HSplitContainer/Score").text = str(distance_travelled / 1000.0).pad_decimals(2) + "k"
