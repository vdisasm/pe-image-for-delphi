program ProcessTest;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,

  WinHelper,

  PE.Common,
  PE.Image,
  PE.Imports.Lib,
  PE.ProcessModuleStream;

procedure PrintAllProcesses;
var
  processList: TProcessRecList;
  processRec: TProcessRec;
begin
  processList := TProcessRecList.Create;
  try
    if not EnumProcessesToList(processList) then
    begin
      writeln('Failed to enum processes');
      exit;
    end;

    // display processes
    for processRec in processList do
      writeln(format('%-6d %s', [processRec.PID, processRec.Name]));

    writeln;
  finally
    processList.Free;
  end;
end;

procedure PrintModules(PID: uint32);
var
  list: TModuleRecList;
  rec: TModuleRec;
begin
  list := TModuleRecList.Create;
  try
    if not EnumModulesToList(PID, list) then
    begin
      writeln('Failed to enum modules for PID ', PID);
      exit;
    end;

    for rec in list do
      writeln(format('%p "%s"', [rec.modBaseAddr, rec.szModule]));

    writeln;
  finally
    list.Free;
  end;
end;

procedure PrintImports(PID: uint32);
var
  Stream: TProcessModuleStream;
  Img: TPEImage;
  Lib: TPEImportLibrary;
begin
  Stream := TProcessModuleStream.CreateFromPid(PID);
  try
    Img := TPEImage.Create;
    try
      if not Img.LoadFromStream(Stream, [PF_IMPORT], PEIMAGE_KIND_MEMORY) then
        writeln('Failed to parse image from process');

      for Lib in Img.Imports.Libs do
        writeln('  ', Lib.Name);

      writeln;
    finally
      Img.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure PrintPidByName(const Name: string);
var
  PID: uint32;
begin
  write('Process "', name, '" has PID = ');
  if FindPIDByProcessName(name, PID, MATCH_STRING_START) then
    writeln(PID)
  else
    writeln('not found');
  writeln;
end;

procedure main;
var
  cmd: string;
  PID: uint32;
  error: integer;
begin
  writeln('usage:');
  writeln('  proc:     show processes');
  writeln('  mod 123:  show modules of process 123');
  writeln('  imp 123:  show imports of process 123');
  writeln('  pid name: get pid of process string with "name"');
  writeln;

  while true do
  begin
    readln(cmd);
    cmd := cmd.ToLower;

    if cmd = 'proc' then
    begin
      PrintAllProcesses;
    end
    else if cmd.StartsWith('mod') then
    begin
      cmd := cmd.Substring(4);
      val(cmd, PID, error);
      if error <> 0 then
        writeln('wrong PID number')
      else
        PrintModules(PID);
    end
    else if cmd.StartsWith('imp') then
    begin
      cmd := cmd.Substring(4);
      val(cmd, PID, error);
      if error <> 0 then
        writeln('wrong PID number')
      else
        PrintImports(PID);
    end
    else if cmd.StartsWith('pid') then
    begin
      PrintPidByName(cmd.Substring(4));
    end
    else
      writeln('unknown command: ', cmd);
  end;
end;

begin
  try
    main;
  except
    on E: Exception do
    begin
      writeln(E.ClassName, ': ', E.Message);
      writeln('Press Enter to quit');
      readln;
    end;
  end;

end.
