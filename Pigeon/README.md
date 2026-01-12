#  Pigeon

A lightweight MacOS application for remote debugging sessions.

## How it works?

This application is essentially a Desktop client for our remote tool Console Dump, but also includes
support for a local only server and other tools for mocking http requests and logging.

1. Connect to a local/remote dump session (`text/event-stream`)
2. Display incoming events in Google Chrome like message console
3. Allow users to send http `POST` requests to an api to appear in the event stream.

The main purpose is to make sending, viewing and organizing debug output like `console.log` or `print` easy
to view in a simple interface.

## Console Dump

We have a remote web application with these same features, and this application can connect to these sessions
to view them natively on the desktop.

### 1. Start a New Session

Visit https://consoledump.io and click “New Session” to instantly create a unique debugging console. You’ll receive a session ID like 42a66873 and a dedicated URL where all your logs will appear.

### 2. Copy & Paste the Code Snippet

Choose your preferred method to send logs. The simplest way is with a single curl command:

```bash
curl -d "hello world" https://consoledump.io/42a66873 
```

### 3. View Logs in Real-Time

Open your session URL https://consoledump.io/42a66873 in any browser. Your logs appear instantly as your application sends them—no page refresh needed. Share the URL with teammates to collaborate on debugging.


## How to Pipe Logs?

Copy and paste this snippet into your code, replacing 42a66873 with your session ID:

```js
// Create a logging function
const dump = (...args) =>
  fetch('https://consoledump.io/42a66873', {
    method: 'POST',
    body: JSON.stringify(args),
  })

// Start logging anything!
dump('Hello, world!')
dump({ data: 123, name: 'Bob' })
dump([1, 2, 3, 4, 5])
dump('User logged in', { userId: 42, timestamp: Date.now() }) 
```

For existing applications, redirect your console output to ConsoleDump without changing your code:

```js
// Override console.log
console.log = (...args) => dump('log:', ...args)

// Override all console methods with level tags
console.warn = (...args) => dump('warn:', ...args)
console.error = (...args) => dump('error:', ...args)
console.info = (...args) => dump('info:', ...args)
console.debug = (...args) => dump('debug:', ...args) 
```

Now all your existing console.log() , console.error() , etc. calls will automatically stream to your ConsoleDump session.


## TODO: Supported Channels

### 1. Unix Domain Sockets

Lowest latency for local IPC, no TCP overhead:

```bash
# CLI side
echo "log message" | nc -U /tmp/consoledump.sock
```

### 2. UDP

Fire-and-forget, minimal overhead (fine for logs where occasional loss is acceptable):

```bash
echo "log message" | nc -u localhost 9999
```

### 3. Named Pipe (FIFO)

Zero network overhead, just pipe directly:

```bash
# App creates:
mkfifo /tmp/consoledump

# CLI just writes:
echo "log message" > /tmp/consoledump

# Or pipe directly:
my-command 2>&1 > /tmp/consoledump
```

### 4. WebSocket (persistent connection)

If you're already sending many logs, one persistent connection beats repeated HTTP handshakes.

For CLI ergonomics, the named pipe or Unix socket approaches are nice because you can just pipe directly without a helper binary:
