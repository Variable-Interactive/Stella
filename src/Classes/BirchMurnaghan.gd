class_name BirchMurnaghan
extends RefCounted


static func evaluate(a: float, e0: float, a0: float, b0: float, b0_prime: float) -> float:
	var V = pow(a, 3)
	var V0 = pow(a0, 3)
	var eta = pow(V0 / V, 2.0 / 3.0)
	var term1 = pow(eta - 1.0, 3.0) * b0_prime
	var term2 = pow(eta - 1.0, 2.0) * (6.0 - 4.0 * eta)
	return e0 + (9.0 * V0 * b0 / 16.0) * (term1 + term2)


static func generate_trial_data(
	a0: float, e0: float, b0: float, b0_prime: float, extents: float, volume_as_x_axis := false
) -> String:
	var data := "{XAXIS}	ENERGY\n".format({"XAXIS": "Volume" if volume_as_x_axis else "LATTICE"})
	var step: float = 0.01
	var count = int(extents / step) + 1
	for i in range(-count, count):
		var lattice := a0 + (float(i) * step)
		var vol := pow(lattice, 3)
		if lattice <= 0:
			continue
		var energy := evaluate(lattice, e0, a0, b0, b0_prime)
		if energy < 0:
			data += "{XAXIS}	{energy}\n".format(
				{"XAXIS": vol if volume_as_x_axis else lattice, "energy": energy}
			)
	return data


static func total_error(params: Array, latices: Array, energies: Array) -> float:
	var e0 = params[0]
	var a0 = params[1]
	var b0 = params[2]
	var b0p = params[3]
	var error = 0.0
	var bound_left = evaluate(0.001, e0, a0, b0, b0p)
	var bound_right = evaluate(Vector2i.MAX.x, e0, a0, b0, b0p)
	var min_energy = evaluate(a0, e0, a0, b0, b0p)
	if bound_left < min_energy or bound_right < min_energy:
		error = INF
	for i in range(latices.size()):
		var predicted = evaluate(latices[i], e0, a0, b0, b0p)
		error += pow(predicted - energies[i], 2)
	return error


static func fit_birch(latices: Array, energies: Array, itter: int) -> Dictionary:
	var best_params = [
		energies.min(),                         # E0 guess
		latices[energies.find(energies.min())], # V0 guess
		1.0,                                    # B0 guess
		4.0                                     # B0p guess
	]
	var best_error = total_error(best_params, latices, energies)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for iter in range(itter):
		var trial = [
			best_params[0] + rng.randf_range(-0.1, 0.1),
			best_params[1] + rng.randf_range(-0.5, 0.5),
			best_params[2] + rng.randf_range(-0.5, 0.5),
			best_params[3] + rng.randf_range(-1.0, 1.0)
		]
		# Keep parameters physically reasonable
		if trial[1] <= 0 or trial[2] <= 0:
			continue
		var err = total_error(trial, latices, energies)
		if err < best_error:
			best_error = err
			best_params = trial
	return {
		"ground_energy": best_params[0],
		"optimum_lattice": best_params[1],
		"bulk_modulo": best_params[2],
		"bulk_modulo_prime": best_params[3],
		"total_error": best_error
	}
