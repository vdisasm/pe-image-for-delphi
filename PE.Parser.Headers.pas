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
function LoadNtHeaders(AStream: TStream; out ANt: TImageNTHeaders; out OptionalHeaderEnd: TFileOffset): boolean;

implementation

function LoadDosHeader;
begin
  Result := StreamRead(AStream, AHdr, SizeOf(AHdr)) and (AHdr.e_magic = MZ_SIGNATURE);
end;

function LoadFileHeader;
begin
  Result := StreamRead(AStream, AHdr, SizeOf(AHdr));
end;

// todo: LoadNtHeaders
function LoadNtHeaders; deprecated;
var
  OptionalHeaderOffset: TFileOffset;
  OHSize: uint32;     // Optional header size / expected size.
  SizeToRead: uint32; //
  SizeRead: uint32;   // Size actually read.
  Buf: pointer;
begin
  Result := False;

  if (StreamRead(AStream, ANt.Signature, SizeOf(ANt.Signature))) then
    case ANt.Signature of
      // PE signature.
      PE00_SIGNATURE:
        begin
          // FileHeader.
          if (StreamRead(AStream, ANt.FileHeader, SizeOf(ANt.FileHeader))) then
          begin
            // Store offset of opt. header.
            OptionalHeaderOffset := AStream.Position;
            OptionalHeaderEnd := OptionalHeaderOffset + ANt.FileHeader.SizeOfOptionalHeader;

            // At least file header is OK.
            Result := True;

            // Optional header.
            OHSize := ANt.FileHeader.SizeOfOptionalHeader;

            if OHSize <> 0 then
            begin
              // Read opt.hdr magic.
              Result := AStream.Read(ANt.OptionalHeader.pe32.Magic, 2) = 2;
              if Result then
              begin
                // Back to opt. header start
                AStream.Seek(-2, soFromCurrent);

                // Get expected (normal) size.
                case ANt.OptionalHeader.pe32.Magic of
                  PE_MAGIC_PE32:
                    begin
                      SizeToRead := SizeOf(TImageOptionalHeader32);
                      Buf := @ANt.OptionalHeader.pe32;
                    end;
                  PE_MAGIC_PE32PLUS:
                    begin
                      SizeToRead := SizeOf(TImageOptionalHeader64);
                      Buf := @ANt.OptionalHeader.pe64;
                    end
                else
                  exit(False);
                end;

                // Get safe size.
                if OHSize <> SizeToRead then
                  SizeToRead := OHSize;

                // Read.
                SizeRead := AStream.Read(Buf^, SizeToRead);

                // Check if match the size specified in header.
                Result := OHSize >= SizeRead;
              end;
            end;

          end;
        end; // PE00_SIGNATURE

    end;
end;

end.
