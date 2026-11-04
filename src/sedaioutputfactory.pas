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
unit SedaiOutputFactory;

{$mode ObjFPC}{$H+}
{$interfaces CORBA}
{$codepage UTF8}

interface

uses
  Classes, SysUtils,
  SedaiOutputInterface,
  SedaiSDL2Input,
  SedaiSDL2GraphicsOutput;

type
  { Factory per creare devices separati - CORRETTO }
  { TOutputDeviceFactory }
  TOutputDeviceFactory = class
  private
    class var FCurrentSDL2Device: TSDL2GraphicsOutputDevice;
    class var FLastSDL2Input: TSDL2InputDevice; // Riferimento per linking
  public
    class function CreateOutputDevice(OutputType: TOutputType): IOutputDevice;
    class function CreateInputDevice(OutputType: TOutputType): IInputDevice;
    class function GetCurrentSDL2Device: TSDL2GraphicsOutputDevice;
    class function GetSDL2InputDevice: TSDL2InputDevice;
  end;

implementation

class function TOutputDeviceFactory.CreateOutputDevice(OutputType: TOutputType): IOutputDevice;
begin
  case OutputType of
    otSDL2:
      begin
        // Create the graphics device that auto-detects capabilities
        FCurrentSDL2Device := TSDL2GraphicsOutputDevice.Create;
        Result := FCurrentSDL2Device;
      end;
    else
      raise Exception.CreateFmt('Only SDL2 output is supported (requested: %d)', [Ord(OutputType)]);
  end;
end;

class function TOutputDeviceFactory.CreateInputDevice(OutputType: TOutputType): IInputDevice;
begin
  case OutputType of
    otSDL2:
      begin
        FLastSDL2Input := TSDL2InputDevice.Create;
        Result := FLastSDL2Input;
      end;
    else
      raise Exception.CreateFmt('Only SDL2 input is supported (requested: %d)', [Ord(OutputType)]);
  end;
end;

class function TOutputDeviceFactory.GetCurrentSDL2Device: TSDL2GraphicsOutputDevice;
begin
  Result := FCurrentSDL2Device;
end;

class function TOutputDeviceFactory.GetSDL2InputDevice: TSDL2InputDevice;
begin
  Result := FLastSDL2Input;
end;

end.
