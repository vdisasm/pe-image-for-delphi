unit PE.Imports.Func;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  PE.Common,
  VDLib.RBTree;

type
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

  TPEImportFunctions = class
  private type
    TFuncTree = TRBTree<TPEImportFunction>;
  private
    FFunctionsByRVA: TFuncTree;
    procedure ImportFunctionNotify(Sender: TObject; const Item: TPEImportFunction;
      Action: TCollectionNotification);
    function FindInternal(Tree: TFuncTree; Key: TPEImportFunction):
      TPEImportFunction; inline;
  public
    constructor Create;
    destructor Destroy; override;

    function Count: integer; inline;

    procedure Add(const Func: TPEImportFunction);

    function FindByRVA(RVA: TRVA): TPEImportFunction;

    property FunctionsByRVA: TFuncTree read FFunctionsByRVA;
  end;

implementation

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

{ TImportFunction }

procedure TPEImportFunction.Clear;
begin
  Ordinal := 0;
  Name := '';
  RVA := 0;
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

{ TPEImportFunctions }

procedure TPEImportFunctions.Add(const Func: TPEImportFunction);
begin
  FFunctionsByRVA.Add(Func);
end;

function TPEImportFunctions.Count: integer;
begin
  Result := FFunctionsByRVA.Count;
end;

constructor TPEImportFunctions.Create;
begin
  inherited Create;

  FFunctionsByRVA := TFuncTree.Create(
    function(const A, B: TPEImportFunction): Boolean
    begin
      Result := A.RVA < B.RVA;
    end);
  FFunctionsByRVA.OnNotify := ImportFunctionNotify;
end;

destructor TPEImportFunctions.Destroy;
begin
  FFunctionsByRVA.Free;
  inherited;
end;

function TPEImportFunctions.FindByRVA(RVA: TRVA): TPEImportFunction;
begin
  Result := FindInternal(FFunctionsByRVA, TPEImportFunction.Create(RVA, ''));
end;

function TPEImportFunctions.FindInternal(Tree: TFuncTree;
Key: TPEImportFunction): TPEImportFunction;
var
  ptr: TFuncTree.TRBNodePtr;
begin
  try
    ptr := Tree.Find(Key);
    if ptr = nil then
      exit(nil);
    Result := ptr^.K;
  finally
    Key.Free;
  end;
end;

procedure TPEImportFunctions.ImportFunctionNotify(Sender: TObject;
const Item: TPEImportFunction; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
    Item.Free;
end;

end.
