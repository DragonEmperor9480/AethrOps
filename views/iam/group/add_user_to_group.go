package group

import (
	"github.com/DragonEmperor9480/AethrOps/views"
)

// Display only usernames and group names side-by-side
func ShowUsersAndGroupsSideBySide(users []string, groups []string) {
	// Determine max rows
	maxRows := len(users)
	if len(groups) > maxRows {
		maxRows = len(groups)
	}

	// Prepare data rows
	var rows [][]string
	for i := 0; i < maxRows; i++ {
		user := ""
		group := ""

		if i < len(users) {
			user = users[i]
		}
		if i < len(groups) {
			group = groups[i]
		}

		rows = append(rows, []string{user, group})
	}

	// Render using common table utility (without serial numbers for side-by-side view)
	views.RenderTableWithoutSerial(views.TableConfig{
		Headers: []string{"IAM Users", "IAM Groups"},
		Rows:    rows,
	})
}
