package service

import (
	"app/backend"
	"context"
	"errors"
	"path/filepath"
)

var errRemoteComponentExists = backend.ErrGunshotRemoteComponentExists

func Initialize(root string) (*Engine, error) {
	e, err := Open(root, upload)
	if err != nil {
		return nil, err
	}
	if err = backend.LoadConfig(filepath.Join(root, "credentials.json")); err != nil {
		return nil, err
	}
	return e, nil
}
func accountExists(email string) bool {
	for _, a := range (&backend.ConfigManager{}).GetAccounts().Accounts {
		if a.Email == email {
			return true
		}
	}
	return false
}
func (e *Engine) accounts(r Request) (any, error) {
	g := &backend.ConfigManager{}
	switch r.Op {
	case "accounts":
		return g.GetAccounts(), nil
	case "account_native":
		return nil, g.AddNativeAccount(r.Account, r.NativeID)
	case "account_add":
		if len(r.Secret) == 0 || len(r.Secret) > 32768 {
			return nil, errRequest
		}
		var err error
		if backend.LooksLikeAuthString(r.Secret) {
			err = g.AddCredentials(r.Secret)
		} else {
			_, err = g.AddGoogleAccountWithProxy(r.Secret, "")
		}
		return nil, err
	case "account_select":
		return nil, g.SelectAccount(r.Account)
	case "account_remove":
		for _, j := range e.state.Jobs {
			if j.Account == r.Account && j.State != "completed" && j.State != "cancelled" {
				return nil, errors.New("cancel account jobs first")
			}
		}
		return nil, g.RemoveCredentials(r.Account)
	}
	return nil, errRequest
}

type reporter struct {
	backend.NopReporter
	callback     func(Progress)
	total        int64
	completed    int64
	previousPath string
}

func (r *reporter) ThreadStatus(s backend.ThreadStatus) {
	phase := "preparing"
	switch s.Status {
	case "uploading":
		phase = "uploading"
	case "finalizing":
		phase = "committing"
	}
	if s.FilePath != r.previousPath && r.previousPath != "" {
		r.completed += r.total
	}
	if s.FilePath != "" {
		r.previousPath = s.FilePath
	}
	if s.BytesTotal > 0 {
		r.total = s.BytesTotal
	}
	r.callback(Progress{State: phase, Uploaded: r.completed + s.BytesUploaded})
}
func upload(ctx context.Context, paths []string, account, quality string, cb func(Progress)) (string, error) {
	opts := backend.UploadOptions{Api: backend.ApiOptions{Account: account, Saver: quality == "saver", UseQuota: quality == "quota"}, Threads: 1, ForceUpload: quality == "original", PairLivePhotos: len(paths) == 2, SkipIncompleteLivePhotos: true}
	return backend.GunshotUpload(ctx, paths, opts, &reporter{callback: cb})
}
