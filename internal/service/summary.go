package service

import (
	"path/filepath"
	"strings"
)

func diagnosticMediaType(resources []Resource) string {
	heic := false
	for _, resource := range resources {
		ext := strings.ToLower(filepath.Ext(resource.Name))
		heic = heic || ext == ".heic" || ext == ".heif"
	}
	if len(resources) == 2 {
		if heic {
			return "heic_live_photo"
		}
		return "live_photo"
	}
	if heic {
		return "heic"
	}
	if len(resources) == 1 {
		switch strings.ToLower(filepath.Ext(resources[0].Name)) {
		case ".jpg", ".jpeg":
			return "jpeg"
		case ".png":
			return "png"
		case ".mov", ".mp4", ".m4v":
			return "video"
		}
	}
	return "other"
}

// State files may come from older versions. Never copy arbitrary error strings
// or extensions into diagnostic output, even when a job has failed.
func diagnosticFailure(code string) string {
	switch code {
	case "remote_live_photo_component_exists", "commit_outcome_unknown",
		"upload_failed_retrying", "upload_failed_check_account_and_network",
		"waiting_for_native_auth", "paused", "import_interrupted":
		return code
	case "":
		return "unspecified"
	default:
		return "other"
	}
}

// Caller holds e.mu. No account, asset, filename, hash, token or media key is
// exported. Profiles describe the immutable job policy, not verified cloud data.
func (e *Engine) uploadSummary() map[string]any {
	media := map[string]any{}
	for _, job := range e.state.Jobs {
		kind := diagnosticMediaType(job.Resources)
		if media[kind] == nil {
			media[kind] = map[string]any{"states": map[string]int{}, "failureCodes": map[string]int{}}
		}
		entry := media[kind].(map[string]any)
		entry["states"].(map[string]int)[job.State]++
		if job.Error != "" || job.State == "failed" {
			entry["failureCodes"].(map[string]int)[diagnosticFailure(job.Error)]++
		}
	}
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
	conditions := map[string]bool{"online": e.online, "wifi": e.wifi, "charging": e.charging, "paused": e.state.Options.Paused}
	return map[string]any{"completionRevision": e.state.CompletionRevision, "defaultQuality": e.state.Options.Quality, "profiles": modes, "mediaTypes": media, "conditions": conditions, "serverQualityVerified": false}
}
