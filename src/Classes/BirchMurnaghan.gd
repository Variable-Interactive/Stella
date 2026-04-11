class_name BirchMurnaghan
extends RefCounted

# Volume will have units of a.u^3.
static func lattice_to_volume(lattice_const: float) -> float:
	return snappedf((pow(lattice_const, 3) * 6.748333037), 0.01)


static func evaluate(
	a: float, e0: float, a0: float, b0: float, b0_prime: float
) -> float:
	var V = lattice_to_volume(a)
	var V0 = lattice_to_volume(a0)
	var eta = pow(V0 / V, 2.0 / 3.0)
	var term1 = pow(eta - 1.0, 3.0) * b0_prime
	var term2 = pow(eta - 1.0, 2.0) * (6.0 - 4.0 * eta)
	return e0 + (9.0 * V0 * b0 / 16.0) * (term1 + term2)


static func generate_trial_data(
	a0: float,
	e0: float,
	b0: float,
	b0_prime: float,
	extents: float,
	primitive_cels: int,
	volume_as_x_axis := false
) -> String:
	var data := "{XAXIS}	ENERGY\n".format(
		{"XAXIS": "Volume (a.u³)" if volume_as_x_axis else "Lattice Constant (Å)"}
	)
	var step: float = 0.01
	var count = int(extents / step) + 1
	for i in range(-count, count):
		var lattice := (a0 + (float(i) * step))
		var vol := lattice_to_volume(lattice)
		if lattice <= 0:
			continue
		var energy := evaluate(lattice, e0, a0, b0, b0_prime)
		if energy < 0:
			data += "{XAXIS}	{energy}\n".format(
				{
					"XAXIS": (
						vol / primitive_cels if volume_as_x_axis
						else lattice / pow(primitive_cels, 1/3.0)
					),
					"energy": energy / primitive_cels
				}
			)
	return data


static func total_error(params: Array, latices: Array, energies: Array) -> float:
	var e0 = params[0]
	var a0 = params[1]
	var b0 = params[2]
	var b0p = params[3]
	var error = 0.0
	var bound_left = 0
	var bound_right = evaluate(Vector2i.MAX.x, e0, a0, b0, b0p)
	var min_energy = evaluate(a0, e0, a0, b0, b0p)
	for i in range(200):
		bound_left = evaluate(i / 100.0, e0, a0, b0, b0p)
		if not is_nan(bound_left):
			break
	if bound_left < min_energy or bound_right < min_energy:
		return INF
	for i in range(latices.size()):
		var predicted = evaluate(latices[i], e0, a0, b0, b0p)
		error += abs(predicted - energies[i])
	return error


static func fit_birch(
	latices: Array, energies: Array, itter: int, old_best_params := []
) -> Dictionary:
	const MIN_INCREMENT = 0.001
	var best_params = [
		energies.min(),                         # E0 guess
		latices[energies.find(energies.min())], # V0 guess
		1.0,                                    # B0 guess
		4.0                                     # B0p guess
	]
	var best_error := total_error(best_params, latices, energies)
	if not old_best_params.is_empty():
		# Remove invalid values if present in old_best_params
		old_best_params[1] = maxf(old_best_params[1], MIN_INCREMENT)
		old_best_params[2] = maxf(old_best_params[2], MIN_INCREMENT)
		old_best_params[3] = maxf(old_best_params[3], MIN_INCREMENT)
		var old_best_error := total_error(old_best_params, latices, energies)
		if old_best_error < best_error:
			best_params = old_best_params
			best_error = old_best_error
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	const MAX_PATIENCE = 10
	var patience := 0
	var jump_step := best_error
	for iter in range(itter):
		var trial = [
			best_params[0] + rng.randf_range(-jump_step, jump_step),
			best_params[1] + rng.randf_range(-jump_step, jump_step),
			best_params[2] + rng.randf_range(-jump_step, jump_step),
			best_params[3] + rng.randf_range(-jump_step, jump_step)
		]
		# Keep parameters physically reasonable
		if trial[1] <= 0 or trial[2] <= 0:
			continue
		var err = total_error(trial, latices, energies)
		if err < best_error:
			patience = 0
			best_error = err
			jump_step = best_error
			best_params = trial
		else:
			patience += 1
			if patience >= MAX_PATIENCE:
				jump_step = clampf(jump_step - MIN_INCREMENT, MIN_INCREMENT, 0.5)
				patience = 0
	return {
		"ground_energy": best_params[0],
		"optimum_lattice": best_params[1],
		"bulk_modulo": best_params[2],
		"bulk_modulo_prime": best_params[3],
		"total_error": best_error
	}
