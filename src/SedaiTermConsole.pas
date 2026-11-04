{*
 * SedaiBasic - A BASIC interpreter with bytecode VM
 * Copyright (C) 2025 Maurizio Cammalleri
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3
 * as published by the Free Software Foundation (GPL-3.0-only).
 * See <https://www.gnu.org/licenses/gpl-3.0.html>
 *
 * Under Section 7 of GPL version 3, you are granted additional permissions
 * described in the GCC Runtime Library Exception, version 3.1, as published
 * by the Free Software Foundation. See the files LICENSE and COPYING.RUNTIME.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * SPDX-License-Identifier: GPL-3.0-only WITH GCC-exception-3.1
 *}
unit SedaiTermConsole;

{$mode ObjFPC}{$H+}
{$codepage UTF8}

{ ============================================================================
  SedaiTermConsole - the console on a Unix TERMINAL, as fbc's runtime has it (DIVERGENZE 415)

  libfb (src/rtlib/unix, 1.10.1) INITIALISES the console at start-up when stdin and stdout are both a
  terminal, the process is in the foreground and TERM names a terminfo entry with the "am" flag - the
  test FbConsoleInited (SedaiTerminalIO) already answers. Once initialised, for the whole run:
    - the terminal is in non-canonical mode with no echo (keys arrive one by one, without Enter);
    - INKEY/GETKEY/SLEEP read keys, and escape sequences become fbc's two-byte codes (Chr(255) + scan);
    - INPUT/LINE INPUT edit the line themselves (fb_ConReadLine): they echo, and know Backspace,
      Left/Right, Home/End, Del, Esc;
    - COLOR, LOCATE (and its cursor-visibility argument) and CLS write the terminfo sequences;
    - CSRLIN/POS ASK THE TERMINAL ("\e[6n") on every call;
    - a PRINTed control character that a terminal would act on (BS, FF, SO, SI, ESC) becomes a glyph;
    - at exit, and on a fatal signal, the terminal is put back.
  Not initialised (any redirect, a background job, no terminfo), none of this happens - in fbc as here.

  ⭐ Answered from the terminfo database directly, no libtinfo: the core takes no dependency for this.
  ⛔ ONE difference from fbc, the owner's (7 Oct 2026, "copy everything but not the defects"): fbc waits
  for the answer to "\e[6n" WITHOUT A LIMIT ("we'll hang forever"), so a terminal that does not answer
  freezes the program before its first line. Here the wait is bounded (TC_QUERY_TIMEOUT_MS); a terminal
  that has not answered once is not asked again, and the runtime's own count answers. fbc upstream report n. 12.
  Two more, both about leaving the terminal usable, neither visible to a program: Ctrl+Z puts the
  terminal back while the program is stopped (fbc leaves it raw), and padding "$<n>" is not sent.
  ⚠️ Not here (still open under 415): MULTIKEY and GETMOUSE on a terminal, VIEW PRINT's scroll region,
  WIDTH/the terminal size, SCREEN() read from the terminal's buffer.
  ============================================================================ }

interface

// sb calls this once, before the program runs. True when the console was initialised (see above).
// SB_TERMCONSOLE=0 is the A/B knob: the console stays as it was before DIVERGENZE 415 was closed.
function TcStart: Boolean;
// Put the terminal back. Idempotent; also runs at exit and on a fatal signal.
procedure TcStop;
function TcActive: Boolean;
// sb asked for fbc's console (TcStart ran, SB_TERMCONSOLE is not 0), initialised or not: where fbc's runtime
// is NOT initialised it writes nothing for CLS either. False in sbv, which never asks - its console stays its own.
function TcFbConsole: Boolean;
// Around a child process (SHELL): the child must see the terminal as the user left it.
procedure TcSuspend;
procedure TcResume;

// Keys. A code is a byte (0..255) or, for a special key, (scan shl 8) or 255 - fbc's GETKEY value.
function TcInkey: string;                 // '' when no key; Chr(255) + scan for a special key
function TcGetkey: Integer;               // blocks until a key
function TcKeyHit: Boolean;               // fbc's fb_ConsoleKeyHit: "has the key buffer CHANGED"
procedure TcSleep(Ms: Integer; Wake: Boolean);   // Ms = -1: until a key
function TcReadLine: string;              // fb_ConReadLine: edits and echoes, the caller ends the line
// "Input ;" / "Line Input ;": the next line read ends WITHOUT a new line (fbc's addnewline = FALSE)
procedure TcNoNewlineOnce;
function TcTakeNoNewline: Boolean;

// Screen.
procedure TcColor(Fg, Bg: Integer; HasFg, HasBg: Boolean);
// Row/Col 1-based, <= 0 keeps that coordinate; Cursor -1 leaves the visibility, 0 hides, 1 shows.
// Returns fbc's packed answer (col or row shl 8 or the visibility bit $10000) and the new position.
function TcLocate(Row, Col, Cursor: Integer; out NewRow, NewCol: Integer): Integer;
// Mode as the VM carries it: -1 (bare CLS) and 2 clear the print area FirstRow..LastRow (1-based),
// 1 clears nothing, anything else the whole screen.
procedure TcClear(Mode, FirstRow, LastRow: Integer);
procedure TcGetXY(out Col, Row: Integer);  // asks the terminal; falls back on the runtime's own count
// VIEW PRINT First TO Last (1-based; <= 0 = the whole screen): the terminal's scroll region and the cursor to the
// start of the area, as libfb's fb_ConsoleViewUpdate + LOCATE. Answers the rows it used.
procedure TcViewPrint(var First, Last: Integer);
// SCREEN 0 closing a graphics screen that a WINDOW showed (DIVERGENZE 729): libfb gives the console back
// cleared, with the whole screen as the print area - measured on a pty, the bytes are "clear, full scroll
// region, home, clear, full scroll region".
procedure TcScreenZero;
function TcCursorVisible: Boolean;
function TcColorFg: Integer;
function TcColorBg: Integer;
// PRINT text on its way to the terminal: the control characters a terminal would obey become glyphs,
// as libfb's fb_ConsolePrintBufferEx writes them, and the position the runtime counts moves with it.
function TcPrintText(const S: string): string;

implementation

uses
  Classes, SysUtils
  {$IFDEF UNIX}
  , BaseUnix, Unix, termio, SedaiTerminalIO
  {$ENDIF}
  ;

