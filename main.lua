
local Main = GDCLASS()

Main.extends = Node3D
Main.class_name = "Main"

function Main:_ready()
    print("My Roblox Studio is running!")

    -- Create the floor
    local floor = MeshInstance3D:new()
    local floor_mesh = BoxMesh:new()

    floor_mesh.size = Vector3(40, 1, 40)
    floor.mesh = floor_mesh
    floor.position = Vector3(0, -0.5, 0)

    self:add_child(floor)

    -- Create the first building block
    self:create_part(Vector3(0, 1, 0))

    -- Create camera
    local camera = Camera3D:new()

    camera.position = Vector3(10, 10, 10)
    camera:look_at(Vector3(0, 0, 0), Vector3.UP)
    camera.current = true

    self:add_child(camera)

    -- Create sunlight
    local light = DirectionalLight3D:new()

    light.rotation_degrees = Vector3(-45, 45, 0)

    self:add_child(light)
end

function Main:create_part(part_position)
    local part = MeshInstance3D:new()
    local mesh = BoxMesh:new()

    mesh.size = Vector3(2, 2, 2)
    part.mesh = mesh
    part.position = part_position

    self:add_child(part)

    print("Part created!")
end

return Main
