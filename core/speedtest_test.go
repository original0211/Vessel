package core

import (
	"fmt"
	"net/http"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestSpeedMbps(t *testing.T) {
	cases := []struct {
		bytes  int64
		window time.Duration
		want   float64
	}{
		{12_500_000, time.Second, 100},
		{1_250_000, 500 * time.Millisecond, 20},
		{0, time.Second, 0},
		{100, 0, 0},
	}
	for _, tc := range cases {
		if got := speedMbps(tc.bytes, tc.window); got != tc.want {
			t.Errorf("speedMbps(%d, %v) = %v, want %v", tc.bytes, tc.window, got, tc.want)
		}
	}
}

func TestSpeedMeterWarmupEndsOnTime(t *testing.T) {
	base := time.Unix(1000, 0)
	meter := &speedMeter{startedAt: base}
	meter.add(100, base.Add(500*time.Millisecond))
	if meter.warmupDone {
		t.Fatal("warmup done at 100 bytes and 500ms, want still warming")
	}
	meter.add(100, base.Add(time.Second))
	if !meter.warmupDone {
		t.Fatal("warmup not done at the one second bound")
	}
	if meter.warmupBytes != 200 || meter.warmupFor != time.Second {
		t.Fatalf("warmup = %d bytes over %v, want 200 over 1s", meter.warmupBytes, meter.warmupFor)
	}
	meter.add(700, base.Add(2*time.Second))
	windowBytes, window := meter.window(base.Add(2 * time.Second))
	if windowBytes != 700 || window != time.Second {
		t.Fatalf("window = %d bytes over %v, want 700 over 1s", windowBytes, window)
	}
}

func TestSpeedMeterWarmupEndsOnBytes(t *testing.T) {
	base := time.Unix(1000, 0)
	meter := &speedMeter{startedAt: base}
	meter.add(speedTestWarmupBytes, base.Add(100*time.Millisecond))
	if !meter.warmupDone {
		t.Fatal("warmup not done at the byte bound")
	}
	if meter.warmupFor != 100*time.Millisecond {
		t.Fatalf("warmupFor = %v, want 100ms", meter.warmupFor)
	}
	windowBytes, window := meter.window(base.Add(600 * time.Millisecond))
	if windowBytes != 0 || window != 500*time.Millisecond {
		t.Fatalf("window = %d bytes over %v, want 0 over 500ms", windowBytes, window)
	}
}

func TestSpeedMeterNoWindowBeforeWarmup(t *testing.T) {
	meter := &speedMeter{startedAt: time.Unix(1000, 0)}
	meter.add(10, time.Unix(1000, 0))
	if bytes, window := meter.window(time.Unix(1001, 0)); bytes != 0 || window != 0 {
		t.Fatalf("window = %d over %v, want none before warmup ends", bytes, window)
	}
}

// dripServer answers the warmup bytes at once, then drips the rest, so the
// measured window spans a known duration at a known rate.
func dripServer(t *testing.T, dripChunks int) (string, int64) {
	t.Helper()
	chunk := make([]byte, 64<<10)
	server := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		flusher := w.(http.Flusher)
		for range 8 {
			_, _ = w.Write(chunk)
		}
		flusher.Flush()
		for range dripChunks {
			time.Sleep(50 * time.Millisecond)
			_, _ = w.Write(chunk)
			flusher.Flush()
		}
	})
	return server.URL, int64((8 + dripChunks) * len(chunk))
}

func TestHandleTestSpeedMeasuresThroughTheNamedProxy(t *testing.T) {
	url, total := dripServer(t, 24)
	withProbeProxies(t, "node-a")

	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{url},
		Timeout:   10_000,
	})

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error != "" {
		t.Fatalf("error = %q, want none", result.Error)
	}
	if result.TotalBytes != total {
		t.Errorf("totalBytes = %d, want %d", result.TotalBytes, total)
	}
	if result.Mbps < 4 || result.Mbps > 40 {
		t.Errorf("mbps = %v, want the drip rate near 10", result.Mbps)
	}
}