{$IFNDEF UNIX}
function TcStart: Boolean; begin Result := False; end;
procedure TcStop; begin end;
function TcActive: Boolean; begin Result := False; end;
function TcFbConsole: Boolean; begin Result := False; end;
procedure TcSuspend; begin end;
procedure TcResume; begin end;
function TcInkey: string; begin Result := ''; end;
function TcGetkey: Integer; begin Result := -1; end;
function TcKeyHit: Boolean; begin Result := False; end;
procedure TcSleep(Ms: Integer; Wake: Boolean); begin if Ms > 0 then Sleep(Ms); end;
function TcReadLine: string; begin Result := ''; end;
procedure TcNoNewlineOnce; begin end;
function TcTakeNoNewline: Boolean; begin Result := False; end;
procedure TcColor(Fg, Bg: Integer; HasFg, HasBg: Boolean); begin end;
function TcLocate(Row, Col, Cursor: Integer; out NewRow, NewCol: Integer): Integer;
begin NewRow := Row; NewCol := Col; Result := 0; end;
procedure TcClear(Mode, FirstRow, LastRow: Integer); begin end;
procedure TcGetXY(out Col, Row: Integer); begin Col := 1; Row := 1; end;
procedure TcViewPrint(var First, Last: Integer); begin end;
procedure TcScreenZero; begin end;
function TcCursorVisible: Boolean; begin Result := True; end;
function TcColorFg: Integer; begin Result := 0; end;
function TcColorBg: Integer; begin Result := 0; end;
function TcPrintText(const S: string): string; begin Result := S; end;
{$ELSE}

const
  TC_QUERY_TIMEOUT_MS = 1000;   // a terminal answers "\e[6n" in well under a millisecond; ssh in tens

  // fbc's special-key codes (FB_MAKE_EXT_KEY): the scan code in the high byte, 255 in the low one.
  // Measured with fbc 1.10.1 on a pty under TERM=xterm, one key at a time (F11/F12 are 'E'/'F' there).
  KEY_F1 = (59 shl 8) or 255;
  KEY_HOME = (71 shl 8) or 255;  KEY_UP = (72 shl 8) or 255;    KEY_PAGE_UP = (73 shl 8) or 255;
  KEY_LEFT = (75 shl 8) or 255;  KEY_RIGHT = (77 shl 8) or 255; KEY_END = (79 shl 8) or 255;
  KEY_DOWN = (80 shl 8) or 255;  KEY_PAGE_DOWN = (81 shl 8) or 255;
  KEY_INS = (82 shl 8) or 255;   KEY_DEL = (83 shl 8) or 255;
  KEY_F11 = (69 shl 8) or 255;   KEY_F12 = (70 shl 8) or 255;
  KEY_MOUSE = $200;

  // terminfo string capabilities, by their index in the compiled entry (term(5); verified against
  // ncurses' tigetstr on this machine's xterm entry)
  CAP_CSR = 3; CAP_CLEAR = 5; CAP_EL = 6; CAP_CUP = 10; CAP_HOME = 12; CAP_CIVIS = 13; CAP_CNORM = 16;
  CAP_DCH1 = 21; CAP_BOLD = 27; CAP_SGR0 = 39; CAP_RMKX = 88; CAP_SMKX = 89;
  CAP_SETAF = 359; CAP_SETAB = 360; CAP_RMACS = 38; CAP_SGR = 131;

  INIT_CONSOLE = 1;   // TERM=linux/console: fbc also switches the character set
  INIT_X11 = 2;

type
  TKeySeq = record
    Seq: string;      // the sequence AFTER the ESC
    Code: Integer;
  end;

var
  GActive: Boolean = False;
  GStarted: Boolean = False;     // TcStart has run (once per process)
  GFbConsole: Boolean = False;   // ...and the A/B knob did not turn it off
  GInitKind: Integer = 0;
  GXterm: Boolean = False;
  GTtyFd: cint = -1;
  GOldOut, GOldIn: Termios;
  GSavedOut, GSavedIn: Boolean;
  GOldFlags: cint = 0;
  GCaps: array of string;        // terminfo strings by index ('' = absent)
  GKeys: array of TKeySeq;
  GKeysBuilt: Boolean = False;
  // fbc's key buffer (io_inkey.c): a ring, plus "has it changed" for SLEEP and fb_ConsoleKeyHit
  GKeyBuf: array[0..255] of Integer;
  GKeyHead: Integer = 0;
  GKeyTail: Integer = 0;
  GKeyChanged: Boolean = False;
  GFg: Integer = 7;
  GBg: Integer = 0;
  GCurX: Integer = 1;            // the runtime's own count, 1-based (fbc's __fb_con.cur_x/cur_y)
  GCurY: Integer = 1;
  GCols: Integer = 80;
  GRows: Integer = 25;
  GVisible: Boolean = True;
  GQueryDead: Boolean = False;   // the terminal did not answer once: never asked again
  GSigInstalled: Boolean = False;
  GExitRegistered: Boolean = False;
  GSuspended: Boolean = False;
  GExitSeq: string = '';         // what TcStop writes, prepared at start so a signal handler can write it
  GSgr0: string = '';            // "me" as libfb's tgetstr answers it (see TrimSgr0)
  GScrollChanged: Boolean = False;   // VIEW PRINT set a scroll region: the exit puts the whole screen back
  GViewTop: Integer = 1;
  GViewBot: Integer = 25;
  GNoNewline: Boolean = False;

{ === terminfo ============================================================== }

function ReadTerminfoStrings(const Term: string): Boolean;
// The compiled entry ncurses would find (the same search TerminfoAutoMargins makes), string section only.
const
  SystemDirs: array[0..2] of string = ('/etc/terminfo', '/lib/terminfo', '/usr/share/terminfo');
var
  Dirs: TStringList;
  S, Home, FN: string;
  i, j: Integer;
  B: TBytes;
  F: THandle;
  Sz, Magic, NamesSz, NBools, NNums, NStrs, TabSz, Off, NumW, P, E: Integer;

  function W(At: Integer): Integer;
  begin
    Result := SmallInt(B[At] or (B[At + 1] shl 8));
  end;

