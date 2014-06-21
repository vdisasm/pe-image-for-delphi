{
  Build exe with a huge graph of simple structure.
  It acutally needed for VDisAsm to test and optimize performance of graph
  rendering.
}
program build_x86_graph;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.Classes,
  System.SysUtils,
  PE.Image,
  PE.Section;

const
  MAX_ITERATIONS = 10000;

  {
    Basic block looks like this:
    jmp next
    @next: ...
  }
  BASIC_BLOCK: array [0 .. 2] of byte = ($EB, $01, $00);

  {
    It ends with:
    ret
  }
  BASIC_BLOCK_LAST: array [0 .. 0] of byte = ($C3);

procedure main;
var
  i: integer;
  ms: TMemoryStream;
  sec: TPESection;
var
  img: TPEImage;
begin
  ms := TMemoryStream.Create;
  try
    // Prepare "code"
    for i := 1 to MAX_ITERATIONS do
      ms.Write(BASIC_BLOCK, Length(BASIC_BLOCK));
    ms.Write(BASIC_BLOCK_LAST, Length(BASIC_BLOCK_LAST));

    // Save image.
    img := TPEImage.Create;
    try
      sec := img.Sections.AddNew('.graph', ms.Size, $60000020, ms.Memory);
      img.EntryPointRVA := sec.RVA;
      img.SaveToFile('x86_graph.exe');
    finally
      img.Free;
    end;
  finally
    ms.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
