
The editor is architected with the MVI (model-view-intent) architecture, also
known as the "react" architecture. This architecture relies on a "stream" of
serializable (human-readable) events that are handled sequentially, with all
state change occuring as the result of handling events.

The basic architecture is:

```
model = Model.new{}
events = List{}
while true do
    model:update(events)  -- process events until empty
    events = model:view() -- asyncronous view and event receiving
end
```

Where:
* `Model` represents all data needed to render a view as well as all
  (non-visibile) application state.
* `events` is a list of serializable (and human-readable) `Event` objects which
  are composed of plain-old-data (POD) which specify what the event is and
  what data it contains.
* The update function receives the `Model` and `Event` list and runs the
  suitable handlers until the event stream is empty.
  * handlers can emit new events, which are handled (sequentially) before new
    events on the stack.
  * when a handler emits an event it increases the event depth. There is a limit
    on event depth (tentatively 12). Essentially this implements "event
    recursion" with a limit on the depth.
* The `view` function renders the screen at appropriate times and checks
  asynchronous state (user inputs, background processes, etc).

`Event` objects are created by:
* user inputs, primarily keyboard input
* background processes (timer, file watcher, etc)
* update methods can emit new events

