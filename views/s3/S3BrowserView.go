package s3

import (
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/models/s3"
	"github.com/gdamore/tcell/v2"
)

// RenderS3Browser renders the S3 file browser UI
func RenderS3Browser(screen tcell.Screen, items []s3.S3Item, selectedIndex int, currentPath, bucketName, statusMsg string) {
	screen.Clear()
	width, height := screen.Size()

	// Header with gradient-like effect
	headerStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorSilver).Bold(true)
	header := fmt.Sprintf(" 📦 S3 Browser - Bucket: %s ", bucketName)
	drawText(screen, 0, 0, width, headerStyle, header)

	// Current path with better color
	pathStyle := tcell.StyleDefault.Background(tcell.ColorTeal).Foreground(tcell.ColorWhite).Bold(true)
	pathText := fmt.Sprintf(" 📂 Path: /%s ", currentPath)
	drawText(screen, 0, 1, width, pathStyle, pathText)

	// Column headers with improved styling
	headerRowStyle := tcell.StyleDefault.Background(tcell.ColorGray).Foreground(tcell.ColorBlack).Bold(true)
	drawText(screen, 0, 3, width, headerRowStyle, fmt.Sprintf(" %-50s %-15s %-20s", "Name", "Size", "Modified"))

	// Items list
	startY := 4
	visibleHeight := height - 7 // Reserve space for header, footer, status

	for i, item := range items {
		if i >= visibleHeight {
			break
		}

		y := startY + i
		style := tcell.StyleDefault

		// Highlight selected item with better colors
		if i == selectedIndex {
			style = style.Background(tcell.ColorPurple).Foreground(tcell.ColorWhite).Bold(true)
		}

		// Icon and name with better folder color
		icon := "📄"
		if item.IsFolder {
			icon = "📁"
			if i != selectedIndex {
				style = style.Foreground(tcell.ColorOlive).Bold(true)
			}
		} else if i != selectedIndex {
			style = style.Foreground(tcell.ColorSilver)
		}

		name := item.Key
		if strings.Contains(name, "/") {
			parts := strings.Split(strings.TrimSuffix(name, "/"), "/")
			name = parts[len(parts)-1]
			if item.IsFolder {
				name += "/"
			}
		}

		// Format size
		sizeStr := ""
		if !item.IsFolder {
			sizeStr = formatSize(item.Size)
		}

		line := fmt.Sprintf(" %s %-48s %-15s %-20s", icon, truncate(name, 48), sizeStr, item.LastModified)
		drawText(screen, 0, y, width, style, line)
	}

	// Help bar with high contrast
	helpY := height - 3
	helpStyle := tcell.StyleDefault.Background(tcell.ColorBlack).Foreground(tcell.ColorWhite).Bold(true)
	help := " ↑↓:Nav | Enter:Open | Back:← | ^D:Download | ^U:Upload | ^N:Folder | ^X:Del | Q:Quit "
	drawText(screen, 0, helpY, width, helpStyle, centerText(help, width))

	// Status bar with dynamic colors
	statusY := height - 1
	statusStyle := tcell.StyleDefault.Background(tcell.ColorGreen).Foreground(tcell.ColorBlack).Bold(true)
	if strings.Contains(statusMsg, "Error") || strings.Contains(statusMsg, "Failed") || strings.Contains(statusMsg, "failed") {
		statusStyle = tcell.StyleDefault.Background(tcell.ColorMaroon).Foreground(tcell.ColorWhite).Bold(true)
	} else if strings.Contains(statusMsg, "Downloading") || strings.Contains(statusMsg, "Uploading") || strings.Contains(statusMsg, "Creating") {
		statusStyle = tcell.StyleDefault.Background(tcell.ColorOlive).Foreground(tcell.ColorWhite).Bold(true)
	}
	drawText(screen, 0, statusY, width, statusStyle, fmt.Sprintf(" ⚡ %s ", statusMsg))

	screen.Show()
}

// Helper functions
func drawText(screen tcell.Screen, x, y, maxWidth int, style tcell.Style, text string) {
	for i, r := range text {
		if x+i >= maxWidth {
			break
		}
		screen.SetContent(x+i, y, r, nil, style)
	}
	// Fill remaining space
	for i := len(text); i < maxWidth; i++ {
		screen.SetContent(x+i, y, ' ', nil, style)
	}
}

func formatSize(size int64) string {
	if size < 1024 {
		return fmt.Sprintf("%d B", size)
	} else if size < 1024*1024 {
		return fmt.Sprintf("%.1f KB", float64(size)/1024)
	} else if size < 1024*1024*1024 {
		return fmt.Sprintf("%.1f MB", float64(size)/(1024*1024))
	}
	return fmt.Sprintf("%.1f GB", float64(size)/(1024*1024*1024))
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}

