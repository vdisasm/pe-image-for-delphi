unit PE.COFF;

interface

uses
  System.Classes,
  System.SysUtils,
  PE.COFF.Types;

type
  TCOFF = class
  private
    FPE: TObject;
    FStrings: TBytes;
    procedure LoadStrings(AStream: TStream);
  public
    constructor Create(PEImage: TObject);

    procedure Clear;
    procedure LoadFromStream(AStream: TStream);

    function GetString(Offset: integer; out Str: String): boolean;
  end;

implementation

uses
  // Expand
  PE.Types.FileHeader,
  //
  PE.Common,
  PE.Image,
  PE.Utils;

{ TCOFF }

procedure TCOFF.Clear;
begin
  SetLength(FStrings, 0);
end;

constructor TCOFF.Create(PEImage: TObject);
begin
  self.FPE := PEImage;
end;

function TCOFF.GetString(Offset: integer; out Str: String): boolean;
begin
  Result := (Offset >= 0) and (Offset < Length(FStrings));
  if Result then
    Str := String(PAnsiChar(@FStrings[Offset]));
end;

procedure TCOFF.LoadFromStream(AStream: TStream);
begin
  LoadStrings(AStream);
end;

procedure TCOFF.LoadStrings(AStream: TStream);
var
  StrTableOfs, EndPos: uint64;
  cbStringData: uint32;
begin

  // 4.6. COFF String Table

  with TPEImage(FPE).FileHeader^ do
  begin
    if PointerToSymbolTable = 0 then
      exit;
    StrTableOfs := PointerToSymbolTable + NumberOfSymbols * SizeOf(TCOFFSymbolTable);
  end;

  if not StreamSeek(AStream, StrTableOfs) then
    exit; // table not found

  if not StreamPeek(AStream, cbStringData, SizeOf(cbStringData)) then
    exit;

  EndPos := AStream.Position + cbStringData;

  if EndPos > AStream.Size then
    exit;

  // Load string block.
  SetLength(FStrings, cbStringData);
  StreamRead(AStream, FStrings[0], cbStringData);
end;

end.
