program MagicBoardClient;

uses
  Forms,
  Windows,
  ClientForm1 in 'ClientForm1.pas' {MainForm},
  Album in 'Album.pas',
  Client in 'Client.pas',
  FileList in 'FileList.pas',
  Globals in 'Globals.pas';

{$R *.RES}

begin
  //프로그램이 재실행되지 않도록 한다.
  CreateFileMapping ($FFFFFFFF, nil, PAGE_READWRITE, 0, 1024, 'Samsung Magic Board Client');
  if GetLastError=ERROR_ALREADY_EXISTS then halt;

  Application.Initialize;
  Application.Title := '매직게시판';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

