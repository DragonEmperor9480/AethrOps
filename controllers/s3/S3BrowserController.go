package s3

import (
	"fmt"
	"path/filepath"
	"strings"
	"time"

	s3model "github.com/DragonEmperor9480/AethrOps/models/s3"
	s3view "github.com/DragonEmperor9480/AethrOps/views/s3"
	"github.com/gdamore/tcell/v2"
)

type S3Browser struct {
	screen          tcell.Screen
	bucketName      string
	currentPath     string
	items           []s3model.S3Item
	selectedIndex   int
	statusMsg       string
	inputMode       bool
	inputBuffer     string
	inputPrompt     string
	inputCallback   func(string)
	progressMode    bool
	progressCurrent int64
	progressTotal   int64
	progressMessage string
	loadingMode     bool
	loadingMessage  string
	loadingFrame    int
}

func NewS3Browser(bucketName string) (*S3Browser, error) {
	screen, err := tcell.NewScreen()
	if err != nil {
		return nil, err
	}

	if err := screen.Init(); err != nil {
		return nil, err
	}

	return &S3Browser{
		screen:      screen,
		bucketName:  bucketName,
		currentPath: "",
		statusMsg:   "Ready",
	}, nil
}

func (b *S3Browser) Run() error {
	defer b.screen.Fini()

	// Load initial items
	if err := b.loadItems(); err != nil {
		return err
	}

	// Event loop
	for {
		b.render()

		ev := b.screen.PollEvent()
		switch ev := ev.(type) {
		case *tcell.EventKey:
			if b.handleKeyEvent(ev) {
				return nil // Exit
			}
		case *tcell.EventResize:
			b.screen.Sync()
		}
	}
}

func (b *S3Browser) loadItems() error {
	items, err := s3model.ListS3ItemsWithPrefix(b.bucketName, b.currentPath)
	if err != nil {
		b.statusMsg = fmt.Sprintf("Error: %v", err)
		return err
	}

	b.items = items
	b.selectedIndex = 0
	b.statusMsg = fmt.Sprintf("Loaded %d items", len(items))
	return nil
}

func (b *S3Browser) render() {
	if b.progressMode {
		s3view.RenderProgressDialog(b.screen, b.progressMessage, b.progressCurrent, b.progressTotal)
	} else if b.loadingMode {
		s3view.RenderLoadingDialog(b.screen, b.loadingMessage, b.loadingFrame)
	} else if b.inputMode {
		s3view.RenderInputDialog(b.screen, b.inputPrompt, b.inputBuffer)
	} else {
		s3view.RenderS3Browser(b.screen, b.items, b.selectedIndex, b.currentPath, b.bucketName, b.statusMsg)
	}
}

func (b *S3Browser) handleKeyEvent(ev *tcell.EventKey) bool {
	// Handle input mode separately
	if b.inputMode {
		return b.handleInputMode(ev)
	}

	switch ev.Key() {
	case tcell.KeyUp:
		if b.selectedIndex > 0 {
			b.selectedIndex--
		}
	case tcell.KeyDown:
		if b.selectedIndex < len(b.items)-1 {
			b.selectedIndex++
		}
	case tcell.KeyEnter:
		b.openItem()
	case tcell.KeyBackspace, tcell.KeyBackspace2:
		b.goBack()
	case tcell.KeyCtrlD:
		b.downloadItem()
	case tcell.KeyCtrlU:
		b.uploadFile()
	case tcell.KeyCtrlN:
		b.createFolder()
	case tcell.KeyCtrlX:
		b.deleteItem()
	case tcell.KeyRune:
		if ev.Rune() == 'q' || ev.Rune() == 'Q' {
			return true // Exit
		}
	case tcell.KeyEscape:
		return true // Exit
	}
	return false
}

func (b *S3Browser) handleInputMode(ev *tcell.EventKey) bool {
	switch ev.Key() {
	case tcell.KeyEnter:
		// Submit input
		if b.inputCallback != nil {
			b.inputCallback(b.inputBuffer)
		}
		b.inputMode = false
		b.inputBuffer = ""
		b.inputPrompt = ""
		b.inputCallback = nil
	case tcell.KeyEscape:
		// Cancel input
		b.inputMode = false
		b.inputBuffer = ""
		b.inputPrompt = ""
		b.inputCallback = nil
		b.statusMsg = "Cancelled"
	case tcell.KeyBackspace, tcell.KeyBackspace2:
		// Remove last character
		if len(b.inputBuffer) > 0 {
			b.inputBuffer = b.inputBuffer[:len(b.inputBuffer)-1]
		}
	case tcell.KeyRune:
		// Add character to buffer
		b.inputBuffer += string(ev.Rune())
	}
	return false
}

