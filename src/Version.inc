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
  Version.inc

  Version and release information for SedaiBasic.

  The version is not written here: the build passes it in the environment variable SEDAI_VERSION.
  The release workflow sets it from the tag (v2.0.0-alpha.3 -> 2.0.0-alpha.3); build.sh and build.ps1
  set it from `git describe` when it is not set. The date is the day of the build. A compiler run by
  hand without the variable warns ("Include environment ... not found") and the banner says 'dev'.
  ============================================================================ }

const
  SEDAIBASIC_BUILD_VERSION = {$I %SEDAI_VERSION%};
  SEDAIBASIC_RELEASE_DATE = {$I %DATE%};
  SEDAIBASIC_COPYRIGHT = 'Copyright (c) 2025 Maurizio Cammalleri';
  SEDAIBASIC_LICENSE = 'Released under GNU GPL v3 with the GCC Runtime Library Exception 3.1';

function SEDAIBASIC_VERSION: string;
begin
  if SEDAIBASIC_BUILD_VERSION = '' then
    Result := 'dev'
  else if (SEDAIBASIC_BUILD_VERSION[1] = 'v') then
    Result := Copy(SEDAIBASIC_BUILD_VERSION, 2, MaxInt)
  else
    Result := SEDAIBASIC_BUILD_VERSION;
end;
