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

  // Bluetooth state
  property bool btPowered: false
  property bool btConnected: false
  property bool btMenuVisible: false
  property bool btScanning: false
  property bool btConfirmDisable: false
  property var btDevices: []

  function btRefreshDevices() {
    btDeviceProc.running = true
  }

  function btTogglePower() {
    btPowerProc.running = true
  }

  function btConnect(mac) {
    btConnectProc.command = ["bluetoothctl", "connect", mac]
    btConnectProc.running = true
  }

  function btDisconnect(mac) {
    btDisconnectProc.command = ["bluetoothctl", "disconnect", mac]
    btDisconnectProc.running = true
  }

  function btStartScan() {
    root.btScanning = true
    btScanProc.running = true
  }

  function btStopScan() {
    btScanStopProc.running = true
  }

  // Bluetooth power status
  Process {
    running: true
    onRunningChanged: if (!running) running = true
    command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
    stdout: StdioCollector {
      onStreamFinished: root.btPowered = this.text.trim() === "on"
    }
  }

  // Bluetooth connected status
  Process {
    running: true
    onRunningChanged: if (!running) running = true
    command: ["bluetoothctl", "devices", "Connected"]
    stdout: StdioCollector {
      onStreamFinished: root.btConnected = this.text.trim().length > 0
    }
  }

  // Get paired devices with connection status
  Process {
    id: btDeviceProc
    running: true
    onRunningChanged: if (!running) running = true
    command: ["sh", "-c", `
      paired=$(bluetoothctl devices Paired)
      connected=$(bluetoothctl devices Connected)
      echo "$paired" | while read -r line; do
        if [ -n "$line" ]; then
          mac=$(echo "$line" | awk '{print $2}')
          name=$(echo "$line" | cut -d' ' -f3-)
          if echo "$connected" | grep -q "$mac"; then
            echo "1|$mac|$name"
          else
            echo "0|$mac|$name"
          fi
        fi
      done
    `]
    stdout: StdioCollector {
      onStreamFinished: {
        let lines = this.text.trim().split('\n').filter(l => l.length > 0)
        root.btDevices = lines.map(line => {
          let parts = line.split('|')
          return { connected: parts[0] === '1', mac: parts[1], name: parts[2] }
        })
      }
    }
  }

  // Toggle power
  Process {
    id: btPowerProc
    running: false
    command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on"]
    onRunningChanged: if (!running) root.btRefreshDevices()
  }

  // Connect to device
  Process {
    id: btConnectProc
    running: false
    onRunningChanged: if (!running) root.btRefreshDevices()
  }

  // Disconnect from device
  Process {
    id: btDisconnectProc
    running: false
    onRunningChanged: if (!running) root.btRefreshDevices()
  }

  // Scan for devices
  Process {
    id: btScanProc
    running: false
    command: ["timeout", "10", "bluetoothctl", "scan", "on"]
    onRunningChanged: if (!running) { root.btScanning = false; root.btRefreshDevices() }
  }

  // Stop scan
  Process {
    id: btScanStopProc
    running: false
    command: ["bluetoothctl", "scan", "off"]
    onRunningChanged: if (!running) { root.btScanning = false; root.btRefreshDevices() }
  }

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

  // Bluetooth Menu Backdrop (click outside to close)
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.btMenuVisible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.btMenuVisible = false
      }
    }
  }

  // Bluetooth Menu
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.btMenuVisible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        right: true
      }

      implicitWidth: 280
      implicitHeight: Math.min(400, 60 + (root.btDevices.length * 50) + 60)
      margins {
        top: 50
        right: 20
      }

      Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#1e1e2e"
        border.color: "#45475a"
        border.width: 1

        Column {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          // Header with power toggle
          Row {
            width: parent.width
            spacing: 10

            Text {
              text: "󰂯"
              color: root.btPowered ? "#89b4fa" : "#6c7086"
              font.pixelSize: 20
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "Bluetooth"
              color: "#cdd6f4"
              font.pixelSize: 14
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 180; height: 1 }

            Rectangle {
              width: 44
              height: 24
              radius: 12
              color: root.btPowered ? "#89b4fa" : "#45475a"
              anchors.verticalCenter: parent.verticalCenter

              Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#cdd6f4"
                anchors.verticalCenter: parent.verticalCenter
                x: root.btPowered ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 150 } }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.btPowered) {
                    root.btConfirmDisable = true
                  } else {
                    root.btTogglePower()
                  }
                }
              }
            }
          }

          // Confirmation dialog
          Rectangle {
            visible: root.btConfirmDisable
            width: parent.width
            height: 80
            radius: 8
            color: "#313244"

            Column {
              anchors.centerIn: parent
              spacing: 10

              Text {
                text: "Turn off Bluetooth?"
                color: "#cdd6f4"
                font.pixelSize: 12
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                  width: 80
                  height: 28
                  radius: 6
                  color: cancelMouse.containsMouse ? "#45475a" : "#3b3d4d"

                  Text {
                    text: "Cancel"
                    color: "#cdd6f4"
                    font.pixelSize: 11
                    anchors.centerIn: parent
                  }

                  MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.btConfirmDisable = false
                  }
                }

                Rectangle {
                  width: 80
                  height: 28
                  radius: 6
                  color: confirmMouse.containsMouse ? "#f38ba8" : "#e06080"

                  Text {
                    text: "Turn Off"
                    color: "#1e1e2e"
                    font.pixelSize: 11
                    font.bold: true
                    anchors.centerIn: parent
                  }

                  MouseArea {
                    id: confirmMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.btConfirmDisable = false
                      root.btTogglePower()
                    }
                  }
                }
              }
            }
          }

          // Divider
          Rectangle {
            width: parent.width
            height: 1
            color: "#45475a"
          }

          // Device list
          Flickable {
            width: parent.width
            height: parent.height - 100
            clip: true
            contentHeight: deviceColumn.height

            Column {
              id: deviceColumn
              width: parent.width
              spacing: 4

              Repeater {
                model: root.btDevices

                Rectangle {
                  width: parent.width
                  height: 44
                  radius: 8
                  color: mouseArea.containsMouse ? "#313244" : "transparent"

                  Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    Text {
                      text: modelData.connected ? "󰂱" : "󰂳"
                      color: modelData.connected ? "#a6e3a1" : "#6c7086"
                      font.pixelSize: 16
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - 80

                      Text {
                        text: modelData.name
                        color: "#cdd6f4"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        width: parent.width
                      }

                      Text {
                        text: modelData.connected ? "Connected" : "Paired"
                        color: modelData.connected ? "#a6e3a1" : "#6c7086"
                        font.pixelSize: 10
                      }
                    }
                  }

                  MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.connected) {
                        root.btDisconnect(modelData.mac)
                      } else {
                        root.btConnect(modelData.mac)
                      }
                    }
                  }
                }
              }

              // Empty state
              Text {
                visible: root.btDevices.length === 0
                text: root.btPowered ? "No paired devices" : "Bluetooth is off"
                color: "#6c7086"
                font.pixelSize: 12
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 20
              }
            }
          }

          // Scan button
          Rectangle {
            width: parent.width
            height: 36
            radius: 8
            color: root.btScanning ? "#45475a" : (scanMouseArea.containsMouse ? "#313244" : "#45475a")
            visible: root.btPowered

            Row {
              anchors.centerIn: parent
              spacing: 8

              Text {
                text: root.btScanning ? "󰐊" : "󰑐"
                color: "#cdd6f4"
                font.pixelSize: 14
              }

              Text {
                text: root.btScanning ? "Scanning..." : "Scan for devices"
                color: "#cdd6f4"
                font.pixelSize: 12
              }
            }

            MouseArea {
              id: scanMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.btScanning) {
                  root.btStopScan()
                } else {
                  root.btStartScan()
                }
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

          // Bluetooth
          Rectangle {
            width: btIcon.width + 8
            height: btIcon.height + 4
            radius: 4
            color: btMouseArea.containsMouse ? "#45475a" : "transparent"

            Text {
              id: btIcon
              anchors.centerIn: parent
              text: root.btConnected ? "󰂱" : root.btPowered ? "󰂯" : "󰂲"
              color: btMouseArea.containsMouse ? "#89b4fa" : root.btConnected ? "#cdd6f4" : root.btPowered ? "#6c7086" : "#f38ba8"
              font.pixelSize: 14
            }

            MouseArea {
              id: btMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.btRefreshDevices()
                root.btMenuVisible = !root.btMenuVisible
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
