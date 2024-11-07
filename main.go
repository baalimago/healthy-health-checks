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
				unhealthySince := timeSinceStart - unhealthyAfter
				w.WriteHeader(http.StatusInternalServerError)
				fmt.Fprintf(w, "Time's up, now I'm unhealthy! Been unhealthy for: %v", unhealthySince)
				return
			}
			out := "Now I'm healthy."
			if shouldGetUnhealthy {
				out += fmt.Sprintf(" Turning unhealthy in: %v", unhealthyAfter-timeSinceStart)
			}
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(out))
		} else {
			bootupDoneAt := healthyAfter - timeSinceStart
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprintf(w, "Not ready and therefore not healthy. 'Bootup' done in: %v", bootupDoneAt)
		}
	})
	fmt.Println("serving health status on localhost:8080/health")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		panic(fmt.Sprintf("failed to serve: %v", err))
	}
}
