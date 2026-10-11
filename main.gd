extends Node3D

const ARENA_SIZE := 28.0
var player: CharacterBody3D
var camera: Camera3D
var gun: Node3D
var hp := 100.0
var ammo := 24
var reserve_ammo := 96
var kills := 0
var yaw := 0.0
var pitch := 0.0
var move_vector := Vector2.ZERO
var touch_points: Dictionary = {}
var look_touch := -1
var move_touch := -1
var last_look := Vector2.ZERO
var fire_held := false
var shoot_timer := 0.0
var dash_timer := 0.0
var shield_timer := 0.0
var hud: CanvasLayer
var hp_label: Label
var ammo_label: Label
var status_label: Label
var joystick_base: Control
var joystick_knob: ColorRect
var fire_button: Button
var shield_button: Button
var dash_button: Button
var reload_button: Button

func _ready() -> void:
    _build_world()
    _build_player()
    _build_bots()
    _build_hud()
    _update_hud()

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.025, 0.045, 0.075)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.45, 0.57, 0.7)
    environment.ambient_light_energy = 0.7
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)

    _make_box("Arena Floor", Vector3(0, -0.5, 0), Vector3(ARENA_SIZE, 1, ARENA_SIZE), Color(0.105, 0.14, 0.18), true)
    _make_box("North Wall", Vector3(0, 1.5, -ARENA_SIZE / 2), Vector3(ARENA_SIZE, 3, 0.6), Color(0.12, 0.23, 0.3), true)
    _make_box("South Wall", Vector3(0, 1.5, ARENA_SIZE / 2), Vector3(ARENA_SIZE, 3, 0.6), Color(0.12, 0.23, 0.3), true)
    _make_box("West Wall", Vector3(-ARENA_SIZE / 2, 1.5, 0), Vector3(0.6, 3, ARENA_SIZE), Color(0.12, 0.23, 0.3), true)
    _make_box("East Wall", Vector3(ARENA_SIZE / 2, 1.5, 0), Vector3(0.6, 3, ARENA_SIZE), Color(0.12, 0.23, 0.3), true)

    # Cover blocks, colored trims, and central objective structure.
    var cover_positions := [
        Vector3(-6, 0.7, -5), Vector3(5, 0.7, -6),
        Vector3(-5, 0.7, 5), Vector3(6, 0.7, 5),
        Vector3(0, 0.8, -9), Vector3(0, 0.8, 9),
        Vector3(-9, 0.8, 0), Vector3(9, 0.8, 0)
    ]
    for i in range(cover_positions.size()):
        var color := Color(0.12, 0.27, 0.34) if i % 2 == 0 else Color(0.23, 0.17, 0.23)
        _make_box("Cover %02d" % i, cover_positions[i], Vector3(2.8, 1.6, 1.2), color, true)
        _make_box("Cover Light %02d" % i, cover_positions[i] + Vector3(0, 0.72, 0), Vector3(2.6, 0.06, 1.05), Color(0.08, 0.72, 0.95) if i % 2 == 0 else Color(0.95, 0.16, 0.28), false)

    _make_box("Objective Plinth", Vector3(0, 0.35, 0), Vector3(3.5, 0.7, 3.5), Color(0.09, 0.13, 0.19), true)
    _make_box("Objective Core", Vector3(0, 1.3, 0), Vector3(0.7, 1.3, 0.7), Color(0.05, 0.72, 0.95), false)

    for x_pos in [-10.0, 10.0]:
        for z_pos in [-10.0, 10.0]:
            var light := OmniLight3D.new()
            light.position = Vector3(x_pos, 3.5, z_pos)
            light.light_color = Color(0.15, 0.68, 1.0) if x_pos < 0 else Color(1.0, 0.18, 0.3)
            light.light_energy = 1.5
            light.omni_range = 9.0
            add_child(light)

