unit PE.Types.Directories;

interface

type
  TImageDataDirectory = packed record
    VirtualAddress: uint32; // RVA
    Size: uint32;
    function IsEmpty: boolean; inline;
    function Contain(rva: uint32): boolean; inline;
  end;

  PImageDataDirectory = ^TImageDataDirectory;

type
// 2.4.3. Optional Header Data Directories (Image Only)

  // variant #1
  TImageDataDirectories = packed record
    ExportTable:            TImageDataDirectory;  // The export table address and size.
    ImportTable:            TImageDataDirectory;  // The import table address and size.
    ResourceTable:          TImageDataDirectory;  // The resource table address and size.
    ExceptionTable:         TImageDataDirectory;  // The exception table address and size.
    CertificateTable:       TImageDataDirectory;  // The attribute certificate table address and size.
    BaseRelocationTable:    TImageDataDirectory;  // The base relocation table address and size.
    Debug:                  TImageDataDirectory;  // The debug data starting address and size.
    Architecture:           TImageDataDirectory;  // Reserved, must be 0
    GlobalPtr:              TImageDataDirectory;  // The RVA of the value to be stored in the global pointer register.
                                                  // The size member of this structure must be set to zero.
    TLSTable:               TImageDataDirectory;  // The thread local storage (TLS) table address and size.
    LoadConfigTable:        TImageDataDirectory;  // The load configuration table address and size.
    BoundImport:            TImageDataDirectory;  // The bound import table address and size.
    IAT:                    TImageDataDirectory;  // The import address table address and size.
    DelayImportDescriptor:  TImageDataDirectory;  // The delay import descriptor address and size.
    CLRRuntimeHeader:       TImageDataDirectory;  // The CLR runtime header address and size.
    RESERVED:               TImageDataDirectory;  // Reserved, must be zero
  end;

  PImageDataDirectories = ^TImageDataDirectories;

const
  NULL_IMAGE_DATA_DIRECTORY: TImageDataDirectory = (VirtualAddress: 0; Size: 0);

  IMAGE_NUMBEROF_DIRECTORY_ENTRIES  = 16;

  DirectoryNames: array [0 .. IMAGE_NUMBEROF_DIRECTORY_ENTRIES - 1] of string =
    (
    'Export',
    'Import',
    'Resource',
    'Exception',
    'Certificate',
    'Base Relocation',
    'Debug',
    'Architecture',
    'Global Pointer',
    'Thread Local Storage',
    'Load Config',
    'Bound Import',
    'Import Address Table',
    'Delay Import Descriptor',
    'CLR Runtime Header',
    ''
    );

// variant #2
// TImageDataDirectories = packed array [0 .. IMAGE_NUMBEROF_DIRECTORY_ENTRIES-1] of TImageDataDirectory;


implementation

function TImageDataDirectory.Contain(rva: uint32): boolean;
begin
  Result := (rva >= Self.VirtualAddress) and (rva < self.VirtualAddress+self.Size);
end;

function TImageDataDirectory.IsEmpty: boolean;
begin
//  Result := (VirtualAddress = 0) or (Size = 0);
  Result := (VirtualAddress = 0);
  // In some cases Size can be 0, but VirtualAddress will point to valid data.
end;


end.
