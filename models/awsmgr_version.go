package models

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

const Version = "Preview Beta 1"

// VersionInfo holds version and OS information
type VersionInfo struct {
	Version string `json:"version"`
	OS      string `json:"-"` // Hidden from JSON, used for backend logic
	OSName  string `json:"os_name"`
}

// GetVersion returns version and OS information
func GetVersion() VersionInfo {
	osInfo := runtime.GOOS
	osName := getOSDetail(osInfo)

	// Fetch version from GitHub JSON
	version := fetchVersionFromGitHub(osInfo)

	// If fetch failed or empty, use hardcoded version as fallback
	if version == "" {
		version = Version
	}

	return VersionInfo{
		Version: version,
		OS:      osInfo,
		OSName:  osName,
	}
}

// GitHubVersionData represents the version.json structure from GitHub
type GitHubVersionData struct {
	TUI struct {
		Version string `json:"version"`
	} `json:"tui"`
	Linux struct {
		Version string `json:"version"`
	} `json:"linux"`
	Windows struct {
		Version string `json:"version"`
	} `json:"windows"`
	Android struct {
		Version string `json:"version"`
	} `json:"android"`
}

// fetchVersionFromGitHub fetches the version from GitHub JSON based on OS
func fetchVersionFromGitHub(osInfo string) string {
	const githubURL = "https://raw.githubusercontent.com/DragonEmperor9480/aws-manager/awsmgr-gui/version.json"

	// Create HTTP client with timeout
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Get(githubURL)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return ""
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return ""
	}

	var versionData GitHubVersionData
	if err := json.Unmarshal(body, &versionData); err != nil {
		return ""
	}

	// Return version based on OS
	switch osInfo {
	case "linux":
		return versionData.Linux.Version
	case "windows":
		return versionData.Windows.Version
	case "android":
		return versionData.Android.Version
	default:
		return versionData.TUI.Version
	}
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
