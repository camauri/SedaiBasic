unit SedaiLangMode;

// =====================================================================================================
// THE LANGUAGE a MODERN program is compiled as (owner, 23 Oct 2026, decisions D3 and D4).
//
//   modern  the default, with no -lang: FreeBASIC plus SedaiBasic's own extensions (the OOP fbc does not
//           have, OPTION DIGITS, REGEXCOUNT, BigInt, ...). This is what sb is.
//   fb      `-lang fb` or `#lang "fb"`: perfect adherence to fbc. Every extension is refused the way fbc
//           refuses it, so a program that compiles here compiles with fbc too.
//   fblite  `-lang fblite` or `#lang "fblite"`: fbc's fblite dialect, with its own semantics.
//
// ⭐ THE SOURCE WINS OVER THE COMMAND LINE, as with fbc: `-lang` sets the default and a `#lang` at the top
// of the file changes it (fbc's -forcelang, which inverts that, is not implemented).
//
// ⛔ `-lang qb` and `-lang deprecated` are refused aloud on the command line - SedaiBasic does not implement
// them, and accepting the flag would be the option that did nothing and said nothing. A `#lang "qb"` in a
// source keeps what it did before this unit existed (QB PRINT spacing, the permissions fbc's message names).
//
// ⭐ FOUR values on the command line (owner, 24 Oct 2026): classic · modern · fb · fblite. Without -lang the
// language is MODERN, and nothing is left undefined:
//   - `-lang classic` is Commodore BASIC v7. sbv runs it, sbc compiles it, sb and sbw refuse it by name.
//   - a source with LINE NUMBERS and no -lang is CLASSIC, so sb refuses it (run it with sbv) and sbc refuses
//     it too (compile it with -lang classic). Line numbers are LABELS only under fblite.
//   - `-lang modern` is the default said aloud.
//
// The language travels in the .basc header (SedaiBytecodeSerializer, BASC_FLAG_LANG_MASK): one bytecode
// format, one extension, and the loader reads which language the file was compiled as.
// LANG_DIAG=1 prints the resolved language and where it came from.
// =====================================================================================================

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TLangMode = (lmModern, lmFb, lmFbLite);

var
  GLangFlag: string = '';             // what followed "-lang" on the command line ('' = not given)
  GLangMode: TLangMode = lmModern;    // the language of the program being compiled, once resolved

{ 'modern' / 'fb' / 'fblite' }
function LangModeName(M: TLangMode): string;

{ True when the program must adhere to fbc exactly: every SedaiBasic extension is refused. }
function LangStrictFb: Boolean; inline;

{ Validate the value of `-lang` (case-insensitive). False, with AError set, for anything that is not classic,
  modern, fb or fblite. Which of them a front end accepts is that front end's to say (LangFlagIsClassic). }
function CheckLangFlag(const AValue: string; out AError: string): Boolean;

{ True when `-lang` asked for CLASSIC (Commodore BASIC v7). }
function LangFlagIsClassic: Boolean;

{ The language a compiled program carries: 'classic' when AModern is False, else the name of ASourceLang (the
  ordinal of TLangMode, as the .basc header stores it). }
function ProgramLangName(AModern: Boolean; ASourceLang: Byte): string;

{ The language of a source about to be compiled. ADeclared is what the source's own #lang / '$lang says,
  lower case ('' when it says nothing; see SedaiPreprocessor.DetectSourceLang). The source wins; then the
  command line; then MODERN. }
function ResolveLangMode(const AFlagValue, ADeclared: string): TLangMode;

implementation

function LangModeName(M: TLangMode): string;
begin
  case M of
    lmFb:     Result := 'fb';
    lmFbLite: Result := 'fblite';
  else
    Result := 'modern';
  end;
end;

function LangStrictFb: Boolean; inline;
begin
  Result := GLangMode = lmFb;
end;

function CheckLangFlag(const AValue: string; out AError: string): Boolean;
var
  V: string;
begin
  AError := '';
  V := LowerCase(AValue);
  Result := (V = 'classic') or (V = 'modern') or (V = 'fb') or (V = 'fblite');
  if Result then Exit;
  if (V = 'qb') or (V = 'deprecated') then
    AError := '-lang ' + V + ' is not supported: the values are classic, modern, fb and fblite ' +
              '(without -lang, MODERN: FreeBASIC with SedaiBasic''s extensions)'
  else
    AError := 'unknown -lang value "' + AValue + '": the values are classic, modern, fb and fblite';
end;

function ProgramLangName(AModern: Boolean; ASourceLang: Byte): string;
begin
  if not AModern then Result := 'classic'
  else if ASourceLang <= Ord(High(TLangMode)) then Result := LangModeName(TLangMode(ASourceLang))
  else Result := '?';
end;

function LangFlagIsClassic: Boolean;
begin
  Result := LowerCase(GLangFlag) = 'classic';
end;

function ResolveLangMode(const AFlagValue, ADeclared: string): TLangMode;
var
  Src, Why: string;
begin
  Src := LowerCase(ADeclared);
  if Src = '' then Src := LowerCase(AFlagValue);
  if Src = 'fb' then Result := lmFb
  else if Src = 'fblite' then Result := lmFbLite
  else Result := lmModern;
  if GetEnvironmentVariable('LANG_DIAG') = '1' then
  begin
    if ADeclared <> '' then Why := 'the source''s #lang'
    else if AFlagValue <> '' then Why := 'the command line'
    else Why := 'the default';
    WriteLn(ErrOutput, 'LANG_DIAG: ', LangModeName(Result), ' (from ', Why, ')');
  end;
end;

end.
