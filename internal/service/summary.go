package service

// Caller holds e.mu. No account, asset, filename, hash, token or media key is
// exported. Profiles describe the immutable job policy, not verified cloud data.
func (e *Engine) uploadSummary() map[string]any {
	modes := map[string]any{}
	for _, mode := range []struct {
		name, model string
		policy      int
	}{{"original", "Pixel XL", 3}, {"saver", "Pixel 2", 1}, {"quota", "Pixel 8", 3}} {
		counts := map[string]int{}
		for _, job := range e.state.Jobs {
			if job.Quality == mode.name {
				counts[job.State]++
			}
		}
		modes[mode.name] = map[string]any{"model": mode.model, "storagePolicy": mode.policy, "uploadQuality": 1, "states": counts}
	}
	return map[string]any{"completionRevision": e.state.CompletionRevision, "defaultQuality": e.state.Options.Quality, "profiles": modes, "serverQualityVerified": false}
}
