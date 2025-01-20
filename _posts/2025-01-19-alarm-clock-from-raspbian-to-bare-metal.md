---
layout: post
title: Alarm Clock from Raspbian to Bare Metal
subtitle: What does it take when you don't have the tools of an OS.
---

I made an alarm clock that you can run on a raspberry pi, and it uses the I/O pins to mix in some
buttons, a display, and a piezo speaker. You can take a look at it playing some music!

<iframe width="560" height="315" src="https://www.youtube.com/embed/5CT8aCWk4vQ?si=6YBuZxMGvDpA07_8" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

Now, the video doesn't quite show how many features it has. It has a whole menu, for setting the
alarm time, alarm song, clock time, or playing any of the song files it has on their own. The menu
has to loop through words cause it's only got 4 characters to display with, so a 5 letter word
immediately means we have to cycle. This has to happen concurrently with music that may be playing,
and we've forever got an alarm timer that may go off at any second.

It's the perfect test bed for what it actually takes to move away from an Operating System
(Raspbian), onto a microcontroller where you have to bring pretty much everything with you yourself
(in this case, an Arduino Nano ESP32).

If you'd like to see the full changes, by all means check out [the repo], but if you're here for
broad strokes, well, I may have already gone too verbose, but broad they are! Let's see what has to
change.

# The Tools

The alarm clock was originally written in Rust, for two reasons.

1. Efficiency - Python was too slow to drive the buzzer within the audible frequency of human ears.
2. Fearless Concurrency - Even amongst higher level languages, few provide the same correctness in a
   multi-threaded or concurrent environment. Though I bet some functional languages can maybe give
   it a run for its money.

We're going to continue that trend, as a very powerful Rust ecosystem for bare-metal environments
have sprung up. In particular, it's surprisingly easy to move our threaded environment to a single
process, honestly like magic. Enter [embassy], a framework for using Rust's async on embedded *almost*
for free. It was actually really lovely to use async on embedded, that I honestly didn't even miss
having an OS handling threads for me, and it's leander than ever!

We'll need a separate toolchain, for Rust, too, it doesn't quite compile on the hardware we have
currently properly. It's pretty simple to set up, though.

```sh
cargo +stable install espup
espup install
```

And now we can use our new toolchain by placing this in `rust-toolchain.toml` in our project.

```toml
[toolchain]
channel = "esp"
```

And then we'll need something to flash our device. [probe-rs] seems to do the job nicely.

```sh
cargo install probe-rs-tools
```

And other than that, we'll meet some libraries that will help us along the way, but we'll get to
them as we go. Let's see all the things we have to change.

One more thing...I have no idea what I'm doing, what some good project configurations are, etc. So
we also use `esp-generate` to first bring us up to speed on what we might need, and pull things over
as we go.

```sh
cargo install esp-generate
esp-generate what-do-i-need
```

But I won't bore you with the things we ended up needing, though `rust-toolchain.toml` was one of
them.

# Code Changes

## Instant vs Instant

In the standard library, `std::time::Instant` allows negative values, but `embassy_time::Instant`
does not. In order to figure out what time it is for the clock, I use an offset called `TIME_ZERO`,
and then we can tell when, according to the system time itself, midnight should come around.

It's not really important it be at a specific midnight, though, as long as we get the offset we need
out of it. We just have to add a bit of math on our own to handle the fact that we've switched from
signed `Instant`s to unsigned.

```rust
impl ClockSub<Instant> for Instant {
    type Output = Duration;

    fn clock_sub(self, b: Duration) -> Self::Output {
        Duration::from_ticks(clock_tick_sub(self.as_ticks(), b.as_ticks()))
    }
}

fn clock_tick_sub(ticks_a: u64, ticks_b: u64) -> u64 {
    (ticks_a.wrapping_sub(ticks_b) as i64)
        .rem_euclid(TICK_HZ as i64 * 60 * 60 * 24) as u64
}
```

And now when we need to figure out what time it is now, in clock terms, we just use this method
instead of straight subtraction.

