package core

import (
	"context"
	"errors"
	"fmt"
	"io"
	"time"

	"github.com/metacubex/http"
	"github.com/metacubex/mihomo/component/ca"
	"github.com/metacubex/mihomo/constant"
)

const (
	speedTestConcurrency    = 1
	defaultSpeedTestTimeout = 10 * time.Second
	speedTestMaxBytes       = 100 << 20
	speedTestWarmup         = time.Second
	speedTestWarmupBytes    = 512 << 10
	speedTestMinWindow      = 200 * time.Millisecond
	speedTestReadBuffer     = 32 * 1024
)

var (
	speedTestSlots = make(slots, speedTestConcurrency)

	errSpeedTestInsufficient = errors.New("speed test source ended before a measurable window")
)

// speedMeter splits a download into the warmup the reading discards and the
// window it is measured over; the warmup ends at the first of the time or
// byte bound, so a fast source is not credited with its slow start either.
type speedMeter struct {
	startedAt   time.Time
	totalBytes  int64
	warmupDone  bool
	warmupBytes int64
	warmupFor   time.Duration
}

func (m *speedMeter) add(n int, at time.Time) {
	m.totalBytes += int64(n)
	if m.warmupDone {
		return
	}
	if elapsed := at.Sub(m.startedAt); elapsed >= speedTestWarmup || m.totalBytes >= speedTestWarmupBytes {
		m.warmupDone = true
		m.warmupBytes = m.totalBytes
		m.warmupFor = elapsed
	}
}

func (m *speedMeter) window(at time.Time) (int64, time.Duration) {
	if !m.warmupDone {
		return 0, 0
	}
	return m.totalBytes - m.warmupBytes, at.Sub(m.startedAt) - m.warmupFor
}

func speedMbps(windowBytes int64, window time.Duration) float64 {
	if windowBytes <= 0 || window <= 0 {
		return 0
	}
	return float64(windowBytes) * 8 / window.Seconds() / 1e6
}

func measureSpeedDownload(ctx context.Context, client *http.Client, url string) (float64, int64, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, 0, err
	}
	response, err := client.Do(request)
	if err != nil {
		return 0, 0, err
	}
	defer func() {
		_ = response.Body.Close()
	}()
	if response.StatusCode != http.StatusOK {
		return 0, 0, fmt.Errorf("speed test source answered %s", response.Status)
	}
	meter := &speedMeter{startedAt: time.Now()}
	buffer := make([]byte, speedTestReadBuffer)
	for meter.totalBytes < speedTestMaxBytes {
		n, readErr := response.Body.Read(buffer)
		if n > 0 {
			meter.add(n, time.Now())
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			if ctx.Err() == nil {
				return 0, meter.totalBytes, readErr
			}
			break
		}
	}
	windowBytes, windowDuration := meter.window(time.Now())
	if windowBytes <= 0 || windowDuration < speedTestMinWindow {
		return 0, meter.totalBytes, errSpeedTestInsufficient
	}
	return speedMbps(windowBytes, windowDuration), meter.totalBytes, nil
}

func runSpeedTest(parent context.Context, proxy constant.Proxy, name string, urls []string, timeout time.Duration) *SpeedTestResult {
	result := &SpeedTestResult{Name: name}
	tlsConfig, err := ca.GetTLSConfig(ca.Option{})
	if err != nil {
		result.Error = err.Error()
		return result
	}
	dialer := &probeDialer{proxy: proxy}
	transport := &http.Transport{
		DialContext:         dialer.dial,
		TLSClientConfig:     tlsConfig,
		TLSHandshakeTimeout: timeout,
		MaxIdleConns:        1,
		IdleConnTimeout:     timeout,
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport}

	ctx, cancel := context.WithTimeout(parent, timeout)
	defer cancel()
	var lastErr error
	for _, url := range urls {
		mbps, totalBytes, err := measureSpeedDownload(ctx, client, url)
		if err == nil {
			result.Mbps = mbps
			result.TotalBytes = totalBytes
			return result
		}
		lastErr = err
		if ctx.Err() != nil {
			break
		}
	}
	if lastErr != nil {
		result.Error = lastErr.Error()
	}
	return result
}

// A nil answer means the test never got the single slot, which says nothing
// about the proxy.
func handleTestSpeed(params *TestSpeedParams) *SpeedTestResult {
	result := &SpeedTestResult{Name: params.ProxyName}
	proxy := lookupProxy(params.ProxyName)
	if proxy == nil {
		logError("speed test: %q is not part of the applied config", params.ProxyName)
		result.Error = fmt.Sprintf("proxy %q is not part of the applied config", params.ProxyName)
		return result
	}
	if len(params.Urls) == 0 {
		result.Error = "no speed test source"
		return result
	}
	timeout := timeoutFromMillis(params.Timeout, defaultSpeedTestTimeout)
	if !speedTestSlots.acquireWithin(context.Background(), timeout) {
		return nil
	}
	defer speedTestSlots.release()
	return runSpeedTest(context.Background(), proxy, params.ProxyName, params.Urls, timeout)
}
