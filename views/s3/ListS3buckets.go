package s3

import (
	"strings"

	"github.com/DragonEmperor9480/AethrOps/views"
)

func RenderS3BucketsTable(raw string) {
	lines := strings.Split(raw, "\n")

	// Prepare data rows
	var rows [][]string
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) >= 3 {
			date := fields[0]
			time := fields[1]
			bucketName := fields[2]
			rows = append(rows, []string{bucketName, date, time})
		}
	}

	// Render using common table utility
	views.RenderTable(views.TableConfig{
		Headers: []string{"Bucket Name", "Created Date", "Created Time"},
		Rows:    rows,
	})
}