begin
  Result := False;
  SetLength(GCaps, 0);
  if (Term = '') or (Pos('/', Term) > 0) then Exit;
  Dirs := TStringList.Create;
  try
    S := GetEnvironmentVariable('TERMINFO');
    if S <> '' then Dirs.Add(S);
    Home := GetEnvironmentVariable('HOME');
    if Home <> '' then Dirs.Add(Home + '/.terminfo');
    S := GetEnvironmentVariable('TERMINFO_DIRS');
    if S <> '' then
    begin
      S := S + ':';
      while S <> '' do
      begin
        j := Pos(':', S);
        if j = 1 then
          for i := Low(SystemDirs) to High(SystemDirs) do Dirs.Add(SystemDirs[i])
        else
          Dirs.Add(Copy(S, 1, j - 1));
        Delete(S, 1, j);
      end;
    end;
    for i := Low(SystemDirs) to High(SystemDirs) do Dirs.Add(SystemDirs[i]);
    FN := '';
    for i := 0 to Dirs.Count - 1 do
    begin
      if Dirs[i] = '' then Continue;
      S := Dirs[i] + '/' + Term[1] + '/' + Term;
      if FileExists(S) then begin FN := S; Break; end;
      S := Dirs[i] + '/' + LowerCase(IntToHex(Ord(Term[1]), 2)) + '/' + Term;
      if FileExists(S) then begin FN := S; Break; end;
    end;
  finally
    Dirs.Free;
  end;
  if FN = '' then Exit;
  F := FileOpen(FN, fmOpenRead or fmShareDenyNone);
  if F = THandle(-1) then Exit;
  try
    Sz := FileSeek(F, 0, fsFromEnd);
    if Sz < 12 then Exit;
    FileSeek(F, 0, fsFromBeginning);
    SetLength(B, Sz);
    if FileRead(F, B[0], Sz) <> Sz then Exit;
  finally
    FileClose(F);
  end;
  Magic := W(0);
  if Magic = $011A then NumW := 2 else if Magic = $021E then NumW := 4 else Exit;
  NamesSz := W(2); NBools := W(4); NNums := W(6); NStrs := W(8); TabSz := W(10);
  Off := 12 + NamesSz + NBools;
  if Odd(Off) then Inc(Off);
  Inc(Off, NNums * NumW);
  if Off + NStrs * 2 + TabSz > Sz then Exit;
  SetLength(GCaps, NStrs);
  for i := 0 to NStrs - 1 do
  begin
    P := W(Off + i * 2);
    GCaps[i] := '';
    if (P < 0) or (P >= TabSz) then Continue;
    P := Off + NStrs * 2 + P;
    E := P;
    while (E < Sz) and (B[E] <> 0) do Inc(E);
    SetLength(S, E - P);
    if E > P then Move(B[P], S[1], E - P);
    GCaps[i] := S;
  end;
  Result := True;
end;

function Cap(Index: Integer): string;
begin
  if Index < Length(GCaps) then Result := GCaps[Index] else Result := '';
end;

function StripPadding(const S: string): string;
// "$<5>" asks for a delay; tputs would send pad characters. Nothing a program can see depends on it.
var
  i, j: Integer;
begin
  Result := S;
  i := Pos('$<', Result);
  while i > 0 do
  begin
    j := i + 2;
    while (j <= Length(Result)) and (Result[j] <> '>') do Inc(j);
    Delete(Result, i, j - i + 1);
    i := Pos('$<', Result);
  end;
end;

function TParm(const Fmt: string; P1: Integer = 0; P2: Integer = 0): string;
// ncurses' tparm, for the operators terminfo entries use: %% %c %d %s %[flags][width][.prec][doxX]
// %p1-9 %P/%g variables %'c' %{n} %l %+ %- %* %/ %m %& %| %^ %= %> %< %A %O %! %~ %i %? %t %e %;
var
  Stk: array[0..31] of Int64;
  SP: Integer;
  Prm: array[1..9] of Int64;
  Vars: array[0..51] of Int64;
  i, n, Depth: Integer;
  c: Char;
  Spec: string;
  a, b: Int64;

  procedure Push(V: Int64);
  begin
    if SP < High(Stk) then begin Inc(SP); Stk[SP] := V; end;
  end;

  function Pop: Int64;
  begin
    if SP >= 0 then begin Result := Stk[SP]; Dec(SP); end else Result := 0;
  end;

  // skip forward from i to the matching %e (when StopAtElse) or %; at this nesting depth
  procedure SkipTo(StopAtElse: Boolean);
  begin
    Depth := 0;
    while i <= Length(Fmt) do
    begin
      if (Fmt[i] = '%') and (i < Length(Fmt)) then
      begin
        Inc(i);
        case Fmt[i] of
          '?': Inc(Depth);
          ';': if Depth = 0 then begin Inc(i); Exit; end else Dec(Depth);
          'e': if (Depth = 0) and StopAtElse then begin Inc(i); Exit; end;
        end;
      end;
      Inc(i);
    end;
  end;

