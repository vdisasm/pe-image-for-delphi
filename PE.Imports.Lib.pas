unit PE.Imports.Lib;

interface

uses
  System.Classes,

  PE.Common,
  PE.Imports.Func;

type
  TPEImportLibrary = class
  private
    FName: String; // imported library name
    FBound: Boolean;
    FFunctions: TPEImportFunctions;
    FTimeDateStamp: uint32;
  public
    // Relative address of IAT region for this library.
    // It is address of first word in array of words (4/8 bytes) corresponding
    // to each imported function in same order as in Functions list.
    //
    // Each RVA is patched by loader if it's mapped into process memory.
    //
    // If image is not bound loader get address of function and write it at RVA.
    // If image is bound nothing changed because value at RVA is already set.
    //
    // This value is modified when import directory parsed on loading or
    // when import directory is rebuilt.
    IatRva: TRVA;

    constructor Create(const AName: String; Bound: Boolean = False);
    destructor Destroy; override;

    function NewFunction(const Name: string): TPEImportFunction; overload;
    function NewFunction(Ordinal: uint16): TPEImportFunction; overload;

    property Name: String read FName;

    // List of imported functions.
    // Order must be kept to match array of words at IatRva.
    property Functions: TPEImportFunctions read FFunctions;

    property Bound: Boolean read FBound;
    property TimeDateStamp: uint32 read FTimeDateStamp write FTimeDateStamp;
  end;

implementation

{ TImportLibrary }

constructor TPEImportLibrary.Create(const AName: String; Bound: Boolean);
begin
  inherited Create;
  FFunctions := TPEImportFunctions.Create;
  FName := AName;
  FBound := Bound;
end;

destructor TPEImportLibrary.Destroy;
begin
  FFunctions.Free;
  inherited;
end;

function TPEImportLibrary.NewFunction(const Name: string): TPEImportFunction;
begin
  Result := TPEImportFunction.Create(Name);
  FFunctions.Add(Result);
end;

function TPEImportLibrary.NewFunction(Ordinal: uint16): TPEImportFunction;
begin
  Result := TPEImportFunction.Create('', Ordinal);
  FFunctions.Add(Result);
end;

end.