func TestHandleTestSpeedFallsBackToTheSecondSource(t *testing.T) {
	forbidden := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	})
	empty := probeServer(t, func(w http.ResponseWriter, r *http.Request) {})
	url, _ := dripServer(t, 24)
	withProbeProxies(t, "node-a")

	for _, first := range []string{forbidden.URL, empty.URL} {
		result := handleTestSpeed(&TestSpeedParams{
			ProxyName: "node-a",
			Urls:      []string{first, url},
			Timeout:   10_000,
		})
		if result == nil || result.Error != "" {
			t.Fatalf("first = %s: result = %+v, want a clean fallback", first, result)
		}
		if result.Mbps <= 0 {
			t.Errorf("first = %s: mbps = %v, want a positive reading", first, result.Mbps)
		}
	}
}

func TestHandleTestSpeedUnknownProxy(t *testing.T) {
	withProbeProxies(t, "node-a")

	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-missing",
		Urls:      []string{"https://example.invalid/file"},
		Timeout:   1000,
	})

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error == "" {
		t.Fatal("error is empty, want the missing proxy reported")
	}
	if result.Mbps != 0 {
		t.Errorf("mbps = %v, want no reading for a missing proxy", result.Mbps)
	}
}

func TestHandleTestSpeedEmptySourceIsNotMeasurable(t *testing.T) {
	empty := probeServer(t, func(w http.ResponseWriter, r *http.Request) {})
	withProbeProxies(t, "node-a")

	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{empty.URL},
		Timeout:   5000,
	})

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error != errSpeedTestInsufficient.Error() {
		t.Fatalf("error = %q, want %q", result.Error, errSpeedTestInsufficient)
	}
}

func TestHandleTestSpeedTimesOut(t *testing.T) {
	hanging := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		<-r.Context().Done()
	})
	withProbeProxies(t, "node-a")

	start := time.Now()
	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{hanging.URL},
		Timeout:   300,
	})
	elapsed := time.Since(start)

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error == "" {
		t.Fatal("error is empty, want the timeout reported")
	}
	if elapsed > 5*time.Second {
		t.Errorf("elapsed = %v, want the 300ms cap to hold", elapsed)
	}
}

func TestHandleTestSpeedStopsAtTheByteCap(t *testing.T) {
	chunk := make([]byte, 1<<20)
	server := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		flusher := w.(http.Flusher)
		for range 110 {
			if _, err := w.Write(chunk); err != nil {
				return
			}
			flusher.Flush()
			time.Sleep(5 * time.Millisecond)
		}
	})
	withProbeProxies(t, "node-a")

	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{server.URL},
		Timeout:   10_000,
	})

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error != "" {
		t.Fatalf("error = %q, want none", result.Error)
	}
	if result.TotalBytes < speedTestMaxBytes || result.TotalBytes >= speedTestMaxBytes+speedTestReadBuffer {
		t.Errorf("totalBytes = %d, want the %d cap plus at most one read", result.TotalBytes, speedTestMaxBytes)
	}
	fmt.Printf("byte cap run: total=%d mbps=%.1f\n", result.TotalBytes, result.Mbps)
}

// chunkedServer answers every GET with the same fixed body and then closes
// it, the shape of a sized download: only a client that asks again makes
// progress. The body drips out slowly enough for the window to measure. It
// reports how many requests it served.
func chunkedServer(t *testing.T, bodySize int) (string, *atomic.Int64) {
	t.Helper()
	var requests atomic.Int64
	chunk := make([]byte, 64<<10)
	server := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		flusher := w.(http.Flusher)
		for written := 0; written < bodySize; written += len(chunk) {
			_, _ = w.Write(chunk)
			flusher.Flush()
			time.Sleep(time.Millisecond)
		}
	})
	return server.URL + "?bytes=25000000", &requests
}

func TestHandleTestSpeedContinuesAcrossChunks(t *testing.T) {
	url, requests := chunkedServer(t, 4<<20)
	withProbeProxies(t, "node-a")

	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{url},
		Timeout:   10_000,
	})

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error != "" {
		t.Fatalf("error = %q, want none", result.Error)
	}
	if got := requests.Load(); got < 2 {
		t.Errorf("requests = %d, want the window continued past one chunk", got)
	}
	if result.TotalBytes < speedTestMaxBytes || result.TotalBytes >= speedTestMaxBytes+speedTestReadBuffer {
		t.Errorf("totalBytes = %d, want the %d cap plus at most one read", result.TotalBytes, speedTestMaxBytes)
	}
}

