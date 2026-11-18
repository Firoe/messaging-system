# ==============================================================================
# Messaging System  —  Secure Enterprise Chat Interface
# ==============================================================================
# Version: 1.1.0
# Description: A lightweight, secure internal messaging system built with PowerShell 
#              and WinForms. Uses network file shares for data persistence.
# Author: firoe172@gmail.com
# ==============================================================================

#region CONFIG & STATE

$ServerRoot   = "\\YOUR-SERVER\Messaging-System"
$ConfigPath   = Join-Path $ServerRoot "config\clients.json"
$ComputerName = $env:COMPUTERNAME
$ClientRoot   = Join-Path $ServerRoot "data\clients\$ComputerName"
$InboxPath    = Join-Path $ClientRoot "Inbox"
$ArchivePath  = Join-Path $ClientRoot "Archive"
$Heartbeat    = Join-Path $ClientRoot "heartbeat.json"
$LogsRoot     = Join-Path $ServerRoot "logs"

if (!(Test-Path $ConfigPath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "clients.json not found.`n$ConfigPath", "Messaging System",
        "OK", "Error")
    exit
}

if (!(Test-Path $ClientRoot)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Client folder not found for this PC:`n$ClientRoot", "Messaging System",
        "OK", "Error")
    exit
}

$Clients    = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$AllTargets = $Clients | Where-Object { $_.ComputerName -ne $ComputerName }

$script:selectedPeer   = ""
$script:sentCount      = 0
$script:failCount      = 0
$script:disposables    = [System.Collections.Generic.List[IDisposable]]::new()
$script:statusCache    = @{}
$script:lastSeenCache  = @{}
$script:unreadPeers    = @{}
$script:muteSound      = $false
$script:lastMsgDate    = ""

#endregion

#region PALETTE & CONSTANTS

$charEnvelope = [char]0x2709
$charDash     = [char]0x2014
$charCheck    = [char]0x2713
$charCross    = [char]0x2717

$navy1       = [System.Drawing.Color]::FromArgb(10, 18, 36)
$navy3       = [System.Drawing.Color]::FromArgb(22, 40, 68)
$gold        = [System.Drawing.Color]::FromArgb(201, 165, 61)
$goldHover   = [System.Drawing.Color]::FromArgb(180, 148, 48)
$bgMain      = [System.Drawing.Color]::FromArgb(237, 242, 248)
$cardBg      = [System.Drawing.Color]::White
$cardBorder  = [System.Drawing.Color]::FromArgb(215, 222, 232)
$txtPrimary  = [System.Drawing.Color]::FromArgb(20, 30, 48)
$txtSecond   = [System.Drawing.Color]::FromArgb(80, 96, 116)
$txtMuted    = [System.Drawing.Color]::FromArgb(140, 156, 176)
$accent      = [System.Drawing.Color]::FromArgb(56, 120, 210)
$successCol  = [System.Drawing.Color]::FromArgb(22, 163, 74)
$successBg   = [System.Drawing.Color]::FromArgb(220, 252, 231)
$successTxt  = [System.Drawing.Color]::FromArgb(21, 90, 48)
$errorCol    = [System.Drawing.Color]::FromArgb(220, 38, 38)
$errorBg     = [System.Drawing.Color]::FromArgb(254, 226, 226)
$errorTxt    = [System.Drawing.Color]::FromArgb(153, 27, 27)
$warnBg      = [System.Drawing.Color]::FromArgb(254, 243, 199)
$warnTxt     = [System.Drawing.Color]::FromArgb(133, 77, 14)
$listBg      = [System.Drawing.Color]::FromArgb(248, 250, 253)
$chatBg      = [System.Drawing.Color]::FromArgb(250, 252, 255)
$selectedBg  = [System.Drawing.Color]::FromArgb(228, 238, 252)
$selectedGlow = [System.Drawing.Color]::FromArgb(20, 56, 120, 210)

$deptColors = @{
    "IT"        = [System.Drawing.Color]::FromArgb(56, 120, 210)
    "HR"        = [System.Drawing.Color]::FromArgb(22, 163, 74)
    "ADMIN"     = [System.Drawing.Color]::FromArgb(139, 92, 246)
    "ACCT"      = [System.Drawing.Color]::FromArgb(234, 138, 16)
    "OPS"       = [System.Drawing.Color]::FromArgb(20, 184, 166)
    "MARKETING" = [System.Drawing.Color]::FromArgb(236, 72, 153)
}

#endregion

#region FONTS

function New-TrackedFont {
    param([string]$Family, [float]$Size, [string]$Style = "Regular")
    $f = New-Object System.Drawing.Font($Family, $Size, [System.Drawing.FontStyle]::$Style)
    $script:disposables.Add($f)
    return $f
}

$fntTitle     = New-TrackedFont "Segoe UI Semibold" 18
$fntHead      = New-TrackedFont "Segoe UI Semibold" 12
$fntSub       = New-TrackedFont "Segoe UI" 9
$fntCap       = New-TrackedFont "Segoe UI Semibold" 8
$fntCapNorm   = New-TrackedFont "Segoe UI" 8
$fntInput     = New-TrackedFont "Segoe UI" 10.5
$fntBtn       = New-TrackedFont "Segoe UI Semibold" 9
$fntBtnLg     = New-TrackedFont "Segoe UI Semibold" 10
$fntStatus    = New-TrackedFont "Segoe UI" 8.5
$fntList      = New-TrackedFont "Segoe UI" 9.5
$fntListBold  = New-TrackedFont "Segoe UI Semibold" 9.5
$fntListSm    = New-TrackedFont "Segoe UI" 7.5
$fntChat      = New-TrackedFont "Segoe UI" 10
$fntChatBold  = New-TrackedFont "Segoe UI Semibold" 10
$fntChatTime  = New-TrackedFont "Segoe UI" 8
$fntToast     = New-TrackedFont "Segoe UI Semibold" 9.5
$fntShortcut  = New-TrackedFont "Segoe UI" 7.5
$fntPeerName  = New-TrackedFont "Segoe UI Semibold" 13
$fntPeerDept  = New-TrackedFont "Segoe UI" 9
$fntGroupHdr  = New-TrackedFont "Segoe UI Semibold" 7.5
$fntEmptyLg   = New-TrackedFont "Segoe UI Semibold" 14
$fntEmptySm   = New-TrackedFont "Segoe UI" 9.5
$fntQuickReply = New-TrackedFont "Segoe UI" 8
$fntLastSeen  = New-TrackedFont "Segoe UI" 7
$fntDateSep   = New-TrackedFont "Segoe UI Semibold" 8

#endregion

# ------------------------------------------------------------------------------
# SECTION: HELPERS
# Description: Utility functions for UI rendering, networking, and status tracking.
# ------------------------------------------------------------------------------

function Enable-DoubleBuffer {
    param($Control)
    $p = $Control.GetType().GetProperty(
        "DoubleBuffered",
        [System.Reflection.BindingFlags]"Instance,NonPublic")
    if ($p) { $p.SetValue($Control, $true, $null) }
}

function New-RoundedRectPath {
    param([System.Drawing.Rectangle]$Rect, [int]$Radius)
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d  = $Radius * 2
    $gp.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $gp.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $gp.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $gp.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $gp.CloseFigure()
    return $gp
}

function Add-CardPaint {
    param($Panel)
    $Panel.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = "AntiAlias"

        # Shadow
        $sr = New-Object System.Drawing.Rectangle(2, 3, ($s.Width - 4), ($s.Height - 4))
        $sp = New-RoundedRectPath -Rect $sr -Radius 10
        $sb = New-Object System.Drawing.SolidBrush(
            [System.Drawing.Color]::FromArgb(16, 0, 0, 0))
        $g.FillPath($sb, $sp); $sb.Dispose(); $sp.Dispose()

        # Card body
        $cr = New-Object System.Drawing.Rectangle(0, 0, ($s.Width - 4), ($s.Height - 6))
        $cp = New-RoundedRectPath -Rect $cr -Radius 10
        $g.FillPath([System.Drawing.Brushes]::White, $cp)
        $bp = New-Object System.Drawing.Pen($cardBorder, 1)
        $g.DrawPath($bp, $cp); $bp.Dispose(); $cp.Dispose()
    })
}

# (Hover effects removed — cursor change only for buttons)

function Get-DeptColor {
    param([string]$DeptName)
    if ($deptColors.ContainsKey($DeptName)) { return $deptColors[$DeptName] }
    return $accent
}

function Get-PeerDepartment {
    param([string]$PeerName)
    $match = $Clients | Where-Object { $_.ComputerName -eq $PeerName } | Select-Object -First 1
    if ($match) { return $match.Department }
    return "UNKNOWN"
}

# Reads heartbeat from disk — only called by the refresh timer, NOT during paint
function Get-PeerOnlineStatus {
    param([string]$PeerName)
    $hbPath = Join-Path $ServerRoot "data\clients\$PeerName\heartbeat.json"
    if (Test-Path $hbPath) {
        try {
            $hb = Get-Content $hbPath -Raw | ConvertFrom-Json
            $lastSeen = [DateTime]::ParseExact(
                $hb.LastSeen, "yyyy-MM-dd HH:mm:ss", $null)
            $diff = (Get-Date) - $lastSeen
            if ($diff.TotalSeconds -le 15) { return "Online" }
            elseif ($diff.TotalMinutes -le 5) { return "Away" }
        } catch {}
    }
    return "Offline"
}

# Fast cached lookup — safe to call during paint (no disk I/O)
function Get-CachedStatus {
    param([string]$PeerName)
    if ($script:statusCache.ContainsKey($PeerName)) {
        return $script:statusCache[$PeerName]
    }
    return "Offline"
}

# Refresh all statuses, returns $true if anything changed
function Update-StatusCache {
    $changed = $false
    foreach ($t in $AllTargets) {
        $pc  = $t.ComputerName
        $old = if ($script:statusCache.ContainsKey($pc)) { $script:statusCache[$pc] } else { "" }
        $newStatus = "Offline"
        $hbPath = Join-Path $ServerRoot "data\clients\$pc\heartbeat.json"
        if (Test-Path $hbPath) {
            try {
                $hb = Get-Content $hbPath -Raw | ConvertFrom-Json
                $lastSeen = [DateTime]::ParseExact(
                    $hb.LastSeen, "yyyy-MM-dd HH:mm:ss", $null)
                $script:lastSeenCache[$pc] = $lastSeen
                $diff = (Get-Date) - $lastSeen
                if ($diff.TotalSeconds -le 15) { $newStatus = "Online" }
                elseif ($diff.TotalMinutes -le 5) { $newStatus = "Away" }
            } catch {}
        }
        if ($newStatus -ne $old) {
            $script:statusCache[$pc] = $newStatus
            $changed = $true
        }
    }
    return $changed
}

function Set-Status {
    param([string]$Text, [System.Drawing.Color]$Color, [System.Drawing.Color]$DotColor)
    $statusLabel.Text      = $Text
    $statusLabel.ForeColor = $Color
    $statusDot.Tag         = $DotColor
    $statusDot.Invalidate()
}

function Update-Counters {
    $lblCounters.Text = (
        "$charCheck $($script:sentCount) sent  " +
        "$charCross $($script:failCount) failed   |   " +
        "Enter = Send   Shift+Enter = Newline   Esc = Close"
    )
}

#endregion

# ------------------------------------------------------------------------------
# SECTION: DRAGGABLE TITLE BAR
# Description: Custom implementation for window dragging and taskbar flashing.
# ------------------------------------------------------------------------------

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinDrag {
    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();
    [DllImport("user32.dll")]
    public static extern bool FlashWindowEx(ref FLASHWINFO pwfi);
    [StructLayout(LayoutKind.Sequential)]
    public struct FLASHWINFO {
        public uint cbSize;
        public IntPtr hwnd;
        public uint dwFlags;
        public uint uCount;
        public uint dwTimeout;
    }
    public static void Drag(IntPtr h) {
        ReleaseCapture();
        SendMessage(h, 0xA1, 0x2, 0);
    }
    public static void Flash(IntPtr h) {
        FLASHWINFO fi = new FLASHWINFO();
        fi.cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(fi);
        fi.hwnd = h;
        fi.dwFlags = 3;
        fi.uCount = 3;
        fi.dwTimeout = 0;
        FlashWindowEx(ref fi);
    }
}
"@

#endregion

#region FORM

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = "Messaging System"
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor       = $bgMain
$form.Font            = $fntSub
$form.AutoScaleMode   = "None"
$form.ClientSize      = New-Object System.Drawing.Size(880, 700)

$prop = $form.GetType().GetProperty(
    "DoubleBuffered",
    [System.Reflection.BindingFlags]"Instance,NonPublic")
$prop.SetValue($form, $true, $null)

#endregion

#region HEADER

$hdr           = New-Object System.Windows.Forms.Panel
$hdr.Location  = New-Object System.Drawing.Point(0, 0)
$hdr.Size      = New-Object System.Drawing.Size(880, 82)
$hdr.BackColor = $navy1
$form.Controls.Add($hdr)

$hdr.Add_MouseDown({ [WinDrag]::Drag($form.Handle) })
$hdr.Add_Paint({
    param($s, $e)
    $g = $e.Graphics; $g.SmoothingMode = "AntiAlias"
    $r = $s.ClientRectangle

    # Gradient background
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $r, $navy1, $navy3,
        [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
    $g.FillRectangle($br, $r); $br.Dispose()

    # Gold accent line at bottom
    $pen = New-Object System.Drawing.Pen($gold, 3)
    $g.DrawLine($pen, 0, ($r.Height - 2), $r.Width, ($r.Height - 2))
    $pen.Dispose()

    $tf = [System.Drawing.StringFormat]::GenericTypographic

    # System brand
    $g.DrawString("GLOBAL", $fntTitle, [System.Drawing.Brushes]::White,
        (New-Object System.Drawing.PointF(22, 10)), $tf)

    # Gold dot separator
    $dotBr = New-Object System.Drawing.SolidBrush($gold)
    $g.FillEllipse($dotBr, 114, 25, 6, 6); $dotBr.Dispose()

    # Subtitle
    $sc = New-Object System.Drawing.SolidBrush(
        [System.Drawing.Color]::FromArgb(188, 205, 226))
    $g.DrawString("Messenger", $fntHead, $sc,
        (New-Object System.Drawing.PointF(128, 12)), $tf); $sc.Dispose()

    # Description
    $dc = New-Object System.Drawing.SolidBrush(
        [System.Drawing.Color]::FromArgb(110, 130, 160))
    $g.DrawString(
        "Secure internal messaging  $charDash  $ComputerName",
        $fntSub, $dc,
        (New-Object System.Drawing.PointF(24, 46)), $tf); $dc.Dispose()

})

# Minimize button
$btnMin           = New-Object System.Windows.Forms.Button
$btnMin.Location  = New-Object System.Drawing.Point(820, 6)
$btnMin.Size      = New-Object System.Drawing.Size(24, 24)
$btnMin.Text      = [string][char]0x2500
$btnMin.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$btnMin.FlatStyle = "Flat"
$btnMin.FlatAppearance.BorderSize = 0
$btnMin.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(40, 255, 255, 255)
$btnMin.ForeColor = [System.Drawing.Color]::FromArgb(188, 205, 226)
$btnMin.BackColor = [System.Drawing.Color]::Transparent
$btnMin.Cursor    = [System.Windows.Forms.Cursors]::Hand
$hdr.Controls.Add($btnMin)
$btnMin.Add_Click({ $form.WindowState = "Minimized" })

# Close button
$btnClose           = New-Object System.Windows.Forms.Button
$btnClose.Location  = New-Object System.Drawing.Point(848, 6)
$btnClose.Size      = New-Object System.Drawing.Size(24, 24)
$btnClose.Text      = [string][char]0x2715
$btnClose.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$btnClose.FlatStyle = "Flat"
$btnClose.FlatAppearance.BorderSize = 0
$btnClose.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(180, 220, 38, 38)
$btnClose.ForeColor = [System.Drawing.Color]::FromArgb(188, 205, 226)
$btnClose.BackColor = [System.Drawing.Color]::Transparent
$btnClose.Cursor    = [System.Windows.Forms.Cursors]::Hand
$hdr.Controls.Add($btnClose)
$btnClose.Add_Click({ $form.Close() })

#endregion

#region TOAST NOTIFICATION

$toastPanel           = New-Object System.Windows.Forms.Panel
$toastPanel.Size      = New-Object System.Drawing.Size(400, 42)
$toastPanel.Location  = New-Object System.Drawing.Point(240, -50)
$toastPanel.BackColor = $successBg
$toastPanel.Visible   = $false
$form.Controls.Add($toastPanel)
$toastPanel.BringToFront()

$toastPanel.Add_Paint({
    param($s, $e)
    $e.Graphics.SmoothingMode = "AntiAlias"
    $r = New-Object System.Drawing.Rectangle(0, 0, ($s.Width - 1), ($s.Height - 1))
    $p = New-RoundedRectPath -Rect $r -Radius 8
    $br = New-Object System.Drawing.SolidBrush($s.BackColor)
    $e.Graphics.FillPath($br, $p); $br.Dispose()
    $pen = New-Object System.Drawing.Pen(
        [System.Drawing.Color]::FromArgb(30, 0, 0, 0), 1)
    $e.Graphics.DrawPath($pen, $p); $pen.Dispose(); $p.Dispose()
})

$toastLabel           = New-Object System.Windows.Forms.Label
$toastLabel.Dock      = "Fill"
$toastLabel.Font      = $fntToast
$toastLabel.TextAlign = "MiddleCenter"
$toastLabel.BackColor = [System.Drawing.Color]::Transparent
$toastLabel.Padding   = New-Object System.Windows.Forms.Padding(12, 0, 12, 0)
$toastPanel.Controls.Add($toastLabel)

$toastTimer            = New-Object System.Windows.Forms.Timer
$toastTimer.Interval   = 35
$script:toastDir       = 1
$script:toastTargetY   = 86

$toastTimer.Add_Tick({
    if ($script:toastDir -eq 1) {
        $newY = [Math]::Min($script:toastTargetY, $toastPanel.Location.Y + 12)
        $toastPanel.Location = New-Object System.Drawing.Point(
            $toastPanel.Location.X, $newY)
        if ($newY -ge $script:toastTargetY) {
            $toastTimer.Stop(); $toastHideTimer.Start()
        }
    } else {
        $newY = $toastPanel.Location.Y - 12
        $toastPanel.Location = New-Object System.Drawing.Point(
            $toastPanel.Location.X, $newY)
        if ($newY -le -50) {
            $toastTimer.Stop(); $toastPanel.Visible = $false
        }
    }
})

$toastHideTimer          = New-Object System.Windows.Forms.Timer
$toastHideTimer.Interval = 3000
$toastHideTimer.Add_Tick({
    $toastHideTimer.Stop()
    $script:toastDir = -1
    $toastTimer.Start()
})

function Show-Toast {
    param([string]$Message, [string]$Type = "success")
    switch ($Type) {
        "success" {
            $toastPanel.BackColor = $successBg
            $toastLabel.ForeColor = $successTxt
        }
        "error" {
            $toastPanel.BackColor = $errorBg
            $toastLabel.ForeColor = $errorTxt
        }
        default {
            $toastPanel.BackColor = $warnBg
            $toastLabel.ForeColor = $warnTxt
        }
    }
    $toastLabel.Text = $Message
    $toastPanel.Location = New-Object System.Drawing.Point(240, -50)
    $toastPanel.Visible = $true
    $toastPanel.BringToFront()
    $script:toastDir = 1
    $toastHideTimer.Stop()
    $toastTimer.Start()
}

#endregion

#region LEFT SIDEBAR — CONTACTS CARD

$pnlContacts           = New-Object System.Windows.Forms.Panel
$pnlContacts.Location  = New-Object System.Drawing.Point(16, 92)
$pnlContacts.Size      = New-Object System.Drawing.Size(260, 556)
$pnlContacts.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($pnlContacts)
Add-CardPaint -Panel $pnlContacts

# Header label
$lblContactsCap           = New-Object System.Windows.Forms.Label
$lblContactsCap.Location  = New-Object System.Drawing.Point(16, 10)
$lblContactsCap.Size      = New-Object System.Drawing.Size(78, 16)
$lblContactsCap.Font      = $fntCap
$lblContactsCap.ForeColor = $txtSecond
$lblContactsCap.Text      = "CONTACTS"
$lblContactsCap.BackColor = $cardBg
$lblContactsCap.TextAlign = "MiddleLeft"
$pnlContacts.Controls.Add($lblContactsCap)

$lblContactCount           = New-Object System.Windows.Forms.Label
$lblContactCount.Location  = New-Object System.Drawing.Point(94, 10)
$lblContactCount.Size      = New-Object System.Drawing.Size(150, 16)
$lblContactCount.Font      = $fntCapNorm
$lblContactCount.ForeColor = $txtMuted
$lblContactCount.Text      = "$($AllTargets.Count) total"
$lblContactCount.BackColor = $cardBg
$lblContactCount.TextAlign = "MiddleLeft"
$pnlContacts.Controls.Add($lblContactCount)

# Department filter combo
$cmbDept           = New-Object System.Windows.Forms.ComboBox
$cmbDept.Location  = New-Object System.Drawing.Point(16, 32)
$cmbDept.Size      = New-Object System.Drawing.Size(224, 26)
$cmbDept.Font      = $fntSub
$cmbDept.ForeColor = $txtPrimary
$cmbDept.BackColor = $listBg
$cmbDept.DropDownStyle = "DropDownList"
$cmbDept.FlatStyle = "Flat"
$pnlContacts.Controls.Add($cmbDept)

# Search box
$filterBox             = New-Object System.Windows.Forms.TextBox
$filterBox.Location    = New-Object System.Drawing.Point(16, 62)
$filterBox.Size        = New-Object System.Drawing.Size(224, 24)
$filterBox.Font        = $fntSub
$filterBox.ForeColor   = $txtMuted
$filterBox.Text        = "Search contacts..."
$filterBox.BorderStyle = "FixedSingle"
$filterBox.BackColor   = $listBg
$pnlContacts.Controls.Add($filterBox)

# Debounce timer for search
$searchDebounce          = New-Object System.Windows.Forms.Timer
$searchDebounce.Interval = 300
$searchDebounce.Add_Tick({
    $searchDebounce.Stop()
    Load-Clients
})

# Contact list — owner-drawn
$lstContacts               = New-Object System.Windows.Forms.ListBox
$lstContacts.Location      = New-Object System.Drawing.Point(16, 92)
$lstContacts.Size          = New-Object System.Drawing.Size(224, 448)
$lstContacts.Font          = $fntList
$lstContacts.BorderStyle   = "None"
$lstContacts.BackColor     = $cardBg
$lstContacts.ForeColor     = $txtPrimary
$lstContacts.DrawMode      = "OwnerDrawFixed"
$lstContacts.ItemHeight    = 48
$lstContacts.IntegralHeight = $false
Enable-DoubleBuffer $lstContacts
$pnlContacts.Controls.Add($lstContacts)

$lstContacts.Add_DrawItem({
    param($s, $e)
    if ($e.Index -lt 0) { return }

    $g = $e.Graphics
    $g.SmoothingMode = "AntiAlias"
    $bounds = $e.Bounds

    $pcName = $s.Items[$e.Index].ToString()
    $dept   = Get-PeerDepartment $pcName
    $dColor = Get-DeptColor $dept

    # Department group header — draw when dept changes from previous item
    $prevDept = ""
    if ($e.Index -gt 0) {
        $prevPC = $s.Items[$e.Index - 1].ToString()
        $prevDept = Get-PeerDepartment $prevPC
    }
    $showGroupHdr = ($dept -ne $prevDept)

    # Selected background (no hover — eliminates blinking)
    $isSelected = ($e.State -band [System.Windows.Forms.DrawItemState]::Selected)
    if ($isSelected) {
        # Subtle glow behind selected row
        $glowBr = New-Object System.Drawing.SolidBrush($selectedGlow)
        $glowR  = New-Object System.Drawing.Rectangle(
            $bounds.X, ($bounds.Y - 1), $bounds.Width, ($bounds.Height + 2))
        $g.FillRectangle($glowBr, $glowR); $glowBr.Dispose()

        $bgBr = New-Object System.Drawing.SolidBrush($selectedBg)
        $g.FillRectangle($bgBr, $bounds); $bgBr.Dispose()

        # Left accent bar (4px wide)
        $accentBr = New-Object System.Drawing.SolidBrush($dColor)
        $g.FillRectangle($accentBr,
            (New-Object System.Drawing.Rectangle($bounds.X, $bounds.Y, 4, $bounds.Height)))
        $accentBr.Dispose()
    } else {
        $bgBr = New-Object System.Drawing.SolidBrush($cardBg)
        $g.FillRectangle($bgBr, $bounds); $bgBr.Dispose()
    }

    # Group header label at top of item
    $yOffset = 0
    if ($showGroupHdr) {
        $hdrBr = New-Object System.Drawing.SolidBrush($dColor)
        $g.DrawString($dept, $fntGroupHdr, $hdrBr,
            (New-Object System.Drawing.PointF(($bounds.X + 14), ($bounds.Y + 2))))
        $hdrBr.Dispose()
        $yOffset = 10
    }

    # Department color dot — avatar circle
    $circleX = $bounds.X + 14
    $circleY = $bounds.Y + $yOffset + ([math]::Max(0, (($bounds.Height - $yOffset - 28) / 2)))
    $circleSz = 28
    $circleBr = New-Object System.Drawing.SolidBrush(
        [System.Drawing.Color]::FromArgb(30, $dColor.R, $dColor.G, $dColor.B))
    $g.FillEllipse($circleBr, $circleX, $circleY, $circleSz, $circleSz)
    $circleBr.Dispose()

    # Initial letter in circle
    $initial = $pcName.Substring(0, 1)
    $initBr  = New-Object System.Drawing.SolidBrush($dColor)
    $initSz  = $g.MeasureString($initial, $fntListBold)
    $initX   = $circleX + ($circleSz - $initSz.Width) / 2
    $initY   = $circleY + ($circleSz - $initSz.Height) / 2
    $g.DrawString($initial, $fntListBold, $initBr,
        (New-Object System.Drawing.PointF($initX, $initY)))
    $initBr.Dispose()

    # Unread badge on avatar
    if ($script:unreadPeers.ContainsKey($pcName) -and $script:unreadPeers[$pcName] -gt 0) {
        $badgeBr = New-Object System.Drawing.SolidBrush($gold)
        $g.FillEllipse($badgeBr, ($circleX + $circleSz - 8), $circleY, 10, 10)
        $badgeBr.Dispose()
        $wBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $cnt = $script:unreadPeers[$pcName].ToString()
        $csz = $g.MeasureString($cnt, $fntGroupHdr)
        $g.DrawString($cnt, $fntGroupHdr, $wBr,
            (New-Object System.Drawing.PointF(
                ($circleX + $circleSz - 8 + (10 - $csz.Width)/2),
                ($circleY + (10 - $csz.Height)/2))))
        $wBr.Dispose()
    }

    # PC name
    $textY = $circleY + 2
    $nameBr = New-Object System.Drawing.SolidBrush($txtPrimary)
    $g.DrawString($pcName, $fntList, $nameBr,
        (New-Object System.Drawing.PointF(($circleX + $circleSz + 10), $textY)))
    $nameBr.Dispose()

    # Department label
    $deptBr = New-Object System.Drawing.SolidBrush($dColor)
    $g.DrawString($dept, $fntListSm, $deptBr,
        (New-Object System.Drawing.PointF(($circleX + $circleSz + 10), ($textY + 16))))
    $deptBr.Dispose()

    # Online status dot (right side) — uses cached status, no disk I/O
    $status = Get-CachedStatus $pcName
    $statusColor = switch ($status) {
        "Online"  { $successCol }
        "Away"    { [System.Drawing.Color]::FromArgb(234, 179, 8) }
        default   { [System.Drawing.Color]::FromArgb(180, 190, 200) }
    }
    $dotBr = New-Object System.Drawing.SolidBrush($statusColor)
    $g.FillEllipse($dotBr, ($bounds.Right - 20), ($circleY + 10), 8, 8)
    $dotBr.Dispose()

    # Last-seen time for offline contacts
    if ($status -eq "Offline" -and $script:lastSeenCache.ContainsKey($pcName)) {
        $ago = (Get-Date) - $script:lastSeenCache[$pcName]
        $agoText = if ($ago.TotalMinutes -lt 60) { "{0}m" -f [math]::Floor($ago.TotalMinutes) }
                   elseif ($ago.TotalHours -lt 24) { "{0}h" -f [math]::Floor($ago.TotalHours) }
                   else { "{0}d" -f [math]::Floor($ago.TotalDays) }
        $agoBr = New-Object System.Drawing.SolidBrush($txtMuted)
        $agoSz = $g.MeasureString($agoText, $fntLastSeen)
        $g.DrawString($agoText, $fntLastSeen, $agoBr,
            (New-Object System.Drawing.PointF(
                ($bounds.Right - 16 - $agoSz.Width / 2), ($circleY + 22))))
        $agoBr.Dispose()
    }

    # Bottom separator
    $sepPen = New-Object System.Drawing.Pen(
        [System.Drawing.Color]::FromArgb(240, 244, 248), 1)
    $g.DrawLine($sepPen,
        ($bounds.X + 14), ($bounds.Bottom - 1),
        ($bounds.Right - 8), ($bounds.Bottom - 1))
    $sepPen.Dispose()
})

# (Contact list hover tracking removed — eliminates blink/flicker)

#endregion

#region RIGHT COLUMN — CHAT AREA

$pnlChat           = New-Object System.Windows.Forms.Panel
$pnlChat.Location  = New-Object System.Drawing.Point(290, 92)
$pnlChat.Size      = New-Object System.Drawing.Size(574, 556)
$pnlChat.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($pnlChat)
Add-CardPaint -Panel $pnlChat

# Chat header panel
$pnlChatHeader           = New-Object System.Windows.Forms.Panel
$pnlChatHeader.Location  = New-Object System.Drawing.Point(0, 0)
$pnlChatHeader.Size      = New-Object System.Drawing.Size(570, 56)
$pnlChatHeader.BackColor = $cardBg
Enable-DoubleBuffer $pnlChatHeader
$pnlChat.Controls.Add($pnlChatHeader)

$pnlChatHeader.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = "AntiAlias"

    # Subtle gradient wash across chat header
    $hdrGradR = $s.ClientRectangle
    if ($hdrGradR.Width -gt 0 -and $hdrGradR.Height -gt 0) {
        $hdrGr = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $hdrGradR,
            [System.Drawing.Color]::FromArgb(252, 254, 255),
            [System.Drawing.Color]::FromArgb(242, 247, 253),
            [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
        $g.FillRectangle($hdrGr, $hdrGradR); $hdrGr.Dispose()
    }

    if ([string]::IsNullOrWhiteSpace($script:selectedPeer)) {
        $emptyBr = New-Object System.Drawing.SolidBrush($txtMuted)
        $g.DrawString("Select a contact to start chatting",
            $fntSub, $emptyBr,
            (New-Object System.Drawing.PointF(18, 20)))
        $emptyBr.Dispose()
        return
    }

    $dept  = Get-PeerDepartment $script:selectedPeer
    $dCol  = Get-DeptColor $dept
    $sts   = Get-CachedStatus $script:selectedPeer

    # Avatar circle
    $avBr = New-Object System.Drawing.SolidBrush(
        [System.Drawing.Color]::FromArgb(30, $dCol.R, $dCol.G, $dCol.B))
    $g.FillEllipse($avBr, 16, 12, 32, 32); $avBr.Dispose()
    $initBr = New-Object System.Drawing.SolidBrush($dCol)
    $initTxt = $script:selectedPeer.Substring(0, 1)
    $isz = $g.MeasureString($initTxt, $fntPeerName)
    $g.DrawString($initTxt, $fntHead, $initBr,
        (New-Object System.Drawing.PointF(
            (16 + (32 - $isz.Width) / 2),
            (12 + (32 - $isz.Height) / 2))))
    $initBr.Dispose()

    # Name
    $nmBr = New-Object System.Drawing.SolidBrush($txtPrimary)
    $g.DrawString($script:selectedPeer, $fntPeerName, $nmBr,
        (New-Object System.Drawing.PointF(58, 6)))
    $nmBr.Dispose()

    # Department + status
    $stsColor = switch ($sts) {
        "Online"  { $successCol }
        "Away"    { [System.Drawing.Color]::FromArgb(234, 179, 8) }
        default   { $txtMuted }
    }
    $dsBr = New-Object System.Drawing.SolidBrush($dCol)
    $g.DrawString("$dept", $fntPeerDept, $dsBr,
        (New-Object System.Drawing.PointF(58, 30)))
    $dsBr.Dispose()

    $stsDotBr = New-Object System.Drawing.SolidBrush($stsColor)
    $deptWidth = $g.MeasureString($dept, $fntPeerDept).Width
    $g.FillEllipse($stsDotBr, (62 + $deptWidth + 6), 35, 7, 7)
    $stsDotBr.Dispose()
    $stsBr = New-Object System.Drawing.SolidBrush($stsColor)
    $g.DrawString($sts, $fntPeerDept, $stsBr,
        (New-Object System.Drawing.PointF(
            (62 + $deptWidth + 16), 30)))
    $stsBr.Dispose()

    # Bottom separator
    $sepPen = New-Object System.Drawing.Pen($cardBorder, 1)
    $g.DrawLine($sepPen, 0, ($s.Height - 1), $s.Width, ($s.Height - 1))
    $sepPen.Dispose()
})

# Conversation text
$txtConversation            = New-Object System.Windows.Forms.RichTextBox
$txtConversation.Location   = New-Object System.Drawing.Point(6, 58)
$txtConversation.Size       = New-Object System.Drawing.Size(558, 356)
$txtConversation.ReadOnly   = $true
$txtConversation.BackColor  = $chatBg
$txtConversation.ForeColor  = $txtPrimary
$txtConversation.Font       = $fntChat
$txtConversation.BorderStyle = "None"
$txtConversation.ScrollBars = "Vertical"
$txtConversation.WordWrap   = $true
$txtConversation.DetectUrls = $false
$txtConversation.Padding    = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)
Enable-DoubleBuffer $txtConversation
$pnlChat.Controls.Add($txtConversation)

# Empty state overlay
$pnlEmptyState           = New-Object System.Windows.Forms.Panel
$pnlEmptyState.Location  = New-Object System.Drawing.Point(6, 58)
$pnlEmptyState.Size      = New-Object System.Drawing.Size(558, 356)
$pnlEmptyState.BackColor = $chatBg
$pnlEmptyState.Visible   = $true
Enable-DoubleBuffer $pnlEmptyState
$pnlChat.Controls.Add($pnlEmptyState)
$pnlEmptyState.BringToFront()

$pnlEmptyState.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = "AntiAlias"
    $g.TextRenderingHint = "ClearTypeGridFit"
    $cx = $s.Width / 2
    $cy = $s.Height / 2 - 30

    # Envelope icon circle
    $iconBr = New-Object System.Drawing.SolidBrush(
        [System.Drawing.Color]::FromArgb(15, 56, 120, 210))
    $g.FillEllipse($iconBr, ($cx - 32), ($cy - 32), 64, 64)
    $iconBr.Dispose()
    $envBr = New-Object System.Drawing.SolidBrush($accent)
    $envSz = $g.MeasureString([string]$charEnvelope, $fntTitle)
    $g.DrawString([string]$charEnvelope, $fntTitle, $envBr,
        (New-Object System.Drawing.PointF(
            ($cx - $envSz.Width / 2), ($cy - $envSz.Height / 2))))
    $envBr.Dispose()

    # Title
    $tf = [System.Drawing.StringFormat]::new()
    $tf.Alignment = "Center"
    $titleBr = New-Object System.Drawing.SolidBrush($txtPrimary)
    $titleR  = New-Object System.Drawing.RectangleF(0, ($cy + 46), $s.Width, 28)
    $g.DrawString("Select a contact to start chatting", $fntEmptyLg, $titleBr, $titleR, $tf)
    $titleBr.Dispose()

    # Subtitle
    $subBr = New-Object System.Drawing.SolidBrush($txtMuted)
    $subR  = New-Object System.Drawing.RectangleF(0, ($cy + 72), $s.Width, 22)
    $g.DrawString("Choose someone from the contacts list on the left", $fntEmptySm, $subBr, $subR, $tf)
    $subBr.Dispose()
    $tf.Dispose()
})

# Message input separator
$sepInput           = New-Object System.Windows.Forms.Panel
$sepInput.Location  = New-Object System.Drawing.Point(6, 418)
$sepInput.Size      = New-Object System.Drawing.Size(558, 1)
$sepInput.BackColor = $cardBorder
$pnlChat.Controls.Add($sepInput)

# Quick-reply preset buttons
$pnlQuickReply           = New-Object System.Windows.Forms.Panel
$pnlQuickReply.Location  = New-Object System.Drawing.Point(12, 422)
$pnlQuickReply.Size      = New-Object System.Drawing.Size(548, 24)
$pnlQuickReply.BackColor = $cardBg
$pnlChat.Controls.Add($pnlQuickReply)

$quickReplies = @("OK", "Noted", "On it", "Thanks", "BRB", "Will do")
$qrX = 0
foreach ($qr in $quickReplies) {
    $qrBtn                            = New-Object System.Windows.Forms.Button
    $qrBtn.Location                   = New-Object System.Drawing.Point($qrX, 0)
    $qrBtn.Size                       = New-Object System.Drawing.Size(76, 22)
    $qrBtn.Text                       = $qr
    $qrBtn.Font                       = $fntQuickReply
    $qrBtn.BackColor                  = $listBg
    $qrBtn.ForeColor                  = $txtSecond
    $qrBtn.FlatStyle                  = "Flat"
    $qrBtn.FlatAppearance.BorderColor = $cardBorder
    $qrBtn.FlatAppearance.BorderSize  = 1
    $qrBtn.Cursor                     = [System.Windows.Forms.Cursors]::Hand
    $qrBtn.Tag                        = $qr
    # (Quick-reply hover removed — eliminates blink)
    $qrBtn.Add_Click({
        param($s,$e)
        if ([string]::IsNullOrWhiteSpace($script:selectedPeer)) {
            Show-Toast "Select a contact first." "warn"
            return
        }
        $txtMessage.Text      = $s.Tag
        $txtMessage.ForeColor = $txtPrimary
        $btnSend.PerformClick()
    })
    $pnlQuickReply.Controls.Add($qrBtn)
    $qrX += 82
}

# "Reply to <peer>" label above input
$lblReplyHint           = New-Object System.Windows.Forms.Label
$lblReplyHint.Location  = New-Object System.Drawing.Point(12, 448)
$lblReplyHint.Size      = New-Object System.Drawing.Size(380, 14)
$lblReplyHint.Font      = $fntChatTime
$lblReplyHint.ForeColor = $txtMuted
$lblReplyHint.Text      = "Message"
$lblReplyHint.BackColor = $cardBg
$pnlChat.Controls.Add($lblReplyHint)

# Character counter
$lblCharCount           = New-Object System.Windows.Forms.Label
$lblCharCount.Size      = New-Object System.Drawing.Size(80, 14)
$lblCharCount.Location  = New-Object System.Drawing.Point(480, 448)
$lblCharCount.Font      = $fntCapNorm
$lblCharCount.ForeColor = $txtMuted
$lblCharCount.TextAlign = "MiddleRight"
$lblCharCount.Text      = "0 / 500"
$lblCharCount.BackColor = $cardBg
$pnlChat.Controls.Add($lblCharCount)

# Message input with focus-ring border
$pnlInputWrap           = New-Object System.Windows.Forms.Panel
$pnlInputWrap.Location  = New-Object System.Drawing.Point(10, 464)
$pnlInputWrap.Size      = New-Object System.Drawing.Size(436, 66)
$pnlInputWrap.BackColor = $cardBg
$pnlInputWrap.Tag       = $cardBorder
Enable-DoubleBuffer $pnlInputWrap
$pnlChat.Controls.Add($pnlInputWrap)
$pnlInputWrap.Add_Paint({
    param($s, $e)
    $g = $e.Graphics; $g.SmoothingMode = "AntiAlias"
    $r = New-Object System.Drawing.Rectangle(0, 0, ($s.Width - 1), ($s.Height - 1))
    $p = New-RoundedRectPath -Rect $r -Radius 10
    $pen = New-Object System.Drawing.Pen($s.Tag, 1.5)
    $g.DrawPath($pen, $p); $pen.Dispose(); $p.Dispose()
})

$txtMessage             = New-Object System.Windows.Forms.TextBox
$txtMessage.Location    = New-Object System.Drawing.Point(4, 4)
$txtMessage.Size        = New-Object System.Drawing.Size(424, 58)
$txtMessage.Multiline   = $true
$txtMessage.BorderStyle = "None"
$txtMessage.Font        = $fntInput
$txtMessage.ForeColor   = $txtMuted
$txtMessage.BackColor   = $cardBg
$txtMessage.MaxLength   = 500
$txtMessage.ScrollBars  = "Vertical"
$txtMessage.Text        = "Type a message..."
$pnlInputWrap.Controls.Add($txtMessage)

# Send button — navy blue, envelope icon
$btnSend                           = New-Object System.Windows.Forms.Button
$btnSend.Location                  = New-Object System.Drawing.Point(452, 462)
$btnSend.Size                      = New-Object System.Drawing.Size(110, 70)
$btnSend.Text                      = "$charEnvelope  SEND"
$btnSend.Font                      = $fntBtnLg
$btnSend.BackColor                 = $navy1
$btnSend.ForeColor                 = [System.Drawing.Color]::White
$btnSend.FlatStyle                 = "Flat"
$btnSend.FlatAppearance.BorderSize = 0
$btnSend.Cursor                    = [System.Windows.Forms.Cursors]::Hand
$pnlChat.Controls.Add($btnSend)
# (Send button hover removed — eliminates blink)

#endregion

#region SYSTEM TRAY

$trayIcon         = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon    = [System.Drawing.Icon]::ExtractAssociatedIcon(
    [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
$trayIcon.Text    = "Messaging System"
$trayIcon.Visible = $true

$trayMenu     = New-Object System.Windows.Forms.ContextMenuStrip
$trayMenuOpen = $trayMenu.Items.Add("Open Messaging System")
$trayMenuOpen.Add_Click({
    $form.Show(); $form.WindowState = "Normal"; $form.Activate()
})
$trayMenuExit = $trayMenu.Items.Add("Exit")
$trayMenuExit.Add_Click({ $form.Close() })
$trayIcon.ContextMenuStrip = $trayMenu
$trayIcon.Add_DoubleClick({
    $form.Show(); $form.WindowState = "Normal"; $form.Activate()
})

$form.Add_Resize({
    if ($form.WindowState -eq "Minimized") {
        $form.Hide()
        $trayIcon.ShowBalloonTip(2000, "Messaging System",
            "Running in system tray", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})

#region FOOTER

$footerDiv           = New-Object System.Windows.Forms.Panel
$footerDiv.Location  = New-Object System.Drawing.Point(0, 653)
$footerDiv.Size      = New-Object System.Drawing.Size(880, 3)
$footerDiv.BackColor = [System.Drawing.Color]::Transparent
Enable-DoubleBuffer $footerDiv
$form.Controls.Add($footerDiv)
$footerDiv.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $r = $s.ClientRectangle
    if ($r.Width -gt 0 -and $r.Height -gt 0) {
        $gb = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $r, $gold,
            [System.Drawing.Color]::FromArgb(0, $gold.R, $gold.G, $gold.B),
            [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
        $g.FillRectangle($gb, $r); $gb.Dispose()
    }
})

$statusDot           = New-Object System.Windows.Forms.Panel
$statusDot.Location  = New-Object System.Drawing.Point(20, 668)
$statusDot.Size      = New-Object System.Drawing.Size(12, 12)
$statusDot.BackColor = $bgMain
$statusDot.Tag       = $successCol
$form.Controls.Add($statusDot)
$statusDot.Add_Paint({
    param($s, $e)
    $e.Graphics.SmoothingMode = "AntiAlias"
    $br3 = New-Object System.Drawing.SolidBrush($s.Tag)
    $e.Graphics.FillEllipse($br3, 1, 1, 9, 9)
    $br3.Dispose()
})

$statusLabel           = New-Object System.Windows.Forms.Label
$statusLabel.Location  = New-Object System.Drawing.Point(38, 664)
$statusLabel.Size      = New-Object System.Drawing.Size(440, 20)
$statusLabel.ForeColor = $txtSecond
$statusLabel.Font      = $fntStatus
$statusLabel.Text      = "Online as $ComputerName $charDash Select a contact to chat"
$form.Controls.Add($statusLabel)

$lblCounters           = New-Object System.Windows.Forms.Label
$lblCounters.Location  = New-Object System.Drawing.Point(38, 682)
$lblCounters.Size      = New-Object System.Drawing.Size(340, 16)
$lblCounters.Font      = $fntShortcut
$lblCounters.ForeColor = $txtMuted
$lblCounters.Text      = "$charCheck 0 sent  $charCross 0 failed   |   Ctrl+Enter = Send   Esc = Close"
$form.Controls.Add($lblCounters)

# Mute button (footer) — toggle style
$btnMute                            = New-Object System.Windows.Forms.Button
$btnMute.Location                   = New-Object System.Drawing.Point(668, 660)
$btnMute.Size                       = New-Object System.Drawing.Size(92, 34)
$btnMute.Text                       = ([char]0x266A) + " Sound"
$btnMute.Font                       = $fntCapNorm
$btnMute.BackColor                  = $cardBg
$btnMute.ForeColor                  = $txtPrimary
$btnMute.FlatStyle                  = "Flat"
$btnMute.FlatAppearance.BorderColor = $successCol
$btnMute.FlatAppearance.BorderSize  = 1
$btnMute.Cursor                     = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnMute)

$btnMute.Add_Click({
    $script:muteSound = -not $script:muteSound
    if ($script:muteSound) {
        $btnMute.Text      = ([char]0x2715) + " Muted"
        $btnMute.ForeColor = $txtMuted
        $btnMute.FlatAppearance.BorderColor = $cardBorder
        $btnMute.BackColor = $listBg
        Show-Toast "Sound muted" "warn"
    } else {
        $btnMute.Text      = ([char]0x266A) + " Sound"
        $btnMute.ForeColor = $txtPrimary
        $btnMute.FlatAppearance.BorderColor = $successCol
        $btnMute.BackColor = $cardBg
        Show-Toast "Sound enabled" "success"
    }
})

# Close button (footer)
$btnFooterClose                            = New-Object System.Windows.Forms.Button
$btnFooterClose.Location                   = New-Object System.Drawing.Point(772, 660)
$btnFooterClose.Size                       = New-Object System.Drawing.Size(92, 34)
$btnFooterClose.Text                       = ([char]0x2715) + "  Close"
$btnFooterClose.Font                       = $fntBtn
$btnFooterClose.BackColor                  = $errorBg
$btnFooterClose.ForeColor                  = $errorTxt
$btnFooterClose.FlatStyle                  = "Flat"
$btnFooterClose.FlatAppearance.BorderColor = $errorCol
$btnFooterClose.FlatAppearance.BorderSize  = 1
$btnFooterClose.Cursor                     = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnFooterClose)
# (Close button hover removed — eliminates blink)

$form.CancelButton = $btnFooterClose

#endregion

#region CORE MESSAGING LOGIC

function Get-ConversationLogFile {
    param([string]$PeerName)
    $myLogFolder = Join-Path $LogsRoot $ComputerName
    if (!(Test-Path $myLogFolder)) {
        New-Item -ItemType Directory -Path $myLogFolder -Force | Out-Null
    }
    return (Join-Path $myLogFolder "$PeerName.log")
}

function Write-ConversationLog {
    param([string]$PeerName, [string]$Line)
    try {
        $logFile = Get-ConversationLogFile -PeerName $PeerName
        Add-Content -Path $logFile -Value ($Line + [Environment]::NewLine)
    } catch {}
}

function Add-ConversationLine {
    param([string]$Sender, [string]$MsgText, [bool]$IsMe = $false)

    $ts = (Get-Date).ToString('hh:mm tt')

    # ── Date separator ───────────────────────────────────────────────────────
    $todayStr = (Get-Date).ToString('yyyy-MM-dd')
    if ($script:lastMsgDate -ne $todayStr) {
        $dateLabel = if ($todayStr -eq (Get-Date).ToString('yyyy-MM-dd')) { "Today" }
                     elseif ($todayStr -eq (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')) { "Yesterday" }
                     else { (Get-Date).ToString('MMM dd, yyyy') }
        $txtConversation.SelectionStart     = $txtConversation.Text.Length
        $txtConversation.SelectionLength    = 0
        $txtConversation.SelectionAlignment = "Center"
        $txtConversation.SelectionFont      = $fntDateSep
        $txtConversation.SelectionColor     = $txtSecond
        $txtConversation.AppendText("$charDash$charDash  $dateLabel  $charDash$charDash" + [Environment]::NewLine)
        $script:lastMsgDate = $todayStr
    }

    # ── Timestamp (centered) ────────────────────────────────────────────────
    $txtConversation.SelectionStart     = $txtConversation.Text.Length
    $txtConversation.SelectionLength    = 0
    $txtConversation.SelectionAlignment = "Center"
    $txtConversation.SelectionFont      = $fntChatTime
    $txtConversation.SelectionColor     = $txtMuted
    $txtConversation.AppendText("$charDash  $ts  $charDash" + [Environment]::NewLine)

    if ($IsMe) {
        # ── MY message: right-aligned, gold accent, bubble styling ────────────
        $txtConversation.SelectionStart     = $txtConversation.Text.Length
        $txtConversation.SelectionLength    = 0
        $txtConversation.SelectionAlignment = "Right"
        $txtConversation.SelectionFont      = $fntChatBold
        $txtConversation.SelectionColor     = $gold
        $txtConversation.AppendText("You" + [Environment]::NewLine)

        $txtConversation.SelectionStart     = $txtConversation.Text.Length
        $txtConversation.SelectionLength    = 0
        $txtConversation.SelectionAlignment = "Right"
        $txtConversation.SelectionFont      = $fntChat
        $txtConversation.SelectionColor     = [System.Drawing.Color]::FromArgb(30, 50, 90)
        $txtConversation.SelectionBackColor = [System.Drawing.Color]::FromArgb(255, 248, 218)
        $txtConversation.AppendText(" $MsgText ")
        $txtConversation.SelectionBackColor = $chatBg
        $txtConversation.AppendText([Environment]::NewLine)

        # Tick receipt indicator
        $txtConversation.SelectionStart     = $txtConversation.Text.Length
        $txtConversation.SelectionLength    = 0
        $txtConversation.SelectionAlignment = "Right"
        $txtConversation.SelectionFont      = $fntChatTime
        $txtConversation.SelectionColor     = $successCol
        $txtConversation.AppendText("$charCheck$charCheck Delivered" + [Environment]::NewLine + [Environment]::NewLine)
    } else {
        # ── THEIR message: left-aligned, blue accent ─────────────────────────
        $txtConversation.SelectionStart     = $txtConversation.Text.Length
        $txtConversation.SelectionLength    = 0
        $txtConversation.SelectionAlignment = "Left"
        $txtConversation.SelectionFont      = $fntChatBold
        $txtConversation.SelectionColor     = $accent
        $txtConversation.AppendText($Sender + [Environment]::NewLine)

        $txtConversation.SelectionStart     = $txtConversation.Text.Length
        $txtConversation.SelectionLength    = 0
        $txtConversation.SelectionAlignment = "Left"
        $txtConversation.SelectionFont      = $fntChat
        $txtConversation.SelectionColor     = $txtPrimary
        $txtConversation.SelectionBackColor = [System.Drawing.Color]::FromArgb(226, 238, 255)
        $txtConversation.AppendText(" $MsgText ")
        $txtConversation.SelectionBackColor = $chatBg
        $txtConversation.AppendText([Environment]::NewLine + [Environment]::NewLine)
    }

    $txtConversation.SelectionStart = $txtConversation.Text.Length
    $txtConversation.ScrollToCaret()
}

function Load-ConversationForClient {
    param([string]$PeerName)
    $txtConversation.Clear()
    $script:selectedPeer = $PeerName
    $pnlChatHeader.Invalidate()

    if ([string]::IsNullOrWhiteSpace($PeerName)) {
        $pnlEmptyState.Visible = $true
        $pnlEmptyState.BringToFront()
        return
    }

    # Hide empty state, show conversation
    $pnlEmptyState.Visible = $false

    # Clear unread for this peer
    if ($script:unreadPeers.ContainsKey($PeerName)) {
        $script:unreadPeers.Remove($PeerName)
        $lstContacts.Invalidate()
    }

    $logFile = Get-ConversationLogFile -PeerName $PeerName
    if (Test-Path $logFile) {
        try {
            $txtConversation.Text = Get-Content $logFile -Raw
            $txtConversation.SelectionStart = $txtConversation.Text.Length
            $txtConversation.ScrollToCaret()
        } catch {}
    }
}

function Load-Departments {
    $cmbDept.Items.Clear()
    [void]$cmbDept.Items.Add("ALL DEPARTMENTS")
    ($AllTargets.Department | Sort-Object -Unique) | ForEach-Object {
        [void]$cmbDept.Items.Add($_)
    }
    $cmbDept.SelectedIndex = 0
}

function Load-Clients {
    $lstContacts.Items.Clear()

    # Cast to [string] explicitly — prevents silent comparison failure when
    # PowerShell returns a ComboBox item object instead of a plain string
    $selectedDept = [string]$cmbDept.SelectedItem

    if ($selectedDept -eq "ALL DEPARTMENTS" -or [string]::IsNullOrEmpty($selectedDept)) {
        $items = @($AllTargets | Sort-Object Department, ComputerName)
    } else {
        $items = @($AllTargets | Where-Object { $_.Department -eq $selectedDept } |
            Sort-Object ComputerName)
    }

    # Apply search filter
    $q = $filterBox.Text.Trim()
    if ($q -ne "" -and $q -ne "Search contacts...") {
        $items = @($items | Where-Object { $_.ComputerName -like "*$q*" })
    }

    # Guard: if nothing matched, ensure $items is an empty array not $null
    if (-not $items) { $items = @() }

    # Sort online contacts first
    $items = @($items | Sort-Object @{
        Expression = {
            $s = Get-CachedStatus $_.ComputerName
            switch ($s) { "Online" { 0 } "Away" { 1 } default { 2 } }
        }
    }, Department, ComputerName)

    foreach ($item in $items) {
        [void]$lstContacts.Items.Add($item.ComputerName)
    }

    # Use $items.Count (our computed array) — NOT $lstContacts.Items.Count,
    # which can read as 1 if a WinForms SelectedIndexChanged event fires
    # mid-loop on the first Add() call before the loop finishes.
    $total   = @($AllTargets).Count
    $showing = $items.Count
    if ($showing -eq $total) {
        $lblContactCount.Text = "$total total"
    } else {
        $lblContactCount.Text = "$showing of $total"
    }
    $lblContactCount.Refresh()
}

function Write-Heartbeat {
    try {
        $hb = @{
            ComputerName = $ComputerName
            LastSeen     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Status       = "Online"
        } | ConvertTo-Json
        Set-Content -Path $Heartbeat -Value $hb -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Send-MessageToPeer {
    $target = $script:selectedPeer
    if ([string]::IsNullOrWhiteSpace($target)) {
        Show-Toast "Select a contact first." "warn"
        return
    }

    $text = $txtMessage.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($text) -or $text -eq "Type a message...") { return }

    $targetInbox = Join-Path $ServerRoot "Clients\$target\Inbox"
    if (!(Test-Path $targetInbox)) {
        Show-Toast "Target inbox not found for $target" "error"
        $script:failCount++
        Update-Counters
        return
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $rand  = Get-Random -Minimum 1000 -Maximum 9999
    $msgId = "{0}_{1}_to_{2}_{3}" -f $stamp, $ComputerName, $target, $rand

    $payload = @{
        MessageId = $msgId
        From      = $ComputerName
        To        = $target
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Type      = "Message"
        Priority  = "Normal"
        Text      = $text
        Status    = "Unread"
    } | ConvertTo-Json -Depth 3

    try {
        $outFile = Join-Path $targetInbox "$msgId.json"
        Set-Content -Path $outFile -Value $payload -Encoding UTF8

        $line = "[$((Get-Date).ToString('hh:mm tt'))] ${ComputerName}:`n$text"
        Add-ConversationLine -Sender $ComputerName -MsgText $text -IsMe $true
        Write-ConversationLog -PeerName $target -Line $line
        $txtMessage.Text = ""

        $script:sentCount++
        Set-Status "Sent to $target" $successTxt $successCol
        Show-Toast "$charCheck Message sent to $target" "success"
    }
    catch {
        $script:failCount++
        Set-Status "Failed to send to $target" $errorTxt $errorCol
        Show-Toast "$charCross Failed: $($_.Exception.Message)" "error"
    }
    finally {
        Update-Counters
    }
}

