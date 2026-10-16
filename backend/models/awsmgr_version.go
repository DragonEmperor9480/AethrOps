package models

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"time"
)

var Version = "placeholder for version"
var BuildNumberStr = "1"

// VersionInfo holds version and OS information
type VersionInfo struct {
	Version     string `json:"version"`
	OS          string `json:"-"` // Hidden from JSON, used for backend logic
	OSName      string `json:"os_name"`
	BuildNumber int    `json:"build_number"`
}

// GetVersion returns version and OS information
func GetVersion() VersionInfo {
	osInfo := runtime.GOOS
	osName := getOSDetail(osInfo)

	buildNumber := 1
	if parsed, err := strconv.Atoi(BuildNumberStr); err == nil {
		buildNumber = parsed
	}

	return VersionInfo{
		Version:     Version,
		OS:          osInfo,
		OSName:      osName,
		BuildNumber: buildNumber,
	}
}

// PlatformData represents the version and build number of a platform
type PlatformData struct {
	Version     string `json:"version"`
	BuildNumber int    `json:"build_number"`
}

// GitHubVersionData represents the version.json structure from GitHub
// GitHubVersionData represents the version.json structure from GitHub
type GitHubVersionData struct {
	Linux   PlatformData `json:"linux"`
	Windows PlatformData `json:"windows"`
	Android PlatformData `json:"android"`
}

// UpdateCheckResponse represents the JSON payload returned to the frontend
type UpdateCheckResponse struct {
	UpdateAvailable    bool   `json:"update_available"`
	LatestVersion      string `json:"latest_version"`
	LatestBuildNumber  int    `json:"latest_build_number"`
	CurrentVersion     string `json:"current_version"`
	CurrentBuildNumber int    `json:"current_build_number"`
}

// CheckForUpdates queries GitHub's version.json and performs the build number comparison
func CheckForUpdates() (UpdateCheckResponse, error) {
	current := GetVersion()

	const githubURL = "https://raw.githubusercontent.com/DragonEmperor9480/AethrOps/refs/heads/master/version.json"

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Get(githubURL)
	if err != nil {
		return UpdateCheckResponse{}, fmt.Errorf("failed to reach update server: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return UpdateCheckResponse{}, fmt.Errorf("update server returned %s", resp.Status)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return UpdateCheckResponse{}, fmt.Errorf("failed to read version data: %w", err)
	}

	var versionData GitHubVersionData
	if err := json.Unmarshal(body, &versionData); err != nil {
		return UpdateCheckResponse{}, fmt.Errorf("invalid version data: %w", err)
	}

	var remote PlatformData
	switch current.OS {
	case "linux":
		remote = versionData.Linux
	case "windows":
		remote = versionData.Windows
	case "android":
		remote = versionData.Android
	default:
		// Fallback default to Linux metadata
		remote = versionData.Linux
	}

	// A missing platform entry would otherwise read as build 0, i.e. "up to date"
	if remote.BuildNumber <= 0 {
		return UpdateCheckResponse{}, fmt.Errorf("version data has no build number for %s", current.OS)
	}

	updateAvailable := remote.BuildNumber > current.BuildNumber

	return UpdateCheckResponse{
		UpdateAvailable:    updateAvailable,
		LatestVersion:      remote.Version,
		LatestBuildNumber:  remote.BuildNumber,
		CurrentVersion:     current.Version,
		CurrentBuildNumber: current.BuildNumber,
	}, nil
}

func getOSDetail(osInfo string) string {
	switch osInfo {
	case "windows":
		return "Windows"
	case "darwin":
		cmd := exec.Command("sw_vers", "-productVersion")
		output, err := cmd.Output()
		if err == nil {
			versionStr := strings.TrimSpace(string(output))
			return "MacOS " + versionStr
		}
		return "MacOS"
	case "linux":
		data, err := os.ReadFile("/etc/os-release")
		if err == nil {
			lines := strings.Split(string(data), "\n")
			for _, line := range lines {
				if strings.HasPrefix(line, "PRETTY_NAME=") {
					return strings.Trim(line[12:], "\"")
				}
			}
		}
		return "Linux"
	default:
		return osInfo
	}
}
