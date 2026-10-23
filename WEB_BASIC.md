# SedaiBasic Web (sbw.exe)

**Version:** 1.0
**Status:** In Development

## Overview

SedaiBasic Web (`sbw.exe`) is a stand-alone HTTP server that executes Web BASIC scripts (`.wbas` files) in response to HTTP requests, similar to PHP or classic ASP.

### Key Features

- **Stand-alone HTTP server** - No nginx/Apache dependency
- **No SDL2/Graphics/Audio** - Lightweight, server-focused
- **Security by default** - GET$/POST$ are HTML-escaped automatically
- **Simple URL mapping** - `/path/script.wbas` -> `{basedir}/path/script.wbas`

## Quick Start

```bash
# Start the server
sbw --port 8080 --basedir C:\www\scripts

# Test with curl
curl http://localhost:8080/hello.wbas
curl "http://localhost:8080/hello.wbas?nome=Mario"
```

## Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--port <number>` | HTTP port | 8080 |
| `--host <address>` | Bind address | 0.0.0.0 |
| `--basedir <path>` | Script directory | (required) |
| `--cache` | Enable bytecode caching | disabled |
| `--verbose` | Verbose logging (adds the real compile diagnostic and a stack trace on a fault) | disabled |
| `--verify-opcodes` | Self-check the dense opcode map, then exit (0 OK / 1 FAIL) | - |
| `--help` | Show help | - |

## File Extensions

| Extension | Description | Executable |
|-----------|-------------|------------|
| `.bas` | Standard BASIC (console) | sb.exe (MODERN), sbv.exe (CLASSIC) |
| `.wbas` | Web BASIC | sbw.exe |
| `.basc` | Compiled bytecode | sb.exe (MODERN), sbv.exe (CLASSIC) |

## Dialect

A `.wbas` script is written in the **MODERN** dialect (FreeBASIC): a `Sub` has its own locals, numbers
print as FreeBASIC prints them, and the preprocessor (`#define`, `#if`, `#include`, `#macro`) is there.

A script with line numbers is **CLASSIC** (Commodore BASIC v7), and `sbw` refuses it: the request gets a
`500 Internal Server Error` page that names the reason. CLASSIC programs run in `sbv`.

`TAB` and `SPC` are cursor movements. FreeBASIC emits them only onto a visible screen, and an HTTP
response body is a redirected stream, so in a `.wbas` they produce nothing - which is what `fbc` does.

## Web BASIC Instructions

### Input Functions (with automatic sanitization)

| Function | Description | Security |
|----------|-------------|----------|
| `GET$("name")` | Query string parameter | HTML-escaped (safe) |
| `POST$("name")` | Form POST parameter | HTML-escaped (safe) |
| `GETRAW$("name")` | Query string raw | Not sanitized |
| `POSTRAW$("name")` | Form POST raw | Not sanitized |

**Security principle:** `GET$` and `POST$` return HTML-escaped values by default.

```basic
' Input: nome=Mario<script>alert(1)</script>
Print Get$("nome")
' Output: Mario&lt;script&gt;alert(1)&lt;/script&gt;
```

For raw data (JSON processing, internal use):
```basic
' Only when necessary and with awareness
Dim As String json = GetRaw$("data")
```

### Encoding Functions

| Function | Description | Use |
|----------|-------------|-----|
| `HTML$(s)` | HTML escape | `< > & " '` -> entities |
| `URL$(s)` | URL encode | For building URLs |

### HTTP Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `METHOD$` | HTTP method | "GET", "POST" |
| `PATH$` | Requested path | "/hello.wbas" |
| `QUERY$` | Full query string | "nome=Mario&eta=30" |
| `HEADER$("name")` | HTTP request header | `HEADER$("User-Agent")` |

### Response Control

| Instruction | Description | Example |
|-------------|-------------|---------|
| `SETHEADER name, value` | Set response header | `SETHEADER "Content-Type", "application/json"` |
| `STATUS code` | Set HTTP status | `STATUS 404` |

## Example Scripts

### hello.wbas - Simple HTML Page

```basic
SetHeader "Content-Type", "text/html; charset=utf-8"
Print "<html><body>"
Print "<h1>Welcome!</h1>"
If Get$("nome") <> "" Then Print "<p>Hello " & Get$("nome") & "!</p>"
Print "<p>Method: " & Method$ & "</p>"
Print "<p>Time: " & Time & "</p>"
Print "</body></html>"
```

**Request:** `GET /hello.wbas?nome=Mario`