function Process-IncomingMessages {
    if (!(Test-Path $InboxPath)) { return }

    $files = Get-ChildItem -Path $InboxPath -Filter *.json -File |
        Sort-Object LastWriteTime
    foreach ($file in $files) {
        try {
            $msg  = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $from = $msg.From
            $line = "[$((Get-Date).ToString('hh:mm tt'))] ${from}:`n$($msg.Text)"

            Write-ConversationLog -PeerName $from -Line $line

            if ($script:selectedPeer -eq $from) {
                Add-ConversationLine -Sender $from -MsgText $msg.Text -IsMe $false
            } else {
                # Track unread count for contacts not currently viewed
                if (-not $script:unreadPeers.ContainsKey($from)) {
                    $script:unreadPeers[$from] = 0
                }
                $script:unreadPeers[$from]++
                $lstContacts.Invalidate()
            }

            $dest = Join-Path $ArchivePath $file.Name
            Move-Item -Path $file.FullName -Destination $dest -Force

            # Sound alert (respects mute toggle)
            if (-not $script:muteSound) {
                [console]::beep(1000, 250)
            }
            $form.WindowState = "Normal"
            $form.Activate()

            Show-Toast "$charEnvelope New message from $from" "success"

            # Flash taskbar when window is not focused
            try { [WinDrag]::Flash($form.Handle) } catch {}
        } catch {}
    }
}

