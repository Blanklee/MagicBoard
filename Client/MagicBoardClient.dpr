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
  //���α׷��� �������� �ʵ��� �Ѵ�.
  CreateFileMapping ($FFFFFFFF, nil, PAGE_READWRITE, 0, 1024, 'Samsung Magic Board Client');
  if GetLastError=ERROR_ALREADY_EXISTS then halt;

  Application.Initialize;
  Application.Title := '�����Խ���';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

