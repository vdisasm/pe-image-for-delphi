unit PE.Imports.Func;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  PE.Common,
  gmap;

type
  TPEImportFunction = class
  public
    Ordinal: uint16;
    Name: String;

    // RVA patched by loader.
    // If image is not bound loader get address of function and write it at RVA.
    // If image is bound nothing changed because value at RVA is already set.
    RVA: TRVA;

    procedure Clear; inline;
    constructor CreateEmpty;
    constructor Create(RVA: TRVA; const Name: String; Ordinal: uint16 = 0);
  end;

  TPEImportFunctionDelayed = class(TPEImportFunction)
  public
  end;

  TPEImportFunctions = class
  private type
    TFuncTree = TMap<TRVA, TPEImportFunction>;
  private
    FFunctionsByRVA: TFuncTree;
    procedure ImportFunctionValueNotify(Sender: TObject; const Item: TPEImportFunction;
      Action: TCollectionNotification);
  public
    constructor Create;
    destructor Destroy; override;

    function Count: integer; inline;

    procedure Add(const Func: TPEImportFunction);

    function FindByRVA(RVA: TRVA): TPEImportFunction;

    property FunctionsByRVA: TFuncTree read FFunctionsByRVA;
  end;

implementation

{ TImportFunction }

procedure TPEImportFunction.Clear;
begin
  self.Ordinal := 0;
  self.Name := '';
  self.RVA := 0;
end;

constructor TPEImportFunction.Create(RVA: TRVA; const Name: String;
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
  FFunctionsByRVA.Add(Func.RVA, Func);
end;

function TPEImportFunctions.Count: integer;
begin
  Result := FFunctionsByRVA.Count;
end;

constructor TPEImportFunctions.Create;
begin
  inherited Create;

  FFunctionsByRVA := TFuncTree.Create(
    function(const A, B: TRVA): Boolean
    begin
      Result := A < B;
    end);
  FFunctionsByRVA.OnValueNotify := ImportFunctionValueNotify;
end;

destructor TPEImportFunctions.Destroy;
begin
  FFunctionsByRVA.Free;
  inherited;
end;

function TPEImportFunctions.FindByRVA(RVA: TRVA): TPEImportFunction;
begin
  FFunctionsByRVA.TryGetValue(RVA, Result);
end;

procedure TPEImportFunctions.ImportFunctionValueNotify(Sender: TObject;
const Item: TPEImportFunction; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
    Item.Free;
end;

end.