#endregion

#region EVENT WIRING

# Search filter
$filterBox.Add_GotFocus({
    if ($filterBox.Text -eq "Search contacts...") {
        $filterBox.Text = ""
        $filterBox.ForeColor = $txtPrimary
    }
})
$filterBox.Add_LostFocus({
    if ($filterBox.Text -eq "") {
        $filterBox.Text = "Search contacts..."
        $filterBox.ForeColor = $txtMuted
    }
})
$filterBox.Add_TextChanged({
    $searchDebounce.Stop()
    $searchDebounce.Start()
})

# Department filter
$cmbDept.Add_SelectedIndexChanged({
    Load-Clients
})

# Contact selection — auto-focus message input (#5)
$lstContacts.Add_SelectedIndexChanged({
    if ($lstContacts.SelectedItem) {
        $peer = $lstContacts.SelectedItem.ToString()
        Load-ConversationForClient -PeerName $peer
        $lblReplyHint.Text = "Message $peer"
        # Auto-focus message input
        if ($txtMessage.Text -eq "Type a message...") {
            $txtMessage.Text = ""
            $txtMessage.ForeColor = $txtPrimary
        }
        $txtMessage.Focus()
    }
})

# Send button
$btnSend.Add_Click({
    $btnSend.Enabled = $false
    $btnSend.Text = "SENDING..."
    Send-MessageToPeer
    $btnSend.Enabled = $true
    $btnSend.Text = "$charEnvelope  SEND"
})

