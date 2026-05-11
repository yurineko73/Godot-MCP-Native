@tool
extends VBoxContainer

var _plugin: EditorPlugin = null
var _server_core: RefCounted = null

var _status_label: Label = null
var _start_button: Button = null
var _stop_button: Button = null
var _auto_start_check: CheckBox = null
var _log_level_option: OptionButton = null
var _security_level_option: OptionButton = null
var _log_text_edit: TextEdit = null
var _tools_list_container: VBoxContainer = null
var _tools_count_label: Label = null

var _transport_mode_option: OptionButton = null
var _http_config_container: VBoxContainer = null
var _http_port_spin: SpinBox = null
var _auth_enabled_check: CheckBox = null
var _auth_token_edit: LineEdit = null
var _sse_enabled_check: CheckBox = null
var _allow_remote_check: CheckBox = null
var _cors_origin_edit: LineEdit = null
var _rate_limit_spin: SpinBox = null
var _connection_info_label: Label = null

var _tab_container: TabContainer = null

func _ready() -> void:
	_create_ui()

func _exit_tree() -> void:
	pass

func set_plugin(plugin: EditorPlugin) -> void:
	_plugin = plugin
	if _plugin and _plugin.has_method("get_native_server"):
		_server_core = _plugin.get_native_server()
	_update_ui_state()
	_refresh_tools_list()

func set_server_core(server_core: RefCounted) -> void:
	_server_core = server_core
	_update_ui_state()
	_refresh_tools_list()

func _create_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	add_child(_create_status_bar())

	_tab_container = TabContainer.new()
	_tab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_tab_container)

	var settings_tab: VBoxContainer = _create_settings_tab()
	var log_tab: VBoxContainer = _create_log_tab()
	var tools_tab: VBoxContainer = _create_tools_tab()

	_tab_container.add_child(settings_tab)
	_tab_container.add_child(log_tab)
	_tab_container.add_child(tools_tab)

	_tab_container.set_tab_title(0, "Settings")
	_tab_container.set_tab_title(1, "Server Log")
	_tab_container.set_tab_title(2, "Tool Manager")

	_update_ui_state()
	_refresh_tools_list()

func _create_status_bar() -> HBoxContainer:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	_status_label = Label.new()
	_status_label.text = "Status: Unknown"
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.add_child(_status_label)

	_connection_info_label = Label.new()
	_connection_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_connection_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connection_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_connection_info_label)

	_start_button = Button.new()
	_start_button.text = "Start Server"
	_start_button.pressed.connect(_on_start_pressed)
	bar.add_child(_start_button)

	_stop_button = Button.new()
	_stop_button.text = "Stop Server"
	_stop_button.pressed.connect(_on_stop_pressed)
	bar.add_child(_stop_button)

	return bar

