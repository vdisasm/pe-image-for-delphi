unit PE.Imports;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  PE.Common,
  PE.Imports.Func,
  PE.Imports.Lib,
  gRBTree;

type
  TPEImports = class
  private type
    TLibTree = TRBTree<TPEImportLibrary>;
  private
    FLibsByName: TLibTree;
    procedure LibTreeItemNotify(Sender: TObject; const Item: TPEImportLibrary;
      Action: TCollectionNotification);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    function Count: integer; inline;

    // Add existing library.
    // Libraries are sorted by name (case insensitive).
    procedure Add(Lib: TPEImportLibrary);

    // Find library by name (first occurrence). Result is nil if not found.
    function FindLib(const LibName: AnsiString): TPEImportLibrary;

    // Add new import function (by IAT RVA).
    procedure AddNew(RVA: TRVA;
      const LibName: AnsiString; Fn: TPEImportFunction); overload;
    procedure AddNew(RVA: TRVA;
      const LibName, FuncName: AnsiString; Ordinal: uint16 = 0); overload; inline;

    property LibsByName: TLibTree read FLibsByName;
  end;

implementation

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

{ TPEImports }

procedure TPEImports.Add(Lib: TPEImportLibrary);
begin
  FLibsByName.Add(Lib);
end;

procedure TPEImports.AddNew(RVA: TRVA; const LibName: AnsiString;
  Fn: TPEImportFunction);
var
  Lib: TPEImportLibrary;
begin
  Lib := FindLib(LibName);
  if Lib = nil then
  begin
    Lib := TPEImportLibrary.Create(LibName);
    Add(Lib);
  end;
  Lib.Functions.Add(Fn);
end;

procedure TPEImports.AddNew(RVA: TRVA; const LibName, FuncName: AnsiString;
  Ordinal: uint16);
begin
  AddNew(RVA, LibName, TPEImportFunction.Create(RVA, FuncName, Ordinal));
end;

procedure TPEImports.Clear;
begin
  FLibsByName.Clear;
end;

function TPEImports.Count: integer;
begin
  Result := FLibsByName.Count;
end;

constructor TPEImports.Create;
begin
  inherited Create;
  FLibsByName := TLibTree.Create(
    function(const A, B: TPEImportLibrary): Boolean
    begin
      Result := LowerCase(A.Name) < LowerCase(B.Name);
    end);
  FLibsByName.OnNotify := LibTreeItemNotify;
end;

destructor TPEImports.Destroy;
begin
  FLibsByName.Free;
  inherited;
end;

function TPEImports.FindLib(const LibName: AnsiString): TPEImportLibrary;
var
  key: TPEImportLibrary;
  ptr: TLibTree.TRBNodePtr;
begin
  key := TPEImportLibrary.Create(LibName);
  try
    ptr := FLibsByName.Find(key);
    if ptr = nil then
      exit(nil);
    Result := ptr^.K;
  finally
    key.Free;
  end;
end;

procedure TPEImports.LibTreeItemNotify(Sender: TObject;
const Item: TPEImportLibrary; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
    Item.Free;
end;

end.
