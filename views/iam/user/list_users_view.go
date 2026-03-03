package userview

import (
	"strings"

	"github.com/DragonEmperor9480/AethrOps/views"
)

func RenderIAMUsersTable(raw string) {
	lines := strings.Split(raw, "\n")

	// Prepare data rows
	var rows [][]string
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) >= 3 {
			username := fields[0]
			userID := fields[1]
			createdAt := fields[2]
			rows = append(rows, []string{username, userID, createdAt})
		}
	}

	// Render using common table utility
	views.RenderTable(views.TableConfig{
		Headers: []string{"Username", "User ID", "Created At"},
		Rows:    rows,
	})
}
