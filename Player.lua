
-- Player.lua
-- Classic Polytoria-style player for Godot 4.5+
-- Requires Lua GDExtension (Lua 5.4)

local ClassicPlayer = GDCLASS("ClassicPlayer", "CharacterBody3D")

ClassicPlayer.extends = CharacterBody3D

-- Player settings
local WALK_SPEED = 7.0
local JUMP_FORCE = 7.0
local GRAVITY = 20.0
local MOUSE_SENSITIVITY = 0.003

-- Create a colored material
local function make_material(color)
    local material = StandardMaterial3D:new()
    material.albedo_color = color
    return material
end

-- Create a block body part
local function make_block(parent, part_name, size, position, material)
    local part = MeshInstance3D:new()
    part.name = part_name

    local mesh = BoxMesh:new()
    mesh.size = size

    part.mesh = mesh
    part.position = position
    part.material_override = material

    parent:add_child(part)

    return part
end

function ClassicPlayer:_ready()

    -- Visual character container
    self.visual_root = Node3D:new()
    self.visual_root.name = "VisualRoot"
    self:add_child(self.visual_root)

    -- Classic colors
    local yellow = make_material(Color(1.0, 0.8, 0.1))
    local blue = make_material(Color(0.1, 0.3, 0.9))
    local green = make_material(Color(0.1, 0.7, 0.2))

    -- Head
    make_block(
        self.visual_root,
        "Head",
        Vector3(0.85, 0.85, 0.85),
        Vector3(0, 2.35, 0),
        yellow
    )

    -- Torso
    make_block(
        self.visual_root,
        "Torso",
        Vector3(1.0, 1.15, 0.55),
        Vector3(0, 1.45, 0),
        blue
    )

    -- Left arm
    make_block(
        self.visual_root,
        "LeftArm",
        Vector3(0.36, 1.05, 0.4),
        Vector3(-0.68, 1.5, 0),
        yellow
    )

    -- Right arm
    make_block(
        self.visual_root,
        "RightArm",
        Vector3(0.36, 1.05, 0.4),
        Vector3(0.68, 1.5, 0),
        yellow
    )

    -- Left leg
    make_block(
        self.visual_root,
        "LeftLeg",
        Vector3(0.42, 1.0, 0.45),
        Vector3(-0.25, 0.5, 0),
        green
    )

    -- Right leg
    make_block(
        self.visual_root,
        "RightLeg",
        Vector3(0.42, 1.0, 0.45),
        Vector3(0.25, 0.5, 0),
        green
    )

    -- Character collision
    local collision = CollisionShape3D:new()
    collision.name = "PlayerCollision"

    local capsule = CapsuleShape3D:new()
    capsule.radius = 0.42
    capsule.height = 2.8

    collision.shape = capsule
    collision.position = Vector3(0, 1.4, 0)

    self:add_child(collision)

    -- Third-person camera pivot
    self.camera_pivot = Node3D:new()
    self.camera_pivot.name = "CameraPivot"
    self.camera_pivot.position = Vector3(0, 1.4, 0)

    self:add_child(self.camera_pivot)

    -- Camera
    self.camera = Camera3D:new()
    self.camera.name = "PlayerCamera"
    self.camera.position = Vector3(0, 1.2, 5.5)
    self.camera.rotation = Vector3(-0.18, 0, 0)
    self.camera.current = true

    self.camera_pivot:add_child(self.camera)

    -- Capture mouse for camera
    Input:set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    print("Classic Polytoria Player loaded!")

end

-- Player movement
function ClassicPlayer:_physics_process(delta)

    local input_vector = Input:get_vector(
        "move_left",
        "move_right",
        "move_forward",
        "move_backward"
    )

    -- Camera-relative movement
    local direction = Vector3(
        input_vector.x,
        0,
        input_vector.y
    )

    direction = direction:rotated(
        Vector3.UP,
        self.camera_pivot.rotation.y
    )

    if direction:length() > 0.01 then

        direction = direction:normalized()

        self.velocity.x = direction.x * WALK_SPEED
        self.velocity.z = direction.z * WALK_SPEED

        -- Turn the avatar toward movement
        self.visual_root.rotation.y = atan2(
            -direction.x,
            -direction.z
        )

    else

        self.velocity.x = 0
        self.velocity.z = 0

    end

    -- Gravity and jumping
    if not self:is_on_floor() then

        self.velocity.y = self.velocity.y - GRAVITY * delta

    elseif Input:is_action_just_pressed("jump") then

        self.velocity.y = JUMP_FORCE

    end

    -- Apply movement
    self:move_and_slide()

end

-- Third-person mouse camera
function ClassicPlayer:_input(event)

    if event:get_class() == "InputEventMouseMotion" then

        if Input:get_mouse_mode() == Input.MOUSE_MODE_CAPTURED then

            self.camera_pivot.rotation.y =
                self.camera_pivot.rotation.y
                - event.relative.x * MOUSE_SENSITIVITY

            local pitch =
                self.camera_pivot.rotation.x
                - event.relative.y * MOUSE_SENSITIVITY

            self.camera_pivot.rotation.x = clamp(
                pitch,
                -0.9,
                0.6
            )

        end

    elseif event:get_class() == "InputEventKey" then

        if event.pressed and event.keycode == KEY_ESCAPE then
            Input:set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        end

    elseif event:get_class() == "InputEventMouseButton" then

        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT then
            Input:set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        end

    end

end

return ClassicPlayer