func _create_settings_tab() -> VBoxContainer:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_constant_override("separation", 4)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var transport_title: Label = Label.new()
	transport_title.text = "Настройки транспорта:"
	transport_title.add_theme_font_size_override("font_size", 13)
	content.add_child(transport_title)

	var transport_hbox: HBoxContainer = HBoxContainer.new()
	content.add_child(transport_hbox)

	var transport_label: Label = Label.new()
	transport_label.text = "Режим транспорта:"
	transport_hbox.add_child(transport_label)

	_transport_mode_option = OptionButton.new()
	_transport_mode_option.add_item("http", 1)
	_transport_mode_option.item_selected.connect(_on_transport_mode_selected)
	transport_hbox.add_child(_transport_mode_option)

	_http_config_container = VBoxContainer.new()
	_http_config_container.add_theme_constant_override("separation", 4)
	content.add_child(_http_config_container)

	var port_hbox: HBoxContainer = HBoxContainer.new()
	_http_config_container.add_child(port_hbox)

	var port_label: Label = Label.new()
	port_label.text = "Порт:"
	port_hbox.add_child(port_label)

	_http_port_spin = SpinBox.new()
	_http_port_spin.min_value = 1024
	_http_port_spin.max_value = 65535
	_http_port_spin.value = 9080
	_http_port_spin.step = 1
	_http_port_spin.value_changed.connect(_on_http_port_changed)
	port_hbox.add_child(_http_port_spin)

	var auth_hbox: HBoxContainer = HBoxContainer.new()
	_http_config_container.add_child(auth_hbox)

	_auth_enabled_check = CheckBox.new()
	_auth_enabled_check.text = "Включить аутентификацию"
	_auth_enabled_check.toggled.connect(_on_auth_enabled_toggled)
	auth_hbox.add_child(_auth_enabled_check)

	var token_label: Label = Label.new()
	token_label.text = "Token:"
	auth_hbox.add_child(token_label)

	_auth_token_edit = LineEdit.new()
	_auth_token_edit.secret = true
	_auth_token_edit.placeholder_text = "Введите токен аутентификации"
	_auth_token_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_token_edit.text_changed.connect(_on_auth_token_changed)
	auth_hbox.add_child(_auth_token_edit)

	_sse_enabled_check = CheckBox.new()
	_sse_enabled_check.text = "Включить SSE"
	_sse_enabled_check.toggled.connect(_on_sse_enabled_toggled)
	_http_config_container.add_child(_sse_enabled_check)

	_allow_remote_check = CheckBox.new()
	_allow_remote_check.text = "Разрешить удаленный доступ"
	_allow_remote_check.toggled.connect(_on_allow_remote_toggled)
	_http_config_container.add_child(_allow_remote_check)

	var cors_hbox: HBoxContainer = HBoxContainer.new()
	_http_config_container.add_child(cors_hbox)

	var cors_label: Label = Label.new()
	cors_label.text = "Источник CORS:"
	cors_hbox.add_child(cors_label)

	_cors_origin_edit = LineEdit.new()
	_cors_origin_edit.text = "*"
	_cors_origin_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cors_origin_edit.text_changed.connect(_on_cors_origin_changed)
	cors_hbox.add_child(_cors_origin_edit)

	_http_config_container.visible = false

	content.add_child(HSeparator.new())

	_auto_start_check = CheckBox.new()
	_auto_start_check.text = "Auto Start"
	_auto_start_check.toggled.connect(_on_auto_start_toggled)
	content.add_child(_auto_start_check)

	var log_hbox: HBoxContainer = HBoxContainer.new()
	content.add_child(log_hbox)

	var log_label: Label = Label.new()
	log_label.text = "Log Level:"
	log_hbox.add_child(log_label)

	_log_level_option = OptionButton.new()
	_log_level_option.add_item("ERROR", 0)
	_log_level_option.add_item("WARN", 1)
	_log_level_option.add_item("INFO", 2)
	_log_level_option.add_item("DEBUG", 3)
	_log_level_option.item_selected.connect(_on_log_level_selected)
	log_hbox.add_child(_log_level_option)

	var security_hbox: HBoxContainer = HBoxContainer.new()
	content.add_child(security_hbox)

	var security_label: Label = Label.new()
	security_label.text = "Security:"
	security_hbox.add_child(security_label)

	_security_level_option = OptionButton.new()
	_security_level_option.add_item("PERMISSIVE", 0)
	_security_level_option.add_item("STRICT", 1)
	_security_level_option.item_selected.connect(_on_security_level_selected)
	security_hbox.add_child(_security_level_option)

	var rate_hbox: HBoxContainer = HBoxContainer.new()
	content.add_child(rate_hbox)

	var rate_label: Label = Label.new()
	rate_label.text = "Rate Limit:"
	rate_hbox.add_child(rate_label)

	_rate_limit_spin = SpinBox.new()
	_rate_limit_spin.min_value = 10
	_rate_limit_spin.max_value = 1000
	_rate_limit_spin.step = 10
	_rate_limit_spin.value = 100
	_rate_limit_spin.value_changed.connect(_on_rate_limit_changed)
	rate_hbox.add_child(_rate_limit_spin)

	return tab

func _create_log_tab() -> VBoxContainer:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_constant_override("separation", 4)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	_log_text_edit = TextEdit.new()
	_log_text_edit.editable = false
	_log_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_log_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_log_text_edit)

	var clear_log_button: Button = Button.new()
	clear_log_button.text = "Clear Log"
	clear_log_button.pressed.connect(_on_clear_log_pressed)
	clear_log_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	content.add_child(clear_log_button)

	return tab

