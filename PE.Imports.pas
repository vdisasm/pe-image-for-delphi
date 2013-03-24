unit PE.Imports;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  PE.Common;

type
  { PEImage import record }

  TPEImportFunction = class
  public
    Ordinal: uint16;
    Name: AnsiString;

    // RVA patched by loader.
    // If image is not bound loader get address of function and write it at RVA.
    // If image is bound nothing changed because value at RVA is already set.
    RVA: TRVA;

    procedure Clear; inline;
    constructor CreateEmpty;
    constructor Create(RVA: TRVA; const Name: AnsiString; Ordinal: uint16 = 0);
  end;

  PPEImportFunction = ^TPEImportFunction;

  TPEImportFunctions = TList<TPEImportFunction>;

  TPEImportLibrary = class
  private
    FName: AnsiString; // imported library name
    FBound: Boolean;
    FFunctions: TPEImportFunctions;
    procedure ImportFunctionNotify(Sender: TObject; const Item: TPEImportFunction;
      Action: TCollectionNotification);
  public
    constructor Create(const AName: AnsiString; Bound: Boolean = False);
    destructor Destroy; override;

    // Find function by name. Result is nil if not found.
    function FindFunc(const AName: AnsiString): TPEImportFunction;

    property Name: AnsiString read FName;
    property Functions: TPEImportFunctions read FFunctions;
    property Bound: Boolean read FBound;
  end;

  TPEImports = class(TList<TPEImportLibrary>)
  public
    // Find library by name (first occurrence). Result is nil if not found.
    function FindLib(const LibName: AnsiString): TPEImportLibrary;

    // Add new import function.
    procedure AddNew(RVA: TRVA; const LibName, FuncName: AnsiString; Ordinal: uint16 = 0);
  end;

implementation

{ TImportFunction }

procedure TPEImportFunction.Clear;
begin
  Ordinal := 0;
  Name := '';
  RVA := 0;
end;

{ TImportLibrary }

constructor TPEImportLibrary.Create(const AName: AnsiString; Bound: Boolean);
begin
  inherited Create;
  FFunctions := TPEImportFunctions.Create;
  FFunctions.OnNotify := ImportFunctionNotify;
  FName := AName;
  FBound := Bound;
end;

destructor TPEImportLibrary.Destroy;
begin
  FFunctions.Free;
  inherited;
end;

function TPEImportLibrary.FindFunc(const AName: AnsiString): TPEImportFunction;
var
  verify: AnsiString;
  tmp: TPEImportFunction;
begin
{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}
  verify := LowerCase(AName);
  for tmp in FFunctions do
    if LowerCase(tmp.Name) = verify then
      exit(tmp);
  exit(nil);
{$WARN IMPLICIT_STRING_CAST ON}
{$WARN IMPLICIT_STRING_CAST_LOSS ON}
end;

procedure TPEImportLibrary.ImportFunctionNotify(Sender: TObject;
  const Item: TPEImportFunction; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
    Item.Free;
end;

constructor TPEImportFunction.Create(RVA: TRVA; const Name: AnsiString;
  Ordinal: uint16);
begin
  self.RVA := RVA;
  self.Name := Name;
  self.Ordinal := Ordinal;
end;

constructor TPEImportFunction.CreateEmpty;
begin
end;

{ TPEImports }

procedure TPEImports.AddNew(RVA: TRVA; const LibName, FuncName: AnsiString;
  Ordinal: uint16);
var
  Lib: TPEImportLibrary;
  Func: TPEImportFunction;
begin
  Lib := FindLib(LibName);
  if Lib = nil then
  begin
    Lib := TPEImportLibrary.Create(LibName);
    Add(Lib);
  end;
  Func := TPEImportFunction.Create(RVA, FuncName, Ordinal);
  Lib.Functions.Add(Func);
end;

function TPEImports.FindLib(const LibName: AnsiString): TPEImportLibrary;
var
  tmp: TPEImportLibrary;
  verify: AnsiString;
begin
{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}
  verify := LowerCase(LibName);
  for tmp in self do
    if LowerCase(tmp.Name) = verify then
      exit(tmp);
  exit(nil);
{$WARN IMPLICIT_STRING_CAST ON}
{$WARN IMPLICIT_STRING_CAST_LOSS ON}
end;

end.
