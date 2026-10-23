{*
 * SedaiBasic - A BASIC interpreter with bytecode VM
 * Copyright (C) 2025 Maurizio Cammalleri
 *
 * This program is dual-licensed:
 *
 * 1) For open source use: GNU General Public License version 3 (GPL-3.0-only)
 *    You may redistribute and/or modify it under the terms of the GNU GPL v3
 *    as published by the Free Software Foundation.
 *    See <https://www.gnu.org/licenses/gpl-3.0.html>
 *
 * 2) For commercial/proprietary use: A separate commercial license is required.
 *    Contact: maurizio.cammalleri@gmail.com for licensing inquiries.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * SPDX-License-Identifier: GPL-3.0-only OR Commercial
 *}
program SedaiBasicVM;

{$mode objfpc}{$H+}
{$interfaces CORBA}
{$codepage UTF8}

// Include shared optimization flags
{$I OptimizationFlags.inc}
// JIT feature flags (hot-loop profiling opt-in)
{$I JitFlags.inc}
// Include debug flags (compile-time control of debug code)
{$I DebugFlags.inc}
// Include profiler flags
{$I ProfilerFlags.inc}

uses
  // M5.2 threading: on Unix the cthreads unit MUST be first so BeginThread uses pthreads.
  {$IFDEF UNIX}cthreads,{$ENDIF}
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  Classes, SysUtils, Variants, TypInfo, Math,
  // Lexer/Parser
  SedaiLexerFSM, SedaiLexerTypes, SedaiLexerToken, SedaiTokenList,
  SedaiParserTypes, SedaiAST, SedaiParserContext, SedaiParserResults,
  SedaiPackratParser, SedaiDateTimeUtils,
  // Bytecode VM
  // -i / -p: dove stanno gli header e le librerie (SedaiConfig e' la loro fonte)
  SedaiConfig, SedaiFFI,
  SedaiMemoryMode,   // --memory=fb|strict: the pointer model a program is compiled for
  SedaiLangMode,     // -lang fb|fblite: the language a MODERN program is compiled as (D3, D4)
  SedaiSSATypes, SedaiSSA,
  SedaiBytecodeTypes, SedaiBytecodeCompiler, SedaiBytecodeVM,
  SedaiBytecodeDisassembler, SedaiOpcodeTable, SedaiJit, SedaiAot,
  // Headless file I/O handler (OPEN/PRINT#/INPUT#/EOF/FREEFILE...) for the CLI VM
  SedaiFileIO,
  // FreeBASIC runtime error codes and the wording fbc's runtime uses when a program aborts
  SedaiExecutorErrors,
  // Register Allocation
  SedaiRegAlloc,
  // Peephole and Superinstructions
  SedaiPeephole, SedaiSuperinstructions,
  // NOP Compaction (removes NOPs after superinstruction fusion)
  SedaiNopCompaction,
  // Register Compaction
  SedaiRegisterCompaction,
  // Debug runtime flags
  SedaiDebug,
  // Profiler
  {$IFDEF ENABLE_PROFILER}SedaiProfiler,{$ENDIF}
  // Executor Context
  SedaiExecutorContext, SedaiExecutorTypes, SedaiOutputInterface,
  // I/O Manager
  SedaiIOManager, SedaiTerminalIO, SedaiConsoleState,
  SedaiTermConsole,   // the console on a terminal, as libfb has it (DIVERGENZE 415): started only here, never by sbv
  // Optional SDL2 window presenter for `sb --window` (WITH_WINDOW build only; no SDL2 dependency otherwise)
  {$IFDEF WITH_WINDOW}SedaiGraphicsBackend, SedaiWindowPresenter,{$ENDIF}
  // Runner and Serializer (for .basc support)
  SedaiRunner, SedaiBytecodeSerializer, SedaiPreprocessor,
  // Installs GPPTypeSizeHook: "#assert sizeof( T )" on a USER TYPE is answered by the compiler's
  // own layout rule instead of being left unmade. Linked for its initialization, not called.
  SedaiTypeSizeProbe,
  // A program that IS an executable: sb + .basc + trailer (DIVERGENZE 573, job/markdown/ESEGUIBILE-FUSO.md)
  SedaiFused;

// Include version information (must be after uses, contains const declarations)
{$I Version.inc}

// The file runner: options, compilation, the three engines. Shared with sbv --headless.
{$I SbCli.inc}

begin
  GCliClassic := False;   // sb runs MODERN programs only (owner, 23 Oct 2026)
  SbCliMain;
end.
