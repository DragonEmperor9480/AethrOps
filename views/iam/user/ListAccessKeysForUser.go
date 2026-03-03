package userview

import (
	"encoding/json"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
)

type AccessKeyMetadata struct {
	AccessKeyId string `json:"AccessKeyId"`
	Status      string `json:"Status"`
	CreateDate  string `json:"CreateDate"`
}

type ListAccessKeysOutput struct {
	AccessKeyMetadata []AccessKeyMetadata `json:"AccessKeyMetadata"`
}

func ListAccessKeysForUserView(output string) {
	var result ListAccessKeysOutput

	if len(result.AccessKeyMetadata) == 0 {
		fmt.Println(utils.Yellow + utils.Bold + "No access keys found for this user." + utils.Reset)
		utils.Bk()
		return

	}
	err := json.Unmarshal([]byte(output), &result)
	if err != nil {
		fmt.Println(utils.Bold + utils.Red + "Error parsing access keys list output:" + utils.Reset)
		fmt.Println(err)
		return
	}

	fmt.Println()
	fmt.Println(utils.Bold + "┌──────────────────────────────┬────────────┬────────────────────────────┐" + utils.Reset)
	fmt.Println(utils.Bold + "│        Access Key ID         │   Status   │         Created At         │" + utils.Reset)
	fmt.Println(utils.Bold + "├──────────────────────────────┼────────────┼────────────────────────────┤" + utils.Reset)

	for _, key := range result.AccessKeyMetadata {
		accessKeyID := key.AccessKeyId
		status := key.Status
		createDate := key.CreateDate

		// Format consistently like your other table
		fmt.Printf(utils.Bold+"│ %-28s │ %-10s │ %-26s │"+utils.Reset+"\n",
			accessKeyID, status, createDate)
	}

	fmt.Println(utils.Bold + "└──────────────────────────────┴────────────┴────────────────────────────┘" + utils.Reset)
	utils.Bk()
}
