package main

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

// main function containing _everything_ since that just made it easier
func main() {
	t0 := time.Now()
	// First parse out the environment variables to determine when to turn healthy
	// Before this, the service is 'booting'
	healthyAfterStr := os.Getenv("HEALTHY_AFTER_DURATION")
	if healthyAfterStr == "" {
		panic("Missing environment variable 'HEALTHY_AFTER_DURATION'")
	}
	healthyAfter, err := time.ParseDuration(healthyAfterStr)

	// Lookup if we should feign unhealthiness at all
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

	// Setup the handler here, reducing the need for complexity
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		// It works by checking the time since start on every request
		timeSinceStart := time.Since(t0)
		// If we've passed the time for turning healthy, do logic (see below)
		// On the other hand, if we haven't yet reached 'healthy', don't return anything
		// at all to simulate a booting service
		if timeSinceStart > healthyAfter {
			// ..check if we instead should be unhealthy
			if shouldGetUnhealthy && timeSinceStart > unhealthyAfter {
				unhealthySince := timeSinceStart - unhealthyAfter
				// Note that this is a 'kind' way of being unhealthy
				// TODO: Deadlock/performance unhealthiness simulations, where response times out
				w.WriteHeader(http.StatusInternalServerError)
				fmt.Fprintf(w, "Time's up, now I'm unhealthy! Been unhealthy for: %v", unhealthySince)
				return
			}
			// otherwise report healthy
			out := "Now I'm healthy."
			if shouldGetUnhealthy {
				out += fmt.Sprintf(" Turning unhealthy in: %v", unhealthyAfter-timeSinceStart)
			}
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(out))
		}
	})

	fmt.Println("serving health status on localhost:8080/health")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		panic(fmt.Sprintf("failed to serve: %v", err))
	}
}