func _create_tools_tab() -> VBoxContainer:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_constant_override("separation", 4)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	var toolbar: HBoxContainer = HBoxContainer.new()
	content.add_child(toolbar)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh Tools"
	refresh_button.pressed.connect(_refresh_tools_list)
	toolbar.add_child(refresh_button)

	_tools_count_label = Label.new()
	_tools_count_label.text = "Tools: 0"
	_tools_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_tools_count_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(scroll)

	_tools_list_container = VBoxContainer.new()
	_tools_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tools_list_container)

	return tab

func _update_ui_state() -> void:
	if not _status_label:
		return

	var is_running: bool = false
	if _server_core and _server_core.has_method("is_running"):
		is_running = _server_core.is_running()

	if is_running:
		_status_label.text = "Status: Running"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_status_label.text = "Status: Stopped"
		_status_label.add_theme_color_override("font_color", Color.RED)

	if _start_button:
		_start_button.disabled = is_running
	if _stop_button:
		_stop_button.disabled = not is_running

	if _plugin:
		if _auto_start_check:
			_auto_start_check.button_pressed = _plugin.auto_start

		if _log_level_option:
			_log_level_option.select(_plugin.log_level)

		if _security_level_option:
			_security_level_option.select(_plugin.security_level)

		if _transport_mode_option:
			var mode: String = _plugin.transport_mode if _plugin.get("transport_mode") != null else "stdio"
			_transport_mode_option.selected = 0 if mode == "stdio" else 1
			_http_config_container.visible = (mode == "http")

		if _http_port_spin:
			_http_port_spin.value = _plugin.http_port if _plugin.get("http_port") != null else 9080

		if _auth_enabled_check:
			_auth_enabled_check.button_pressed = _plugin.auth_enabled if _plugin.get("auth_enabled") != null else false

		if _auth_token_edit:
			_auth_token_edit.text = _plugin.auth_token if _plugin.get("auth_token") != null else ""

		if _sse_enabled_check:
			_sse_enabled_check.button_pressed = _plugin.sse_enabled if _plugin.get("sse_enabled") != null else true

		if _allow_remote_check:
			_allow_remote_check.button_pressed = _plugin.allow_remote if _plugin.get("allow_remote") != null else false

		if _cors_origin_edit:
			_cors_origin_edit.text = _plugin.cors_origin if _plugin.get("cors_origin") != null else "*"

		if _rate_limit_spin:
			_rate_limit_spin.value = _plugin.rate_limit if _plugin.get("rate_limit") != null else 100

	if _transport_mode_option:
		_transport_mode_option.disabled = is_running

	if _http_config_container:
		_set_controls_disabled(_http_config_container, is_running)

	if _auth_token_edit:
		var auth_on: bool = _auth_enabled_check.button_pressed if _auth_enabled_check else false
		_auth_token_edit.editable = auth_on and not is_running

	if _connection_info_label:
		var mode: String = "stdio"
		if _plugin and _plugin.get("transport_mode") != null:
			mode = _plugin.transport_mode
		if mode == "http" and is_running:
			var port: int = 9080
			if _plugin and _plugin.get("http_port") != null:
				port = _plugin.http_port
			_connection_info_label.text = "URL: http://localhost:" + str(port) + "/mcp"
		elif mode == "stdio" and is_running:
			_connection_info_label.text = "Mode: stdio (via stdin/stdout)"
		else:
			_connection_info_label.text = ""

func _set_controls_disabled(container: Container, disabled: bool) -> void:
	for child in container.get_children():
		if child is SpinBox or child is LineEdit:
			child.editable = not disabled
		elif child is CheckBox or child is OptionButton or child is Button:
			child.disabled = disabled
		elif child is Container:
			_set_controls_disabled(child, disabled)

func _on_start_pressed() -> void:
	if not _plugin:
		return
	_plugin.start_server()
	await get_tree().process_frame
	_update_ui_state()

func _on_stop_pressed() -> void:
	if not _plugin:
		return
	_plugin.stop_server()
	await get_tree().process_frame
	_update_ui_state()

func _on_auto_start_toggled(button_pressed: bool) -> void:
	if _plugin:
		_plugin.auto_start = button_pressed