```rust
// `new` creates a `ClockTime` out of a minutes number.
pub fn now() -> Self {
    //Self::new((((Instant::now() - *TIME_ZERO.read()).as_secs() / 60) % (24 * 60)) as u16)
    let delta = Instant::now().clock_sub(TIME_ZERO.try_get().unwrap());
    Self::new((delta.as_secs() / 60 % (24 * 60)) as u16)
}
```

## Await vs Sleep

Normally we can tell the OS that we're going to take a break for a period of time, and off it goes
to do some other stuff. It can do other stuff whenever it feels like it, too, mind you, but this is
convenient on both sides that we say to get back to us in a bit, and other things can do work.

Async provides pretty much a drop in replacement. It lets the async executor know it can do other
stuff, and gets back to us after a period of time. We just switch thread sleeping to async sleeping.

```rust
//std::thread::sleep(std::time::Duration::from_secs(1))

embassy_time::Timer::after_secs(1).await
```

Actually, it's way more important to do this in the async case, because other tasks cannot do
anything unless we await. But ergonomically, it's super easy to switch over, and we already ended up
doing this in the synchronous code anyway.

## Embedding vs File System

We don't have a file system by default. There are some ways to create one, but for now...let's just
add everything into our code! Our files aren't that big.

I use midi files to play music on the alarm clock. They're like sheet music for computers, perfect
since I can only play tones effectively on my piezo speaker, not complex wave forms. The closest I
came to an external crate to do such a thing, was [include_dir]...but it uses the standard library,
and we don't have that.

We can write it by hand pretty easily, rust has `include_bytes` which basically just takes a file,
and includes it into the binary in the data section. This way, you don't have to read it later,
though this does of course come with the drawback that to change the file, you have to recompile
your program now. But it does very quickly solve our problem.

```rust
pub static MIDI_DIR: [File; 21] = {
    File { name: "Bach 846", data: include_bytes!("../midi/Bach 846.mid") },
    File { name: "Beethoven 5th", data: include_bytes!("../midi/Beethoven 5th.mid") },
    /* ... */
};
```

But, of course, there's better ways to do that then manually writing it out. I mentioned a macro
library earlier, we'll write one of those for ourselves. I wrote a procedural macro, which takes in
some tokens from the code, and outputs new tokens to replace them. The special thing about
procedural macros, is that ***they can use std***, even if we're building something without access
to the standard library. This is because they're done before we even start compiling for the
architecture, they produce some code, that we then compile for our target architecture.

Here it is in action.

```rust
#[dir_array("../midi")]
pub static MIDI_DIR: [File];
```

It expands to something like this, giving us all our names for our midi files, and the midi files
themselves, in a nice array.

```rust
pub static MIDI_DIR: [File; 21] = [
    File { name: "Bach 846", data: include_bytes!("../midi/Bach 846.mid") },
    // ... the rest of the files
];
```

Voila, no manual step, the entire midi directory embedded into an array for reading from.

## Stack vs Heap

Now we don't have an allocator (we could get one, but it turns out we don't need one super badly).
In fact, the hardware we're working on has only 512kB of memory, yes, that's with a `k`. If we avoid
using the heap, we're a bit less likely to run into allocation surprises later. And it's faster.

Instead we use [heapless], which gives us maximum capacity structures on the stack. They're super
fast to allocate and deallocate, because we just move the stack pointer around. We don't have to
check for a memory region free that is big enough, that we would on the heap.

Some places we convert the clock time into four characters, but we're allocating all over the place.
`format!` makes a `String` on the heap, `collect` makes a `Vec` on the heap, and then finally we
convert it into an array.

Honestly, that code kinda sucks, even for regular rust, but anyway, we can get rid of all the heap
allocations entirely, using `heapless::String`, which has a fixed size, and lives entirely on the
stack.

```rust
//pub fn as_chars(&self) -> [char; 4] {
//    format!("{:02}{:02}", self.hours(), self.minutes())
//        .chars()
//        .collect::<Vec<_>>()
//        .try_into()
//        .unwrap()
//}

pub fn as_chars(&self) -> String<4> {
    let mut string = String::new();

    use core::fmt::Write;
    write!(&mut string, "{:02}{:02}", self.hours(), self.minutes()).unwrap();

    string
}
```

A lot of places we know the size that we have, we just didn't have a way of expressing it before and
did an allocation. These are pretty obvious to just switch with a capacity. Sometimes we have to
make a choice, and it is certainly a trade-off.