# Close buttons
$btnFooterClose.Add_Click({ $form.Close() })

# Message placeholder events + focus ring
$txtMessage.Add_GotFocus({
    if ($txtMessage.Text -eq "Type a message...") {
        $txtMessage.Text = ""
        $txtMessage.ForeColor = $txtPrimary
    }
    $pnlInputWrap.Tag = $accent
    $pnlInputWrap.Invalidate()
})
$txtMessage.Add_LostFocus({
    if ($txtMessage.Text -eq "") {
        $txtMessage.Text = "Type a message..."
        $txtMessage.ForeColor = $txtMuted
    }
    $pnlInputWrap.Tag = $cardBorder
    $pnlInputWrap.Invalidate()
})

# Character counter (skip placeholder)
$txtMessage.Add_TextChanged({
    $t = $txtMessage.Text
    if ($t -eq "Type a message...") {
        $lblCharCount.Text = "0 / 500"
        $lblCharCount.ForeColor = $txtMuted
        return
    }
    $len = $t.Length
    $lblCharCount.Text = "$len / 500"
    if ($len -gt 440)     { $lblCharCount.ForeColor = $errorCol }
    elseif ($len -gt 380) { $lblCharCount.ForeColor = [System.Drawing.Color]::FromArgb(217, 119, 6) }
    else                  { $lblCharCount.ForeColor = $txtMuted }
})

