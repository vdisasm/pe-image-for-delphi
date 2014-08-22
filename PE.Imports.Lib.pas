unit PE.Imports.Lib;

interface

uses
  System.Classes,

  PE.Imports.Func;

type
  TPEImportLibrary = class
  private
    FName: String; // imported library name
    FBound: Boolean;
    FFunctions: TPEImportFunctions;
    FTimeDateStamp: uint32;
  public
    constructor Create(const AName: String; Bound: Boolean = False);
    destructor Destroy; override;

    property Name: String read FName;
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

end.
