import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Cloned from omarchy.workspaces. Two departures from the stock widget:
//
//  - It keys off workspace names rather than ids. The stock widget filters to
//    `id > 0 && id <= 10` and prints the id, so named workspaces never appear:
//    Hyprland gives them negative ids (🚧 is -1337 here).
//  - Each monitor's bar shows only its own workspaces, the way waybar's
//    persistent-workspaces map did. Membership comes from Hyprland, so the
//    hl.workspace_rule() monitor assignments in ~/.config/hypr/hyprland.lua are
//    the single source of truth and nothing here needs updating alongside them.
BarWidget {
  id: root
  moduleName: "rame0.workspace-icons"

  // Display order for named workspaces, matching the old waybar bar. Named
  // workspaces missing from this list (🥁 has no monitor rule, so it shows up
  // only once it exists) sort after these, alphabetically.
  readonly property var namedOrder: ["⛁", "🚧", "🌐", "💬", "📩"]

  // The output this bar instance is drawn on. Empty while the window is still
  // being set up, which falls back to showing every workspace.
  readonly property var ownWindow: root.QsWindow ? root.QsWindow.window : null
  readonly property string screenName: ownWindow && ownWindow.screen ? String(ownWindow.screen.name || "") : ""

  function monitorNameOf(workspace) {
    var monitor = workspace ? workspace.monitor : null
    if (!monitor) return ""

    // Quickshell hands back a HyprlandMonitor; older builds hand back a name.
    return String(typeof monitor === "string" ? monitor : (monitor.name || ""))
  }

  function onThisScreen(workspace) {
    if (root.screenName === "") return true

    var name = root.monitorNameOf(workspace)
    return name === "" || name === root.screenName
  }

  function workspaceByName(name) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].name === name) return values[i]
    }

    return null
  }

  // Numeric workspaces first, in numeric order, then the named ones in
  // namedOrder. Only workspaces belonging to this bar's monitor are listed.
  function workspaceNames() {
    var numeric = []
    var named = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var name = workspace.name

      // Special workspaces (scratchpad) get their own toggle, not a button.
      if (name.indexOf("special") === 0) continue
      if (!root.onThisScreen(workspace)) continue

      if (/^\d+$/.test(name)) numeric.push(name)
      else named.push(name)
    }

    numeric.sort(function(left, right) { return Number(left) - Number(right) })

    named.sort(function(left, right) {
      var leftRank = root.namedOrder.indexOf(left)
      var rightRank = root.namedOrder.indexOf(right)

      if (leftRank === -1 && rightRank === -1) return left < right ? -1 : (left > right ? 1 : 0)
      if (leftRank === -1) return 1
      if (rightRank === -1) return -1
      return leftRank - rightRank
    })

    return numeric.concat(named)
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.workspaceNames().length)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceNames()

      WidgetButton {
        required property string modelData

        readonly property var workspace: root.workspaceByName(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.name === modelData

        bar: root.bar
        // Keep the label on the focused workspace rather than swapping it for a
        // focus glyph: with named workspaces the label is the thing you read.
        text: modelData
        active: focused
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        // Emoji are wider than digits, so size to the label instead of the
        // stock fixed slot.
        fixedWidth: root.vertical ? root.barSize : -1
        fixedHeight: root.barSize
        tooltipText: "Workspace " + modelData
        onPressed: function() {
          if (!root.bar) return

          // A numeric workspace is selected by number; anything else by name,
          // so an emoji doesn't get parsed as an id.
          var selector = /^\d+$/.test(modelData) ? modelData : "name:" + modelData
          root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + selector + "\" })"))
        }
      }
    }
  }
}