func (b *S3Browser) openItem() {
	if len(b.items) == 0 || b.selectedIndex >= len(b.items) {
		return
	}

	item := b.items[b.selectedIndex]
	if item.IsFolder {
		b.currentPath = item.Key
		b.loadItems()
	}
}

func (b *S3Browser) goBack() {
	if b.currentPath == "" {
		return
	}

	// Remove last folder from path
	parts := strings.Split(strings.TrimSuffix(b.currentPath, "/"), "/")
	if len(parts) > 1 {
		b.currentPath = strings.Join(parts[:len(parts)-1], "/") + "/"
	} else {
		b.currentPath = ""
	}
	b.loadItems()
}

func (b *S3Browser) downloadItem() {
	if len(b.items) == 0 || b.selectedIndex >= len(b.items) {
		return
	}

	item := b.items[b.selectedIndex]
	if item.IsFolder {
		b.statusMsg = "Cannot download folders"
		return
	}

	fileName := filepath.Base(item.Key)
	downloadPath := filepath.Join(".", fileName)

	// Enable progress mode
	b.progressMode = true
	b.progressCurrent = 0
	b.progressTotal = item.Size
	b.progressMessage = fmt.Sprintf("Downloading: %s", fileName)
	b.render()

	// Download with progress callback
	err := s3model.DownloadS3ObjectToFileWithProgress(b.bucketName, item.Key, downloadPath, func(current, total int64) {
		b.progressCurrent = current
		b.progressTotal = total
		b.render()
	})

	// Disable progress mode
	b.progressMode = false

	if err != nil {
		b.statusMsg = fmt.Sprintf("Download failed: %v", err)
	} else {
		b.statusMsg = fmt.Sprintf("Downloaded: %s", downloadPath)
	}
}

func (b *S3Browser) uploadFile() {
	b.inputMode = true
	b.inputPrompt = "Enter local file path to upload:"
	b.inputBuffer = ""
	b.inputCallback = func(filePath string) {
		if filePath == "" {
			b.statusMsg = "Upload cancelled - empty path"
			return
		}

		// Determine the S3 key (path in bucket)
		fileName := filepath.Base(filePath)
		objectKey := b.currentPath + fileName

		// Enable progress mode
		b.progressMode = true
		b.progressCurrent = 0
		b.progressTotal = 0
		b.progressMessage = fmt.Sprintf("Uploading: %s", fileName)
		b.render()

		// Upload with progress callback
		err := s3model.UploadS3ObjectWithProgress(b.bucketName, objectKey, filePath, func(current, total int64) {
			b.progressCurrent = current
			b.progressTotal = total
			b.render()
		})

		// Disable progress mode
		b.progressMode = false

		if err != nil {
			b.statusMsg = fmt.Sprintf("Upload failed: %v", err)
		} else {
			b.statusMsg = fmt.Sprintf("Uploaded: %s", fileName)
			b.loadItems()
		}
	}
}

func (b *S3Browser) createFolder() {
	b.inputMode = true
	b.inputPrompt = "Enter folder name:"
	b.inputBuffer = ""
	b.inputCallback = func(folderName string) {
		if folderName == "" {
			b.statusMsg = "Cancelled - empty folder name"
			return
		}

		// Show loading message
		b.loadingMode = true
		b.loadingMessage = fmt.Sprintf("Creating folder: %s", folderName)
		b.loadingFrame = 0

		// Create folder in goroutine with animation
		done := make(chan error, 1)
		go func() {
			folderPath := b.currentPath + folderName
			done <- s3model.CreateS3Folder(b.bucketName, folderPath)
		}()

		// Animate while waiting (with timeout)
		ticker := time.NewTicker(80 * time.Millisecond)
		defer ticker.Stop()

		timeout := time.After(10 * time.Second)

		for {
			select {
			case err := <-done:
				b.loadingMode = false
				if err != nil {
					b.statusMsg = fmt.Sprintf("Create folder failed: %v", err)
				} else {
					b.statusMsg = fmt.Sprintf("Created folder: %s", folderName)
					b.loadItems()
				}
				return
			case <-ticker.C:
				b.loadingFrame++
				b.render()
			case <-timeout:
				b.loadingMode = false
				b.statusMsg = "Create folder timed out"
				return
			}
		}
	}
}

func (b *S3Browser) deleteItem() {
	if len(b.items) == 0 || b.selectedIndex >= len(b.items) {
		return
	}

	item := b.items[b.selectedIndex]

	b.statusMsg = fmt.Sprintf("Deleting %s...", item.Key)
	b.render()

	err := s3model.DeleteS3Object(b.bucketName, item.Key)
	if err != nil {
		b.statusMsg = fmt.Sprintf("Delete failed: %v", err)
	} else {
		b.statusMsg = fmt.Sprintf("Deleted: %s", item.Key)
		b.loadItems()
	}
}