begin
  Result := '';
  SP := -1;
  FillChar(Prm, SizeOf(Prm), 0);
  FillChar(Vars, SizeOf(Vars), 0);
  Prm[1] := P1; Prm[2] := P2;
  i := 1;
  while i <= Length(Fmt) do
  begin
    c := Fmt[i];
    if (c <> '%') or (i = Length(Fmt)) then
    begin
      Result := Result + c;
      Inc(i);
      Continue;
    end;
    Inc(i);
    c := Fmt[i];
    Inc(i);
    case c of
      '%': Result := Result + '%';
      'c': Result := Result + Chr(Byte(Pop));
      's': Result := Result + IntToStr(Pop);
      'd', 'o', 'x', 'X', ':', '0'..'9', '.':
        begin
          // a printf conversion, possibly with flags / width / precision
          Spec := '%';
          if c = ':' then begin c := Fmt[i]; Inc(i); end;
          while c in ['-', '+', '#', ' ', '0'..'9', '.'] do
          begin
            Spec := Spec + c;
            c := Fmt[i]; Inc(i);
          end;
          a := Pop;
          case c of
            'd': Result := Result + Format(Spec + 'd', [a]);
            'x': Result := Result + LowerCase(Format(Spec + 'x', [a]));
            'X': Result := Result + Format(Spec + 'x', [a]);
            'o': Result := Result + OctStr(a, 1);
            's': Result := Result + IntToStr(a);
          end;
        end;
      'p': begin n := Ord(Fmt[i]) - Ord('0'); Inc(i); if (n >= 1) and (n <= 9) then Push(Prm[n]) else Push(0); end;
      'P': begin
             if Fmt[i] in ['a'..'z'] then Vars[Ord(Fmt[i]) - Ord('a')] := Pop
             else if Fmt[i] in ['A'..'Z'] then Vars[26 + Ord(Fmt[i]) - Ord('A')] := Pop;
             Inc(i);
           end;
      'g': begin
             if Fmt[i] in ['a'..'z'] then Push(Vars[Ord(Fmt[i]) - Ord('a')])
             else if Fmt[i] in ['A'..'Z'] then Push(Vars[26 + Ord(Fmt[i]) - Ord('A')])
             else Push(0);
             Inc(i);
           end;
      '''': begin Push(Ord(Fmt[i])); Inc(i, 2); end;
      '{': begin
             n := 0;
             while (i <= Length(Fmt)) and (Fmt[i] in ['0'..'9']) do
             begin n := n * 10 + Ord(Fmt[i]) - Ord('0'); Inc(i); end;
             Inc(i);   // '}'
             Push(n);
           end;
      'l': Push(Length(IntToStr(Pop)));
      '+', '-', '*', '/', 'm', '&', '|', '^', '=', '>', '<', 'A', 'O':
        begin
          b := Pop; a := Pop;
          case c of
            '+': Push(a + b);
            '-': Push(a - b);
            '*': Push(a * b);
            '/': if b <> 0 then Push(a div b) else Push(0);
            'm': if b <> 0 then Push(a mod b) else Push(0);
            '&': Push(a and b);
            '|': Push(a or b);
            '^': Push(a xor b);
            '=': Push(Ord(a = b));
            '>': Push(Ord(a > b));
            '<': Push(Ord(a < b));
            'A': Push(Ord((a <> 0) and (b <> 0)));
            'O': Push(Ord((a <> 0) or (b <> 0)));
          end;
        end;
      '!': Push(Ord(Pop = 0));
      '~': Push(not Pop);
      'i': begin Inc(Prm[1]); Inc(Prm[2]); end;
      '?': ;
      't': if Pop = 0 then SkipTo(True);
      'e': SkipTo(False);
      ';': ;
    end;
  end;
end;

function TrimSgr0: string;
// libfb asks termcap for "me", and ncurses answers it through _nc_trim_sgr0: sgr0 without the part that
// leaves the alternate character set, replaced by sgr(0,...,0) when the two say the same thing. Measured
// with fbc: xterm's "\e(B\e[m" and screen's "\e[m\x0f" are written "\e[0m"; the Linux console's
// "\e[m\x0f", whose sgr(0) is "\e[0;10m", is written as it is.
var
  Me, Off, Rm: string;
  k: Integer;

  function Norm(const X: string): string;
  begin
    Result := X;
    if Result = #27'[m' then Result := #27'[0m';
  end;

begin
  Result := StripPadding(Cap(CAP_SGR0));
  if (Result = '') or (Cap(CAP_SGR) = '') then Exit;
  Off := StripPadding(TParm(Cap(CAP_SGR)));
  Me := Result;
  Rm := Cap(CAP_RMACS);
  if Rm <> '' then
  begin
    k := Pos(Rm, Off);
    if k > 0 then Delete(Off, k, Length(Rm));
    k := Pos(Rm, Me);
    if k > 0 then Delete(Me, k, Length(Rm));
  end;
  if Norm(Me) = Norm(Off) then Result := Off;
end;

{ === output ================================================================ }

procedure Emit(const S: string);
// Through the stream PRINT uses, flushed: an escape sequence must not overtake text written before it.
begin
  if S = '' then Exit;
  if GfxScreenOwnsText then Exit;   // DIVERGENZE 729: a window shows a graphics screen - it is the console
  TerminalWriteRaw(StripPadding(S));
end;

procedure EmitCup(Row0, Col0: Integer);
var
  C: string;
begin
  C := Cap(CAP_CUP);
  if C = '' then Exit;
  Emit(TParm(C, Row0, Col0));
end;

procedure RawWrite(const S: string);
// For the signal handler: no buffers, no allocation the handler cannot afford.
begin
  if S <> '' then FpWrite(1, S[1], Length(S));
end;

{ === sizes and the cursor query ============================================= }

procedure RecheckSize;
var
  WS: TWinSize;
begin
  FillChar(WS, SizeOf(WS), 0);
  if (FpIOCtl(1, TIOCGWINSZ, @WS) = 0) and (WS.ws_row > 0) and (WS.ws_col > 0) then
  begin
    GRows := WS.ws_row;
    GCols := WS.ws_col;
  end
  else
  begin
    GRows := 25;
    GCols := 80;
  end;
end;

procedure AddCh(K: Integer);
// fb_hAddCh: DEL reads as Backspace and LF as CR, as a key
begin
  if K = $7F then K := 8
  else if K = 10 then K := 13;
  GKeyBuf[GKeyTail] := K;
  if ((GKeyTail + 1) and 255) = GKeyHead then GKeyHead := (GKeyHead + 1) and 255;
  GKeyTail := (GKeyTail + 1) and 255;
  GKeyChanged := True;
end;

function ReadByte(TimeoutMs: Integer): Integer;
// One byte from the terminal, waiting at most TimeoutMs (0 = only what is already there); -1 if none.
var
  Fds: TPollFd;
  Ch: Byte;
begin
  Result := -1;
  if GTtyFd < 0 then Exit;
  if TimeoutMs > 0 then
  begin
    Fds.fd := GTtyFd;
    Fds.events := POLLIN;
    Fds.revents := 0;
    if FpPoll(@Fds, 1, TimeoutMs) <= 0 then Exit;
  end;
  if FpRead(GTtyFd, Ch, 1) = 1 then Result := Ch;
end;

function QueryCursor(out Row, Col: Integer): Boolean;
// fb_hTermQuery(SEQ_QUERY_CURSOR), bounded: whatever arrives before the answer is a KEY and goes to the
// key buffer, as libfb does with it.
var
  Deadline: QWord;
  C, Left, A, B: Integer;
  InNum: Boolean;
  Stage: Integer;   // 0 wait ESC, 1 wait '[', 2 row digits, 3 col digits
begin
  Result := False;
  Row := 0; Col := 0;
  if GQueryDead or not GActive then Exit;
  Emit(#27'[6n');
  Deadline := GetTickCount64 + TC_QUERY_TIMEOUT_MS;
  Stage := 0; A := 0; B := 0; InNum := False;
  repeat
    Left := Integer(Int64(Deadline) - Int64(GetTickCount64));
    if Left <= 0 then Break;
    C := ReadByte(Left);
    if C < 0 then Continue;
    case Stage of
      0: if C = 27 then Stage := 1 else AddCh(C);
      1: if C = Ord('[') then begin Stage := 2; A := 0; InNum := False; end
         else begin AddCh(C); Stage := 0; end;
      2: if (C >= Ord('0')) and (C <= Ord('9')) then begin A := A * 10 + C - Ord('0'); InNum := True; end
         else if (C = Ord(';')) and InNum then begin Stage := 3; B := 0; InNum := False; end
         else Stage := 0;   // not a cursor report: scanf would fail and libfb read on
      3: if (C >= Ord('0')) and (C <= Ord('9')) then begin B := B * 10 + C - Ord('0'); InNum := True; end
         else if (C = Ord('R')) and InNum then
         begin
           Row := A; Col := B;
           Exit(True);
         end
         else Stage := 0;
    end;
  until False;
  // ⛔ fbc waits here for ever (fbc upstream report n. 12). A terminal that did not answer is not asked again.
  GQueryDead := True;
end;

procedure TcGetXY(out Col, Row: Integer);
var
  R, C: Integer;
begin
  if GActive and QueryCursor(R, C) then
  begin
    GCurX := C;
    GCurY := R;
  end;
  if GActive then
  begin
    Col := GCurX;
    Row := GCurY;
  end
  else
  begin
    Col := 1;
    Row := 1;
  end;
end;

{ === keys ================================================================== }

procedure AddKeySeq(const Full: string; Code: Integer);
// Only sequences that begin with ESC: libfb files the capability under the bytes AFTER the first one.
var
  n: Integer;
begin
  if (Length(Full) < 2) or (Full[1] <> #27) then Exit;
  n := Length(GKeys);
  SetLength(GKeys, n + 1);
  GKeys[n].Seq := Copy(Full, 2, MaxInt);
  GKeys[n].Code := Code;
end;

procedure BuildKeys;
// io_inkey.c's key_data, in its order, from the terminfo entry: kbs kT k1-k9 k; F1 F2 kh ku kP kl kr @7
// kd kN kI kD, then "[M" for an xterm mouse report.
const
  // kbs khts kf1..kf9 kf10 kf11 kf12 khome kcuu1 kpp kcub1 kcuf1 kend kcud1 knp kich1 kdch1
  Idx: array[0..23] of Integer = (55, 86, 66, 68, 69, 70, 71, 72, 73, 74, 75, 67, 216, 217,
                                  76, 87, 82, 79, 83, 164, 61, 81, 77, 59);
var
  Codes: array[0..23] of Integer;
  i: Integer;
begin
  GKeysBuilt := True;
  SetLength(GKeys, 0);
  Codes[0] := 8; Codes[1] := 9;
  for i := 0 to 9 do Codes[2 + i] := ((59 + i) shl 8) or 255;
  Codes[12] := KEY_F11; Codes[13] := KEY_F12;
  Codes[14] := KEY_HOME; Codes[15] := KEY_UP; Codes[16] := KEY_PAGE_UP; Codes[17] := KEY_LEFT;
  Codes[18] := KEY_RIGHT; Codes[19] := KEY_END; Codes[20] := KEY_DOWN; Codes[21] := KEY_PAGE_DOWN;
  Codes[22] := KEY_INS; Codes[23] := KEY_DEL;
  for i := 0 to High(Idx) do
    AddKeySeq(Cap(Idx[i]), Codes[i]);
  AddKeySeq(#27'[M', KEY_MOUSE);
end;

function GetInput: Integer;
// io_inkey.c's get_input: one key, or -1. An escape sequence nobody declared is dropped TOGETHER WITH
// everything still pending - libfb does exactly that, and so does a program reading keys under fbc.
var
  K, i, Len: Integer;
  Prefix: string;
  Any: Boolean;
begin
  K := ReadByte(0);
  if K <> 27 then Exit(K);
  K := ReadByte(0);
  if K < 0 then Exit(27);
  if not GKeysBuilt then BuildKeys;
  Prefix := '';
  repeat
    Prefix := Prefix + Chr(K);
    Len := Length(Prefix);
    Any := False;
    for i := 0 to High(GKeys) do
      if (Length(GKeys[i].Seq) >= Len) and (CompareByte(GKeys[i].Seq[1], Prefix[1], Len) = 0) then
      begin
        Any := True;
        if Length(GKeys[i].Seq) = Len then
        begin
          if GKeys[i].Code = KEY_MOUSE then
          begin
            ReadByte(0); ReadByte(0); ReadByte(0);   // button, x, y: GETMOUSE on a terminal is still open
            Exit(-1);
          end;
          Exit(GKeys[i].Code);
        end;
      end;
    if not Any then Break;
    K := ReadByte(0);
    if K < 0 then Exit(-1);
  until False;
  while ReadByte(0) >= 0 do ;
  Result := -1;
end;

function GetCh(Remove: Boolean): Integer;
// fb_hGetCh
begin
  Result := GetInput;
  if Result >= 0 then AddCh(Result);
  Result := -1;
  if GKeyHead <> GKeyTail then
  begin
    Result := GKeyBuf[GKeyHead];
    if Remove then GKeyHead := (GKeyHead + 1) and 255;
  end;
end;

function KeyString(K: Integer): string;
// fb_hMakeInkeyStr
begin
  if K > $FF then Result := Chr(K and $FF) + Chr(K shr 8)
  else Result := Chr(K);
end;

function TcInkey: string;
var
  K: Integer;
begin
  Result := '';
  if not GActive then Exit;
  TerminalOutFlush;   // fbc flushes after every PRINT: what the program wrote is on screen before it waits
  K := GetCh(True);
  if K >= 0 then Result := KeyString(K);
end;

function TcKeyHit: Boolean;
begin
  Result := False;
  if not GActive then Exit;
  TerminalOutFlush;
  GetCh(False);
  Result := GKeyChanged;
  GKeyChanged := False;
end;

function TcGetkey: Integer;
begin
  Result := -1;
  if not GActive then Exit;
  TerminalOutFlush;
  repeat
    Result := GetCh(True);
    if Result >= 0 then Exit;
    // fb_Sleep(-1): until the key buffer changes
    while not TcKeyHit do Sleep(50);
  until False;
end;

procedure TcSleep(Ms: Integer; Wake: Boolean);
// fb_ConsoleSleep: -1 waits for a key; 100 ms or more wakes on one (unless Wake is False); less is a delay
begin
  TerminalOutFlush;
  if Ms = -1 then
  begin
    while not TcKeyHit do Sleep(50);
    Exit;
  end;
  if Wake and (Ms >= 100) then
    while Ms > 50 do
    begin
      if TcKeyHit then Exit;
      Sleep(50);
      Dec(Ms, 50);
    end;
  if Ms > 0 then Sleep(Ms);
end;

{ === screen ================================================================ }

function TcCursorVisible: Boolean;
begin
  Result := GVisible;
end;

function TcColorFg: Integer;
begin
  Result := GFg;
end;

function TcColorBg: Integer;
begin
  Result := GBg;
end;

procedure TcColor(Fg, Bg: Integer; HasFg, HasBg: Boolean);
// io_color.c
const
  Map: array[0..7] of Integer = (0, 4, 2, 6, 1, 5, 3, 7);
var
  OldFg, OldBg: Integer;
  Force: Boolean;
begin
  if not GActive then Exit;
  OldFg := GFg; OldBg := GBg;
  if HasFg then GFg := Fg and $F;
  if HasBg then GBg := Bg and $F;
  Force := False;
  if (GInitKind = INIT_CONSOLE) or not GXterm then
  begin
    // the Linux console and any terminal but xterm: 8 colours plus "bright" as bold
    if GFg <> OldFg then
    begin
      if ((GFg xor OldFg) and 8) <> 0 then
      begin
        Emit(GSgr0);
        if (GFg and 8) <> 0 then Emit(Cap(CAP_BOLD));
        Force := True;
      end;
      if Cap(CAP_SETAF) <> '' then Emit(TParm(Cap(CAP_SETAF), Map[GFg and 7]));
    end;
    if ((GBg <> OldBg) or Force) and (Cap(CAP_SETAB) <> '') then
      Emit(TParm(Cap(CAP_SETAB), Map[GBg and 7]));
  end
  else
  begin
    // xterm: 16 + 16 colours through SGR 30-37/90-97 and 40-47/100-107
    if GFg <> OldFg then
      if (GFg and 8) <> 0 then Emit(#27'[' + IntToStr(Map[GFg and 7] + 90) + 'm')
      else Emit(#27'[' + IntToStr(Map[GFg and 7] + 30) + 'm');
    if GBg <> OldBg then
      if (GBg and 8) <> 0 then Emit(#27'[' + IntToStr(Map[GBg and 7] + 100) + 'm')
      else Emit(#27'[' + IntToStr(Map[GBg and 7] + 40) + 'm');
  end;
end;

function TcLocate(Row, Col, Cursor: Integer; out NewRow, NewCol: Integer): Integer;
// io_locate.c
var
  X, Y: Integer;
begin
  NewRow := Row; NewCol := Col;
  Result := 0;
  if not GActive then Exit;
  X := GCurX; Y := GCurY;
  if (Row <= 0) or (Col <= 0) then TcGetXY(X, Y);
  if Col > 0 then X := Col;
  if Row > 0 then Y := Row;
  RecheckSize;
  if X <= GCols then GCurX := X else GCurX := GCols;
  if Y <= GRows then GCurY := Y else GCurY := GRows;
  EmitCup(Y - 1, X - 1);
  if Cursor = 0 then
  begin
    Emit(Cap(CAP_CIVIS));
    GVisible := False;
  end
  else if Cursor = 1 then
  begin
    Emit(Cap(CAP_CNORM));
    GVisible := True;
  end;
  NewRow := GCurY; NewCol := GCurX;
  Result := (X and $FF) or ((Y and $FF) shl 8);
  if GVisible then Result := Result or $10000;
end;

procedure TcClear(Mode, FirstRow, LastRow: Integer);
// io_cls.c: one line at a time, cursor to the start of each and clear to its end
var
  Start, Stop, i: Integer;
begin
  if (not GActive) or (Mode = 1) then Exit;
  RecheckSize;
  if (Mode = -1) or (Mode = 2) then
  begin
    Start := FirstRow; Stop := LastRow;
  end
  else
  begin
    Start := 1; Stop := GRows;
  end;
  if Start < 1 then Start := 1;
  if Start > GRows then Start := GRows;
  if Stop > GRows then Stop := GRows;
  for i := Start to Stop do
  begin
    EmitCup(i - 1, 0);
    Emit(Cap(CAP_EL));
  end;
  EmitCup(Start - 1, 0);
  GCurY := Start;
  GCurX := 1;
end;

procedure TcViewPrint(var First, Last: Integer);
var
  R, C: Integer;
begin
  if not GActive then Exit;
  RecheckSize;
  if (First <= 0) or (Last <= 0) then
  begin
    First := 1;
    Last := GRows;
  end;
  if Last < First then Last := First;
  GViewTop := First; GViewBot := Last;
  GScrollChanged := True;
  if Cap(CAP_CSR) <> '' then Emit(TParm(Cap(CAP_CSR), First - 1, Last - 1));
  TcLocate(First, 1, -1, R, C);
end;

procedure TcScreenZero;
begin
  if not GActive then Exit;
  RecheckSize;
  TcClear(0, 1, GRows);
  GViewTop := 1; GViewBot := GRows;
  if Cap(CAP_CSR) <> '' then Emit(TParm(Cap(CAP_CSR), 0, GRows - 1));
  EmitCup(0, 0);
  TcClear(0, 1, GRows);
  if Cap(CAP_CSR) <> '' then Emit(TParm(Cap(CAP_CSR), 0, GRows - 1));
  GScrollChanged := False;
end;

function TcPrintText(const S: string): string;
// fb_ConsolePrintBufferEx: NUL prints as a space; BS, FF, SO, SI and ESC - the CTRL_ALWAYS mask
// 0x0800D101 - print as U+F0xx in UTF-8 between "\e%G" and "\e%@" instead of being obeyed. The position
// moves as libfb counts it.
var
  i: Integer;
  c: Byte;
  NeedsMap: Boolean;
begin
  Result := S;
  if not GActive then Exit;
  NeedsMap := False;
  for i := 1 to Length(S) do
  begin
    c := Ord(S[i]);
    if (c = 0) or ((c < 32) and (((Cardinal($0800D101) shr c) and 1) <> 0)) then NeedsMap := True;
    Inc(GCurX);
    if (c = 10) or (GCurX >= GCols) then
    begin
      GCurX := 1;
      Inc(GCurY);
      if GCurY > GRows then GCurY := GRows;
    end;
  end;
  if not NeedsMap then Exit;
  Result := '';
  for i := 1 to Length(S) do
  begin
    c := Ord(S[i]);
    if c = 0 then c := 32;
    if (c < 32) and (((Cardinal($0800D101) shr c) and 1) <> 0) then
      Result := Result + #27'%G'#$EF#$80 + Chr(c or $80) + #27'%@'
    else
      Result := Result + Chr(c);
  end;
end;

{ === INPUT: fb_ConReadLine ================================================= }

procedure PrintRaw(const S: string);
// fb_PrintBufferEx on the console: the text as PRINT writes it
begin
  if S <> '' then Emit(TcPrintText(S));
end;

procedure DoAdjust(var X, Y: Integer; DX, DY, Cols: Integer);
// con_readline.c, as written
begin
  Dec(X); Dec(Y);
  Inc(X, DX);
  if X < 0 then
  begin
    X := -X + Cols;
    Dec(Y, X div Cols);
    X := Cols - (X mod Cols);
  end;
  Inc(Y, X div Cols);
  X := X mod Cols;
  Inc(Y, DY);
  Inc(X); Inc(Y);
end;

procedure DoMove(var X, Y: Integer; DX, DY, Cols, Rows: Integer);
var
  R, C: Integer;
begin
  DoAdjust(X, Y, DX, DY, Cols);
  if (Y = Rows + 1) and (X = 1) then
  begin
    TcLocate(Rows, Cols, -1, R, C);
    PrintRaw(#10);
  end
  else
    TcLocate(Y, X, -1, R, C);
end;

function TcReadLine: string;
// fb_ConReadLine(FALSE), statement by statement - the cursor dance included, because it is what the
// terminal sees: the cursor is hidden while the line is redrawn and shown while a key is awaited.
var
  Cols, Rows, CurX, CurY, K, Del, OldX, OldY, TX, TY, R, C: Integer;
  Pos0, Len: Integer;
  Visible: Boolean;
  Add, S: string;
begin
  Result := '';
  if not GActive then Exit;
  RecheckSize;
  Cols := GCols; Rows := GRows;
  Visible := (TcLocate(0, 0, -1, R, C) and $10000) <> 0;
  TcLocate(0, 0, 0, R, C);
  Pos0 := 0; Len := 0;
  TcLocate(0, 0, 1, R, C);   // the cursor is visible during INPUT
  repeat
    Del := 0;
    Add := '';
    TcGetXY(CurX, CurY);
    while not TcKeyHit do Sleep(25);
    S := TcInkey;
    if S = '' then
    begin
      K := 0;
      Continue;
    end;
    if Length(S) = 2 then K := (Ord(S[2]) shl 8) or 255 else K := Ord(S[1]);
    case K of
      8:
        if Pos0 <> 0 then
        begin
          DoMove(CurX, CurY, -1, 0, Cols, Rows);
          Dec(Pos0);
          Del := 1;
        end;
      9: Add := StringOfChar(' ', ((Pos0 + 8) div 8 * 8) - Pos0);
      27:
        begin
          DoMove(CurX, CurY, -Pos0, 0, Cols, Rows);
          Pos0 := 0;
          Del := Len;
        end;
      KEY_DEL:
        if Len <> Pos0 then Del := 1 else Emit(Cap(1));   // fb_Beep: "bl"
      KEY_LEFT:
        if Pos0 <> 0 then begin DoMove(CurX, CurY, -1, 0, Cols, Rows); Dec(Pos0); end;
      KEY_RIGHT:
        if Pos0 <> Len then begin DoMove(CurX, CurY, 1, 0, Cols, Rows); Inc(Pos0); end;
      KEY_HOME:
        begin DoMove(CurX, CurY, -Pos0, 0, Cols, Rows); Pos0 := 0; end;
      KEY_END:
        begin DoMove(CurX, CurY, Len - Pos0, 0, Cols, Rows); Pos0 := Len; end;
      KEY_UP:
        if Pos0 >= Cols then begin DoMove(CurX, CurY, -Cols, 0, Cols, Rows); Dec(Pos0, Cols); end;
      KEY_DOWN:
        if Pos0 + Cols <= Len then begin DoMove(CurX, CurY, Cols, 0, Cols, Rows); Inc(Pos0, Cols); end;
    else
      if (K >= 32) and (K <= 255) then Add := Chr(K);
    end;
    if (Del <> 0) or (Add <> '') then
      TcLocate(0, 0, 0, R, C);   // the cursor off while the line is redrawn
    if Del <> 0 then
    begin
      Delete(Result, Pos0 + 1, Del);
      Dec(Len, Del);
      PrintRaw(Copy(Result, Pos0 + 1, Len - Pos0));
      PrintRaw(StringOfChar(' ', Del));
      TcLocate(CurY, CurX, -1, R, C);
    end;
    if Add <> '' then
    begin
      OldX := CurX; OldY := CurY;
      Insert(Add, Result, Pos0 + 1);
      Inc(Len, Length(Add));
      PrintRaw(Copy(Result, Pos0 + 1, Len - Pos0));
      TcGetXY(CurX, CurY);
      if Pos0 = Len - Length(Add) then
      begin
        CurX := OldX; CurY := OldY;
        DoMove(CurX, CurY, Length(Add), 0, Cols, Rows);
      end
      else
      begin
        TX := OldX; TY := OldY;
        DoAdjust(TX, TY, Len - Pos0, 0, Cols);
        if (TY > Rows + 1) or ((TY = Rows + 1) and (TX > 1)) then
          DoMove(CurX, CurY, -(Len - Pos0 - Length(Add)), 0, Cols, Rows)
        else
        begin
          CurX := OldX; CurY := OldY;
          DoMove(CurX, CurY, Length(Add), 0, Cols, Rows);
        end;
      end;
      Inc(Pos0, Length(Add));
    end;
    TcLocate(0, 0, 1, R, C);
  until (K = 13) or (K = 10);
  // the cursor to the end of the line, and its visibility back as it was
  TcGetXY(CurX, CurY);
  DoMove(CurX, CurY, Len - Pos0, 0, Cols, Rows);
  if Visible then TcLocate(0, 0, 1, R, C) else TcLocate(0, 0, 0, R, C);
end;

procedure TcNoNewlineOnce;
begin
  GNoNewline := True;
end;

function TcTakeNoNewline: Boolean;
begin
  Result := GNoNewline;
  GNoNewline := False;
end;

{ === start, stop, signals ================================================== }

procedure ApplyRaw;
var
  T: Termios;
begin
  if GSavedOut then
  begin
    T := GOldOut;
    T.c_oflag := T.c_oflag or OPOST;
    TCSetAttr(1, TCSANOW, T);
  end;
  if GSavedIn then
  begin
    T := GOldIn;
    T.c_iflag := (T.c_iflag or BRKINT) and not (IXOFF or IXON or IGNBRK);
    T.c_lflag := T.c_lflag and not (ICANON or ECHO);
    T.c_cc[VMIN] := 1;
    T.c_cc[VTIME] := 0;
    TCSetAttr(GTtyFd, TCSANOW, T);
  end;
  FpFcntl(GTtyFd, F_SETFL, GOldFlags or O_NONBLOCK);
end;

procedure RestoreTerm;
// async-signal-safe: system calls only
begin
  RawWrite(GExitSeq);
  if GSavedOut then TCSetAttr(1, TCSANOW, GOldOut);
  if GTtyFd >= 0 then FpFcntl(GTtyFd, F_SETFL, GOldFlags);
  if GSavedIn then TCSetAttr(GTtyFd, TCSANOW, GOldIn);
end;

procedure FatalSignal(Sig: cint); cdecl;
// fbc's signal_handler: put the terminal back, then let the signal do what it would have done
begin
  if GActive and not GSuspended then RestoreTerm;
  GActive := False;
  FpSignal(Sig, SignalHandler(SIG_DFL));
  FpKill(FpGetpid, Sig);
end;

procedure StopSignal(Sig: cint); cdecl;
// Ctrl+Z: the shell gets a usable terminal while the program is stopped (fbc leaves it raw)
begin
  if GActive and not GSuspended then RestoreTerm;
  FpSignal(SIGTSTP, SignalHandler(SIG_DFL));
  FpKill(FpGetpid, SIGTSTP);
end;

procedure ContSignal(Sig: cint); cdecl;
begin
  FpSignal(SIGTSTP, SignalHandler(@StopSignal));
  if GActive and not GSuspended then
  begin
    ApplyRaw;
    RawWrite(StripPadding(Cap(CAP_SMKX)));
  end;
end;

function SignalIgnored(Sig: cint): Boolean;
var
  A: SigActionRec;
begin
  FillChar(A, SizeOf(A), 0);
  Result := (FpSigAction(Sig, nil, @A) = 0) and (PtrUInt(A.sa_handler) = PtrUInt(SIG_IGN));
end;

procedure ExitStop;
begin
  TcStop;
end;

function TcStart: Boolean;
const
  Sigs: array[0..4] of cint = (SIGABRT, SIGTERM, SIGINT, SIGQUIT, SIGHUP);
var
  Term: string;
  i: Integer;
begin
  Result := GActive;
  if GStarted then Exit;
  GStarted := True;
  if GetEnvironmentVariable('SB_TERMCONSOLE') = '0' then Exit;
  GFbConsole := True;
  if not FbConsoleInited then Exit;
  Term := GetEnvironmentVariable('TERM');
  if not ReadTerminfoStrings(Term) then Exit;
  if (Term = 'console') or (Copy(Term, 1, 5) = 'linux') then GInitKind := INIT_CONSOLE
  else GInitKind := INIT_X11;
  GXterm := Copy(Term, 1, 5) = 'xterm';
  GTtyFd := FpOpen('/dev/tty', O_RDWR);
  if GTtyFd < 0 then Exit;
  GSavedOut := TCGetAttr(1, GOldOut) = 0;
  GSavedIn := TCGetAttr(GTtyFd, GOldIn) = 0;
  if not (GSavedOut and GSavedIn) then
  begin
    FpClose(GTtyFd);
    GTtyFd := -1;
    Exit;
  end;
  GOldFlags := FpFcntl(GTtyFd, F_GETFL);
  ApplyRaw;
  // what the exit writes, in libfb's order: the character set (Linux console), colours, cursor, keypad
  GExitSeq := '';
  if GInitKind = INIT_CONSOLE then GExitSeq := #27'(B';
  GSgr0 := TrimSgr0;
  GExitSeq := StripPadding(GExitSeq + GSgr0 + Cap(CAP_CNORM) + Cap(CAP_RMKX));
  GActive := True;
  if GInitKind = INIT_CONSOLE then Emit(#27'(U');
  Emit(Cap(CAP_SMKX));
  RecheckSize;
  GFg := 7; GBg := 0;
  GCurX := 1; GCurY := 1;
  GVisible := True;
  if not GSigInstalled then
  begin
    // a signal the shell started us IGNORING (a background job, nohup) stays ignored. ⚠️ Asked with
    // FpSigAction: FPC 3.2.2's FpSignal answers 0 instead of the handler it replaced (measured).
    for i := Low(Sigs) to High(Sigs) do
      if not SignalIgnored(Sigs[i]) then FpSignal(Sigs[i], SignalHandler(@FatalSignal));
    if not SignalIgnored(SIGTSTP) then FpSignal(SIGTSTP, SignalHandler(@StopSignal));
    FpSignal(SIGCONT, SignalHandler(@ContSignal));
    GSigInstalled := True;
  end;
  if not GExitRegistered then
  begin
    AddExitProc(@ExitStop);
    GExitRegistered := True;
  end;
  Result := True;
end;

procedure TcStop;
begin
  if not GActive then Exit;
  // fb_hExitConsole: a scroll region still set is put back to the whole screen, which is then cleared
  if GScrollChanged then
  begin
    RecheckSize;
    if (GViewTop <> 1) or (GViewBot <> GRows) then
    begin
      if Cap(CAP_CSR) <> '' then Emit(TParm(Cap(CAP_CSR), 0, GRows - 1));
      Emit(Cap(CAP_CLEAR));
      Emit(Cap(CAP_HOME));
    end;
    GScrollChanged := False;
  end;
  TerminalOutFlush;
  if not GSuspended then RestoreTerm;
  GActive := False;
  if GTtyFd >= 0 then
  begin
    FpClose(GTtyFd);
    GTtyFd := -1;
  end;
end;

function TcActive: Boolean;
begin
  Result := GActive;
end;

function TcFbConsole: Boolean;
begin
  Result := GFbConsole;
end;

procedure TcSuspend;
begin
  if (not GActive) or GSuspended then Exit;
  TerminalOutFlush;
  RestoreTerm;
  GSuspended := True;
end;

procedure TcResume;
begin
  if (not GActive) or not GSuspended then Exit;
  GSuspended := False;
  ApplyRaw;
  Emit(Cap(CAP_SMKX));
end;

{$ENDIF}

end.