func centerText(text string, width int) string {
	if len(text) >= width {
		return text
	}
	padding := (width - len(text)) / 2
	return strings.Repeat(" ", padding) + text
}

// ShowMessage displays a message dialog
func ShowMessage(screen tcell.Screen, title, message string) {
	width, height := screen.Size()

	boxWidth := 60
	boxHeight := 8
	startX := (width - boxWidth) / 2
	startY := (height - boxHeight) / 2

	// Draw box with better colors
	boxStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorSilver)
	borderStyle := tcell.StyleDefault.Background(tcell.ColorPurple).Foreground(tcell.ColorWhite).Bold(true)

	// Border
	for y := startY; y < startY+boxHeight; y++ {
		for x := startX; x < startX+boxWidth; x++ {
			if y == startY || y == startY+boxHeight-1 || x == startX || x == startX+boxWidth-1 {
				screen.SetContent(x, y, ' ', nil, borderStyle)
			} else {
				screen.SetContent(x, y, ' ', nil, boxStyle)
			}
		}
	}

	// Title
	drawText(screen, startX, startY, boxWidth, borderStyle, centerText(title, boxWidth))

	// Message
	drawText(screen, startX+2, startY+3, boxWidth-4, boxStyle, message)

	// Footer
	drawText(screen, startX, startY+boxHeight-1, boxWidth, borderStyle, centerText("Press any key to continue", boxWidth))

	screen.Show()
}

// RenderInputDialog renders an input dialog box
func RenderInputDialog(screen tcell.Screen, prompt, input string) {
	screen.Clear()
	width, height := screen.Size()

	boxWidth := 70
	boxHeight := 10
	startX := (width - boxWidth) / 2
	startY := (height - boxHeight) / 2

	// Draw box background with better colors
	boxStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorSilver)
	borderStyle := tcell.StyleDefault.Background(tcell.ColorPurple).Foreground(tcell.ColorWhite).Bold(true)

	// Border
	for y := startY; y < startY+boxHeight; y++ {
		for x := startX; x < startX+boxWidth; x++ {
			if y == startY || y == startY+boxHeight-1 || x == startX || x == startX+boxWidth-1 {
				screen.SetContent(x, y, ' ', nil, borderStyle)
			} else {
				screen.SetContent(x, y, ' ', nil, boxStyle)
			}
		}
	}

	// Title
	drawText(screen, startX, startY, boxWidth, borderStyle, centerText(" Input ", boxWidth))

	// Prompt
	drawText(screen, startX+2, startY+2, boxWidth-4, boxStyle, prompt)

	// Input field with better contrast
	inputStyle := tcell.StyleDefault.Background(tcell.ColorWhite).Foreground(tcell.ColorBlack).Bold(true)
	inputY := startY + 4
	inputFieldWidth := boxWidth - 4

	// Draw input field background
	for x := startX + 2; x < startX+2+inputFieldWidth; x++ {
		screen.SetContent(x, inputY, ' ', nil, inputStyle)
	}

	// Draw input text
	for i, r := range input {
		if i >= inputFieldWidth-1 {
			break
		}
		screen.SetContent(startX+2+i, inputY, r, nil, inputStyle)
	}

	// Draw cursor with high visibility
	cursorX := startX + 2 + len(input)
	if cursorX < startX+2+inputFieldWidth {
		cursorStyle := tcell.StyleDefault.Background(tcell.ColorYellow).Foreground(tcell.ColorBlack).Bold(true)
		screen.SetContent(cursorX, inputY, '█', nil, cursorStyle)
	}

	// Help text with better visibility
	helpStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorWhite)
	helpText := "Press Enter to submit, Esc to cancel"
	for i, r := range helpText {
		if i >= boxWidth-4 {
			break
		}
		screen.SetContent(startX+2+i, startY+6, r, nil, helpStyle)
	}

	screen.Show()
}

