unit PE.Utils;

interface

uses
  System.Classes,
  PE.Common;

function StreamRead(AStream: TStream; var Buf; Count: longint): boolean; inline;
function StreamPeek(AStream: TStream; var Buf; Count: longint): boolean; inline;
function StreamWrite(AStream: TStream; const Buf; Count: longint): boolean; inline;

// Read 0-terminated 1-byte string.
function StreamReadStringA(AStream: TStream; var S: RawByteString): boolean;

function StreamSeek(AStream: TStream; Offset: TFileOffset): boolean; inline;

// Try to seek Offset and insert padding if Offset < stream Size.
procedure StreamSeekWithPadding(AStream: TStream; Offset: TFileOffset);

function Min(A, B: uint64): uint64; inline;
function Max(A, B: uint64): uint64; inline;

function AlignUp(Value: uint64; Align: uint32): uint64;

function IsStringASCII(const S: AnsiString): boolean;

implementation

{ Stream }

function StreamRead(AStream: TStream; var Buf; Count: longint): boolean;
begin
  Result := AStream.Read(Buf, Count) = Count;
end;

function StreamPeek(AStream: TStream; var Buf; Count: longint): boolean; inline;
var
  Read: integer;
begin
  Read := AStream.Read(Buf, Count);
  AStream.Seek(-Read, soFromCurrent);
  Result := Read = Count;
end;

function StreamWrite(AStream: TStream; const Buf; Count: longint): boolean;
begin
  Result := AStream.Write(Buf, Count) = Count;
end;

function StreamReadStringA(AStream: TStream; var S: RawByteString): boolean;
var
  c: AnsiChar;
begin
  S := '';
  while True do
    if AStream.Read(c, 1) <> 1 then
      break
    else if (c = #0) then
      exit(True)
    else
      S := S + c;
  exit(False);
end;

function StreamSeek(AStream: TStream; Offset: TFileOffset): boolean;
begin
  Result := AStream.Seek(Offset, soFromBeginning) = Offset;
end;

procedure StreamSeekWithPadding(AStream: TStream; Offset: TFileOffset);
var
  d: integer;
  p: pointer;
begin
  if Offset <= AStream.Size then
  begin
    AStream.Seek(Offset, soFromBeginning);
    exit;
  end;
  // Insert padding.
  AStream.Seek(AStream.Size, soFromBeginning);
  d := Offset - AStream.Size; // delta
  p := AllocMem(d);
  try
    AStream.Write(p^, d);
  finally
    FreeMem(p);
  end;
end;

{ Min / Max }

function Min(A, B: uint64): uint64;
begin
  if A < B then
    exit(A)
  else
    exit(B);
end;

function Max(A, B: uint64): uint64; inline;
begin
  if A > B then
    exit(A)
  else
    exit(B);
end;

{ AlignUp }

function AlignUp(Value: uint64; Align: uint32): uint64;
var
  d, m: uint32;
begin
  d := Value div Align;
  m := Value mod Align;
  if m = 0 then
    Result := Value
  else
    Result := (d + 1) * Align;
end;

function IsStringASCII(const S: AnsiString): boolean;
var
  A: AnsiChar;
begin
  for A in S do
    if not(byte(A) in [32 .. 126]) then
      exit(False);
  exit(True);
end;

end.
