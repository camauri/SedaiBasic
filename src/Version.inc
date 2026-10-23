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
  SEDAIBASIC_LICENSE = 'Released under GNU GPL v3';

function SEDAIBASIC_VERSION: string;
begin
  if SEDAIBASIC_BUILD_VERSION = '' then
    Result := 'dev'
  else if (SEDAIBASIC_BUILD_VERSION[1] = 'v') then
    Result := Copy(SEDAIBASIC_BUILD_VERSION, 2, MaxInt)
  else
    Result := SEDAIBASIC_BUILD_VERSION;
end;