# Keyboard: Enter = send, Shift+Enter = newline (#4), Ctrl+Enter also sends
$form.KeyPreview = $true
$form.Add_KeyDown({
    param($s, $e)
    # Ctrl+Enter always sends
    if ($e.Control -and $e.KeyCode -eq "Return") {
        $e.SuppressKeyPress = $true
        $btnSend.PerformClick()
        return
    }
    # Plain Enter sends when message input is focused (Shift+Enter = newline)
    if ($e.KeyCode -eq "Return" -and -not $e.Shift -and $txtMessage.Focused) {
        $e.SuppressKeyPress = $true
        $btnSend.PerformClick()
    }
})

#endregion

#region TIMERS

# Fast timer: inbox poll + heartbeat write only — no UI invalidation
$timer          = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    Process-IncomingMessages
    Write-Heartbeat
})

# Slow timer: refresh heartbeat statuses and only repaint if something changed
$refreshTimer          = New-Object System.Windows.Forms.Timer
$refreshTimer.Interval = 15000
$refreshTimer.Add_Tick({
    $changed = Update-StatusCache
    if ($changed) {
        $lstContacts.Invalidate()
        $pnlChatHeader.Invalidate()
    }
})

#endregion

#region FORM LIFECYCLE

$form.Add_Shown({
    Load-Departments
    Load-Clients
    Write-Heartbeat
    Update-StatusCache | Out-Null
    $timer.Start()
    $refreshTimer.Start()
    $txtMessage.Focus()
})

$form.Add_FormClosing({
    $trayIcon.Visible = $false
    $trayIcon.Dispose()
    $timer.Stop()
    $refreshTimer.Stop()
    $toastTimer.Stop()
    $toastHideTimer.Stop()
    $searchDebounce.Stop()

    foreach ($d in $script:disposables) {
        try { $d.Dispose() } catch {}
    }
})

[void]$form.ShowDialog()

#endregion