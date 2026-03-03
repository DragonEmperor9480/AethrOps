package userview

import (
	"encoding/json"
	"fmt"

	utils "github.com/DragonEmperor9480/AethrOps/utils"
)

type AccessKeyOutput struct {
	AccessKey struct {
		AccessKeyId     string `json:"AccessKeyId"`
		SecretAccessKey string `json:"SecretAccessKey"`
	} `json:"AccessKey"`
}

func ShowAccessKeyView(output string) (string, string) {
	var result AccessKeyOutput
	err := json.Unmarshal([]byte(output), &result)
	if err != nil {
		fmt.Println("Error parsing access key output:", err)
		return "", ""
	}
	fmt.Println(utils.Bold + utils.Green + "\nAccess Key Created Successfully!" + utils.Reset)
	fmt.Println("Access Key ID:      ", result.AccessKey.AccessKeyId)
	fmt.Println("Secret Access Key:  ", result.AccessKey.SecretAccessKey)
	return result.AccessKey.AccessKeyId, result.AccessKey.SecretAccessKey
}