// RenderProgressDialog renders a progress bar dialog
func RenderProgressDialog(screen tcell.Screen, message string, current, total int64) {
	screen.Clear()
	width, height := screen.Size()

	boxWidth := 70
	boxHeight := 12
	startX := (width - boxWidth) / 2
	startY := (height - boxHeight) / 2

	// Draw box background with better colors
	boxStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorSilver)
	borderStyle := tcell.StyleDefault.Background(tcell.ColorPurple).Foreground(tcell.ColorWhite).Bold(true)

	// Border
	for y := startY; y < startY+boxHeight; y++ {
		for x := startX; x < startX+boxWidth; x++ {
			if y == startY || y == startY+boxHeight-1 || x == startX || x == startX+boxWidth-1 {
				screen.SetContent(x, y, ' ', nil, borderStyle)
			} else {
				screen.SetContent(x, y, ' ', nil, boxStyle)
			}
		}
	}

	// Title
	titleText := centerText(" Progress ", boxWidth)
	for i, r := range titleText {
		if i >= boxWidth {
			break
		}
		screen.SetContent(startX+i, startY, r, nil, borderStyle)
	}

	// Message
	messageWidth := boxWidth - 4
	for i, r := range message {
		if i >= messageWidth {
			break
		}
		screen.SetContent(startX+2+i, startY+2, r, nil, boxStyle)
	}

	// Calculate progress percentage
	percentage := float64(0)
	if total > 0 {
		percentage = float64(current) / float64(total) * 100
	}

	// Progress bar
	progressBarWidth := boxWidth - 8
	progressBarY := startY + 5
	filledWidth := int(float64(progressBarWidth) * percentage / 100)

	// Draw progress bar background with vibrant colors
	progressBgStyle := tcell.StyleDefault.Background(tcell.ColorGray).Foreground(tcell.ColorWhite)
	progressFillStyle := tcell.StyleDefault.Background(tcell.ColorLime).Foreground(tcell.ColorBlack).Bold(true)

	for x := 0; x < progressBarWidth; x++ {
		style := progressBgStyle
		if x < filledWidth {
			style = progressFillStyle
		}
		screen.SetContent(startX+4+x, progressBarY, ' ', nil, style)
	}

	// Progress text with high contrast
	progressTextStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorWhite).Bold(true)
	progressText := fmt.Sprintf("%.1f%% (%s / %s)", percentage, formatSize(current), formatSize(total))
	centeredProgress := centerText(progressText, boxWidth-4)
	for i, r := range centeredProgress {
		if i >= boxWidth-4 {
			break
		}
		screen.SetContent(startX+2+i, startY+7, r, nil, progressTextStyle)
	}

	// Help text with better visibility
	helpStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorWhite)
	helpText := centerText("Please wait...", boxWidth-4)
	for i, r := range helpText {
		if i >= boxWidth-4 {
			break
		}
		screen.SetContent(startX+2+i, startY+9, r, nil, helpStyle)
	}

	screen.Show()
}

// RenderLoadingDialog renders a loading animation dialog
func RenderLoadingDialog(screen tcell.Screen, message string, frame int) {
	screen.Clear()
	width, height := screen.Size()

	boxWidth := 60
	boxHeight := 10
	startX := (width - boxWidth) / 2
	startY := (height - boxHeight) / 2

	// Draw box background with better colors
	boxStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorSilver)
	borderStyle := tcell.StyleDefault.Background(tcell.ColorPurple).Foreground(tcell.ColorWhite).Bold(true)

	// Border
	for y := startY; y < startY+boxHeight; y++ {
		for x := startX; x < startX+boxWidth; x++ {
			if y == startY || y == startY+boxHeight-1 || x == startX || x == startX+boxWidth-1 {
				screen.SetContent(x, y, ' ', nil, borderStyle)
			} else {
				screen.SetContent(x, y, ' ', nil, boxStyle)
			}
		}
	}

	// Title
	titleText := centerText(" Loading ", boxWidth)
	for i, r := range titleText {
		if i >= boxWidth {
			break
		}
		screen.SetContent(startX+i, startY, r, nil, borderStyle)
	}

	// Message
	centeredMsg := centerText(message, boxWidth-4)
	for i, r := range centeredMsg {
		if i >= boxWidth-4 {
			break
		}
		screen.SetContent(startX+2+i, startY+2, r, nil, boxStyle)
	}

	// Loading animation (spinner) with high contrast
	spinnerFrames := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	spinner := spinnerFrames[frame%len(spinnerFrames)]

	spinnerStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorYellow).Bold(true)
	spinnerText := fmt.Sprintf("%s  Processing...  %s", spinner, spinner)
	centeredSpinner := centerText(spinnerText, boxWidth-4)
	for i, r := range centeredSpinner {
		if i >= boxWidth-4 {
			break
		}
		screen.SetContent(startX+2+i, startY+5, r, nil, spinnerStyle)
	}

	// Help text with better visibility
	helpStyle := tcell.StyleDefault.Background(tcell.ColorNavy).Foreground(tcell.ColorWhite)
	helpText := centerText("Please wait...", boxWidth-4)
	for i, r := range helpText {
		if i >= boxWidth-4 {
			break
		}
		screen.SetContent(startX+2+i, startY+7, r, nil, helpStyle)
	}

	screen.Show()
}
