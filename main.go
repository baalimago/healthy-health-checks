package main

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

func main() {
	t0 := time.Now()
	healthyAfterStr := os.Getenv("HEALTHY_AFTER_DURATION")
	if healthyAfterStr == "" {
		panic("Missing environment variable 'HEALTHY_AFTER_DURATION'")
	}
	healthyAfter, err := time.ParseDuration(healthyAfterStr)

	unhealthyAfterStr, shouldGetUnhealthy := os.LookupEnv("UNHEALTHY_AFTER_DURATION")
	var unhealthyAfter time.Duration
	if shouldGetUnhealthy {
		unhealthyAfter, err = time.ParseDuration(unhealthyAfterStr)
		if err != nil {
			panic("Missing environment variable 'HEALTHY_AFTER_DURATION'")
		}
	}

	if err != nil {
		panic(fmt.Sprintf("failed to parse 'UNHEALTHY_AFTER_DURATION': %v", err))
	}

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		timeSinceStart := time.Since(t0)
		if timeSinceStart > healthyAfter {
			if shouldGetUnhealthy && timeSinceStart > unhealthyAfter {
				w.WriteHeader(http.StatusInternalServerError)
				w.Write([]byte("Time's up! Now I'm unhealthy!"))
				return
			}
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Now I'm healthy."))
		} else {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("Not ready and therefore not healthy."))
		}
	})
	fmt.Println("serving health status on localhost:8080/health")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		panic(fmt.Sprintf("failed to serve: %v", err))
	}
}
