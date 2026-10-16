package utils

import (
	"encoding/json"
	"net/http"

	"github.com/DragonEmperor9480/AethrOps/models"
)

func JSON(w http.ResponseWriter, statusCode int, data models.Response) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(data)

}

func Error(w http.ResponseWriter, status int, message string) {
	JSON(w, status, models.Response{
		Status:  false,
		Message: message,
	})
}

func Success(w http.ResponseWriter, status int, message string, data any) {
	JSON(w, status, models.Response{
		Status:  true,
		Message: message,
		Data:    data,
	})
}
