#[path = "actor_model.rs"]
mod actor_model;

use actor_model::*;

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn test_actor_system_creation() {
        let system = ActorSystem::new();
        system.shutdown();
    }

    #[test]
    fn test_spawn_echo_actor() {
        let mut system = ActorSystem::new();
        let (echo, received) = EchoActor::new();
        let id = system.spawn(echo);
        assert!(id > 0);

        system.send(id, Message::Text("hello".to_string())).unwrap();
        thread::sleep(Duration::from_millis(50));

        let msgs = received.lock().unwrap();
        assert_eq!(msgs.len(), 1);
        if let Message::Text(s) = &msgs[0] {
            assert_eq!(s, "hello");
        } else {
            panic!("Expected Text message");
        }

        system.shutdown();
    }

    #[test]
    fn test_counter_actor_increment() {
        let mut system = ActorSystem::new();
        let (counter, final_count) = CounterActor::new();
        let id = system.spawn(counter);

        system
            .send(
                id,
                Message::Command {
                    action: "increment".to_string(),
                    args: vec![],
                },
            )
            .unwrap();
        system
            .send(
                id,
                Message::Command {
                    action: "increment".to_string(),
                    args: vec![],
                },
            )
            .unwrap();
        system
            .send(
                id,
                Message::Command {
                    action: "increment".to_string(),
                    args: vec![],
                },
            )
            .unwrap();

        thread::sleep(Duration::from_millis(50));

        let count = *final_count.lock().unwrap();
        assert_eq!(count, 3);

        system.shutdown();
    }

    #[test]
    fn test_counter_actor_decrement() {
        let mut system = ActorSystem::new();
        let (counter, final_count) = CounterActor::new();
        let id = system.spawn(counter);

        system.send(id, Message::Number(10)).unwrap();
        system
            .send(
                id,
                Message::Command {
                    action: "decrement".to_string(),
                    args: vec![],
                },
            )
            .unwrap();

        thread::sleep(Duration::from_millis(50));

        let count = *final_count.lock().unwrap();
        assert_eq!(count, 9);

        system.shutdown();
    }

    #[test]
    fn test_send_to_nonexistent_actor() {
        let system = ActorSystem::new();
        let result = system.send(999, Message::Text("hello".to_string()));
        assert!(result.is_err());
        system.shutdown();
    }

    #[test]
    fn test_stop_actor() {
        let mut system = ActorSystem::new();
        let (echo, _received) = EchoActor::new();
        let id = system.spawn(echo);

        let result = system.stop(id);
        assert!(result.is_ok());

        thread::sleep(Duration::from_millis(50));
        system.shutdown();
    }

    #[test]
    fn test_multiple_actors() {
        let mut system = ActorSystem::new();

        let (echo1, received1) = EchoActor::new();
        let (echo2, received2) = EchoActor::new();

        let id1 = system.spawn(echo1);
        let id2 = system.spawn(echo2);

        assert_ne!(id1, id2);

        system.send(id1, Message::Text("msg1".to_string())).unwrap();
        system.send(id2, Message::Text("msg2".to_string())).unwrap();

        thread::sleep(Duration::from_millis(50));

        assert_eq!(received1.lock().unwrap().len(), 1);
        assert_eq!(received2.lock().unwrap().len(), 1);

        system.shutdown();
    }

    #[test]
    fn test_message_types() {
        let mut system = ActorSystem::new();
        let (echo, received) = EchoActor::new();
        let id = system.spawn(echo);

        system.send(id, Message::Text("text".to_string())).unwrap();
        system.send(id, Message::Number(42)).unwrap();
        system
            .send(
                id,
                Message::Command {
                    action: "test".to_string(),
                    args: vec!["arg1".to_string()],
                },
            )
            .unwrap();

        thread::sleep(Duration::from_millis(50));

        let msgs = received.lock().unwrap();
        assert_eq!(msgs.len(), 3);

        system.shutdown();
    }
}
