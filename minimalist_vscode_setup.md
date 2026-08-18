# Minimalist VSCode Setup

> Setup ini sangat terinspirasi dari video YouTube content creator Igor Babko: https://youtu.be/VmFOsK7IhI4?si=-tXqEoiuyIoXfeXo

---

## Prasyarat & Ekstensi

Sebelum menerapkan konfigurasi JSON, pastikan untuk menyiapkan font dan beberapa ekstensi pendukung berikut:

### 1. Font (Opsional)
* JetBrains Mono: Unduh melalui situs resmi https://www.jetbrains.com/lp/mono/.

**Panduan Instalasi Font:**
* **Windows:** Ekstrak file ZIP yang telah diunduh, buka folder `ttf`, pilih semua file font (`.ttf`), klik kanan, lalu pilih **Install** (atau **Install for all users**).
* **macOS:** Ekstrak file ZIP, buka folder `ttf`, klik ganda pada file font, lalu klik **Install Font** di jendela Font Book.
* **Linux:** Ekstrak file ZIP dan pindahkan file `.ttf` ke direktori `~/.local/share/fonts/` (atau `/usr/local/share/fonts/` untuk sistem), kemudian jalankan perintah `fc-cache -fv` di terminal.

*Setelah font terinstall, restart VSCode agar font terdeteksi dengan sempurna.*

### 2. Ekstensi VSCode
Buka tab Extensions (Ctrl + Shift + X / Cmd + Shift + X) lalu install ekstensi berikut:

* Custom UI Style by subframe7536
* Error Lens by Alexander
* Material Icon Theme by Philipp Kief
* Bracket Lens by wraith13
* PDF Viewer by Mathematic Inc
* Image Viewer by Easy VSCode

Untuk tema VSCode (opsional/bebas) rekomendasi nya:
* Aura Spirit Dracula by JoseMurilloc
* codeSTACKr Theme by codestackckr
* Level Up Theme Official by leveluptutorials

---

## Cara Mengubah Konfigurasi

1. Buka Command Palette (Ctrl + Shift + P / Cmd + Shift + P).
2. Cari dan pilih `Preferences: Open User Settings (JSON)`.
3. Salin dan tempel (paste) kode konfigurasi di bawah ini ke dalam file tersebut
4. Restart VSCode