```rust
pub struct Buzzer<..., const SIZE: usize> {
    ...
    //notes: HashMap<MidiNote, time::Instant>,
    notes: FnvIndexMap<MidiNote, Instant, SIZE>,
}
```

It's okay really, we may just miss some notes if we pick the wrong value, but it won't crash.
Instead of our previous infallible definition.

We have to return an error, and we'll log it, but it's safe and we don't have to crash just cause we
missed some notes.

```rust
//pub fn add_note(&mut self, note: MidiNote) {
pub fn add_note(&mut self, note: MidiNote) -> Result<Option<Instant>, (MidiNote, Instant)> {
    self.notes.insert(note, time::Instant::now());
}
```


Some cases of strings, we end up in a case where we can just pass around references to values,
without having to know the size However, our previous need to embed all our files (and their names,
most of all) ends up working in our favor. It may need changing in the future, but for now, all
possible strings are stored in the code, which means they live forever.

Turns out there's another optimization we can do, which is sometimes we borrow, and sometimes we
make a new string. It's not necessary, but it's a tool that may help with future development, to
avoid copying needlessly. It's like a `std::borrow::Cow`, but we don't have the standard library.

```rust
pub enum AlphanumMessage {
    //Static([char; 4]),
    Static(Calf<'static, String<4>>),
    //Loop(String),
    Loop(&'static str),
    ...
}
```

Here we have both cases, a string reference is sufficient, or we have a clear maximum size that
maybe we allocate or we already have a reference.

So, we did have to make some concessions where guess how big certain things need to be to put them
on the stack, but since there's no dynamic data, we can feel pretty confident after a little testing
that nowhere broke our assumptions.

## Enum vs Dyn

I had my code sort of loose so that it would be easy to add new states, where they just implement
the `State` trait. This handles all the menu stuff, and what to do with each button press in each
different state. But I had been making `Box<dyn State>` to handle the storage of this, which is on
the heap, it has to be because the size is unknown.

