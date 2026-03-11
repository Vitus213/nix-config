import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Services.System
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  readonly property int modeWork: 0
  readonly property int modeShortBreak: 1
  readonly property int modeLongBreak: 2

  readonly property var mainInstance: pluginApi?.mainInstance

  onPluginApiChanged: {
    // Force re-evaluation of mainInstance binding when pluginApi changes
    if (pluginApi && pluginApi.mainInstance) {
      mainInstanceChanged();
    }
  }

  readonly property bool compactMode: mainInstance ? mainInstance.compactMode : false
  
  // Only provide proper dimensions when mainInstance is available to prevent blank panel glitches
  readonly property bool panelReady: pluginApi !== null && mainInstance !== null && mainInstance !== undefined
  
  property real contentPreferredWidth: panelReady ? (compactMode ? 340 : 380) * Style.uiScaleRatio : 0
  property real contentPreferredHeight: panelReady ? (compactMode ? 240 : 360) * Style.uiScaleRatio : 0

  anchors.fill: parent
  
  readonly property bool isRunning: mainInstance ? mainInstance.pomodoroRunning : false
  readonly property int currentMode: mainInstance ? mainInstance.pomodoroMode : modeWork
  readonly property int remainingSeconds: mainInstance ? mainInstance.pomodoroRemainingSeconds : 0
  readonly property int totalSeconds: mainInstance ? mainInstance.pomodoroTotalSeconds : 0
  readonly property int originalTotal: mainInstance ? mainInstance.pomodoroOriginalTotal : 0
  readonly property int completedSessions: mainInstance ? mainInstance.pomodoroCompletedSessions : 0
  readonly property int activeTimerType: mainInstance ? mainInstance.activeTimerType : 0
  readonly property int timerPomodoro: mainInstance ? mainInstance.timerPomodoro : 0
  readonly property int timerCountUp: mainInstance ? mainInstance.timerCountUp : 1
  readonly property int timerCountDown: mainInstance ? mainInstance.timerCountDown : 2
  readonly property bool isPomodoroTimer: activeTimerType === timerPomodoro
  readonly property bool isCountUpTimer: activeTimerType === timerCountUp
  readonly property bool isCountDownTimer: activeTimerType === timerCountDown
  readonly property bool customRunning: mainInstance ? mainInstance.customRunning : false
  readonly property int customElapsedSeconds: mainInstance ? mainInstance.customElapsedSeconds : 0
  readonly property int customRemainingSeconds: mainInstance ? mainInstance.customRemainingSeconds : 0
  readonly property int customOriginalTargetSeconds: mainInstance ? mainInstance.customOriginalTargetSeconds : 0
  readonly property int customTargetSeconds: mainInstance ? mainInstance.customTargetSeconds : 0
  readonly property int trackedTotalSeconds: mainInstance ? mainInstance.trackedTotalSeconds : 0
  readonly property int trackedTotalHours: Math.floor(trackedTotalSeconds / 3600)
  readonly property int trackedTotalMinutes: Math.floor((trackedTotalSeconds % 3600) / 60)
  readonly property bool soundPlaying: mainInstance ? mainInstance.pomodoroSoundPlaying : false
  readonly property int sessionsBeforeLongBreak: mainInstance ? mainInstance.sessionsBeforeLongBreak : 4
  readonly property bool timerRunning: isPomodoroTimer ? isRunning : customRunning
  readonly property int displayedSeconds: {
    if (isPomodoroTimer)
      return remainingSeconds;
    if (isCountDownTimer)
      return customRemainingSeconds;
    return customElapsedSeconds;
  }
  readonly property int displayTotalSeconds: {
    if (isPomodoroTimer)
      return totalSeconds;
    if (isCountDownTimer)
      return customOriginalTargetSeconds;
    return 0;
  }
  readonly property bool timerHasProgress: {
    return isPomodoroTimer && originalTotal > 0;
  }
  
  function startTimer() { if (mainInstance) mainInstance.startActiveTimer(); }
  function pauseTimer() { if (mainInstance) mainInstance.pauseActiveTimer(); }
  function resetSession() { if (mainInstance) mainInstance.resetActiveTimer(); }
  function resetAll() { if (mainInstance) mainInstance.resetAllTimers(); }
  function skipTimer() { if (mainInstance) mainInstance.pomodoroSkip(); }
  function stopAlarm() { if (mainInstance) mainInstance.pomodoroStopAlarm(); }
  function finishTimer() { if (mainInstance) mainInstance.customFinish(); }
  function abandonTimer() { if (mainInstance) mainInstance.customAbandon(); }
  function setTimerType(type) { if (mainInstance) mainInstance.setActiveTimerType(type); }
  function setCountdownDuration(hours, minutes) {
    if (!mainInstance)
      return;
    const totalMinutes = Math.max(1, Math.floor(Number(hours)) * 60 + Math.floor(Number(minutes)));
    mainInstance.customSetCountdownDurationMinutes(totalMinutes);
  }

  function formatTime(seconds, totalTimeSeconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (!totalTimeSeconds || totalTimeSeconds === 0) {
      if (hours > 0) {
        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
      }
      return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }

    if (totalTimeSeconds < 3600) {
      return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
  
  function getModeIcon() {
    if (isCountUpTimer) return "clock-up"
    if (isCountDownTimer) return "hourglass"
    if (currentMode === modeWork) return "brain"
    if (currentMode === modeShortBreak) return "coffee"
    if (currentMode === modeLongBreak) return "bed"
    return "clock"
  }
  
  function getModeName() {
    if (isCountUpTimer) return pluginApi?.tr("panel.count-up") || "Count Up"
    if (isCountDownTimer) return pluginApi?.tr("panel.count-down") || "Count Down"
    if (currentMode === modeWork) return pluginApi?.tr("panel.work") || "Work"
    if (currentMode === modeShortBreak) return pluginApi?.tr("panel.short-break") || "Short Break"
    if (currentMode === modeLongBreak) return pluginApi?.tr("panel.long-break") || "Long Break"
    return "Pomodoro"
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"
    visible: panelReady

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginL

      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          id: content
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM
          clip: true

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: getModeIcon()
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            NText {
              text: pluginApi?.tr("panel.title") || "Pomodoro"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            Item {
              id: alarmButtonContainer
              Layout.alignment: Qt.AlignVCenter
              Layout.preferredWidth: soundPlaying ? (bellIcon.implicitWidth + Style.marginS) : 0
              Layout.preferredHeight: bellIcon.implicitHeight + Style.marginS
              clip: true

              Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
              }

              NIcon {
                id: bellIcon
                anchors.centerIn: parent
                icon: "bell-ringing"
                pointSize: Style.fontSizeXL
                color: bellMouseArea.containsMouse ? Qt.lighter(Color.mError, 1.2) : Color.mError
                opacity: soundPlaying ? 1 : 0

                Behavior on opacity {
                  NumberAnimation { duration: 150 }
                }
              }

              MouseArea {
                id: bellMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: soundPlaying
                cursorShape: Qt.PointingHandCursor
                onClicked: stopAlarm()
              }
            }
            
            NText {
              visible: isPomodoroTimer
              text: (pluginApi?.tr("panel.session") || "Session") + " " + (completedSessions + 1) + "/" + sessionsBeforeLongBreak
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            NText {
              text: (pluginApi?.tr("panel.total-hours") || "Total") + ": " + trackedTotalHours + "h " + trackedTotalMinutes + "m"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NButton {
              Layout.fillWidth: true
              text: pluginApi?.tr("panel.timer-pomodoro") || "Pomodoro"
              icon: "brain"
              enabled: !timerRunning || isPomodoroTimer
              onClicked: setTimerType(timerPomodoro)
            }

            NButton {
              Layout.fillWidth: true
              text: pluginApi?.tr("panel.timer-count-up") || "Count Up"
              icon: "clock-up"
              enabled: !timerRunning || isCountUpTimer
              onClicked: setTimerType(timerCountUp)
            }

            NButton {
              Layout.fillWidth: true
              text: pluginApi?.tr("panel.timer-count-down") || "Count Down"
              icon: "hourglass"
              enabled: !timerRunning || isCountDownTimer
              onClicked: setTimerType(timerCountDown)
            }
          }

          RowLayout {
            visible: isCountDownTimer
            Layout.fillWidth: true
            spacing: Style.marginS

            SpinBox {
              id: countdownHours
              Layout.fillWidth: true
              from: 0
              to: 23
              editable: true
              enabled: !customRunning && customElapsedSeconds === 0
              value: Math.floor(customTargetSeconds / 3600)
              onValueModified: setCountdownDuration(value, countdownMinutes.value)
            }

            SpinBox {
              id: countdownMinutes
              Layout.fillWidth: true
              from: 0
              to: 59
              editable: true
              enabled: !customRunning && customElapsedSeconds === 0
              value: Math.floor((customTargetSeconds % 3600) / 60)
              onValueModified: setCountdownDuration(countdownHours.value, value)
            }
          }

      Item {
        id: timerDisplayItem
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Style.marginM

        Canvas {
          id: progressRing
          anchors.centerIn: parent
          width: Math.min(parent.width, parent.height) * 0.9
          height: width
          visible: timerHasProgress && !compactMode && (timerRunning || displayedSeconds > 0)
          z: -1

          property real progressRatio: {
            if (!timerHasProgress)
              return 0;
            const denominator = isPomodoroTimer ? originalTotal : customOriginalTargetSeconds;
            if (denominator <= 0)
              return 0;
            const ratio = displayedSeconds / denominator;
            return Math.max(0, Math.min(1, ratio));
          }

          onProgressRatioChanged: requestPaint()

          onPaint: {
            var ctx = getContext("2d");
            if (width <= 0 || height <= 0) {
              return;
            }

            var centerX = width / 2;
            var centerY = height / 2;
            var radius = Math.min(width, height) / 2 - 5;

            if (radius <= 0) {
              return;
            }

            ctx.reset();

            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
            ctx.lineWidth = 6;
            ctx.strokeStyle = Qt.alpha(Color.mOnSurface, 0.1);
            ctx.stroke();

            if (progressRatio > 0) {
              ctx.beginPath();
              ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + progressRatio * 2 * Math.PI);
              ctx.lineWidth = 6;
              ctx.strokeStyle = Color.mPrimary;
              ctx.lineCap = "round";
              ctx.stroke();
            }
          }
        }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.marginS
          
          NText {
            id: modeLabel
            Layout.alignment: Qt.AlignHCenter
            text: getModeName()
            pointSize: Style.fontSizeM
            color: Color.mPrimary
            font.weight: Style.fontWeightMedium
          }

          NText {
            id: timerDisplay
            Layout.alignment: Qt.AlignHCenter
            font.family: Settings.data.ui.fontFixed

            readonly property bool showingHours: displayTotalSeconds >= 3600 || displayedSeconds >= 3600

            font.pointSize: {
              const scale = compactMode ? 0.8 : 1.0;
              return (showingHours ? Style.fontSizeXXL * 1.3 : (Style.fontSizeXXL * 1.8)) * scale;
            }

            font.weight: Style.fontWeightBold
            color: Color.mPrimary

            text: formatTime(displayedSeconds, displayTotalSeconds)
          }
        }
      }

      GridLayout {
        visible: isPomodoroTimer
        id: buttonGrid
        Layout.fillWidth: true
        columns: 2
        rowSpacing: Style.marginS
        columnSpacing: Style.marginS
        uniformCellWidths: true

        NButton {
          id: startButton
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          text: timerRunning ? (pluginApi?.tr("panel.pause") || "Pause") : (displayTotalSeconds > 0 ? (pluginApi?.tr("panel.resume") || "Resume") : (pluginApi?.tr("panel.start") || "Start"))
          icon: timerRunning ? "player-pause" : "player-play"
          onClicked: {
            if (timerRunning) {
              pauseTimer();
            } else {
              startTimer();
            }
          }
        }

        NButton {
          id: skipButton
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          text: pluginApi?.tr("panel.skip") || "Skip"
          icon: "player-skip-forward"
          enabled: isRunning || remainingSeconds > 0 || totalSeconds > 0
          onClicked: {
            skipTimer();
          }
        }

        NButton {
          id: resetButton
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          text: pluginApi?.tr("panel.reset") || "Reset"
          icon: "refresh"
          enabled: isRunning || remainingSeconds > 0 || soundPlaying
          onClicked: {
            resetSession();
          }
        }

        NButton {
          id: resetAllButton
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          text: pluginApi?.tr("panel.reset-all") || "Reset All"
          icon: "rotate"
          enabled: isRunning || remainingSeconds > 0 || soundPlaying || completedSessions > 0
          onClicked: {
            resetAll();
          }
        }
      }

      GridLayout {
        visible: !isPomodoroTimer
        Layout.fillWidth: true
        columns: 2
        rowSpacing: Style.marginS
        columnSpacing: Style.marginS
        uniformCellWidths: true

        NButton {
          Layout.fillWidth: true
          text: customRunning ? (pluginApi?.tr("panel.pause") || "Pause") : ((customElapsedSeconds > 0 || (isCountDownTimer && customRemainingSeconds < customTargetSeconds)) ? (pluginApi?.tr("panel.resume") || "Resume") : (pluginApi?.tr("panel.start") || "Start"))
          icon: customRunning ? "player-pause" : "player-play"
          onClicked: {
            if (customRunning) {
              pauseTimer();
            } else {
              startTimer();
            }
          }
        }

        NButton {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.finish") || "Finish"
          icon: "flag"
          enabled: customRunning || customElapsedSeconds > 0
          onClicked: finishTimer()
        }

        NButton {
          Layout.fillWidth: true
          Layout.columnSpan: 2
          text: pluginApi?.tr("panel.abandon") || "Abandon"
          icon: "x"
          enabled: customRunning || customElapsedSeconds > 0 || (isCountDownTimer && customRemainingSeconds < customTargetSeconds)
          onClicked: abandonTimer()
        }
      }
        }
      }
    }
  }
}
