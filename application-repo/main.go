package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"
)

type AppConfig struct {
    DatabaseURL string `json:"database_url"`
    APIKey      string `json:"api_key"`
    Debug       bool   `json:"debug"`
}

type HealthResponse struct {
    Status    string    `json:"status"`
    Timestamp time.Time `json:"timestamp"`
    Version   string    `json:"version"`
    Config    bool      `json:"vault_config_loaded"`
}

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    // Simulation de lecture depuis Vault
    // En production, ceci serait injecté par l'agent Vault
    vaultConfigPath := os.Getenv("VAULT_CONFIG_PATH")
    configLoaded := false
    
    if vaultConfigPath != "" {
        if _, err := os.Stat(vaultConfigPath); err == nil {
            configLoaded = true
            log.Printf("Configuration Vault chargée depuis: %s", vaultConfigPath)
        }
    }

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        response := HealthResponse{
            Status:    "healthy",
            Timestamp: time.Now(),
            Version:   "1.0.0",
            Config:    configLoaded,
        }
        
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(response)
    })

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "DevSecOps Zero Trust Application - Running Securely! 🔒")
    })

    log.Printf("Application démarrée sur le port %s", port)
    log.Printf("Endpoints: /health, /")
    
    if err := http.ListenAndServe(":"+port, nil); err != nil {
        log.Fatal("Erreur serveur:", err)
    }
}