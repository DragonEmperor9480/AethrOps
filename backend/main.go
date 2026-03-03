package main

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/DragonEmperor9480/AethrOps/routes"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/gorilla/mux"
)

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

func main() {
	// Initialize database
	if err := db_service.InitDB(); err != nil {
		log.Fatal("Error initializing database:", err)
	}

	// Try to initialize AWS SDK clients (don't fail if credentials not available)
	if err := utils.InitAWSClients(); err != nil {
		log.Printf("Warning: AWS clients not initialized: %v", err)
		log.Println("AWS credentials will be loaded from ~/.aws/credentials or environment variables")
	} else {
		log.Println("AWS clients initialized successfully")
	}

	r := mux.NewRouter()

	// Register all API routes
	routes.RegisterRoutes(r)

	// Health check
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}).Methods("GET")

	log.Println("Server running on http://127.0.0.1:9480")
	if err := http.ListenAndServe("127.0.0.1:9480", corsMiddleware(r)); err != nil {
		log.Fatal("Server error:", err)
	}
}
