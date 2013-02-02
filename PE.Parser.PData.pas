(*
  .pdata section parser
*)
unit PE.Parser.PData;

interface

uses
  PE.Image,
  PE.Section,
  PE.Sections,
  PE.Types.FileHeader,
  PE.Types.Sections;

{ http://msdn.microsoft.com/en-us/library/ms864326.aspx }

type
  PDATA_EH = packed record
    // OS Versions: Windows CE .NET 4.0 and later.
    // Header: no public definition.
    pHandler: uint32;     // Address of the exception handler for the function.
    pHandlerData: uint32; // Address of the exception handler data record for the function.
  end;

  { 5.5. The .pdata Section }

type
  { 32-bit MIPS images }
  TPDATA_MIPS32 = packed record
    // The VA of the corresponding function.
    BeginAddress: uint32;

    // The VA of the end of the function.
    EndAddress: uint32;

    // The pointer to the exception handler to be executed.
    ExceptionHandler: uint32;

    // The pointer to additional information to be passed to the handler.
    HandlerData: uint32;

    // The VA of the end of the function’s prolog.
    PrologEndAddress: uint32;
  end;

  { ARM, PowerPC, SH3 and SH4 Windows CE platforms }
  TPDATA_ARM = packed record
  strict private
    _BeginAddress: uint32;
    _DATA: uint32;
  public
    // The VA of the corresponding function.
    function BeginAddress: uint32; inline;

    // 8 bit: The number of instructions in the function’s prolog.
    function PrologLength: uint8; inline;

    // 22 bit: The number of instructions in the function.
    function FunctionLength: uint32; inline;

    // 1 bit: If set, the function consists of 32-bit instructions.
    // If clear, the function consists of 16-bit instructions.
    function Is32Bit: boolean; inline;

    // 1 bit: If set, an exception handler exists for the function.
    // Otherwise, no exception handler exists.
    function IsExceptionFlag: boolean; inline;

    function IsEmpty: boolean; inline;

  end;

  { For x64 and Itanium platforms }
  TPDATA_x64 = packed record
    BeginAddress: uint32;      // The RVA of the corresponding function.
    EndAddress: uint32;        // The RVA of the end of the function.
    UnwindInformation: uint32; // The RVA of the unwind information.
  end;

  { For the ARMv7 platform }
  TPDATA_ARMv7 = packed record
    // The RVA of the corresponding function.
    BeginAddress: uint32;

    // The RVA of the unwind information, including function length.
    // If the low 2 bits are non-zero, then this word represents a compacted
    // inline form of the unwind information, including function length.
    UnwindInformation: uint32;
  end;

type
  TPDATAType = (pdata_NONE, pdata_MIPS32, pdata_ARM, pdata_x64, pdata_ARMv7);

  TPDATAItem = record
    case TPDATAType of
      pdata_MIPS32:
        (MIPS32: TPDATA_MIPS32);
      pdata_ARM:
        (ARM: TPDATA_ARM);
      pdata_x64:
        (x64: TPDATA_x64);
      pdata_ARMv7:
        (ARMv7: TPDATA_ARMv7);
  end;

  TPDATARecord = record
    &Type: TPDATAType;
    Data: TPDATAItem;
    procedure Clear; inline;
  end;

type
  TPDATARecords = array of TPDATARecord;

  // Parses .PDATA section (if exists) and returns count of elements found
function ParsePDATA(PE: TPEImage; out Data: TPDATARecords): integer;

implementation

{ TPDATA_ARM }

function TPDATA_ARM.BeginAddress: uint32;
begin
  result := _BeginAddress;
end;

function TPDATA_ARM.FunctionLength: uint32;
begin
  result := (_DATA shr 8) and ((1 shl 22) - 1);
end;

function TPDATA_ARM.Is32Bit: boolean;
begin
  result := _DATA and (1 shl 30) <> 0;
end;

function TPDATA_ARM.IsEmpty: boolean;
begin
  result := (_BeginAddress = 0) or (_DATA = 0);
end;

function TPDATA_ARM.IsExceptionFlag: boolean;
begin
  result := _DATA and (1 shl 31) <> 0;
end;

function TPDATA_ARM.PrologLength: uint8;
begin
  result := byte(_DATA);
end;

{ ParsePDATA }

function ParsePDATA(PE: TPEImage; out Data: TPDATARecords): integer;
var
  sec: TPESection;
  i, cnt: integer;
  actual: integer;
  size: integer;
  D: TPDATARecord;
begin
  SetLength(Data, 0);

  sec := PE.GetSectionByName('.pdata');

  if
    (sec <> nil) and
    (sec.RawSize > 0) and
    ((sec.flags and IMAGE_SCN_CNT_INITIALIZED_DATA) <> 0) and
    ((sec.flags and IMAGE_SCN_MEM_READ) <> 0) and
    (PE.SeekRVA(sec.RVA)) then
  begin
    case PE.FileHeader^.Machine of
      IMAGE_FILE_MACHINE_ARM:
        begin
          size := sizeof(TPDATA_ARM);
          cnt := sec.RawSize div size;
          actual := 0;
          SetLength(Data, cnt); // pre-allocate
          for i := 1 to cnt do
          begin
            D.Clear;
            D.&Type := pdata_ARM;
            if not PE.ReadEx(@D.Data.ARM, size) then
              break;
            if D.Data.ARM.IsEmpty then
              break;
            inc(actual);
            Data[i - 1] := D;
          end;
          SetLength(Data, actual); // post-trim
        end;
    end;
  end;

  result := Length(Data);
end;

{ TPDATARecord }

procedure TPDATARecord.Clear;
begin
  FillChar(self, sizeof(self), 0);
end;

end.
