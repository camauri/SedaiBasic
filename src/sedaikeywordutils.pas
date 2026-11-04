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
unit SedaiKeywordUtils;

{$mode ObjFPC}{$H+}
{$interfaces CORBA}
{$codepage UTF8}

interface

uses
  SysUtils,
  SedaiLexerTypes, SedaiLexerToken, SedaiKeywordBase, SedaiKeywordTypes;

// === FACTORY FUNCTIONS ===
function CreateDefaultSearchOptions: TKeywordSearchOptions;
function CreatePrefixSearchOptions: TKeywordSearchOptions;
function CreateExactSearchOptions: TKeywordSearchOptions;

// Compare functions for sorting
function CompareKeywordsByName(Info1, Info2: TKeywordInfo): Integer;
function CompareKeywordsByType(Info1, Info2: TKeywordInfo): Integer;
function CompareKeywordsByCategory(Info1, Info2: TKeywordInfo): Integer;
function CompareKeywordsByLength(Info1, Info2: TKeywordInfo): Integer;

implementation

var
  FilterTargetType: TTokenType;
  FilterTargetCategory: string;

// === UTILITY FUNCTIONS ===

function CreateDefaultSearchOptions: TKeywordSearchOptions;
begin
  Result.CaseSensitive := False;
  Result.AllowPartialMatch := True;
  Result.RequireWordBoundary := False;
  Result.MaxResults := 0; // No limit
  Result.IncludeDeprecated := False;
  Result.CategoryFilter := '';
  Result.MinConfidence := 0.0;
end;

function CreatePrefixSearchOptions: TKeywordSearchOptions;
begin
  Result := CreateDefaultSearchOptions;
  Result.AllowPartialMatch := True;
  Result.MinConfidence := 0.1;
end;

function CreateExactSearchOptions: TKeywordSearchOptions;
begin
  Result := CreateDefaultSearchOptions;
  Result.AllowPartialMatch := False;
  Result.MinConfidence := 1.0;
end;

// === COMPARE FUNCTIONS ===

function CompareKeywordsByName(Info1, Info2: TKeywordInfo): Integer;
begin
  Result := CompareStr(Info1.Keyword, Info2.Keyword);
end;

function CompareKeywordsByType(Info1, Info2: TKeywordInfo): Integer;
begin
  Result := Ord(Info1.TokenType) - Ord(Info2.TokenType);
end;

function CompareKeywordsByCategory(Info1, Info2: TKeywordInfo): Integer;
begin
  Result := CompareStr(Info1.Category, Info2.Category);
end;

function CompareKeywordsByLength(Info1, Info2: TKeywordInfo): Integer;
begin
  Result := System.Length(Info1.Keyword) - System.Length(Info2.Keyword);
end;

end.
