program MagicBoardServer;

uses
  Forms,
  Windows,
  ServerForm1 in 'ServerForm1.pas' {MainForm1},
  AlbumForm1 in 'AlbumForm1.pas' {AlbumForm},
  SchForm1 in 'SchForm1.pas' {SchForm},
  MagicInfoForm1 in 'MagicInfoForm1.pas' {MagicInfoForm},
  Globals in 'Globals.pas',
  Client in 'Client.pas',
  FileList in 'FileList.pas';

{$R *.RES}

begin
  //���α׷��� �������� �ʵ��� �Ѵ�.
  CreateFileMapping ($FFFFFFFF, nil, PAGE_READWRITE, 0, 1024, 'Samsung Magic Board Server');
  if GetLastError=ERROR_ALREADY_EXISTS then halt;

  Application.Initialize;
  Application.Title := '�����Խ���';
  Application.CreateForm(TMainForm1, MainForm1);
  Application.CreateForm(TAlbumForm, AlbumForm);
  Application.CreateForm(TSchForm, SchForm);
  Application.CreateForm(TMagicInfoForm, MagicInfoForm);
  Application.Run;
end.