There is a library called [sized-dst], which almost fit my use case, but I switched all my state
transition functions to async at the same time, and those aren't
[object safe](https://rust-lang.github.io/rfcs/0255-object-safety.html)! Darn.

Let's throw them in an enum, but it would be a shame to throw away all the code separation and throw
it into giant match statements. For this I used [enum-dispatch], which lets me jam them all together
and get the trait on the container enum for free.

```rust
#[enum_dispatch]
pub trait State { ... }

#[enum_dispatch(State)]
pub enum ConcreteState {
    StateClock(StateClock),
    StateModeSelect(StateModeSelect),
    StateClockSet(StateClockSet),
    StateAlarmTime(StateAlarmTimeSet),
    StateAlarmSong(StateAlarmSongSet),
    StatePlay(StatePlay),
}
```

Change the `Box`es in the rest of the code to `ConcreteState`, and we're good to go!

## Synchronization Primitives

Now we get into some of the meat on how I juggled all my threads before, because we don't want
simultaneous mutation ***ever***. Doesn't matter the language, though Rust does it better than any
I've ever seen. So to keep things organized, we have our threads in charge of our peripherals like
displays, and they receive messages telling them what to do. We can replace the standard library
primitives with ones that [embassy] provided for us.

We also have to make them global, because their senders and receivers have lifetimes unlike the
standard library. The standard library allocates and can reference track a buffer if need be. Since
we have no allocator, it makes sense we have to explicitly store the buffer in a place where it will
not die, though, this is partly due to the fact that embassy also requires channels sent to tasks
must live for the `'static` lifetime. Anyway, a little downgrade in ergonomics, but it directly
follows out of our lack of heap allocation.

```rust
//let (midi_note_sender, midi_note_receiver) = mpsc::channel();
//let (event_sender, event_receiver) = mpsc::channel();
//let (player_sender, player_receiver) = mpsc::channel();
//let (alphanum_sender, alphanum_receiver) = mpsc::channel();

type Channel<T, const CAP: usize> = embassy_sync::channel::Channel<CriticalSectionRawMutex, T, CAP>;

static MIDI_NOTE_CHANNEL: Channel<BuzzerMessage, 64> = Channel::new();
static EVENT_CHANNEL: Channel<EventMessage, 1> = Channel::new();
static PLAYER_CHANNEL: Channel<PlayerMessage, 1> = Channel::new();
static ALPHANUM_CHANNEL: Channel<AlphanumMessage, 1> = Channel::new();
```

For shared globals behind locks, we were using `parking_lot::RwLock`. We need an async version, and
ideally we would have an async `RwLock`, but for now `embassy_sync::Mutex` is good enough, and
`embassy_sync::Watch` actually has some useful value we'll use later to allow us to write a much
better implementation of our alarm task than we had before.

Since these embassy concurrency primitives also have const function implementations, we can ditch
the `Lazy` initialization as well.

```rust
//static TIME_ZERO: Lazy<RwLock<Instant>> = Lazy::new(|| {
//    RwLock::new(Instant::now() - (Local::now().time() - NaiveTime::from_hms(0, 0, 0)).to_std().unwrap_or(Duration::ZERO))
//});
//static ALARM_TIME: Lazy<RwLock<Option<ClockTime>>> = Lazy::new(|| RwLock::new(None));
//static ALARM_SONG: Lazy<RwLock<Option<PathBuf>>> = Lazy::new(|| RwLock::new(None));

type Mutex<T> = embassy_sync::mutex::Mutex<CriticalSectionRawMutex, T>;
type Watch<T, const CAP: usize> = embassy_sync::watch::Watch<CriticalSectionRawMutex, T, CAP>;

static TIME_ZERO: Watch<Instant, 64> = Watch::new_with(Instant::from_ticks(0));
static ALARM_TIME: Watch<ClockTime, 1> = Watch::new();
static ALARM_SONG: Mutex<Midi> = Mutex::new(MIDI_DIR[0]);
```

Though, my one complaint is that Watch can be uninitialized, so returns an `Option`. I'd like if I
could enforce it's always there.

All of these allow us to asynchronously wait for things coming from the channel, for locks to free
up, for values to change, etc. The conversion is pretty simple. For channels it looks something like
this, where we explicitly say we're waiting instead of expecting the OS to go get busy with
something else.

```rust
// player_receiver.recv()
player_reciver.receive().await
```

## Midly no_std

One of our main libraries required conveniently comes in no_std, so we don't even have to change
much! Big shout out to [midly]. But it does require us to do a little allocation ourselves as we
play live. We probably won't have a file that has more than 64 tracks at once, right?

```rust
const TRACK_CAPCITY: usize = 64;

//let smf = Smf::parse(&midi_file).expect("Unable to parse midi file");
let (header, tracks) = midly::parse(&now_playing.data).expect("Unable to parse midi file");

//let mut events = Vec::with_capacity(tracks.len());
//let mut next_times = Vec::with_capacity(tracks.len());
let mut events = Vec::<_, TRACK_CAPCITY>::new();
let mut next_times = Vec::<_, TRACK_CAPCITY>::new();
```

## No more Threads, only Bugs

Every time I started reading a midi file, the whole thing locked up. We have to get rid of the busy
loop in our midi reader, and make it sleep so we can get other work done. Actually, for the player,
that's the only thing we're missing, is that we're not sleeping when really we could have been this
whole time.

```rust
loop {
    // ... code for reading and sending notes, when the time is right

    // add a sleep to sleep until the next note is coming up
    Timer::at(*next_times.iter().min().unwrap()).await
}
```

Turns out our buzzer thread was also very much assuming that the OS would schedule other things and
bump it off the CPU. Even replacing the channel with an async one, it would lock up when there were
no notes, because a simple substitution of try_receive kept us in a busy loop. If you await a
function that always returns, rather than pending, like a timer would, it doesn't actually let
anybody else do work, and takes all the CPU time. And the buzzer has never actually awaited except
for when it had notes playing.

We'll comment out the naive conversion and rewrite the whole thing

```rust
pub async fn update_buzzer(
    note_receiver: Receiver<'static, CriticalSectionRawMutex, BuzzerMessage, CHANNEL_CAPACITY>,
    mut buzzer: hal::Buzzer<BUZZER_NOTES>,
) {
    loop {

    // can very easily hit no await point. Even though there is one, it will always immediately
    // return and not wait when there are no notes.

    //let _ = buzzer.update().await.inspect_err(|e| error!("{:?}", e));
    //match note_receiver.try_receive() {
    //    Ok(message) => apply_message(&mut buzzer, message)
    //    Err(_) => (),
    //}

    // here we avoid accidentally never waiting. If the buzzer is empty, we tell the executor to
    // only get back to us when we get a message to start playing a note.
    if buzzer.is_empty() {
        apply_message(&mut buzzer, note_receiver.receive().await)
    } else {
        let _ = buzzer.update().await.inspect_err(|e| error!("{:?}", e));

        match note_receiver.try_receive() {
            Ok(message) => apply_message(&mut buzzer, message),
            Err(_) => (),
        }
    }
}
```

Our alarm thread currently just sleeps, but only for 100ms. It keeps checking the time over and
over. In theory, this consumes more power if our hardware can never rest for prolonged periods of
time. We can do better, and we'll use the `Watch` primitive we got from [embassy].

```rust
pub async fn alarm_task(
    player_sender: Sender<'static, CriticalSectionRawMutex, PlayerMessage, CHANNEL_CAPACITY>,
) {
    let mut alarm_time = ALARM_TIME.receiver().unwrap();

    loop {
        // We don't need to sleep and keep waking
        // Timer::after(Duration::from_millis(100)).await;
        match alarm_time.try_get() {
            None => { alarm_time.changed().await; },
            Some(time) => {
                info!("Next alarm at {}", time.as_chars());
                // Instead, we wait for either:
                // a) the clock to hit the alarm time. I wrote wait_until to know how to handle the clock changing, too
                // b) the alarm time changes, in which case, we'll restart this loop, and call wait_until on the new time
                match select(
                    time.wait_until(),
                    alarm_time.changed(),
                ).await {
                    Either::First(_) => {
                        info!("Alarm time!");

                        player_sender.send(PlayerMessage::Loop(*ALARM_SONG.lock().await)).await;
                    },
                    Either::Second(_) => (),
                }
            }
        }
    }
}
```

And that's pretty much it, a couple of bad assumptions was all, leftover from a time where we didn't
have to cooperate fully, because the OS would push our threads on and off just the same.

# Conclusion

The Rust ecosystem for embedded programming is honestly kind of a joy to work with. The embassy
folks have it totally right, that embedded is the perfect space to use asynchronous programming, as
a language feature that can pretty much entirely replace the need for threads.

In fact, a few of our changes made the code cleaner than it was, with no more busy loops or
arbitrary short sleeps, which are like busy loops but less busy.

It's not the only option mind you, there are real-time operating system implementations for all
sorts of devices, like [FreeRTOS]. But it certainly feels like overkill, and we've accomplished it
here with nary an OS in site, and have a lean mean device as a result. The overhead for an RTOS is
not nothing, and it's always good to be able to get away with less.

I intentionally avoided using an allocator throughout as it can cause errors down the line if we run
out of heap space. Would we have? I don't know. But I know it can't happen now. Adding an allocator
is a future goal, to remove some arbitrary limits we place in a couple places along the way, but
none of the places are actually prohibitive.

Thanks for joining me to the end. If you're less interested in code, but more interested in seeing
some cool things I'm doing to change the sound on it (I've got a harpsicord sound in the works,
following a new discovery), stay tuned! Also, I have a temperature, humidity, and ambient pressure
sensor that I've got to hook up so you can know how things are going this morning in your house
when the alarm goes off. Less code next time, but I wanted to document how the process went so
hopefully, others may follow.

[embassy]: https://embassy.dev/
[enum_dispatch]: https://docs.rs/enum_dispatch/latest/enum_dispatch/
[heapless]: https://docs.rs/heapless/latest/heapless/
[include_dir]: https://docs.rs/include_dir/latest/include_dir/
[midly]: https://docs.rs/midly/latest/midly/
[probe-rs]: https://probe.rs/
[sized-dst]: https://docs.rs/sized-dst/latest/sized_dst/

[the repo]: https://github.com/asampley/alarm-clock

[FreeRTOS]: https://en.wikipedia.org/wiki/FreeRTOS