func TestHandleTestSpeedWarmsUpOnceAcrossChunks(t *testing.T) {
	chunk := make([]byte, 64<<10)
	var requests atomic.Int64
	server := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		flusher := w.(http.Flusher)
		switch requests.Add(1) {
		case 1:
			// The first chunk fills the warmup byte bound at once.
			for range 8 {
				_, _ = w.Write(chunk)
			}
		case 2:
			// The second chunk drips the same amount over about a second;
			// it is measurable only if the warmup is not charged again.
			for range 8 {
				time.Sleep(125 * time.Millisecond)
				_, _ = w.Write(chunk)
				flusher.Flush()
			}
		}
	})
	withProbeProxies(t, "node-a")

	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{server.URL + "?bytes=25000000"},
		Timeout:   10_000,
	})

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error != "" {
		t.Fatalf("error = %q, want none (a second warmup would leave no window)", result.Error)
	}
	if result.TotalBytes != 2*speedTestWarmupBytes {
		t.Errorf("totalBytes = %d, want %d over the two chunks", result.TotalBytes, 2*speedTestWarmupBytes)
	}
	if result.Mbps < 2.5 || result.Mbps > 8 {
		t.Errorf("mbps = %v, want the drip rate near 4.2", result.Mbps)
	}
}

func TestHandleTestSpeedFailedChunkFallsBack(t *testing.T) {
	var requests atomic.Int64
	body := make([]byte, 1<<20)
	flaky := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		if requests.Add(1) > 1 {
			w.WriteHeader(http.StatusForbidden)
			return
		}
		_, _ = w.Write(body)
	})
	url, _ := dripServer(t, 24)
	withProbeProxies(t, "node-a")

	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{flaky.URL + "?bytes=25000000", url},
		Timeout:   10_000,
	})

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error != "" {
		t.Fatalf("error = %q, want a clean fallback after the failed chunk", result.Error)
	}
	if result.Mbps <= 0 {
		t.Errorf("mbps = %v, want a positive reading from the second source", result.Mbps)
	}
	if got := requests.Load(); got != 2 {
		t.Errorf("requests = %d, want the failed second chunk to end the source", got)
	}
}

func TestHandleTestSpeedWholeFileIsRequestedOnce(t *testing.T) {
	var requests atomic.Int64
	chunk := make([]byte, 64<<10)
	server := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		flusher := w.(http.Flusher)
		for range 8 {
			_, _ = w.Write(chunk)
		}
		flusher.Flush()
		for range 24 {
			time.Sleep(50 * time.Millisecond)
			_, _ = w.Write(chunk)
			flusher.Flush()
		}
	})
	withProbeProxies(t, "node-a")

	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{server.URL},
		Timeout:   10_000,
	})

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error != "" {
		t.Fatalf("error = %q, want none", result.Error)
	}
	if got := requests.Load(); got != 1 {
		t.Errorf("requests = %d, want a whole file read exactly once", got)
	}
	if result.TotalBytes != 32*int64(len(chunk)) {
		t.Errorf("totalBytes = %d, want the whole file", result.TotalBytes)
	}
}

func TestHandleTestSpeedAggregatesSourceErrors(t *testing.T) {
	forbidden := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	})
	empty := probeServer(t, func(w http.ResponseWriter, r *http.Request) {})
	withProbeProxies(t, "node-a")

	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{forbidden.URL, empty.URL},
		Timeout:   5000,
	})

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	for _, want := range []string{forbidden.URL, "403", empty.URL, errSpeedTestInsufficient.Error()} {
		if !strings.Contains(result.Error, want) {
			t.Errorf("error = %q, want it to carry %q", result.Error, want)
		}
	}
}

func TestHandleTestSpeedChunkedSourceTimesOut(t *testing.T) {
	server := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		flusher := w.(http.Flusher)
		chunk := make([]byte, 64<<10)
		for {
			select {
			case <-r.Context().Done():
				return
			default:
			}
			if _, err := w.Write(chunk); err != nil {
				return
			}
			flusher.Flush()
			time.Sleep(200 * time.Millisecond)
		}
	})
	withProbeProxies(t, "node-a")

	start := time.Now()
	result := handleTestSpeed(&TestSpeedParams{
		ProxyName: "node-a",
		Urls:      []string{server.URL + "?bytes=25000000"},
		Timeout:   300,
	})
	elapsed := time.Since(start)

	if result == nil {
		t.Fatal("handleTestSpeed = nil, want a result")
	}
	if result.Error == "" {
		t.Fatal("error is empty, want the timeout reported")
	}
	if elapsed > 5*time.Second {
		t.Errorf("elapsed = %v, want the 300ms cap to hold", elapsed)
	}
}