func _make_box(label_text: String, pos: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
    var root: Node3D
    if solid:
        var body := StaticBody3D.new()
        body.name = label_text
        root = body
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
    else:
        root = Node3D.new()
        root.name = label_text
    root.position = pos
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.35
    material.roughness = 0.42
    if color.b > 0.65 or color.r > 0.65:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 0.55
    mesh_instance.material_override = material
    root.add_child(mesh_instance)
    add_child(root)
    return root

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1.0, 10.5)
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    collider.shape = capsule
    player.add_child(collider)
    add_child(player)

    camera = Camera3D.new()
    camera.position = Vector3(0, 0.58, 0)
    camera.fov = 82
    camera.current = true
    player.add_child(camera)

    # Original low-poly VX-9 rifle built from 3D meshes; no external assets needed.
    gun = Node3D.new()
    gun.position = Vector3(0.32, -0.28, -0.62)
    camera.add_child(gun)
    _gun_box(Vector3(0, 0, 0), Vector3(0.19, 0.15, 0.48), Color(0.075, 0.095, 0.12))
    _gun_box(Vector3(0, 0.095, -0.04), Vector3(0.12, 0.06, 0.22), Color(0.19, 0.27, 0.33))
    _gun_box(Vector3(0, -0.12, 0.08), Vector3(0.095, 0.24, 0.13), Color(0.08, 0.11, 0.14))
    _gun_box(Vector3(0, 0.01, -0.37), Vector3(0.07, 0.07, 0.32), Color(0.035, 0.045, 0.06))
    _gun_box(Vector3(0, 0.12, -0.09), Vector3(0.08, 0.08, 0.1), Color(0.035, 0.045, 0.06))
    _gun_box(Vector3(0, 0.125, -0.09), Vector3(0.025, 0.018, 0.045), Color(0.1, 0.85, 1.0), true)
    _gun_box(Vector3(-0.08, -0.16, 0.16), Vector3(0.16, 0.14, 0.22), Color(0.23, 0.3, 0.34))

func _gun_box(pos: Vector3, size: Vector3, color: Color, glow := false) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.5
    material.roughness = 0.3
    if glow:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 2.0
    mesh_instance.material_override = material
    gun.add_child(mesh_instance)

func _build_bots() -> void:
    for i in range(5):
        var bot := CharacterBody3D.new()
        bot.name = "RiftBot_%02d" % (i + 1)
        bot.set_meta("hp", 100.0)
        bot.set_meta("respawn", 0.0)
        bot.position = Vector3(-7.0 + float(i) * 3.5, 0.9, -8.0)
        bot.add_to_group("bots")
        var collision := CollisionShape3D.new()
        var capsule := CapsuleShape3D.new()
        capsule.radius = 0.38
        capsule.height = 1.8
        collision.shape = capsule
        bot.add_child(collision)
        var mesh_instance := MeshInstance3D.new()
        var mesh := CapsuleMesh.new()
        mesh.radius = 0.38
        mesh.height = 1.8
        mesh_instance.mesh = mesh
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.95, 0.12, 0.23)
        mat.metallic = 0.2
        mat.roughness = 0.45
        mat.emission_enabled = true
        mat.emission = Color(0.45, 0.015, 0.04)
        mat.emission_energy_multiplier = 0.35
        mesh_instance.material_override = mat
        bot.add_child(mesh_instance)
        var visor := MeshInstance3D.new()
        var visor_mesh := BoxMesh.new()
        visor_mesh.size = Vector3(0.35, 0.1, 0.08)
        visor.mesh = visor_mesh
        visor.position = Vector3(0, 0.35, -0.33)
        var visor_mat := StandardMaterial3D.new()
        visor_mat.albedo_color = Color(0.15, 0.9, 1.0)
        visor_mat.emission_enabled = true
        visor_mat.emission = Color(0.1, 0.8, 1.0)
        visor.material_override = visor_mat
        bot.add_child(visor)
        add_child(bot)

