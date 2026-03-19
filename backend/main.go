package main

import (
	"log"
	"net/http"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/DragonEmperor9480/AethrOps/routes"
	"github.com/DragonEmperor9480/AethrOps/service"
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

	// Initialize log directory for CloudWatch log sessions
	if err := service.InitLogDirectory(); err != nil {
		log.Printf("Warning: Log directory not initialized: %v", err)
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

	log.Println("Server running on http://127.0.0.1:9480")

	// Create HTTP server with optimized settings for large file transfers
	server := &http.Server{
		Addr:           "127.0.0.1:9480",
		Handler:        corsMiddleware(r),
		ReadTimeout:    0, // No timeout for large file transfers
		WriteTimeout:   0, // No timeout for large file transfers
		IdleTimeout:    0,
		MaxHeaderBytes: 1 << 20, // 1MB
	}

	if err := server.ListenAndServe(); err != nil {
		log.Fatal("Server error:", err)
	}
}
