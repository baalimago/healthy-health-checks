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
		panic("Not the good kind! Missing environment variable 'HEALTHY_AFTER_DURATION'")
	}
	healthyAfter, err := time.ParseDuration(healthyAfterStr)
	if err != nil {
		panic(fmt.Sprintf("failed to parse 'HEALTHY_AFTER_DURATION': %v", err))
	}

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		timeSinceStart := time.Since(t0)
		if timeSinceStart > healthyAfter {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Now I'm healthy."))
		} else {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("Not ready!"))
		}
	})
	fmt.Println("serving health status on localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		panic(fmt.Sprintf("failed to serve: %v", err))
	}
}
