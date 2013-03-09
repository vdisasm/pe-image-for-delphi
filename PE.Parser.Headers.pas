unit PE.Parser.Headers;

interface

uses
  System.Classes,

  PE.Common,
  PE.Types.DOSHeader,
  PE.Types.FileHeader,
  PE.Types.OptionalHeader,
  PE.Types.NTHeaders,

  PE.Utils;

function LoadDosHeader(AStream: TStream; out AHdr: TImageDOSHeader): boolean;
function LoadFileHeader(AStream: TStream; out AHdr: TImageFileHeader): boolean; inline;

implementation

function LoadDosHeader;
begin
  Result := StreamRead(AStream, AHdr, SizeOf(AHdr)) and (AHdr.e_magic = MZ_SIGNATURE);
end;

function LoadFileHeader;
begin
  Result := StreamRead(AStream, AHdr, SizeOf(AHdr));
end;

end.
