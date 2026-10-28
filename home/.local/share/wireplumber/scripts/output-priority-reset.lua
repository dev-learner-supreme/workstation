-- Forget the manually configured default sink whenever a new sink appears,
-- so the priority.session order (60-output-priority.conf) picks the output.

log = Log.open_topic ("s-output-priority")

SimpleEventHook {
  name = "custom/output-priority-reset",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "session-item-added" },
      Constraint { "event.session-item.interface", "=", "linkable" },
      Constraint { "media.class", "=", "Audio/Sink" },
    },
  },
  execute = function (event)
    local source = event:get_source ()
    local metadata_om = source:call ("get-object-manager", "metadata")
    local metadata = metadata_om:lookup { Constraint { "metadata.name", "=", "default" } }
    if metadata and metadata:find (0, "default.configured.audio.sink") then
      log:info ("new sink appeared; clearing configured default sink")
      metadata:set (0, "default.configured.audio.sink", nil, nil)
    end
  end
}:register ()
