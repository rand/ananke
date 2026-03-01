#[path = "state_machine.rs"]
mod state_machine;

use state_machine::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_state_machine_creation() {
        let sm = StateMachine::new(StateId::new("idle"));
        assert_eq!(sm.current_state().0, "idle");
    }

    #[test]
    fn test_add_state() {
        let mut sm = StateMachine::new(StateId::new("idle"));
        sm.add_state(StateId::new("running"));
        sm.add_state(StateId::new("stopped"));
        // No direct way to check states, but should not panic
    }

    #[test]
    fn test_simple_transition() {
        let mut sm = StateMachine::new(StateId::new("idle"));
        sm.add_state(StateId::new("running"));
        sm.add_transition(Transition::new(
            StateId::new("idle"),
            EventId::new("start"),
            StateId::new("running"),
        ));

        let result = sm.trigger(EventId::new("start"));
        assert!(result.is_ok());
        assert_eq!(sm.current_state().0, "running");
    }

    #[test]
    fn test_invalid_transition() {
        let mut sm = StateMachine::new(StateId::new("idle"));
        sm.add_state(StateId::new("running"));
        sm.add_transition(Transition::new(
            StateId::new("idle"),
            EventId::new("start"),
            StateId::new("running"),
        ));

        let result = sm.trigger(EventId::new("stop"));
        assert!(result.is_err());
    }

    #[test]
    fn test_transition_chain() {
        let mut sm = StateMachineBuilder::new("idle")
            .state("running")
            .state("paused")
            .state("stopped")
            .transition("idle", "start", "running")
            .transition("running", "pause", "paused")
            .transition("paused", "resume", "running")
            .transition("running", "stop", "stopped")
            .build();

        sm.trigger(EventId::new("start")).unwrap();
        assert_eq!(sm.current_state().0, "running");

        sm.trigger(EventId::new("pause")).unwrap();
        assert_eq!(sm.current_state().0, "paused");

        sm.trigger(EventId::new("resume")).unwrap();
        assert_eq!(sm.current_state().0, "running");

        sm.trigger(EventId::new("stop")).unwrap();
        assert_eq!(sm.current_state().0, "stopped");
    }

    #[test]
    fn test_can_transition() {
        let mut sm = StateMachineBuilder::new("idle")
            .state("running")
            .transition("idle", "start", "running")
            .build();

        assert!(sm.can_transition(&EventId::new("start")));
        assert!(!sm.can_transition(&EventId::new("stop")));

        sm.trigger(EventId::new("start")).unwrap();
        assert!(!sm.can_transition(&EventId::new("start")));
    }

    #[test]
    fn test_transition_with_guard() {
        let mut sm = StateMachine::new(StateId::new("idle"));
        sm.add_state(StateId::new("running"));

        let transition = Transition::new(
            StateId::new("idle"),
            EventId::new("start"),
            StateId::new("running"),
        )
        .with_guard(|ctx| ctx.get_counter("ready") > 0);

        sm.add_transition(transition);

        // Guard fails - counter is 0
        let result = sm.trigger(EventId::new("start"));
        assert!(result.is_err());

        // Set counter and try again
        sm.context_mut().increment("ready");
        let result = sm.trigger(EventId::new("start"));
        assert!(result.is_ok());
        assert_eq!(sm.current_state().0, "running");
    }

    #[test]
    fn test_transition_with_action() {
        let mut sm = StateMachine::new(StateId::new("idle"));
        sm.add_state(StateId::new("running"));

        let transition = Transition::new(
            StateId::new("idle"),
            EventId::new("start"),
            StateId::new("running"),
        )
        .with_action(|ctx| {
            ctx.increment("transitions");
            ctx.set("last_event", "start");
        });

        sm.add_transition(transition);
        sm.trigger(EventId::new("start")).unwrap();

        assert_eq!(sm.context().get_counter("transitions"), 1);
        assert_eq!(sm.context().get("last_event"), Some(&"start".to_string()));
    }

    #[test]
    fn test_history() {
        let mut sm = StateMachineBuilder::new("idle")
            .state("running")
            .state("stopped")
            .transition("idle", "start", "running")
            .transition("running", "stop", "stopped")
            .build();

        sm.trigger(EventId::new("start")).unwrap();
        sm.trigger(EventId::new("stop")).unwrap();

        let history = sm.history();
        assert_eq!(history.len(), 3);
        assert_eq!(history[0].0, "idle");
        assert_eq!(history[1].0, "running");
        assert_eq!(history[2].0, "stopped");
    }

    #[test]
    fn test_reset() {
        let mut sm = StateMachineBuilder::new("idle")
            .state("running")
            .transition("idle", "start", "running")
            .build();

        sm.trigger(EventId::new("start")).unwrap();
        assert_eq!(sm.current_state().0, "running");

        sm.reset(StateId::new("idle")).unwrap();
        assert_eq!(sm.current_state().0, "idle");
    }

    #[test]
    fn test_reset_invalid_state() {
        let mut sm = StateMachine::new(StateId::new("idle"));
        let result = sm.reset(StateId::new("nonexistent"));
        assert!(result.is_err());
    }

    #[test]
    fn test_context() {
        let mut sm = StateMachine::new(StateId::new("idle"));

        sm.context_mut().set("key", "value");
        sm.context_mut().increment("count");
        sm.context_mut().increment("count");

        assert_eq!(sm.context().get("key"), Some(&"value".to_string()));
        assert_eq!(sm.context().get_counter("count"), 2);
    }

    #[test]
    fn test_builder_pattern() {
        let sm = StateMachineBuilder::new("initial")
            .state("state_a")
            .state("state_b")
            .transition("initial", "to_a", "state_a")
            .transition("state_a", "to_b", "state_b")
            .transition("state_b", "to_a", "state_a")
            .build();

        assert_eq!(sm.current_state().0, "initial");
    }

    #[test]
    fn test_error_display() {
        let err = StateMachineError::InvalidTransition {
            from: StateId::new("idle"),
            event: EventId::new("invalid"),
        };
        assert!(err.to_string().contains("No transition"));

        let err = StateMachineError::GuardFailed {
            transition: "a -> b".to_string(),
        };
        assert!(err.to_string().contains("Guard failed"));

        let err = StateMachineError::InvalidState(StateId::new("unknown"));
        assert!(err.to_string().contains("Invalid state"));
    }
}
