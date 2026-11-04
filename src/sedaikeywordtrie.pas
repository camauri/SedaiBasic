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
unit SedaiKeywordTrie;

{$mode ObjFPC}{$H+}
{$interfaces CORBA}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, fgl, contnrs,
  SedaiLexerTypes, SedaiLexerToken;

type
  { TKeywordTrieNode - Struttura Trie per ricerca prefix ottimizzata }
  TKeywordTrieNode = class
  private
    FChar: Char;
    FChildren: TFPHashObjectList;
    FKeywordInfo: TKeywordInfo;
    FIsEndOfWord: Boolean;
    FDepth: Integer;

  public
    constructor Create(AChar: Char = #0);
    destructor Destroy; override;

    function GetChild(Ch: Char): TKeywordTrieNode;
    function AddChild(Ch: Char): TKeywordTrieNode;
    function HasChildren: Boolean;
    function GetChildrenCount: Integer;

    property Char: Char read FChar;
    property Children: TFPHashObjectList read FChildren;
    property KeywordInfo: TKeywordInfo read FKeywordInfo write FKeywordInfo;
    property IsEndOfWord: Boolean read FIsEndOfWord write FIsEndOfWord;
    property Depth: Integer read FDepth write FDepth;
  end;

implementation

{ TKeywordTrieNode }

constructor TKeywordTrieNode.Create(AChar: Char);
begin
  inherited Create;
  FChar := AChar;
  FChildren := TFPHashObjectList.Create(True);
  FKeywordInfo := nil;
  FIsEndOfWord := False;
  FDepth := 0;
end;

destructor TKeywordTrieNode.Destroy;
begin
  FChildren.Free;
  inherited Destroy;
end;

function TKeywordTrieNode.GetChild(Ch: Char): TKeywordTrieNode;
begin
  Result := TKeywordTrieNode(FChildren.Find(Ch));
end;

function TKeywordTrieNode.AddChild(Ch: Char): TKeywordTrieNode;
begin
  // Defensive: log and protect trie node creation to help debug heap corruption
  try
    Result := GetChild(Ch);
    if not Assigned(Result) then
    begin
      // Debug trace: show depth and character being added
      //WriteLn(Format('TRIE: AddChild depth=%d char=%s ord=%d', [FDepth, Ch, Ord(Ch)]));
      Result := TKeywordTrieNode.Create(Ch);
      Result.FDepth := FDepth + 1;
      try
        FChildren.Add(Ch, Result);
      except
        on E: Exception do
        begin
          WriteLn(Format('ERROR: Exception while adding child to FChildren at depth %d for char ord=%d: %s',
            [FDepth, Ord(Ch), E.Message]));
          // Free the node we created to avoid leaks and re-raise
          Result.Free;
          raise;
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      WriteLn(Format('ERROR: Exception in TKeywordTrieNode.AddChild depth=%d char=%s ord=%d: %s',
        [FDepth, Ch, Ord(Ch), E.ClassName + ': ' + E.Message]));
      raise;
    end;
  end;
end;

function TKeywordTrieNode.HasChildren: Boolean;
begin
  Result := FChildren.Count > 0;
end;

function TKeywordTrieNode.GetChildrenCount: Integer;
begin
  Result := FChildren.Count;
end;

end.