func _build_hud() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var title := Label.new()
    title.text = "RIFTSTRIKE  //  TACTICAL FPS"
    title.position = Vector2(18, 12)
    title.add_theme_font_size_override("font_size", 18)
    title.add_theme_color_override("font_color", Color(0.5, 0.92, 1.0))
    hud.add_child(title)

    hp_label = Label.new()
    hp_label.position = Vector2(18, 42)
    hp_label.add_theme_font_size_override("font_size", 16)
    hud.add_child(hp_label)
    ammo_label = Label.new()
    ammo_label.anchor_left = 1.0
    ammo_label.anchor_right = 1.0
    ammo_label.offset_left = -220
    ammo_label.offset_right = -18
    ammo_label.offset_top = 16
    ammo_label.add_theme_font_size_override("font_size", 20)
    ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hud.add_child(ammo_label)

    status_label = Label.new()
    status_label.text = "BLUE TEAM  |  5v5 ARENA TEST  |  OFFLINE BOTS"
    status_label.anchor_left = 0.5
    status_label.anchor_right = 0.5
    status_label.offset_left = -200
    status_label.offset_right = 200
    status_label.offset_top = 15
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 13)
    status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
    hud.add_child(status_label)

    joystick_base = Control.new()
    joystick_base.position = Vector2(24, -164)
    joystick_base.anchor_top = 1.0
    joystick_base.anchor_bottom = 1.0
    joystick_base.custom_minimum_size = Vector2(128, 128)
    joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(joystick_base)
    var ring := ColorRect.new()
    ring.size = Vector2(128, 128)
    ring.color = Color(0.15, 0.42, 0.56, 0.38)
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_base.add_child(ring)
    joystick_knob = ColorRect.new()
    joystick_knob.position = Vector2(40, 40)
    joystick_knob.size = Vector2(48, 48)
    joystick_knob.color = Color(0.45, 0.85, 1.0, 0.8)
    joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_base.add_child(joystick_knob)

    fire_button = _make_button("FIRE", Vector2(-108, -112), Vector2(88, 88), Color(0.72, 0.12, 0.22))
    fire_button.anchor_left = 1.0
    fire_button.anchor_right = 1.0
    fire_button.anchor_top = 1.0
    fire_button.anchor_bottom = 1.0
    fire_button.button_down.connect(func(): fire_held = true)
    fire_button.button_up.connect(func(): fire_held = false)
    fire_button.pressed.connect(_shoot)

    reload_button = _make_button("RELOAD", Vector2(-210, -72), Vector2(70, 54), Color(0.12, 0.3, 0.42))
    reload_button.anchor_left = 1.0
    reload_button.anchor_right = 1.0
    reload_button.anchor_top = 1.0
    reload_button.anchor_bottom = 1.0
    reload_button.pressed.connect(_reload)

    dash_button = _make_button("DASH", Vector2(-210, -136), Vector2(62, 52), Color(0.12, 0.3, 0.42))
    dash_button.anchor_left = 1.0
    dash_button.anchor_right = 1.0
    dash_button.anchor_top = 1.0
    dash_button.anchor_bottom = 1.0
    dash_button.pressed.connect(func(): dash_timer = 0.22)

    shield_button = _make_button("PULSE", Vector2(-282, -72), Vector2(62, 54), Color(0.12, 0.3, 0.42))
    shield_button.anchor_left = 1.0
    shield_button.anchor_right = 1.0
    shield_button.anchor_top = 1.0
    shield_button.anchor_bottom = 1.0
    shield_button.pressed.connect(func(): shield_timer = 3.0)

func _make_button(text_value: String, pos: Vector2, size_value: Vector2, color_value: Color) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = pos
    button.size = size_value
    button.add_theme_font_size_override("font_size", 14)
    var style := StyleBoxFlat.new()
    style.bg_color = color_value
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.5, 0.85, 1.0, 0.8)
    button.add_theme_stylebox_override("normal", style)
    hud.add_child(button)
    return button

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_points[event.index] = event.position
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.42 and move_touch == -1:
                move_touch = event.index
                _update_joystick(event.position)
            elif look_touch == -1:
                look_touch = event.index
                last_look = event.position
        else:
            touch_points.erase(event.index)
            if event.index == move_touch:
                move_touch = -1
                move_vector = Vector2.ZERO
                joystick_knob.position = Vector2(40, 40)
            if event.index == look_touch:
                look_touch = -1
    elif event is InputEventScreenDrag:
        if event.index == move_touch:
            _update_joystick(event.position)
        elif event.index == look_touch:
            var delta: Vector2 = event.position - last_look
            yaw -= delta.x * 0.006
            pitch = clamp(pitch - delta.y * 0.004, -1.0, 1.0)
            last_look = event.position
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        yaw -= event.relative.x * 0.004
        pitch = clamp(pitch - event.relative.y * 0.004, -1.0, 1.0)
    elif event is InputEventKey and event.pressed:
        if event.keycode == KEY_R:
            _reload()
        elif event.keycode == KEY_SPACE:
            _shoot()
        elif event.keycode == KEY_Q:
            shield_timer = 3.0
        elif event.keycode == KEY_E:
            dash_timer = 0.22

