unit PE.Build.Resource;

interface

uses
  System.Classes,
  PE.Build.Common,
  PE.Section,
  PE.Common;

type
  TRsrcBuilder = class(TDirectoryBuilder)
    procedure Build(DirRVA: TRVA; Stream: TStream); override;
    class function GetDefaultSectionFlags: Cardinal; override;
    class function GetDefaultSectionName: string; override;
    class function NeedRebuildingIfRVAChanged: Boolean; override;
  end;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  PE.Resources,
  PE.Types.Resources;

type
  TNodeList = TList<TResourceTreeNode>;
  TDirEntries = TList<TResourceDirectoryEntry>;

procedure TRsrcBuilder.Build(DirRVA: TRVA; Stream: TStream);
begin
  raise Exception.Create('Not Implemented.');
end;

class function TRsrcBuilder.GetDefaultSectionFlags: Cardinal;
begin
  Result := $40000040; // readable + initialized data
end;

class function TRsrcBuilder.GetDefaultSectionName: string;
begin
  Result := '.rsrc';
end;

class function TRsrcBuilder.NeedRebuildingIfRVAChanged: Boolean;
begin
  Result := False;
end;

end.
