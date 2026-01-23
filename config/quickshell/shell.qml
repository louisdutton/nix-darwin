import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Scope {
  id: root
  property int volumePct: 0
  property bool volumeMuted: false
  property int prevVolumePct: 0
  property bool prevVolumeMuted: false
  property bool osdVisible: false

  Process {
    running: true
    onRunningChanged: if (!running) running = true
    command: ["pamixer", "--get-volume-human"]
    stdout: StdioCollector {
      onStreamFinished: {
        let val = this.text.trim()
        root.volumeMuted = val === "muted" || val === "0%"
        root.volumePct = val === "muted" ? 0 : parseInt(val) || 0

        if (root.volumePct !== root.prevVolumePct || root.volumeMuted !== root.prevVolumeMuted) {
          if (root.prevVolumePct !== 0 || root.prevVolumeMuted !== false) {
            root.osdVisible = true
            osdTimer.restart()
          }
          root.prevVolumePct = root.volumePct
          root.prevVolumeMuted = root.volumeMuted
        }
      }
    }
  }

  Timer {
    id: osdTimer
    interval: 1500
    onTriggered: root.osdVisible = false
  }

  // Volume OSD
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: osdWindow
      required property var modelData
      screen: modelData
      visible: root.osdVisible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      anchors {
        bottom: true
        left: true
        right: true
      }

      implicitHeight: 80
      margins.bottom: 100

      Rectangle {
        anchors.centerIn: parent
        width: 280
        height: 60
        radius: 12
        color: "#1e1e2e"
        border.color: "#45475a"
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: 15

          Text {
            text: root.volumeMuted ? "󰝟" : "󰕾"
            color: root.volumeMuted ? "#f38ba8" : "#cdd6f4"
            font.pixelSize: 28
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
              text: root.volumeMuted ? "Muted" : root.volumePct + "%"
              color: "#cdd6f4"
              font.pixelSize: 14
              font.bold: true
            }

            Rectangle {
              width: 180
              height: 6
              radius: 3
              color: "#45475a"

              Rectangle {
                width: parent.width * (root.volumePct / 100)
                height: parent.height
                radius: 3
                color: root.volumeMuted ? "#f38ba8" : "#89b4fa"
              }
            }
          }
        }
      }
    }
  }

  // Status bar
  Variants {
    model: Quickshell.screens

    PanelWindow {
    required property var modelData
    screen: modelData
    color: "transparent"
    
    anchors {
      top: true
      left: true
      right: true
    }
    
    implicitHeight: 30
    margins {
      top: 10
      left: 10
      right: 10
    }
    
    Rectangle {
      anchors.fill: parent
      color: "transparent"
      
      Item {
        anchors {
          fill: parent
          leftMargin: 2
          rightMargin: 2
        }
        
        // Left section - workspaces
        Row {
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
          }
          spacing: 5
          
          Repeater {
            model: Hyprland.workspaces
            delegate: Rectangle {
              width: 26
              height: 26
              radius: 4
              color: modelData.active ? "#89b4fa" : "#45475a"
              
              Text {
                anchors.centerIn: parent
                text: modelData.id
                color: modelData.active ? "#1e1e2e" : "#cdd6f4" 
                font.pixelSize: 12
                font.bold: modelData.active
              }
              
              MouseArea {
                anchors.fill: parent
                onClicked: modelData.activate()
                cursorShape: Qt.PointingHandCursor
              }
            }
          }
        }
        
        // Center section - window title
        Text {
          anchors.centerIn: parent
          text: {
            if (Hyprland.activeTopLevel) {
              let title = Hyprland.activeTopLevel.title
              return title.length > 50 ? title.substring(0, 47) + "..." : title
            }
            return "Desktop"
          }
          color: "#cdd6f4"
          font.pixelSize: 14
          elide: Text.ElideRight
          maximumLineCount: 1
        }
        
        // Right section - system info
        Row {
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
          }
          spacing: 15
          
          // Volume
          Text {
            text: root.volumeMuted ? "󰝟" : "󰕾"
            color: root.volumeMuted ? "#f38ba8" : "#cdd6f4"
            font.pixelSize: 14
          }

          // Network
          Text {
            id: network
            property string networkStatus: "disconnected"
            property string networkIcon: {
              switch (networkStatus) {
                case "connected": return "󰤨"
                case "connecting": return "󰤪"
                default: return "󰤭"
              }
            }
            text: networkIcon
            color: networkStatus === "connected" ? "#cdd6f4" : "#f38ba8"
            font.pixelSize: 14

            Process {
              running: true
              onRunningChanged: if (!running) running = true
              command: ["nmcli", "-t", "-f", "STATE", "general"]
              stdout: StdioCollector {
                onStreamFinished: network.networkStatus = this.text.trim()
              }
            }
          }
          
          // Battery
          Text {
            id: battery
            property int percentage: -1
            property bool charging: false
            property bool hasBattery: percentage >= 0
            property string batteryIcon: {
              if (charging) return "󰂄"
              let pct = percentage
              if (pct > 90) return "󰁹"
              if (pct > 80) return "󰂂"
              if (pct > 70) return "󰂁"
              if (pct > 60) return "󰂀"
              if (pct > 50) return "󰁿"
              if (pct > 40) return "󰁾"
              if (pct > 30) return "󰁽"
              if (pct > 20) return "󰁼"
              if (pct > 10) return "󰁻"
              return "󰁺"
            }
            text: batteryIcon + " " + percentage + "%"
            color: percentage < 20 ? "#f38ba8" : "#cdd6f4"
            font.pixelSize: 14
            visible: hasBattery

            Process {
              running: true
              onRunningChanged: if (!running) running = true
              command: ["sh", "-c", "cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo -1"]
              stdout: StdioCollector {
                onStreamFinished: {
                  let val = Number.parseInt(this.text.trim())
                  battery.percentage = isNaN(val) ? -1 : val
                }
              }
            }

            Process {
              running: battery.hasBattery
              onRunningChanged: if (!running && battery.hasBattery) running = true
              command: ["cat", "/sys/class/power_supply/BAT1/status"]
              stdout: StdioCollector {
                onStreamFinished: battery.charging = this.text.trim() === "Charging"
              }
            }
          }
          
          // Clock
          Text {
            id: clock
            color: "#cdd6f4"
            font.pixelSize: 14

            Process {
              running: true
              onRunningChanged: if (!running) running = true // loop
              command: ["date"]
              stdout: StdioCollector {
                onStreamFinished: clock.text = `󱑂  ${this.text.trim()}` 
              }
            }

          }
        }
      }
    }
    }
  }
}