func _update_joystick(pos: Vector2) -> void:
    var center := joystick_base.global_position + Vector2(64, 64)
    var delta := pos - center
    if delta.length() > 48.0:
        delta = delta.normalized() * 48.0
    move_vector = Vector2(delta.x / 48.0, delta.y / 48.0)
    joystick_knob.position = Vector2(40, 40) + delta

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    shoot_timer = maxf(0.0, shoot_timer - delta)
    dash_timer = maxf(0.0, dash_timer - delta)
    shield_timer = maxf(0.0, shield_timer - delta)
    var speed := 7.0 if dash_timer > 0.0 else 4.2
    var direction := (player.transform.basis * Vector3(move_vector.x, 0, move_vector.y)).normalized()
    player.velocity.x = direction.x * speed
    player.velocity.z = direction.z * speed
    player.velocity.y -= 18.0 * delta
    player.move_and_slide()
    player.rotation.y = yaw
    camera.rotation.x = pitch
    gun.position.y = -0.28 + sin(Time.get_ticks_msec() * 0.009) * 0.008
    if fire_held and shoot_timer <= 0.0:
        _shoot()
    _update_bots(delta)
    _update_hud()

func _update_bots(delta: float) -> void:
    for bot in get_tree().get_nodes_in_group("bots"):
        if not is_instance_valid(bot):
            continue
        var respawn: float = float(bot.get_meta("respawn", 0.0))
        if respawn > 0.0:
            respawn -= delta
            bot.set_meta("respawn", respawn)
            if respawn <= 0.0:
                bot.set_meta("hp", 100.0)
                bot.position = Vector3(randf_range(-8, 8), 0.9, randf_range(-10, -6))
                bot.visible = true
                bot.get_node("CollisionShape3D").set_deferred("disabled", false)
            continue
        var to_player: Vector3 = player.global_position - bot.global_position
        to_player.y = 0
        if to_player.length() > 3.5:
            var step: Vector3 = to_player.normalized() * delta * 1.1
            bot.position.x += step.x
            bot.position.z += step.z
        bot.look_at(Vector3(player.global_position.x, bot.global_position.y, player.global_position.z), Vector3.UP)

func _shoot() -> void:
    if shoot_timer > 0.0:
        return
    shoot_timer = 0.18
    if ammo <= 0:
        return
    ammo -= 1
    gun.position.z = -0.52
    var from := camera.global_position
    var to := from + (-camera.global_transform.basis.z * 70.0)
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [player.get_rid()]
    var result := get_world_3d().direct_space_state.intersect_ray(query)
    if not result.is_empty():
        var collider = result.get("collider")
        if collider is Node and collider.is_in_group("bots"):
            var new_hp := float(collider.get_meta("hp", 100.0)) - 34.0
            collider.set_meta("hp", new_hp)
            if new_hp <= 0:
                kills += 1
                collider.visible = false
                collider.get_node("CollisionShape3D").set_deferred("disabled", true)
                collider.set_meta("respawn", 3.0)
    _update_hud()

func _reload() -> void:
    if ammo < 24 and reserve_ammo > 0:
        var amount := mini(24 - ammo, reserve_ammo)
        ammo += amount
        reserve_ammo -= amount
    _update_hud()

func _update_hud() -> void:
    if is_instance_valid(hp_label):
        hp_label.text = "HP %03d   |   SHIELD %s" % [int(hp), "ACTIVE" if shield_timer > 0 else "READY"]
        ammo_label.text = "%02d  /  %03d" % [ammo, reserve_ammo]
        status_label.text = "RIFTSTRIKE  •  KILLS %02d  •  LOCAL BOT TEST" % kills