```json
{
  // --- Workbench & Layout Minimalis ---
  "workbench.colorTheme": "Level Up",
  "workbench.iconTheme": "material-icon-theme",
  "workbench.startupEditor": "none",
  "workbench.tips.enabled": false,
  "workbench.activityBar.location": "hidden",
  "workbench.statusBar.visible": false,
  "workbench.sideBar.location": "right",
  "workbench.editor.showTabs": "single",
  "breadcrumbs.enabled": false,

  // --- Window & Titlebar ---
  "window.zoomLevel": 1.5,
  "window.menuBarVisibility": "toggle",
  "window.customTitleBarVisibility": "never",
  "window.titleBarStyle": "native",
  "window.autoDetectColorScheme": true,
  "workbench.preferredDarkColorTheme": "codeSTACKr Theme (Muted)",

  // --- Custom UI Style (Extension) ---
  "custom-ui-style.electron": {
    "titleBarStyle": "hiddenInset",
    "trafficLightPosition": {
      "x": 20,
      "y": 16
    }
  },
  "custom-ui-style.font.sansSerif": "JetBrains Mono",
  "custom-ui-style.stylesheet": {
    ".notification-toast": "box-shadow: none !important",
    ".quick-input-widget.show-file-icons": "box-shadow: none !important",
    ".quick-input-widget": "top: 25vh !important",
    ".quick-input-list .scrollbar": "display: none",
    ".monaco-action-bar.quick-input-inline-action-bar": "display: none",
    ".editor-widget.find-widget": "box-shadow: none; border-radius: 4px",
    ".quick-input-titlebar": "background: #100B15 !important",
    ".monaco-workbench .part.editor > .content .editor-group-container > .title.title-border-bottom:after": "display: none",
    ".monaco-scrollable-element > .shadow.top": "display: none",
    ".sidebar .title-label": "padding: 0 !important",
    ".sidebar": "border: none !important",
    ".monaco-workbench .monaco-list:not(.element-focused):focus:before": "outline: none !important",
    ".monaco-list-row.focused": "outline: none !important",
    ".monaco-editor .scroll-decoration": "display: none",
    ".title-actions": "display: none !important",
    ".title.show-file-icons .label-container .monaco-icon-label.file-icon": "justify-content: center; padding: 0 !important",
    ".title .monaco-icon-label:after": "margin-right: 0",
    ".monaco-workbench .part.editor > .content .editor-group-container > .title > .label-container > .title-label": "padding-left: 60px",
    ".title .monaco-icon-label.file-icon": "margin: 0 60px",
    ".monaco-editor .cursors-layer .cursor": "background-image: linear-gradient(135deg, #ffaffc 10%, #DA70D6 100%)"
  },

  // --- Typography & Cursor ---
  "editor.fontFamily": "'JetBrains Mono', Dank Mono",
  "editor.fontSize": 14,
  "editor.fontLigatures": true,
  "editor.lineHeight": 2.5,
  "editor.cursorStyle": "block",
  "editor.cursorBlinking": "solid",

  // --- Hide Editor Distractions ---
  "editor.minimap.enabled": false,
  "editor.lineNumbers": "relative",
  "editor.showFoldingControls": "never",
  "editor.guides.indentation": false,
  "editor.guides.bracketPairs": false,
  "editor.renderWhitespace": "none",
  "editor.renderLineHighlight": "none",
  "editor.occurrencesHighlight": "off",
  "editor.selectionHighlight": false,
  "editor.matchBrackets": "never",
  "editor.scrollbar.horizontal": "hidden",
  "editor.scrollbar.vertical": "hidden",
  "editor.overviewRulerBorder": false,
  "editor.hideCursorInOverviewRuler": true,
  "editor.stickyScroll.enabled": false,
  "editor.colorDecorators": false,
  "editor.codeLens": false,
  "editor.links": false,
  "editor.parameterHints.enabled": false,
  "editor.lightbulb.enabled": "off",
  "editor.hover.enabled": "off",
  "editor.inlayHints.enabled": "off",
  "editor.wordWrap": "off",
  "diffEditor.wordWrap": "off",

  // --- Explorer & Tree Styling ---
  "material-icon-theme.hidesExplorerArrows": true,
  "workbench.tree.enableStickyScroll": false,
  "workbench.tree.renderIndentGuides": "none",
  "workbench.tree.indent": 8,
  "explorer.compactFolders": false,
  "explorer.decorations.badges": false,
  "git.decorations.enabled": false,

  // --- Theme & Token Color Customizations ---
  "editor.tokenColorCustomizations": {
    "textMateRules": [
      {
        "scope": "comment",
        "settings": {
          "fontStyle": "italic"
        }
      }
    ]
  },
  "workbench.colorCustomizations": {
    "editorCursor.background": "#000000",
    "editorOverviewRuler.wordHighlightStrongForeground": "#0000",
    "editorOverviewRuler.selectionHighlightForeground": "#0000",
    "editorOverviewRuler.rangeHighlightForeground": "#0000",
    "editorOverviewRuler.wordHighlightForeground": "#0000",
    "editorOverviewRuler.bracketMatchForeground": "#0000",
    "editorOverviewRuler.findMatchForeground": "#0000",
    "editorOverviewRuler.modifiedForeground": "#0000",
    "editorOverviewRuler.deletedForeground": "#0000",
    "editorOverviewRuler.warningForeground": "#0000",
    "editorOverviewRuler.addedForeground": "#0000",
    "editorOverviewRuler.errorForeground": "#0000",
    "editorOverviewRuler.infoForeground": "#0000",
    "editorOverviewRuler.border": "#0000",
    "[Aura Dracula Spirit (Soft)]": {
      "editorSuggestWidget.selectedBackground": "#3A334B",
      "sideBar.background": "#191521"
    },
    "editor.lineHighlightBackground": "#1073cf2d",
    "editor.lineHighlightBorder": "#9fced11f"
  },

  // --- ErrorLens (Visual Error Styling) ---
  "errorLens.followCursor": "activeLine",
  "errorLens.removeLinebreaks": false,
  "errorLens.gutterIconsEnabled": true,
  "errorLens.statusBarColorsEnabled": true,
  "errorLens.messageBackgroundMode": "message",
  "errorLens.editorHoverPartsEnabled": {
    "messageEnabled": false,
    "sourceCodeEnabled": false,
    "buttonsEnabled": false
  },
  "errorLens.borderRadius": "0.4em",
  "errorLens.fontStyleItalic": true,
  "errorLens.fontWeight": "300",
  "errorLens.respectUpstreamEnabled": {
    "statusBar": true
  },
  "errorLens.statusBarIconsEnabled": true,

  // --- Terminal Settings ---
  "terminal.integrated.defaultLocation": "editor",
  "terminal.integrated.defaultProfile.windows": "Command Prompt",
  "terminal.integrated.profiles.windows": {
    "PowerShell": {
      "source": "PowerShell",
      "icon": "terminal-powershell"
    },
    "Command Prompt": {
      "path": [
        "${env:windir}\\Sysnative\\cmd.exe",
        "${env:windir}\\System32\\cmd.exe"
      ],
      "args": [],
      "icon": "terminal-cmd"
    },
    "Git Bash": {
      "path": "C:\\Program Files\\Git\\bin\\bash.exe",
      "args": [
        "--login",
        "-i"
      ]
    }
  }
}
