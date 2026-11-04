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
unit SedaiMemoryConfig;

{$mode ObjFPC}{$H+}
{$interfaces CORBA}
{$codepage UTF8}

interface

const
  // ===== MEMORY DETECTION LIMITS =====
  MEMORY_MIN_MB = 64;              // Minimum detectable memory: 64MB
  MEMORY_MAX_MB = 2048;            // Maximum memory to consider: 2GB
  MEMORY_USAGE_PERCENT = 0.25;     // Use 25% of available memory
  MEMORY_DEFAULT_MB = 512;         // Fallback if detection fails

  // ===== TOKEN POOL LIMITS =====
  POOL_MIN_TOKENS = 1000;          // Minimum pool size: 1K tokens
  POOL_MAX_TOKENS = 100000;        // Maximum pool size: 100K tokens
  POOL_OVERHEAD_BYTES = 64;        // Estimated object overhead per token

  // ===== LINUX MEMORY DETECTION =====
  LINUX_DEFAULT_MEMINFO_KB = 524288;  // 512MB in KB (fallback value)

implementation

end.
