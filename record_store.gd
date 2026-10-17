extends RefCounted

var path: String


func _init(save_path: String) -> void:
	path = save_path


func load_score() -> int:
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Não foi possível ler o recorde.")
		return 0
	var value := file.get_as_text().strip_edges()
	if not value.is_valid_int():
		push_warning("Arquivo de recorde inválido; usando zero.")
		return 0
	return maxi(0, int(value))


func save_score(score: int) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar o recorde.")
		return false
	file.store_string(str(maxi(0, score)))
	file.flush()
	var succeeded := file.get_error() == OK
	file.close()
	if not succeeded:
		push_warning("Falha ao gravar o recorde.")
	return succeeded