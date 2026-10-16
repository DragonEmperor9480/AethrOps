package main

import (
	"log"
	"net/http"
	"os"

	"github.com/DragonEmperor9480/AethrOps/constants"
	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/DragonEmperor9480/AethrOps/middleware"
	"github.com/DragonEmperor9480/AethrOps/routes"
	"github.com/DragonEmperor9480/AethrOps/service"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/gorilla/mux"
)

func main() {
	// The Flutter app passes a per-launch token; refuse to serve without one.
	token := os.Getenv(constants.AuthTokenEnv)
	if token == "" {
		log.Fatalf("%s is not set. The backend must be started by the AethrOps app.", constants.AuthTokenEnv)
	}
	os.Unsetenv(constants.AuthTokenEnv)
	middleware.SetAuthToken(token)

	// Fail-safe: Detect if the parent Flutter process terminates abruptly (stdin closed)
	go func() {
		buf := make([]byte, 1)
		_, err := os.Stdin.Read(buf)
		if err != nil {
			log.Println("Parent process disconnected (stdin closed). Exiting backend gracefully...")
			os.Exit(0)
		}
	}()

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
		log.Println("AWS credentials will be loaded from ~/.aethrops/credentials or environment variables")
	} else {
		log.Println("AWS clients initialized successfully")
	}

	r := mux.NewRouter()

	// Register all API routes
	routes.RegisterRoutes(r)

	log.Println("Server running on http://" + constants.BackendAddress)

	server := &http.Server{
		Addr:    constants.BackendAddress,
		Handler: middleware.Secure(r),
	}

	if err := server.ListenAndServe(); err != nil {
		log.Fatal("Server error:", err)
	}
}
