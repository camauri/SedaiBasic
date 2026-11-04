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
{ ============================================================================
  ConfigFlags.inc

  Compile-time configuration flags for the SedaiBasic compiler.

  These flags enable/disable optional features and external library support.
  ============================================================================ }

{ ============================================================================
  AUDIO SUPPORT
  ============================================================================ }

{.$DEFINE WITH_SEDAI_AUDIO}            // Enable Sedai Audio Foundation support
                                        // Provides SID emulation and audio synthesis
                                        // Requires SAF library paths in compiler search path

