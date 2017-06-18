program test;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows,
  SysUtils,
  PE.Common,
  PE.Image,
  PE.Imports.Lib,
  PE.Imports.Func,
  PE.Build,
  PE.Section;

const
  NORMAL_EXIT_CODE = $C0DE;
  SRC_FILENAME = 'test.exe';
  DST_FILENAME = 'test.out.exe';

procedure Log(text: string);
begin
  WriteLn(Format('[%4x] %s', [GetCurrentProcessId(), text]));
end;

function RunWithParam(exe: string; param: string = ''): boolean;
var
  cmdLine: string;
  si: TStartupInfo;
  pi: TProcessInformation;
  code: dword;
begin
  cmdLine := param;

  ZeroMemory(@si, sizeof(si));
  si.cb := sizeof(si);

  ZeroMemory(@pi, sizeof(pi));

  if (CreateProcess(Pointer(exe), Pointer(cmdLine), nil, nil, false, 0, nil, nil, si, pi)) then
  begin
    WaitForSingleObject(pi.hProcess, INFINITE);
    if (GetExitCodeProcess(pi.hProcess, code)) then
    begin
      CloseHandle(pi.hThread);
      CloseHandle(pi.hProcess);
      exit(code = NORMAL_EXIT_CODE);
    end;
  end;

  exit(false);
end;

procedure WritePushDword(img: TPEImage; value: dword);
var
  rec: packed record
    op: byte;
    value: dword;
  end;
begin
  rec.op := $68;
  rec.value := value;
  img.Write(rec, sizeof(rec));
end;

function GetIatEntryAddr(img: TPEImage; lib: TPEImportLibrary; fn: TPEImportFunction): NativeUInt;
var
  i: integer;
begin
  for i := 0 to lib.Functions.Count - 1 do
    if (lib.Functions[i] = fn) then
      exit(lib.IatRva + i * img.ImageWordSize);

  raise Exception.Create('Function not found');
end;

procedure WriteCall(img: TPEImage; lib: TPEImportLibrary; fn: TPEImportFunction);
var
  rec: packed record
    op1, op2: byte;
    addr: NativeUInt;
  end;
begin
  rec.op1 := $FF;
  rec.op2 := $15;
  rec.addr := img.RVAToVA(GetIatEntryAddr(img, lib, fn));
  img.Write(rec, sizeof(rec));
end;

procedure WriteJmpRel(img: TPEImage; dst: TRVA);
var
  rec: packed record
    op: byte;
    delta: dword;
  end;
begin
  rec.op := $E9;
  rec.delta := dst - (img.PositionRVA + sizeof(rec));
  img.Write(rec, sizeof(rec));
end;

procedure TestImportRebuilding();
var
  img: TPEImage;
  oep: TRVA;
  sec: TPESection;
  lib: TPEImportLibrary;
  fn: TPEImportFunction;
begin
  img := TPEImage.Create();
  try
    if (img.LoadFromFile(SRC_FILENAME)) then
    begin
      lib :=  img.Imports.NewLib(kernel32);
      fn := lib.NewFunction('Beep');

      if (ReBuildDirData(img, DDIR_IMPORT, true) <> nil) then
      begin
        // Make some code to call beep at new entry point (in new section).
        // Then jump to original entry point.
        // Without relocations to make it simpler.
        oep := img.EntryPointRVA;
        sec := img.Sections.AddNew('.my', 32, $60000020, nil);
        img.EntryPointRVA := sec.RVA;

        img.SeekRVA(sec.RVA);
        WritePushDword(img, 1000); // dwDuration
        WritePushDword(img, 5000); // dwFreq
        WriteCall(img, lib, fn);
        WriteJmpRel(img, oep);

        // Save to file and try to run.
        img.SaveToFile(DST_FILENAME);

        if (RunWithParam(DST_FILENAME)) then
        begin
          Log('Import rebuilt OK');
        end
        else
        begin
          Log('Rebuilt image failed');
        end;
      end
      else
      begin
        Log('Failed to rebuld imports');
      end;
    end
    else
    begin
      Log('Failed to parse image');
    end;
  finally
    img.Free();
  end;

  RunWithParam(SRC_FILENAME);
end;

begin
  if (ParamStr(1) = 'test') then
  begin
    Log('Test call');
    TestImportRebuilding();
  end
  else
  begin
    Log('Normal call');
    Halt(NORMAL_EXIT_CODE);
  end;
end.
