import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Variants {
  model: Quickshell.screens
  
  PanelWindow {
    required property var modelData
    screen: modelData
    
    anchors {
      top: true
      left: true
      right: true
    }
    
    implicitHeight: 40
    margins {
      left: 10
      right: 10
      top: 10
    }
    
    color: "transparent"
    
    Rectangle {
      anchors.fill: parent
      color: "transparent"
      radius: 10
      opacity: 0.9
      
      Item {
        anchors {
          fill: parent
          leftMargin: 15
          rightMargin: 15
        }
        
        // Left section - workspaces
        Row {
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
          }
          spacing: 10
          
          Repeater {
            model: Hyprland.workspaces
            delegate: Rectangle {
              width: 30
              height: 30
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
            if (Hyprland.focusedWindow) {
              let title = Hyprland.focusedWindow.title
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
            property var audioNode: Pipewire.linkGroups.speakers ? Pipewire.linkGroups.speakers.audio : null
            text: " " + Math.round(audioNode && audioNode.volume ? audioNode.volume * 100 : 0) + "%"
            color: audioNode && audioNode.muted ? "#f38ba8" : "#cdd6f4"
            font.pixelSize: 14
          }
          
          // Network
          Text {
            property string networkStatus: "Checking..."
            property string networkIcon: {
              if (networkStatus === "connected") return "󰤨"
              if (networkStatus === "connecting") return "󰤪"
              return "󰤭"
            }
            text: networkIcon + "  " + (networkStatus === "connected" ? "Connected" : "Disconnected")
            color: networkStatus === "connected" ? "#cdd6f4" : "#f38ba8"
            font.pixelSize: 14
            
            Process {
              id: networkCheck
              command: ["nmcli", "-t", "-f", "STATE", "general"]
              running: true
              onExited: {
                if (exitCode === 0) {
                  parent.networkStatus = stdout.trim()
                } else {
                  parent.networkStatus = "disconnected"
                }
              }
            }
            
            Timer {
              interval: 5000
              running: true
              repeat: true
              onTriggered: networkCheck.start()
            }
            
            Component.onCompleted: networkCheck.start()
          }
          
          // Battery
          Text {
            property var battery: UPower ? UPower.displayDevice : null
            property bool hasBattery: battery !== null && battery !== undefined
            property string batteryIcon: {
              if (!hasBattery) return "󰚥"
              if (battery.charging) return "󰂄"
              let pct = battery.percentage || 0
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
            text: batteryIcon + " " + (hasBattery ? Math.round(battery.percentage) : "AC") + (hasBattery ? "%" : "")
            color: hasBattery && battery.percentage < 20 ? "#f38ba8" : "#cdd6f4"
            font.pixelSize: 14
            visible: true
          }
          
          // Clock
          Text {
            text: {
              try {
                return Qt.formatDateTime(new Date(), "HH:mm")
              } catch (e) {
                return new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})
              }
            }
            color: "#cdd6f4"
            font.pixelSize: 14
            
            Timer {
              interval: 1000
              running: true
              repeat: true
              onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm")
            }
          }
        }
      }
    }
  }
}
