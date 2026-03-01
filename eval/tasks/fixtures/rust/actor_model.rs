//! Actor Model Implementation
//! Demonstrates message-passing concurrency with actors in Rust

use std::collections::HashMap;
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};

pub type ActorId = u64;

#[derive(Debug, Clone)]
pub enum Message {
    Text(String),
    Number(i64),
    Command { action: String, args: Vec<String> },
    Stop,
}

pub trait Actor: Send {
    fn receive(&mut self, message: Message, ctx: &mut ActorContext);
}

pub struct ActorContext {
    self_id: ActorId,
    sender: Sender<(ActorId, Message)>,
}

impl ActorContext {
    pub fn self_id(&self) -> ActorId {
        self.self_id
    }

    pub fn send(&self, target: ActorId, message: Message) {
        let _ = self.sender.send((target, message));
    }

    pub fn reply(&self, message: Message) {
        // Reply goes back to system for routing
        let _ = self.sender.send((self.self_id, message));
    }
}

pub struct ActorSystem {
    next_id: ActorId,
    actors: HashMap<ActorId, Sender<Message>>,
    handles: Vec<JoinHandle<()>>,
    system_sender: Sender<(ActorId, Message)>,
    system_receiver: Arc<Mutex<Receiver<(ActorId, Message)>>>,
}

impl ActorSystem {
    pub fn new() -> Self {
        let (tx, rx) = mpsc::channel();
        ActorSystem {
            next_id: 1,
            actors: HashMap::new(),
            handles: Vec::new(),
            system_sender: tx,
            system_receiver: Arc::new(Mutex::new(rx)),
        }
    }

    pub fn spawn<A: Actor + 'static>(&mut self, mut actor: A) -> ActorId {
        let id = self.next_id;
        self.next_id += 1;

        let (tx, rx) = mpsc::channel::<Message>();
        let system_sender = self.system_sender.clone();

        let handle = thread::spawn(move || {
            let mut ctx = ActorContext {
                self_id: id,
                sender: system_sender,
            };

            while let Ok(msg) = rx.recv() {
                if matches!(msg, Message::Stop) {
                    break;
                }
                actor.receive(msg, &mut ctx);
            }
        });

        self.actors.insert(id, tx);
        self.handles.push(handle);
        id
    }

    pub fn send(&self, target: ActorId, message: Message) -> Result<(), &'static str> {
        if let Some(sender) = self.actors.get(&target) {
            sender.send(message).map_err(|_| "Actor disconnected")
        } else {
            Err("Actor not found")
        }
    }

    pub fn stop(&self, target: ActorId) -> Result<(), &'static str> {
        self.send(target, Message::Stop)
    }

    pub fn shutdown(self) {
        for (_, sender) in self.actors {
            let _ = sender.send(Message::Stop);
        }
        for handle in self.handles {
            let _ = handle.join();
        }
    }
}

impl Default for ActorSystem {
    fn default() -> Self {
        Self::new()
    }
}

// Example actors for testing

pub struct EchoActor {
    pub received: Arc<Mutex<Vec<Message>>>,
}

impl EchoActor {
    pub fn new() -> (Self, Arc<Mutex<Vec<Message>>>) {
        let received = Arc::new(Mutex::new(Vec::new()));
        (
            EchoActor {
                received: received.clone(),
            },
            received,
        )
    }
}

impl Actor for EchoActor {
    fn receive(&mut self, message: Message, _ctx: &mut ActorContext) {
        self.received.lock().unwrap().push(message);
    }
}

pub struct CounterActor {
    count: i64,
    pub final_count: Arc<Mutex<i64>>,
}

impl CounterActor {
    pub fn new() -> (Self, Arc<Mutex<i64>>) {
        let final_count = Arc::new(Mutex::new(0));
        (
            CounterActor {
                count: 0,
                final_count: final_count.clone(),
            },
            final_count,
        )
    }
}

impl Actor for CounterActor {
    fn receive(&mut self, message: Message, _ctx: &mut ActorContext) {
        match message {
            Message::Command { action, .. } => match action.as_str() {
                "increment" => self.count += 1,
                "decrement" => self.count -= 1,
                "get" => *self.final_count.lock().unwrap() = self.count,
                _ => {}
            },
            Message::Number(n) => self.count += n,
            _ => {}
        }
        *self.final_count.lock().unwrap() = self.count;
    }
}

pub struct ForwarderActor {
    target: ActorId,
}

impl ForwarderActor {
    pub fn new(target: ActorId) -> Self {
        ForwarderActor { target }
    }
}

impl Actor for ForwarderActor {
    fn receive(&mut self, message: Message, ctx: &mut ActorContext) {
        ctx.send(self.target, message);
    }
}
