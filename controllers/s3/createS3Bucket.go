package s3

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	s3model "github.com/DragonEmperor9480/AethrOps/models/s3"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func CreateS3Bucket() {

	reader := bufio.NewReader(os.Stdin)
	fmt.Println("Enter a unique bucket name:")
	input, _ := reader.ReadString('\n')
	bucketname := strings.TrimSpace(input)

	if utils.InputChecker(bucketname) {
		s3model.CreateS3BucketModel(bucketname)
	}

}
