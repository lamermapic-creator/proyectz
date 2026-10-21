class_name Rbx
## Equivalencias de la API de Roblox (CFrame, Vector3, utilidades de AnimShared) para portar
## el código 1:1. Unidades: studs (1 stud ~ 0.31 m). Roblox y Godot usan los dos ejes Y arriba,
## -Z hacia delante y mano derecha, así que los CFrame se traducen directamente a Transform3D.

const XAXIS := Vector3(1, 0, 0)
const YAXIS := Vector3(0, 1, 0)
const ZAXIS := Vector3(0, 0, 1)


## CFrame.new(x, y, z)
static func cf(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


## CFrame.new(pos)
static func cfp(p: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p)


## CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz
static func ang(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(angb(x, y, z), Vector3.ZERO)


static func angb(x: float, y: float, z: float) -> Basis:
	return Basis(XAXIS, x) * Basis(YAXIS, y) * Basis(ZAXIS, z)


## CFrame.fromMatrix(pos, x, y, z)
static func from_matrix(p: Vector3, x: Vector3, y: Vector3, z: Vector3) -> Transform3D:
	return Transform3D(Basis(x, y, z), p)


## CFrame.lookAt(pos, target)
static func look_at(p: Vector3, target: Vector3, up: Vector3 = YAXIS) -> Transform3D:
	var d := target - p
	if d.length() < 1e-6:
		return cfp(p)
	if absf(d.normalized().dot(up)) > 0.999:
		up = ZAXIS
	return Transform3D(Basis.looking_at(d, up), p)


## CFrame.fromAxisAngle
static func axis_angle(axis: Vector3, a: float) -> Transform3D:
	return Transform3D(Basis(axis.normalized(), a), Vector3.ZERO)


## cf - cf.Position (solo rotación)
static func rot(t: Transform3D) -> Transform3D:
	return Transform3D(t.basis, Vector3.ZERO)


## cf + v
static func add(t: Transform3D, v: Vector3) -> Transform3D:
	return Transform3D(t.basis, t.origin + v)


## CFrame:Lerp
static func lerp_cf(a: Transform3D, b: Transform3D, t: float) -> Transform3D:
	return a.interpolate_with(b, t)


static func look(t: Transform3D) -> Vector3:
	return -t.basis.z


static func right(t: Transform3D) -> Vector3:
	return t.basis.x


static func upv(t: Transform3D) -> Vector3:
	return t.basis.y


## cf:PointToObjectSpace(p)
static func to_obj(t: Transform3D, p: Vector3) -> Vector3:
	return t.affine_inverse() * p


## cf:VectorToObjectSpace(v)
static func vec_to_obj(t: Transform3D, v: Vector3) -> Vector3:
	return t.basis.inverse() * v


## yaw de cf:ToOrientation() (orden Y, X, Z como Roblox)
static func yaw_of(t: Transform3D) -> float:
	return t.basis.get_euler(EULER_ORDER_YXZ).y


static func unit(v: Vector3) -> Vector3:
	return v.normalized() if v.length() > 1e-9 else Vector3.ZERO


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


static func wrap_a(a: float) -> float:
	return fposmod(a + PI, TAU) - PI


static func sgn(x: float) -> float:
	return 1.0 if x > 0 else (-1.0 if x < 0 else 0.0)


## ---------------------------------------------------------------- AnimShared
static func damp(a: float, b: float, speed: float, dt: float) -> float:
	return a + (b - a) * (1.0 - exp(-speed * dt))


static func damp_v(a: Vector3, b: Vector3, speed: float, dt: float) -> Vector3:
	return a.lerp(b, 1.0 - exp(-speed * dt))


static func damp_cf(a: Transform3D, b: Transform3D, speed: float, dt: float) -> Transform3D:
	return a.interpolate_with(b, 1.0 - exp(-speed * dt))


static func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Curva por claves: [[t, valor], ...] (valor float, Vector3 o Transform3D)
static func sample(keys: Array, t: float):
	if t <= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		var k0: Array = keys[i]
		var k1: Array = keys[i + 1]
		if t <= k1[0]:
			var u := smooth((t - k0[0]) / maxf(1e-4, k1[0] - k0[0]))
			var a = k0[1]
			var b = k1[1]
			if a is Transform3D:
				return (a as Transform3D).interpolate_with(b, u)
			return a + (b - a) * u
	return keys[keys.size() - 1][1]


## Muelle amortiguado (frecuencia en Hz, zeta = amortiguación; 1 = crítico)
class Muelle:
	var x := 0.0
	var v := 0.0
	var target := 0.0
	var f := 4.0
	var z := 1.0

	func _init(freq: float = 4.0, zeta: float = 1.0, init: float = 0.0) -> void:
		f = freq
		z = zeta
		x = init
		target = init

	func step(dt: float) -> float:
		var w := f * TAU
		var steps := maxi(1, ceili(dt / (1.0 / 120.0)))
		var h := dt / steps
		for _i in steps:
			var a := -2.0 * z * w * v - w * w * (x - target)
			v += a * h
			x += v * h
		return x

	func impulse(dv: float) -> void:
		v += dv
