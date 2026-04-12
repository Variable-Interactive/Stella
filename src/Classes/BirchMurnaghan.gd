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


static func relative_error(params: Array, latices: Array, energies: Array) -> Array[float]:
	var e0 = params[0]
	var a0 = params[1]
	var b0 = params[2]
	var b0p = params[3]
	var bound_left = 0
	var bound_right = evaluate(Vector2i.MAX.x, e0, a0, b0, b0p)
	var min_energy = evaluate(a0, e0, a0, b0, b0p)
	for i in range(200):
		bound_left = evaluate(i / 100.0, e0, a0, b0, b0p)
		if not is_nan(bound_left):
			break
	if bound_left < min_energy or bound_right < min_energy:
		return []
	var rel_error: Array[float] = []
	for i in range(latices.size()):
		var predicted = evaluate(latices[i], e0, a0, b0, b0p)
		rel_error.append(abs(predicted - energies[i]))
	return rel_error


static func max_error(params: Array, latices: Array, energies: Array) -> Array[float]:
	var e0 = params[0]
	var a0 = params[1]
	var b0 = params[2]
	var b0p = params[3]
	var bound_left = 0
	var bound_right = evaluate(Vector2i.MAX.x, e0, a0, b0, b0p)
	var min_energy = evaluate(a0, e0, a0, b0, b0p)
	for i in range(200):
		bound_left = evaluate(i / 100.0, e0, a0, b0, b0p)
		if not is_nan(bound_left):
			break
	if bound_left < min_energy or bound_right < min_energy:
		return []
	var rel_error: Array[float] = []
	for i in range(latices.size()):
		var predicted = evaluate(latices[i], e0, a0, b0, b0p)
		rel_error.append(abs(predicted - energies[i]))
	return rel_error


static func total_error(params: Array, latices: Array, energies: Array) -> float:
	var e0 = params[0]
	var a0 = params[1]
	var b0 = params[2]
	var b0p = params[3]
	var bound_left = 0
	var bound_right = evaluate(Vector2i.MAX.x, e0, a0, b0, b0p)
	var min_energy = evaluate(a0, e0, a0, b0, b0p)
	for i in range(200):
		bound_left = evaluate(i / 100.0, e0, a0, b0, b0p)
		if not is_nan(bound_left):
			break
	if bound_left < min_energy or bound_right < min_energy:
		return INF
	var error: float = 0
	for i in range(latices.size()):
		var predicted = evaluate(latices[i], e0, a0, b0, b0p)
		error += abs(predicted - energies[i])
	return error


static func fit_birch(
	latices: Array, energies: Array, itter: int, old_best_params := []
) -> Dictionary:
	const MIN_INCREMENT = 0.001
	if latices.is_empty() or energies.is_empty():
		return {}

	var best_params = [
		energies.min(),                         # E0 guess
		latices[energies.find(energies.min())], # a0 guess
		1.0,                                    # B0 guess
		4.0                                     # B0p guess
	]
	var best_last_error: Array[float] = []

	var best_net_error := total_error(best_params, latices, energies)
	if not old_best_params.is_empty():
		# Remove invalid values if present in old_best_params
		old_best_params[1] = maxf(old_best_params[1], MIN_INCREMENT)
		old_best_params[2] = maxf(old_best_params[2], MIN_INCREMENT)
		old_best_params[3] = maxf(old_best_params[3], MIN_INCREMENT)
		var old_best_net_error := total_error(old_best_params, latices, energies)
		if old_best_net_error < best_net_error:
			best_params = old_best_params
			best_net_error = old_best_net_error

	prints("Old error", best_net_error)
	for iter in range(itter):
		var new_trials := prepare_trials(best_params)
		for trial in new_trials:
			# Keep parameters physically reasonable (check lattice and bulk modulo, and derivative).
			# NOTE: For the energy to be +inf at the limit V -> 0, B' should be greater than 4.0.
			if trial[1] <= 0 or trial[2] <= 0 or trial[3] <= 4.0:
				continue
			var error: Array[float] = relative_error(trial, latices, energies)
			if error.is_empty():
				continue

			var net_error := error.size()
			if best_last_error.is_empty():
				best_last_error = error
				best_net_error = total_error(trial, latices, energies)
			else:
				for i in error.size():
					if error[i] < best_last_error[i]:
						net_error -= 1
				if net_error <= 1:
					best_last_error = error
					best_params = trial
	print(best_last_error)
	Global.debug_funny("The total error of this fitting is: %s" % str(snappedf(best_net_error, 0.0001)))
	return {
		"ground_energy": best_params[0],
		"optimum_lattice": best_params[1],
		"bulk_modulo": best_params[2],
		"bulk_modulo_prime": best_params[3],
	}


static func prepare_trials(old_best: Array) -> Array[Array]:
	var results: Array[Array] = []
	var energy_range := absf(randf_range(0.01, 0.1))
	var latt_range := absf(randf_range(0.01, 0.1))
	var bulk_range := absf(randf_range(0.01, 0.1))
	var bulk_prime_range := absf(randf_range(0.5, 2.0))
	for energy in [-energy_range, 0, energy_range]:
		for latt in [-latt_range, 0, latt_range]:
			latt = latt if old_best[1] + latt > 0.0 else 0.0
			for bulk in [-bulk_range, 0, bulk_range]:
				bulk = bulk if old_best[2] + bulk > 0.0 else 0.0
				for bulk_prime in [-bulk_prime_range, 0, bulk_prime_range]:
					bulk_prime = bulk_prime if old_best[3] + bulk_prime > 4.0 else 4.0
					if energy == 0 and latt == 0 and bulk == 0 and bulk_prime == 0:
						continue
					results.append(
						[
							old_best[0] + energy,
							old_best[1] + latt,
							old_best[2] + bulk,
							old_best[3] + bulk_prime
						]
					)
	return results
