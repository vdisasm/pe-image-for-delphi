unit PE.Utils;

interface

// When writing padding use PADDINGX string instead of zeros.
{$DEFINE WRITE_PADDING_STRING}


uses
  System.Classes,
  PE.Common;

function StreamRead(AStream: TStream; var Buf; Count: longint): boolean; inline;
function StreamPeek(AStream: TStream; var Buf; Count: longint): boolean; inline;
function StreamWrite(AStream: TStream; const Buf; Count: longint): boolean; inline;

// Read 0-terminated 1-byte string.
function StreamReadStringA(AStream: TStream; var S: RawByteString): boolean;

// Read 0-terminated 2-byte string
function StreamReadStringW(AStream: TStream; var S: UnicodeString): boolean;

// Write Count of zero bytes to stream.
procedure WritePadding(AStream: TStream; Count: uint32);

function StreamSeek(AStream: TStream; Offset: TFileOffset): boolean; inline;
function StreamSkip(AStream: TStream; Count: integer = 1): boolean; inline;

// Seek from current position to keep alignment.
function StreamSeekAlign(AStream: TStream; Align: integer): boolean; inline;

// Try to seek Offset and insert padding if Offset < stream Size.
procedure StreamSeekWithPadding(AStream: TStream; Offset: TFileOffset);

function Min(A, B: uint64): uint64; inline;
function Max(A, B: uint64): uint64; inline;

function AlignUp(Value: uint64; Align: uint32): uint64; inline;
function AlignDown(Value: uint64; Align: uint32): uint64; inline;

function IsStringASCII(const S: AnsiString): boolean;

function CompareRVA(A, B: TRVA): integer; inline;

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
    if AStream.Read(c, SizeOf(c)) <> SizeOf(c) then
      break
    else if (c = #0) then
      exit(True)
    else
      S := S + c;
  exit(False);
end;

function StreamReadStringW(AStream: TStream; var S: UnicodeString): boolean;
var
  c: WideChar;
begin
  S := '';
  while True do
    if AStream.Read(c, SizeOf(c)) <> SizeOf(c) then
      break
    else if (c = #0) then
      exit(True)
    else
      S := S + c;
  exit(False);
end;

procedure WritePadding(AStream: TStream; Count: uint32);
{$IFDEF WRITE_PADDING_STRING}
const
  sPadding: array [0 .. 7] of char = ('P', 'A', 'D', 'D', 'I', 'N', 'G', 'X');
var
  i: integer;
{$ENDIF}
var
  p: pbyte;
begin
  if Count <> 0 then
  begin
{$IFDEF WRITE_PADDING_STRING}
    GetMem(p, Count);
    for i := 0 to Count - 1 do
      p[i] := byte(sPadding[i mod Length(sPadding)]);
{$ELSE}
    p := AllocMem(Count);
{$ENDIF}
    try
      AStream.Write(p^, Count);
    finally
      FreeMem(p);
    end;
  end;
end;

function StreamSeek(AStream: TStream; Offset: TFileOffset): boolean;
begin
  Result := AStream.Seek(Offset, TSeekOrigin.soBeginning) = Offset;
end;

function StreamSkip(AStream: TStream; Count: integer): boolean; inline;
var
  Offset: TFileOffset;
begin
  Offset := AStream.Position + Count;
  Result := AStream.Seek(Offset, TSeekOrigin.soBeginning) = Offset;
end;

function StreamSeekAlign(AStream: TStream; Align: integer): boolean;
var
  m: integer;
  pos: TFileOffset;
begin
  if Align in [0, 1] then
    exit(True); // don't need alignment
  pos := AStream.Position;
  m := pos mod Align;
  if m = 0 then
    exit(True);        // already aligned
  inc(pos, Align - m); // next aligned position
  Result := AStream.Seek(pos, TSeekOrigin.soBeginning) = pos;
end;

procedure StreamSeekWithPadding(AStream: TStream; Offset: TFileOffset);
begin
  if Offset <= AStream.Size then
  begin
    AStream.Seek(Offset, TSeekOrigin.soBeginning);
    exit;
  end;
  // Insert padding if need.
  AStream.Seek(AStream.Size, TSeekOrigin.soBeginning);
  WritePadding(AStream, Offset - AStream.Size);
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

function AlignDown(Value: uint64; Align: uint32): uint64;
begin
  Result := (Value div Align) * Align;
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

function CompareRVA(A, B: TRVA): integer;
begin
  if A > B then
    exit(1)
  else if A < B then
    exit(-1)
  else
    exit(0);
end;

end.
