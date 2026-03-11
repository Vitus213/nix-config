import QtQuick
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import Quickshell.Io

Item {
  id: root

  // --- CONFIGURATION: Change sound here ---
  readonly property string alarmSoundFile: Qt.resolvedUrl("alarm.mp3").toString().replace("file://", "")


  property var pluginApi: null

  onPluginApiChanged: {
    if (pluginApi) {
      settingsVersion++
      Logger.i("Pomodoro", "pluginApi available, loading settings")
    }
  }

  FileView {
    id: settingsFileWatcher
    path: Qt.resolvedUrl("settings.json")
    
    onTextChanged: {
      if (text && text.length > 0) {
        try {
          var newSettings = JSON.parse(text);
          if (pluginApi && pluginApi.pluginSettings) {
            if (newSettings.workDuration !== undefined)
              pluginApi.pluginSettings.workDuration = newSettings.workDuration;
            if (newSettings.shortBreakDuration !== undefined)
              pluginApi.pluginSettings.shortBreakDuration = newSettings.shortBreakDuration;
            if (newSettings.longBreakDuration !== undefined)
              pluginApi.pluginSettings.longBreakDuration = newSettings.longBreakDuration;
            if (newSettings.sessionsBeforeLongBreak !== undefined)
              pluginApi.pluginSettings.sessionsBeforeLongBreak = newSettings.sessionsBeforeLongBreak;
            if (newSettings.autoStartBreaks !== undefined)
              pluginApi.pluginSettings.autoStartBreaks = newSettings.autoStartBreaks;
            if (newSettings.autoStartWork !== undefined)
              pluginApi.pluginSettings.autoStartWork = newSettings.autoStartWork;
            if (newSettings.compactMode !== undefined)
              pluginApi.pluginSettings.compactMode = newSettings.compactMode;
            if (newSettings.countdownDurationMinutes !== undefined)
              pluginApi.pluginSettings.countdownDurationMinutes = newSettings.countdownDurationMinutes;
              
            // Trigger update
            root.settingsVersion++;
            
            Logger.i("Pomodoro", "Settings reloaded from file");
          }
        } catch (e) {
          Logger.e("Pomodoro", "Failed to parse settings.json: " + e);
        }
      }
    }
  }

  IpcHandler {
    target: "plugin:pomodoro"

    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.togglePanel(screen);
        });
      }
    }

    function start() {
      root.startActiveTimer();
    }

    function pause() {
      root.pauseActiveTimer();
    }

    function reset() {
      root.resetActiveTimer();
    }

    function resetAll() {
      root.resetAllTimers();
    }

    function skip() {
      root.pomodoroSkip();
    }

    function stopAlarm() {
      root.pomodoroStopAlarm();
    }

    function finish() {
      root.finishActiveTimer();
    }

    function abandon() {
      root.abandonActiveTimer();
    }

    function setTimerType(type) {
      root.setActiveTimerType(Number(type));
    }

    function setCountdownMinutes(minutes) {
      root.customSetCountdownDurationMinutes(Number(minutes));
    }
  }

  readonly property int timerPomodoro: 0
  readonly property int timerCountUp: 1
  readonly property int timerCountDown: 2

  readonly property int modeWork: 0
  readonly property int modeShortBreak: 1
  readonly property int modeLongBreak: 2

  property int activeTimerType: timerPomodoro
  property bool pomodoroRunning: false
  property int pomodoroMode: modeWork  // 0-1-2 = work, short-break, long-break
  property int pomodoroRemainingSeconds: 0
  property int pomodoroTotalSeconds: 0
  property int pomodoroOriginalTotal: 0
  property int pomodoroCompletedSessions: 0
  property int trackedTotalSeconds: 0

  property bool customRunning: false
  property bool customCountUpMode: true
  property int customElapsedSeconds: 0
  property int customTargetSeconds: _computeCountdownDuration()
  property int customRemainingSeconds: _computeCountdownDuration()
  property int customOriginalTargetSeconds: _computeCountdownDuration()
  property bool pomodoroSoundPlaying: false
  property bool restoringPersistedState: false

  property int settingsVersion: 0
  
  property int workDuration: _computeWorkDuration()
  property int shortBreakDuration: _computeShortBreakDuration()
  property int longBreakDuration: _computeLongBreakDuration()
  property int sessionsBeforeLongBreak: _computeSessionsBeforeLongBreak()
  property bool autoStartBreaks: _computeAutoStartBreaks()
  property bool autoStartWork: _computeAutoStartWork()
  property bool compactMode: _computeCompactMode()
  property int defaultCountdownDuration: _computeCountdownDuration()
  
  function _computeWorkDuration() { return (pluginApi?.pluginSettings?.workDuration ?? 25) * 60; }
  function _computeShortBreakDuration() { return (pluginApi?.pluginSettings?.shortBreakDuration ?? 5) * 60; }
  function _computeLongBreakDuration() { return (pluginApi?.pluginSettings?.longBreakDuration ?? 15) * 60; }
  function _computeSessionsBeforeLongBreak() { return pluginApi?.pluginSettings?.sessionsBeforeLongBreak ?? 4; }
  function _computeAutoStartBreaks() { return pluginApi?.pluginSettings?.autoStartBreaks ?? false; }
  function _computeAutoStartWork() { return pluginApi?.pluginSettings?.autoStartWork ?? false; }
  function _computeCompactMode() { return pluginApi?.pluginSettings?.compactMode ?? false; }
  function _computeCountdownDuration() {
    const minutes = Number(pluginApi?.pluginSettings?.countdownDurationMinutes ?? 25);
    const safeMinutes = Number.isFinite(minutes) && minutes > 0 ? minutes : 25;
    return Math.floor(safeMinutes * 60);
  }

  function loadPersistedCounters() {
    if (!pluginApi || !pluginApi.pluginSettings)
      return;

    const persistedSeconds = Number(pluginApi.pluginSettings.totalTrackedSeconds);
    const persistedHours = Number(pluginApi.pluginSettings.totalTrackedHours);
    restoringPersistedState = true;
    if (Number.isFinite(persistedSeconds) && persistedSeconds >= 0) {
      root.trackedTotalSeconds = Math.floor(persistedSeconds);
    } else if (Number.isFinite(persistedHours) && persistedHours >= 0) {
      root.trackedTotalSeconds = Math.floor(persistedHours) * 3600;
    } else {
      root.trackedTotalSeconds = 0;
    }
    restoringPersistedState = false;
  }

  function persistCounters() {
    if (!pluginApi || !pluginApi.pluginSettings || restoringPersistedState)
      return;

    pluginApi.pluginSettings.totalTrackedSeconds = root.trackedTotalSeconds;
    pluginApi.pluginSettings.totalTrackedHours = Math.floor(root.trackedTotalSeconds / 3600);
    pluginApi.saveSettings();
  }

  function addTrackedDuration(seconds) {
    const safeSeconds = Math.floor(Number(seconds));
    if (!Number.isFinite(safeSeconds) || safeSeconds <= 0)
      return;
    root.trackedTotalSeconds = root.trackedTotalSeconds + safeSeconds;
  }
  
  onSettingsVersionChanged: {
    workDuration = _computeWorkDuration()
    shortBreakDuration = _computeShortBreakDuration()
    longBreakDuration = _computeLongBreakDuration()
    sessionsBeforeLongBreak = _computeSessionsBeforeLongBreak()
    autoStartBreaks = _computeAutoStartBreaks()
    autoStartWork = _computeAutoStartWork()
    compactMode = _computeCompactMode()
    defaultCountdownDuration = _computeCountdownDuration()
    if (!customRunning && customElapsedSeconds === 0) {
      customTargetSeconds = defaultCountdownDuration
      customRemainingSeconds = customTargetSeconds
      customOriginalTargetSeconds = customTargetSeconds
    }
    loadPersistedCounters()
    Logger.i("Pomodoro", "Settings updated: autoStartBreaks=" + autoStartBreaks + ", autoStartWork=" + autoStartWork + ", compactMode=" + compactMode)
  }

  onTrackedTotalSecondsChanged: {
    persistCounters()
  }

  function getDurationForMode(mode) {
    if (mode === modeWork) return workDuration;
    if (mode === modeShortBreak) return shortBreakDuration;
    if (mode === modeLongBreak) return longBreakDuration;
    return workDuration;
  }

  Timer {
    id: updateTimer
    interval: 1000
    repeat: true
    running: root.pomodoroRunning || root.customRunning
    triggeredOnStart: false

    onTriggered: {
      if (root.pomodoroRunning) {
        root.pomodoroRemainingSeconds = root.pomodoroRemainingSeconds - 1;

        if (root.pomodoroRemainingSeconds <= 0) {
          root.pomodoroOnFinished();
        }
      } else if (root.customRunning) {
        root.customElapsedSeconds = root.customElapsedSeconds + 1;
        if (root.customCountUpMode) {
          return;
        }

        root.customRemainingSeconds = Math.max(0, root.customRemainingSeconds - 1);
        if (root.customRemainingSeconds <= 0) {
          root.customOnFinished(true);
        }
      }
    }
  }

  // ---  Alarm Limit Timer ---
  Timer {
    id: alarmLimitTimer
    interval: 5000 // 5 seconds
    repeat: false
    running: false
    onTriggered: {
       root.pomodoroStopAlarm();
    }
  }

  function pomodoroStart(stopSound = true) {
    // Stop any playing alarm sound when starting, unless explicitly asked not to (for auto-start)
    if (stopSound && root.pomodoroSoundPlaying) {
      SoundService.stopSound(root.alarmSoundFile); // Uses variable
      root.pomodoroSoundPlaying = false;
      alarmLimitTimer.stop();
    }
    
    if (root.pomodoroRemainingSeconds <= 0) {
      root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
      root.pomodoroOriginalTotal = root.pomodoroRemainingSeconds;
    } else if (root.pomodoroOriginalTotal <= 0) {
      root.pomodoroOriginalTotal = root.pomodoroRemainingSeconds;
    }
    
    root.pomodoroTotalSeconds = root.pomodoroRemainingSeconds;
    root.pomodoroRunning = true;
  }

  function pomodoroPause() {
    root.pomodoroRunning = false;
    SoundService.stopSound(root.alarmSoundFile); // Uses variable
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
  }

  function pomodoroResetSession() {
    root.pomodoroRunning = false;
    root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;

    SoundService.stopSound(root.alarmSoundFile); // Uses variable
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
  }

  function pomodoroResetAll() {
    root.pomodoroRunning = false;
    root.pomodoroRemainingSeconds = 0;
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;
    root.pomodoroCompletedSessions = 0;
    root.pomodoroMode = modeWork;

    SoundService.stopSound(root.alarmSoundFile); // Uses variable
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
  }

  function pomodoroSkip() {
    root.pomodoroRunning = false;
    SoundService.stopSound(root.alarmSoundFile); // Uses variable
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
    
    pomodoroAdvanceToNextPhase();
  }

  function pomodoroStopAlarm() {
    if (root.pomodoroSoundPlaying) {
      SoundService.stopSound(root.alarmSoundFile); // Uses variable
      root.pomodoroSoundPlaying = false;
      alarmLimitTimer.stop();
    }
  }

  function setActiveTimerType(type) {
    const normalized = Math.floor(Number(type));
    if (normalized !== timerPomodoro && normalized !== timerCountUp && normalized !== timerCountDown)
      return;
    if (root.pomodoroRunning) root.pomodoroPause();
    if (root.customRunning) root.customPause();
    if (root.activeTimerType === timerCountUp && normalized !== timerCountUp) {
      root.customAbandon();
    }
    if (root.activeTimerType === timerCountDown && normalized !== timerCountDown) {
      root.customAbandon();
    }
    root.activeTimerType = normalized;
    root.customCountUpMode = normalized === timerCountUp;
    if (normalized === timerCountDown && root.customElapsedSeconds === 0 && root.customRemainingSeconds <= 0) {
      root.customRemainingSeconds = Math.max(1, root.customTargetSeconds);
      root.customOriginalTargetSeconds = root.customRemainingSeconds;
    }
  }

  function startActiveTimer() {
    if (root.activeTimerType === timerPomodoro) {
      root.pomodoroStart();
      return;
    }
    root.customCountUpMode = root.activeTimerType === timerCountUp;
    root.customStart();
  }

  function pauseActiveTimer() {
    if (root.activeTimerType === timerPomodoro) {
      root.pomodoroPause();
      return;
    }
    root.customPause();
  }

  function resetActiveTimer() {
    if (root.activeTimerType === timerPomodoro) {
      root.pomodoroResetSession();
      return;
    }
    root.customAbandon();
  }

  function finishActiveTimer() {
    if (root.activeTimerType === timerPomodoro) {
      if (root.pomodoroMode === modeWork && root.pomodoroOriginalTotal > 0) {
        const elapsed = Math.max(0, root.pomodoroOriginalTotal - Math.max(0, root.pomodoroRemainingSeconds));
        root.addTrackedDuration(elapsed);
      }
      root.pomodoroSkip();
      return;
    }
    root.customFinish();
  }

  function abandonActiveTimer() {
    if (root.activeTimerType === timerPomodoro) {
      root.pomodoroResetSession();
      return;
    }
    root.customAbandon();
  }

  function resetAllTimers() {
    root.pomodoroResetAll();
    root.customAbandon();
    root.activeTimerType = timerPomodoro;
  }

  function pomodoroSetMode(mode) {
    if (root.pomodoroRunning) {
      root.pomodoroPause();
    }
    root.pomodoroMode = mode;
    root.pomodoroRemainingSeconds = getDurationForMode(mode);
    root.pomodoroTotalSeconds = 0;
  }

  function pomodoroAdvanceToNextPhase() {
    if (root.pomodoroMode === modeWork) {
      if (root.pomodoroCompletedSessions + 1 >= root.sessionsBeforeLongBreak) {
        root.pomodoroMode = modeLongBreak;
      } else {
        root.pomodoroMode = modeShortBreak;
      }
    } else {
      if (root.pomodoroMode === modeLongBreak) {
        root.pomodoroCompletedSessions = 0;
      } else {
        root.pomodoroCompletedSessions++;
      }
      root.pomodoroMode = modeWork;
    }
    
    root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;
  }

  function pomodoroOnFinished() {
    root.pomodoroRunning = false;
    root.pomodoroRemainingSeconds = 0;
    root.pomodoroSoundPlaying = true;

    // Play Sound (checking toggle setting)
    if (pluginApi?.pluginSettings?.playSound !== false) {
      SoundService.playSound(root.alarmSoundFile, { // Uses variable
        repeat: true,
        volume: 0.3 
      });
      // Start the alarm limit timer
      alarmLimitTimer.start();
    }

    var toastMessage;
    var shouldAutoStart = false;
    
    if (root.pomodoroMode === modeWork) {
      root.addTrackedDuration(root.pomodoroOriginalTotal > 0 ? root.pomodoroOriginalTotal : root.workDuration);
      toastMessage = pluginApi?.tr("toast.work-finished") || "Work session complete! Time for a break.";
      shouldAutoStart = root.autoStartBreaks;
    } else if (root.pomodoroMode === modeLongBreak) {
      toastMessage = pluginApi?.tr("toast.long-break-finished") || "Long break over! Ready for a new cycle?";
      shouldAutoStart = root.autoStartWork;
    } else {
      toastMessage = pluginApi?.tr("toast.break-finished") || "Break over! Ready to focus?";
      shouldAutoStart = root.autoStartWork;
    }

    ToastService.showNotice(
      pluginApi?.tr("toast.title") || "Pomodoro",
      toastMessage,
      "clock"
    );

    pomodoroAdvanceToNextPhase();
    
    if (shouldAutoStart) {
      Qt.callLater(() => {
        // Pass false to keep sound playing!
        root.pomodoroStart(false);
      });
    }
  }

  function customSetCountdownDurationMinutes(minutes) {
    const safeMinutes = Math.floor(Number(minutes));
    if (!Number.isFinite(safeMinutes) || safeMinutes <= 0)
      return;
    const target = safeMinutes * 60;
    root.customTargetSeconds = target;
    if (!root.customRunning && root.customElapsedSeconds === 0) {
      root.customRemainingSeconds = target;
      root.customOriginalTargetSeconds = target;
    }
    if (pluginApi?.pluginSettings) {
      pluginApi.pluginSettings.countdownDurationMinutes = safeMinutes;
      pluginApi.saveSettings();
    }
  }

  function customStart(stopSound = true) {
    if (stopSound && root.pomodoroSoundPlaying) {
      SoundService.stopSound(root.alarmSoundFile);
      root.pomodoroSoundPlaying = false;
      alarmLimitTimer.stop();
    }

    if (!root.customCountUpMode && root.customRemainingSeconds <= 0) {
      root.customRemainingSeconds = Math.max(1, root.customTargetSeconds);
      root.customOriginalTargetSeconds = root.customRemainingSeconds;
    }

    if (!root.customCountUpMode && root.customOriginalTargetSeconds <= 0) {
      root.customOriginalTargetSeconds = Math.max(1, root.customRemainingSeconds);
    }

    root.customRunning = true;
  }

  function customPause() {
    root.customRunning = false;
  }

  function customResetState() {
    root.customRunning = false;
    root.customElapsedSeconds = 0;
    root.customRemainingSeconds = root.customCountUpMode ? 0 : Math.max(1, root.customTargetSeconds);
    root.customOriginalTargetSeconds = root.customCountUpMode ? 0 : root.customRemainingSeconds;
  }

  function customFinish() {
    if (!root.customRunning && root.customElapsedSeconds <= 0)
      return;

    root.customRunning = false;
    root.addTrackedDuration(root.customElapsedSeconds);
    ToastService.showNotice(
      pluginApi?.tr("toast.title") || "Pomodoro",
      pluginApi?.tr("toast.custom-finished") || "Custom timer finished.",
      "clock"
    );
    root.customResetState();
  }

  function customAbandon() {
    root.customResetState();
  }

  function customOnFinished(playAlarm) {
    root.customRunning = false;
    if (playAlarm) {
      root.pomodoroSoundPlaying = true;
      if (pluginApi?.pluginSettings?.playSound !== false) {
        SoundService.playSound(root.alarmSoundFile, {
          repeat: true,
          volume: 0.3
        });
        alarmLimitTimer.start();
      }
    }

    root.addTrackedDuration(root.customElapsedSeconds);
    ToastService.showNotice(
      pluginApi?.tr("toast.title") || "Pomodoro",
      pluginApi?.tr("toast.custom-finished") || "Custom timer finished.",
      "clock"
    );
    root.customResetState();
  }
}