**Response:**
```html
<html><body>
<h1>Welcome!</h1>
<p>Hello Mario!</p>
<p>Method: GET</p>
<p>Time: 14:35:22</p>
</body></html>
```

### api.wbas - JSON API

```basic
SetHeader "Content-Type", "application/json"
Dim As String id = GetRaw$("id")
If id = "" Then id = "0"
Print "{""id"": " & id & ", ""status"": ""ok"", ""time"": """ & Time & """}"
```

### form.wbas - Form Handling

```basic
SetHeader "Content-Type", "text/html; charset=utf-8"
Print "<html><body>"
If Method$ = "POST" Then
  ' Process POST
  Print "<h1>Hello " & Post$("nome") & "!</h1>"
  Print "<a href='/form.wbas'>Back</a>"
Else
  ' Show form
  Print "<form method='post'>"
  Print "<input name='nome' placeholder='Name'>"
  Print "<button>Submit</button>"
  Print "</form>"
End If
Print "</body></html>"
```

## Excluded Instructions

The following instructions are **not available** in sbw.exe and will cause syntax errors:

### Graphics
`GRAPHIC`, `DRAW`, `CIRCLE`, `BOX`, `COLOR`, `SCNCLR`, `PLOT`, `LINE`, `PAINT`, `CHAR`, `SPRITE`, `MOVSPR`, `SPRCOLOR`, etc.

### Audio
`SOUND`, `PLAY`, `VOL`, `ENVELOPE`, `TEMPO`, `FILTER`, etc.

### Interactive Console
`INPUT` (blocking), `GET`, `GETKEY`, `INKEY$`

### PEEK/POKE
Only "safe" memory operations. Video/audio memory mapping will cause errors.

### Not excluded, despite where they used to live
`REGEXCOUNT` and `REGEXREPLACE` are string functions and work in `sbw`. Until 1 September 2026 their two
registrations sat inside the block of graphics keywords that `WEB_MODE` compiles out, so `sbw` did not
know the names at all.

### How a refusal reports itself
A CLASSIC script (line numbers) answers `500 Internal Server Error` with the reason on the page. Any
other script `sbw` cannot compile answers `500 Internal Server Error: Compilation failed`. Run the server
with `--verbose` to get the real reason in the log (`SSA generation error: ...`, `Parser error: ...`,
`Preprocessor error: ...`). Before 1 September 2026 every such refusal surfaced as `Access violation`,
which named nothing.

## Security Considerations

### XSS Prevention

Use `GET$`/`POST$` (not `GETRAW$`/`POSTRAW$`) when outputting to HTML:

```basic
' SAFE - HTML-escaped
Print "<p>Hello " & Get$("name") & "</p>"

' UNSAFE - XSS vulnerable
Print "<p>Hello " & GetRaw$("name") & "</p>"
```

### Path Traversal Protection

The server sanitizes paths and prevents directory traversal:
- `../../../etc/passwd` is blocked
- Only `.wbas` files can be executed
- Files must be within `--basedir`

### Null Byte Injection

Null bytes in paths are rejected.

## Build

```powershell
# Build sbw only
.\build.ps1 -Target sbw

# Build all targets including sbw
.\build.ps1 -Target all

# Build with debug
.\build.ps1 -Target sbw -Debug
```

## Architecture

```
+-------------------------------------------------------------+
|                      sbw.exe                                |
+-------------------------------------------------------------+
|  HTTP Server (fphttpserver)                                 |
|    GET /hello.wbas  ->  executes basedir/hello.wbas         |
|    GET /admin/login.wbas  ->  executes basedir/admin/login  |
+-------------------------------------------------------------+
|  Web I/O Adapter                                            |
|    TWebOutput : IOutputDevice  (PRINT -> response body)     |
|    TWebContext : request/response data                      |
+-------------------------------------------------------------+
|  SedaiBasic Core (NO SDL2, NO Audio, NO Graphics)           |
|    Lexer -> Parser -> SSA -> Bytecode -> VM                 |
+-------------------------------------------------------------+
```

## Comparison with Other Executables

| Executable | Description | SDL2 | Audio | Graphics | Web |
|------------|-------------|------|-------|----------|-----|
| `sb.exe` | Console | No | Optional | No | No |
| `sbv.exe` | Vision (graphic) | Yes | Yes | Yes | No |
| `sbc.exe` | Compiler | No | No | No | No |
| `sbd.exe` | Disassembler | No | No | No | No |
| `sbw.exe` | Web Server | No | No | No | Yes |

## Future Improvements

- Multi-threaded/worker pool mode
- Session management
- Database connectivity
- Template engine integration
- WebSocket support
