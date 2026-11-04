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
unit SedaiArenaAllocator;

{$mode objfpc}{$H+}
{$interfaces CORBA}
{$codepage UTF8}

interface

uses
  SysUtils;

type
  // SESSION 14.5: Fast bump-pointer allocator for array temporaries
  // Eliminates heap manager overhead for arrays in loop scope
  TArenaAllocator = class
  private
    FBuffer: Pointer;
    FBufferSize: NativeUInt;
    FOffset: NativeUInt;
  public
    constructor Create(BufferSize: NativeUInt);
    destructor Destroy; override;

    // Allocate memory from arena (fast bump-pointer allocation)
    function Allocate(Size: NativeUInt): Pointer; inline;

    // Reset arena to reuse memory (called after program execution)
    procedure Reset; inline;

    // Check if allocation would fit
    function CanAllocate(Size: NativeUInt): Boolean; inline;

    property BufferSize: NativeUInt read FBufferSize;
    property UsedSize: NativeUInt read FOffset;
  end;

implementation

constructor TArenaAllocator.Create(BufferSize: NativeUInt);
begin
  inherited Create;
  FBufferSize := BufferSize;
  FBuffer := GetMem(BufferSize);
  FOffset := 0;
end;

destructor TArenaAllocator.Destroy;
begin
  if Assigned(FBuffer) then
    FreeMem(FBuffer);
  inherited Destroy;
end;

function TArenaAllocator.Allocate(Size: NativeUInt): Pointer; inline;
begin
  // Align to 16 bytes for AVX2 compatibility
  Size := (Size + 15) and not NativeUInt(15);

  if FOffset + Size > FBufferSize then
  begin
    // Arena full - return nil (caller must fallback to heap)
    Result := nil;
    Exit;
  end;

  // Bump-pointer allocation (extremely fast!)
  Result := Pointer(NativeUInt(FBuffer) + FOffset);
  Inc(FOffset, Size);
end;

procedure TArenaAllocator.Reset; inline;
begin
  // Reset offset to reuse entire buffer
  FOffset := 0;
end;

function TArenaAllocator.CanAllocate(Size: NativeUInt): Boolean; inline;
begin
  Size := (Size + 15) and not NativeUInt(15);
  Result := (FOffset + Size) <= FBufferSize;
end;

end.
