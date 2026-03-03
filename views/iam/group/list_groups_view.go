package group

import (
	"strings"

	"github.com/DragonEmperor9480/AethrOps/views"
)

func ShowGroupsTable(data string) {
	lines := strings.Split(data, "\n")

	// Prepare data rows
	var rows [][]string
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) >= 3 {
			groupName := fields[0]
			groupID := fields[1]
			createdAt := strings.Join(fields[2:], " ")
			rows = append(rows, []string{groupName, groupID, createdAt})
		}
	}

	// Render using common table utility
	views.RenderTable(views.TableConfig{
		Headers: []string{"Group Name", "Group ID", "Created At"},
		Rows:    rows,
	})
}
