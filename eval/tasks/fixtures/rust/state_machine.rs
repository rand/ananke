//! State Machine Implementation
//! Demonstrates type-safe state machines with Rust's type system

use std::collections::HashMap;
use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct StateId(pub String);

impl StateId {
    pub fn new(name: &str) -> Self {
        StateId(name.to_string())
    }
}

impl fmt::Display for StateId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct EventId(pub String);

impl EventId {
    pub fn new(name: &str) -> Self {
        EventId(name.to_string())
    }
}

impl fmt::Display for EventId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

#[derive(Debug, Clone)]
pub struct Transition {
    pub from: StateId,
    pub event: EventId,
    pub to: StateId,
    pub guard: Option<fn(&Context) -> bool>,
    pub action: Option<fn(&mut Context)>,
}

impl Transition {
    pub fn new(from: StateId, event: EventId, to: StateId) -> Self {
        Transition {
            from,
            event,
            to,
            guard: None,
            action: None,
        }
    }

    pub fn with_guard(mut self, guard: fn(&Context) -> bool) -> Self {
        self.guard = Some(guard);
        self
    }

    pub fn with_action(mut self, action: fn(&mut Context)) -> Self {
        self.action = Some(action);
        self
    }
}

#[derive(Debug, Clone, Default)]
pub struct Context {
    pub data: HashMap<String, String>,
    pub counters: HashMap<String, i64>,
}

impl Context {
    pub fn new() -> Self {
        Context {
            data: HashMap::new(),
            counters: HashMap::new(),
        }
    }

    pub fn set(&mut self, key: &str, value: &str) {
        self.data.insert(key.to_string(), value.to_string());
    }

    pub fn get(&self, key: &str) -> Option<&String> {
        self.data.get(key)
    }

    pub fn increment(&mut self, key: &str) {
        *self.counters.entry(key.to_string()).or_insert(0) += 1;
    }

    pub fn get_counter(&self, key: &str) -> i64 {
        *self.counters.get(key).unwrap_or(&0)
    }
}

#[derive(Debug)]
pub enum StateMachineError {
    InvalidTransition { from: StateId, event: EventId },
    GuardFailed { transition: String },
    InvalidState(StateId),
}

impl fmt::Display for StateMachineError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            StateMachineError::InvalidTransition { from, event } => {
                write!(f, "No transition from {} on event {}", from, event)
            }
            StateMachineError::GuardFailed { transition } => {
                write!(f, "Guard failed for transition: {}", transition)
            }
            StateMachineError::InvalidState(state) => {
                write!(f, "Invalid state: {}", state)
            }
        }
    }
}

impl std::error::Error for StateMachineError {}

pub struct StateMachine {
    current_state: StateId,
    states: Vec<StateId>,
    transitions: Vec<Transition>,
    context: Context,
    history: Vec<StateId>,
}

impl StateMachine {
    pub fn new(initial_state: StateId) -> Self {
        let history = vec![initial_state.clone()];
        StateMachine {
            current_state: initial_state.clone(),
            states: vec![initial_state],
            transitions: Vec::new(),
            context: Context::new(),
            history,
        }
    }

    pub fn add_state(&mut self, state: StateId) {
        if !self.states.contains(&state) {
            self.states.push(state);
        }
    }

    pub fn add_transition(&mut self, transition: Transition) {
        self.transitions.push(transition);
    }

    pub fn current_state(&self) -> &StateId {
        &self.current_state
    }

    pub fn context(&self) -> &Context {
        &self.context
    }

    pub fn context_mut(&mut self) -> &mut Context {
        &mut self.context
    }

    pub fn history(&self) -> &[StateId] {
        &self.history
    }

    pub fn can_transition(&self, event: &EventId) -> bool {
        self.transitions.iter().any(|t| {
            t.from == self.current_state
                && t.event == *event
                && t.guard.map(|g| g(&self.context)).unwrap_or(true)
        })
    }

    pub fn trigger(&mut self, event: EventId) -> Result<&StateId, StateMachineError> {
        let transition = self
            .transitions
            .iter()
            .find(|t| t.from == self.current_state && t.event == event)
            .cloned();

        match transition {
            Some(t) => {
                // Check guard
                if let Some(guard) = t.guard {
                    if !guard(&self.context) {
                        return Err(StateMachineError::GuardFailed {
                            transition: format!("{} -> {}", t.from, t.to),
                        });
                    }
                }

                // Execute action
                if let Some(action) = t.action {
                    action(&mut self.context);
                }

                // Update state
                self.current_state = t.to;
                self.history.push(self.current_state.clone());
                Ok(&self.current_state)
            }
            None => Err(StateMachineError::InvalidTransition {
                from: self.current_state.clone(),
                event,
            }),
        }
    }

    pub fn reset(&mut self, state: StateId) -> Result<(), StateMachineError> {
        if !self.states.contains(&state) {
            return Err(StateMachineError::InvalidState(state));
        }
        self.current_state = state.clone();
        self.history.push(state);
        Ok(())
    }
}

// Builder pattern for easier construction
pub struct StateMachineBuilder {
    initial_state: StateId,
    states: Vec<StateId>,
    transitions: Vec<Transition>,
}

impl StateMachineBuilder {
    pub fn new(initial_state: &str) -> Self {
        let initial = StateId::new(initial_state);
        StateMachineBuilder {
            initial_state: initial.clone(),
            states: vec![initial],
            transitions: Vec::new(),
        }
    }

    pub fn state(mut self, name: &str) -> Self {
        let state = StateId::new(name);
        if !self.states.contains(&state) {
            self.states.push(state);
        }
        self
    }

    pub fn transition(mut self, from: &str, event: &str, to: &str) -> Self {
        self.transitions.push(Transition::new(
            StateId::new(from),
            EventId::new(event),
            StateId::new(to),
        ));
        self
    }

    pub fn build(self) -> StateMachine {
        let mut sm = StateMachine::new(self.initial_state);
        for state in self.states {
            sm.add_state(state);
        }
        for transition in self.transitions {
            sm.add_transition(transition);
        }
        sm
    }
}
