library SampleLib;

uses
  WinApi.Windows;

{ Procedures for export }

procedure p_ord_10;
begin
end;

procedure p_ord_20;
begin
end;

procedure p3;
begin
end;

procedure p4;
begin
end;

procedure p_ord_50;
begin
end;

procedure p6;
begin
end;

procedure p7;
begin
end;

var
  ExpVar: integer;

exports
  p_ord_10 index $10,
  p_ord_20 index $20,
  p3 name 'p3',
  p4 name 'p4',
  p_ord_50 index $50,
  p6,
  p7,
  ExpVar;

begin
  MessageBox(0, 'Text', 'Caption', 0);

end.
