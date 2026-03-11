import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.System

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property bool pillDirection: BarService.getPillDirection(root)

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property int timerPomodoro: mainInstance ? mainInstance.timerPomodoro : 0
  readonly property int timerCountUp: mainInstance ? mainInstance.timerCountUp : 1
  readonly property int timerCountDown: mainInstance ? mainInstance.timerCountDown : 2
  readonly property int activeTimerType: mainInstance ? mainInstance.activeTimerType : timerPomodoro
  readonly property bool isPomodoroTimer: activeTimerType === timerPomodoro
  readonly property bool isCountUpTimer: activeTimerType === timerCountUp
  readonly property bool isCountDownTimer: activeTimerType === timerCountDown
  readonly property bool timerRunning: {
    if (!mainInstance)
      return false
    return isPomodoroTimer ? mainInstance.pomodoroRunning : mainInstance.customRunning
  }
  readonly property int displayedSeconds: {
    if (!mainInstance)
      return 0
    if (isPomodoroTimer)
      return mainInstance.pomodoroRemainingSeconds
    if (isCountDownTimer)
      return mainInstance.customRemainingSeconds
    return mainInstance.customElapsedSeconds
  }
  readonly property bool isActive: {
    if (!mainInstance)
      return false
    if (isPomodoroTimer)
      return mainInstance.pomodoroRunning || mainInstance.pomodoroRemainingSeconds > 0 || mainInstance.pomodoroTotalSeconds > 0
    if (isCountDownTimer)
      return mainInstance.customRunning || mainInstance.customElapsedSeconds > 0 || mainInstance.customRemainingSeconds < mainInstance.customTargetSeconds
    return mainInstance.customRunning || mainInstance.customElapsedSeconds > 0
  }

  readonly property int modeWork: 0
  readonly property int modeShortBreak: 1
  readonly property int modeLongBreak: 2

  readonly property string barPosition: Settings.data.bar.position || "top"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  readonly property real contentWidth: {
    if (barIsVertical) return Style.capsuleHeight
    if (isActive) return contentRow.implicitWidth + Style.marginM * 2
    return Style.capsuleHeight
  }
  readonly property real contentHeight: Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  function formatTime(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  function getModeIcon() {
    if (!mainInstance) return "clock"
    if (mainInstance.pomodoroSoundPlaying) return "bell-ringing"
    if (isCountUpTimer) return "clock"
    if (isCountDownTimer) return "hourglass"
    if (mainInstance.pomodoroMode === modeWork) return "brain"
    if (mainInstance.pomodoroMode === modeShortBreak) return "coffee"
    if (mainInstance.pomodoroMode === modeLongBreak) return "bed"
    return "clock"
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: {
      if (mouseArea.containsMouse &&
          (!mainInstance || (!mainInstance.pomodoroRunning && !mainInstance.pomodoroSoundPlaying)))
        return Color.mHover
      return Style.capsuleColor
    }
    radius: Style.radiusL

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginS
      layoutDirection: Qt.LeftToRight

      NIcon {
        icon: getModeIcon()
        applyUiScale: false
        color: {
          if (mainInstance && (mainInstance.pomodoroRunning || mainInstance.pomodoroSoundPlaying)) {
            return Color.mPrimary
          }
          return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
      }

      NText {
        visible: !barIsVertical && isActive
        family: Settings.data.ui.fontFixed
        pointSize: Style.barFontSize
        text: {
          if (!mainInstance) return ""
          return formatTime(displayedSeconds)
        }
        color: {
          if (mainInstance && (mainInstance.pomodoroRunning || mainInstance.pomodoroSoundPlaying)) {
            return Color.mPrimary
          }
          return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: {
      var items = [];

      if (mainInstance) {
        if (isPomodoroTimer && (mainInstance.pomodoroRunning || mainInstance.pomodoroRemainingSeconds > 0 || mainInstance.pomodoroTotalSeconds > 0)) {
          items.push({
            "label": mainInstance.pomodoroRunning ? pluginApi.tr("panel.pause") : pluginApi.tr("panel.resume"),
            "action": "toggle",
            "icon": mainInstance.pomodoroRunning ? "media-pause" : "media-play"
          });

          items.push({
            "label": pluginApi.tr("panel.skip"),
            "action": "skip",
            "icon": "player-skip-forward"
          });

          items.push({
            "label": pluginApi.tr("panel.reset"),
            "action": "reset",
            "icon": "refresh"
          });

          items.push({
            "label": pluginApi.tr("panel.reset-all"),
            "action": "reset-all",
            "icon": "rotate"
          });
        } else if (!isPomodoroTimer && isActive) {
          items.push({
            "label": timerRunning ? pluginApi.tr("panel.pause") : pluginApi.tr("panel.resume"),
            "action": "toggle",
            "icon": timerRunning ? "media-pause" : "media-play"
          });

          items.push({
            "label": pluginApi.tr("panel.finish") || "Finish",
            "action": "finish",
            "icon": "player-stop"
          });

          items.push({
            "label": pluginApi.tr("panel.abandon") || "Abandon",
            "action": "abandon",
            "icon": "x"
          });
        }
      }

      items.push({
        "label": pluginApi.tr("panel.settings"),
        "action": "widget-settings",
        "icon": "settings"
      });

      return items;
    }

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "widget-settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest);
      } else if (mainInstance) {
        if (action === "toggle") {
          if (timerRunning) {
            mainInstance.pauseActiveTimer();
          } else {
            mainInstance.startActiveTimer();
          }
        } else if (action === "reset") {
          mainInstance.pomodoroResetSession();
        } else if (action === "reset-all") {
          mainInstance.resetAllTimers();
        } else if (action === "skip") {
          mainInstance.pomodoroSkip();
        } else if (action === "finish") {
          mainInstance.customFinish();
        } else if (action === "abandon") {
          mainInstance.customAbandon();
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) {
          pluginApi.openPanel(root.screen, root)
        }
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      } else if (mouse.button === Qt.MiddleButton) {
        if (!mainInstance)
          return
        timerRunning
          ? mainInstance.pauseActiveTimer()
          : mainInstance.startActiveTimer()
      }
    }
  }
}
