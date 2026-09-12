package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"context"
	"github.com/tqmane/gunshot/internal/service"
	"io"
	"log"
	"log/slog"
	"sync"
	"unsafe"
)

var engine *service.Engine
var initMu sync.Mutex

//export GunshotPing
func GunshotPing() C.int { return 1 }

//export GunshotInitialize
func GunshotInitialize(path *C.char) C.int {
	initMu.Lock()
	defer initMu.Unlock()
	if engine != nil {
		return 0
	}
	log.SetOutput(io.Discard)
	slog.SetDefault(slog.New(slog.DiscardHandler))
	e, err := service.Initialize(C.GoString(path))
	if err != nil {
		return -1
	}
	engine = e
	go e.Run(context.Background())
	return 0
}

//export GunshotRequest
func GunshotRequest(request *C.char, role *C.char) (out *C.char) {
	defer func() {
		if recover() != nil {
			out = C.CString(`{"ok":false,"error":"internal_error"}`)
		}
	}()
	if engine == nil {
		return C.CString(`{"ok":false,"error":"not_initialized"}`)
	}
	return C.CString(string(engine.HandleJSON([]byte(C.GoString(request)), C.GoString(role))))
}

//export GunshotFree
func GunshotFree(p unsafe.Pointer) { C.free(p) }
func main()                        {}
