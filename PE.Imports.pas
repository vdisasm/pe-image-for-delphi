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
    procedure LibTreeItemNotify(Sender: TObject; const Item: TPEImportLibrary; Action: TCollectionNotification);
    function GetCount: integer; inline;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    // Add existing library.
    // Libraries are sorted by name (case insensitive).
    // Result is same library.
    function Add(Lib: TPEImportLibrary): TPEImportLibrary; inline;

    // Find library by name (first occurrence). Result is nil if not found.
    function FindLib(const LibName: String): TPEImportLibrary;

    // Find library by name (first occurrence). If it's not found create and
    // add new library.
    function FetchLib(const LibName: String): TPEImportLibrary;

    // Add new import function (by IAT RVA).
    procedure AddNew(RVA: TRVA; const LibName: String; Fn: TPEImportFunction); overload;
    procedure AddNew(RVA: TRVA; const LibName, FuncName: String; Ordinal: uint16 = 0); overload; inline;

    property LibsByName: TLibTree read FLibsByName;

    property Count: integer read GetCount;
  end;

implementation

{ TPEImports }

constructor TPEImports.Create;
begin
  inherited Create;
  FLibsByName := TLibTree.Create(
    function(const A, B: TPEImportLibrary): Boolean
    begin
      result := A.Name.ToLower < B.Name.ToLower;
    end);
  FLibsByName.OnNotify := LibTreeItemNotify;
end;

destructor TPEImports.Destroy;
begin
  FLibsByName.Free;
  inherited;
end;

procedure TPEImports.LibTreeItemNotify(Sender: TObject; const Item: TPEImportLibrary; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
    Item.Free;
end;

function TPEImports.GetCount: integer;
begin
  result := FLibsByName.Count;
end;

procedure TPEImports.Clear;
begin
  FLibsByName.Clear;
end;

function TPEImports.Add(Lib: TPEImportLibrary): TPEImportLibrary;
begin
  FLibsByName.Add(Lib);
  result := Lib;
end;

function TPEImports.FindLib(const LibName: String): TPEImportLibrary;
var
  key: TPEImportLibrary;
  ptr: TLibTree.TRBNodePtr;
begin
  key := TPEImportLibrary.Create(LibName);
  try
    ptr := FLibsByName.Find(key);
    if ptr = nil then
      exit(nil);
    result := ptr^.K;
  finally
    key.Free;
  end;
end;

function TPEImports.FetchLib(const LibName: String): TPEImportLibrary;
begin
  result := FindLib(LibName);
  if not Assigned(result) then
    result := Add(TPEImportLibrary.Create(LibName));
end;

procedure TPEImports.AddNew(RVA: TRVA; const LibName: String; Fn: TPEImportFunction);
begin
  FetchLib(LibName).Functions.Add(Fn);
end;

procedure TPEImports.AddNew(RVA: TRVA; const LibName, FuncName: String; Ordinal: uint16);
begin
  AddNew(RVA, LibName, TPEImportFunction.Create(RVA, FuncName, Ordinal));
end;

end.