func _on_log_level_selected(index: int) -> void:
	if _plugin:
		_plugin.log_level = index

func _on_security_level_selected(index: int) -> void:
	if _plugin:
		_plugin.security_level = index

func _on_transport_mode_selected(index: int) -> void:
	var mode: String = _transport_mode_option.get_item_text(index)
	if _plugin:
		_plugin.transport_mode = mode
	_http_config_container.visible = (mode == "http")
	_update_ui_state()

func _on_http_port_changed(value: float) -> void:
	if _plugin:
		_plugin.http_port = int(value)

func _on_auth_enabled_toggled(enabled: bool) -> void:
	if _plugin:
		_plugin.auth_enabled = enabled
	if _auth_token_edit:
		_auth_token_edit.editable = enabled

func _on_auth_token_changed(text: String) -> void:
	if _plugin:
		_plugin.auth_token = text

func _on_sse_enabled_toggled(enabled: bool) -> void:
	if _plugin:
		_plugin.sse_enabled = enabled

func _on_allow_remote_toggled(enabled: bool) -> void:
	if _plugin:
		_plugin.allow_remote = enabled

func _on_cors_origin_changed(text: String) -> void:
	if _plugin:
		_plugin.cors_origin = text

func _on_rate_limit_changed(value: float) -> void:
	if _plugin:
		_plugin.rate_limit = int(value)

func _on_clear_log_pressed() -> void:
	clear_log()

func clear_log() -> void:
	if _log_text_edit:
		_log_text_edit.text = ""

func _refresh_tools_list() -> void:
	if not _tools_list_container:
		return

	var tools: Array = []
	if _server_core and _server_core.has_method("get_registered_tools"):
		tools = _server_core.get_registered_tools()

	var existing_tools: Dictionary = {}
	for child in _tools_list_container.get_children():
		var check: CheckBox = child.get_child(0) as CheckBox if child.get_child_count() > 0 else null
		if check:
			existing_tools[check.text] = check.button_pressed
		child.queue_free()

	var enabled_count: int = 0
	for tool_info in tools:
		var tool_name: String = tool_info.get("name", "Unknown")
		var is_enabled: bool = tool_info.get("enabled", true)
		if is_enabled:
			enabled_count += 1

		var tool_hbox: HBoxContainer = HBoxContainer.new()
		_tools_list_container.add_child(tool_hbox)

		var tool_check: CheckBox = CheckBox.new()
		tool_check.text = tool_name
		tool_check.button_pressed = is_enabled
		tool_check.toggled.connect(_on_tool_toggled.bind(tool_name))
		tool_hbox.add_child(tool_check)

		var desc_label: Label = Label.new()
		desc_label.text = tool_info.get("description", "")
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tool_hbox.add_child(desc_label)

	if _tools_count_label:
		_tools_count_label.text = "Enabled: %d / %d" % [enabled_count, tools.size()]

func _on_tool_toggled(button_pressed: bool, tool_name: String) -> void:
	if _server_core and _server_core.has_method("set_tool_enabled"):
		_server_core.set_tool_enabled(tool_name, button_pressed)
	_update_tools_count()

func _update_tools_count() -> void:
	if not _tools_count_label:
		return
	var tools: Array = []
	if _server_core and _server_core.has_method("get_registered_tools"):
		tools = _server_core.get_registered_tools()
	var enabled_count: int = 0
	for tool_info in tools:
		if tool_info.get("enabled", true):
			enabled_count += 1
	_tools_count_label.text = "Enabled: %d / %d" % [enabled_count, tools.size()]

func update_log(message: String) -> void:
	if not _log_text_edit:
		return
	if Thread.is_main_thread():
		_append_log(message)
	else:
		call_deferred("_append_log", message)

func _append_log(message: String) -> void:
	if not _log_text_edit:
		return
	_log_text_edit.text += message + "\n"
	_log_text_edit.scroll_vertical = _log_text_edit.get_line_count()

func refresh() -> void:
	if Thread.is_main_thread():
		_update_ui_state()
		_refresh_tools_list()
	else:
		call_deferred("_update_ui_state")
		call_deferred("_refresh_tools_list")
