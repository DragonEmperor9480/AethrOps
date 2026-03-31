package main

import "C"
import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/DragonEmperor9480/AethrOps/routes"
	"github.com/DragonEmperor9480/AethrOps/service"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/gorilla/mux"
)

var server *http.Server

// CORS middleware
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length")
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

//export SetDataDirectory
func SetDataDirectory(dir *C.char) int {
	dataDir := C.GoString(dir)
	db_service.SetDataDirectory(dataDir)
	// Set environment variable so other packages can access it
	os.Setenv("AETHROPS_DATA_DIR", dataDir)
	log.Printf("Data directory set to: %s", dataDir)

	// Initialize log directory after setting data directory
	if err := service.InitLogDirectory(); err != nil {
		log.Printf("Warning: Failed to initialize log directory: %v", err)
	}

	return 0
}

//export SetAWSCredentials
func SetAWSCredentials(accessKey, secretKey, region *C.char) int {
	accessKeyStr := strings.TrimSpace(C.GoString(accessKey))
	secretKeyStr := strings.TrimSpace(C.GoString(secretKey))
	regionStr := strings.TrimSpace(C.GoString(region))

	if accessKeyStr == "" || secretKeyStr == "" || regionStr == "" {
		log.Printf("Error: Empty credentials provided")
		return 1
	}

	if !isValidAWSRegion(regionStr) {
		log.Printf("Error: Invalid AWS region format: %s", regionStr)
		return 1
	}

	os.Setenv("AWS_ACCESS_KEY_ID", accessKeyStr)
	os.Setenv("AWS_SECRET_ACCESS_KEY", secretKeyStr)
	os.Setenv("AWS_DEFAULT_REGION", regionStr)
	os.Setenv("AWS_REGION", regionStr)

	log.Printf("AWS credentials set for region: %s", regionStr)

	// Initialize AWS SDK clients with the new credentials
	if err := utils.InitAWSClients(); err != nil {
		log.Printf("Error initializing AWS clients: %v", err)
		return 1
	}

	log.Printf("AWS SDK clients initialized successfully")
	return 0
}

func isValidAWSRegion(region string) bool {
	if region == "" || len(region) < 9 {
		return false
	}

	for _, char := range region {
		if !((char >= 'a' && char <= 'z') || (char >= '0' && char <= '9') || char == '-') {
			return false
		}
	}

	return strings.Contains(region, "-")
}

//export StartBackend
func StartBackend() int {
	if err := db_service.InitDB(); err != nil {
		log.Printf("Warning: Database initialization failed: %v", err)
	}

	r := mux.NewRouter()

	// Register all API routes
	routes.RegisterRoutes(r)

	// Health check
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}).Methods("GET")

	server = &http.Server{
		Addr:         "127.0.0.1:9480",
		Handler:      corsMiddleware(r),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 0, // Disable write timeout for SSE streaming
	}

	go func() {
		log.Println("Backend starting on http://127.0.0.1:9480")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("Server error: %v", err)
		}
	}()

	time.Sleep(500 * time.Millisecond)
	return 0
}

//export StopBackend
func StopBackend() int {
	if server != nil {
		server.Close()
	}
	return 0
}

func main() {}
