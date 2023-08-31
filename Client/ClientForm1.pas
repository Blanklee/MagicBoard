unit ClientForm1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  StdCtrls, ExtCtrls, Registry, IniFiles, Dialogs, ShellApi, OleCtrls,
  WMPLib_TLB, BlankUtils, Globals, Client, Album;

const
  TrialVersion = '';
  MyCopyRight = '매직게시판 v4.4e  for Samsung Display'#13#10;

type
  TLogFile = class
  private
    FLogFile: TextFile;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendText (msg: string);
  end;

  TMainForm = class(TForm)
    Panel1: TPanel;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    LogoLabel: TLabel;
    TrialLabel: TLabel;
    curFile: TLabel;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    Edit5: TEdit;
    cbClient: TCheckBox;
    cbAlbum: TCheckBox;
    saveButton: TButton;
    aboutButton: TButton;
    exitButton: TButton;
    nextButton: TButton;
    Memo1: TMemo;
    Image1: TImage;
    WMP1: TWindowsMediaPlayer;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure WMP1MouseMove(Sender: TObject; nButton, nShiftState: Smallint; fX, fY: Integer);
    procedure WMP1PlayStateChange(Sender: TObject; NewState: Integer);
    procedure cbClientClick(Sender: TObject);
    procedure saveButtonClick(Sender: TObject);
    procedure aboutButtonClick(Sender: TObject);
    procedure exitButtonClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure nextButtonClick(Sender: TObject);
  private
    { Private declarations }
    Client1: TClient;
    Album1: TAlbum;
    LogFile1: TLogFile;
    procedure RegisterAutorunAtBoot;
    procedure LoadFromRegistry;
	procedure LoadFromIniFile;
	procedure SaveToIniFile;
    procedure SetScreenSize;
    procedure ImageFileFound (FileName: string);
    procedure Memo_Out_Detail (msg: string);
    procedure Album1State (AState: string);
    procedure Client1ProcessCommand (cmd: string);
    procedure Client1DoneFile (cmd, FileName: string);
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;


implementation

{$R *.DFM}

// ----------------------------------------------------------------------------
// 여기서부터 TLogFile 함수
// ----------------------------------------------------------------------------

constructor TLogFile.Create;
begin
    inherited Create;
    AssignFile (FLogFile, LogFileName);
    if FileExists (LogFileName) then Append (FLogFile)
    else ReWrite (FLogFile);
end;

destructor TLogFile.Destroy;
begin
    CloseFile (FLogFile);
    inherited Destroy;
end;

procedure TLogFile.AppendText(msg: string);
begin
    Writeln (FLogFile, msg);
    Flush (FLogFile);
end;





// ----------------------------------------------------------------------------
// 여기서부터 공통기능 함수
// ----------------------------------------------------------------------------

procedure TMainForm.FormCreate(Sender: TObject);
begin
    ForceDirectories (FolderName);
    ChDir (FolderName);

    RegisterAutorunAtBoot;	// 부팅시 자동실행 설정
    LoadFromIniFile;		// 설정값을 불러온다
    SetScreenSize;			// 각종 화면설정
    Panel1.BringToFront;
    Memo1.BringToFront;

    // Trial Version
    if (TrialVersion = 'Trial') then begin
        TrialLabel.Left:= (Screen.Width - trialLabel.Width) div 2;
        TrialLabel.BringToFront;
        TrialLabel.Show;
    end;

    {$IFOPT D+}
    // LogFile 기록을 위한 Class
    LogFile1:= TLogFile.Create;
    {$ENDIF}

    // Server와 통신하기 위한 Client
    Client1:= TClient.Create;
    Client1.OnCommand:= Client1ProcessCommand;
    Client1.OnDoneFile:= Client1DoneFile;
    Client1.OnMemoOut:= Memo_Out_Detail;
    Client1.Number:= Edit2.Text;
    Client1.Server:= Edit1.Text;
    Client1.ServerPort:= strtoint32 (Edit3.Text, 51111);
    Client1.HttpPort:= Edit4.Text;

    // 앨범으로 하나씩 보여준다.
    Album1:= TAlbum.Create;
    Album1.Logo:= LogoLabel;
    Album1.Image:= Image1;
    Album1.WMPlayer:= WMP1;
    Album1.MagicInfo:= Edit5.Text;
    Album1.OnMemoOut:= Memo_Out_Detail;
    Album1.OnAlbumState:= Album1State;
    Album1.OnImageFile:= ImageFileFound;
    Album1.InitialLaunch;

(*
    {$IFOPT D+}
    Panel1.Show; Memo1.Show;
    Edit3.Show; Edit4.Show; Edit5.Show;
    cbClient.Show; cbAlbum.Show;
    nextButton.Show;
    WMP1.OnPlayStateChange:= WMP1PlayStateChange;
    {$ENDIF}
*)
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
    SaveToIniFile;
    Album1.Free;
    Client1.Free;
    
    {$IFOPT D+}
    LogFile1.Free;
    {$ENDIF}
end;

procedure TMainForm.RegisterAutorunAtBoot;
var
    Reg: TRegistry;
begin
    Reg := TRegistry.Create;
    try
        Reg.RootKey := HKEY_LOCAL_MACHINE;
        if Reg.OpenKey('\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', True) then
            Reg.WriteString('MagicBoard', Application.ExeName)
    finally
        Reg.CloseKey;
        Reg.Free;
    end;
end;

procedure TMainForm.LoadFromRegistry;
var
    Reg: TRegistry;
    WindowsBit: integer;
begin
    Reg:= TRegistry.Create;
    Reg.RootKey:= HKEY_LOCAL_MACHINE;
    try
        if Reg.OpenKey('\SOFTWARE\BlankSoft\MagicBoard', True) then begin
            if (Reg.ValueExists('Client Number')) then Edit2.Text:= Reg.ReadString ('Client Number') else Edit2.Text:= '1';
            if (Reg.ValueExists('Server IP'    )) then Edit1.Text:= Reg.ReadString ('Server IP')   else Edit1.Text:= '127.0.0.1';
            if (Reg.ValueExists('Server Port'  )) then Edit3.Text:= Reg.ReadString ('Server Port') else Edit3.Text:= '51111';
            if (Reg.ValueExists('Http Port'    )) then Edit4.Text:= Reg.ReadString ('Http Port')   else Edit4.Text:= '8001';
            if (Reg.ValueExists('MagicInfo'    )) then Edit5.Text:= Reg.ReadString ('MagicInfo')   else Edit5.Text:= 'nil';
            // 현재의 Windows가 32bit인지 64bit인지 확인한다
            if DirectoryExists('C:\Program Files (x86)') then WindowsBit:= 64 else WindowsBit:= 32;
            if (Reg.ValueExists('Windows Bit')) then WindowsBit:= Reg.ReadInteger ('Windows Bit');
            if (WindowsBit = 32) then ProgramFiles:= 'C:\Program Files\' else ProgramFiles:= 'C:\Program Files (x86)\';
            Reg.CloseKey;
        end;
    finally
        Reg.CloseKey;
        Reg.Free;
    end;
end;

procedure TMainForm.LoadFromIniFile;
var
	IniFile: TIniFile;
    WindowsBit: integer;
begin
    // ini 파일이 없다면 Registry에서 읽어온다
    if not FileExists (IniFileName) then begin
        LoadFromRegistry; exit;
    end;

	IniFile:= TIniFile.Create (IniFileName);
	try
		try
            Edit2.Text:= IniFile.ReadString ('Options', 'Client Number', '1');
            Edit1.Text:= IniFile.ReadString ('Options', 'Server IP', '127.0.0.1');
            Edit3.Text:= IniFile.ReadString ('Options', 'Server Port', '51111');
            Edit4.Text:= IniFile.ReadString ('Options', 'Http Port', '8001');
            Edit5.Text:= IniFile.ReadString ('Options', 'MagicInfo', 'nil');
            // 현재의 Windows가 32bit인지 64bit인지 확인한다
            if DirectoryExists('C:\Program Files (x86)') then WindowsBit:= 64 else WindowsBit:= 32;
            WindowsBit:= IniFile.ReadInteger ('Options', 'Windows Bit', WindowsBit);
            if (WindowsBit = 32) then ProgramFiles:= 'C:\Program Files\' else ProgramFiles:= 'C:\Program Files (x86)\';
            IniFile.WriteInteger('Options', 'Windows Bit', WindowsBit);
		except
		end;
	finally
		IniFile.Free;
	end;

	// 버튼의 Visible도 Menu를 따라간다
	// 현재는 해당사항 없음
end;

procedure TMainForm.SaveToIniFile;
var
    IniFile: TIniFile;
begin
    IniFile:= TIniFile.Create (IniFileName);
    if (IniFile = nil) then exit;
    try
        try
            IniFile.WriteString ('Options', 'Client Number', Client1.Number);
            IniFile.WriteString ('Options', 'Server IP',     Client1.Server);
            IniFile.WriteInteger('Options', 'Server Port',   Client1.ServerPort);
            IniFile.WriteString ('Options', 'Http Port',     Client1.HttpPort);
            IniFile.WriteString ('Options', 'MagicInfo',     Album1.MagicInfo);
        except
        end;
    finally
        IniFile.Free;
    end;
end;


procedure TMainForm.SetScreenSize;
begin
    // 폼의 기본색깔을 검은색으로
    Color:= clBlack;

    // 화면을 최대로 키운다.
    Width:= Screen.Width;
    Height:= Screen.Height;

    // 이미지 영역의 크기
    Image1.Align:= alClient;
    WMP1.Align:= alClient;

    // 크기조정 한후에 Hide시켜야 한다
    Image1.Hide;
    WMP1.Hide;

    // 마우스 커서 치우기 초기화 (현재위치 기준)
    // GetOffMouse (0, 0);

    // 파일이름 출력할 Label 위치
    curFile.Top:= Height - 50;

    // Debug창 크기
    Memo1.Width:= 640;
    Memo1.Height:= 540;
end;

procedure TMainForm.ImageFileFound (FileName: string);
begin
    // 옵션에 따라 Caption을 표시할지 말지 설정할수 있게할것
    curFile.Caption:= FileName;
end;

procedure TMainForm.Memo_Out_Detail (msg: string);
begin
    {$IFOPT D+}
    if (Memo1 <> nil) then begin
        Memo1.Lines.Add (msg);
        LogFile1.AppendText (msg);
        SendMessage(Memo1.Handle, EM_SCROLLCARET, 0, 0);
    end;
    {$ENDIF}
end;

procedure TMainForm.cbClientClick(Sender: TObject);
begin
    // 디버그창에서 Client의 메세지만 보여준다
    if cbClient.Checked then
        Client1.OnMemoOut:= Memo_Out_Detail
    else Client1.OnMemoOut:= nil;

    // 디버그창에서 Album의 메세지만 보여준다
    if cbAlbum.Checked then
        Album1.OnMemoOut:= Memo_Out_Detail
    else Album1.OnMemoOut:= nil;
end;

procedure TMainForm.Album1State (AState: string);
begin
    Client1.AlbumState:= AState;
    // Album 운영상태를 Server로 통보해 준다
    Client1.SendTextToServer ('AlbumState=' + AState);
    Memo_Out_Detail ('전송: AlbumState=' + AState);
end;





// ----------------------------------------------------------------------------
// 여기서부터 Event 관련 함수
// ----------------------------------------------------------------------------

procedure TMainForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
    {$IFOPT D-}
    if (X > Panel1.Width) or (Y > Panel1.Height) then Panel1.Hide else Panel1.Show;
    {$ELSE}
    if (X > Panel1.Width) or (Y > Panel1.Height+200) then
    begin
        Panel1.Hide; Memo1.Hide;
    end else begin
        Panel1.Show; Memo1.Show;
    end;
    {$ENDIF}
end;

procedure TMainForm.WMP1MouseMove(Sender: TObject; nButton, nShiftState: Smallint; fX, fY: Integer);
begin
    FormMouseMove (Sender, [], fX, fY);
end;

procedure TMainForm.WMP1PlayStateChange(Sender: TObject; NewState: Integer);
begin
    // if (NewState <> wmppsPlaying) then Album1.PlayNextFile;
    Memo_Out_Detail ('WMP1.PlayState = ' + inttostr(NewState));
end;

procedure TMainForm.saveButtonClick(Sender: TObject);
begin
    // 설정값을 적용한다
    Client1.Server:= Edit1.Text;
    Client1.Number:= Edit2.Text;
    SaveToIniFile;
end;

procedure TMainForm.aboutButtonClick(Sender: TObject);
begin
    ShowMessage (MyCopyRight);
end;

procedure TMainForm.exitButtonClick(Sender: TObject);
begin
    Close;
end;

procedure TMainForm.nextButtonClick(Sender: TObject);
begin
    Album1.PlayNextFile;
end;


procedure TMainForm.Timer1Timer(Sender: TObject);
begin
    GetOffMouse (Screen.Width, Screen.Height-300);
end;


procedure TMainForm.Client1ProcessCommand (cmd: string);
begin
    // 전원제어 명령 => 즉시 실행한다
    if (cmd = 'PWR_OFF') then
        ShellExecute (0, nil, PChar('shutdown'), PChar('-s -f -t 3'), nil, SW_NORMAL)
    else if (cmd = 'PWR_REBOOT') then
        ShellExecute (0, nil, PChar('shutdown'), PChar('-r -f -t 3'), nil, SW_NORMAL)

    // 매직인포 실행 => 즉시 실행한다. 나머지 명령은 파일을 추가로 받아야 함
    else if (cmd = 'RUN_MIP') or (cmd = 'RUN_MIIP') then begin
        Album1.RunMagicInfo (cmd);
        Edit5.Text:= Album1.MagicInfo;
        SaveToIniFile;  // MagicInfo=Pro/Premium 저장
    end

    else if (cmd = 'STOP_MIP') or (cmd = 'STOP_MIIP') then begin
        Album1.StopMagicInfo;
        Edit5.Text:= Album1.MagicInfo;
        SaveToIniFile;  // MagicInfo=nil 저장
    end

    // 위의 경우가 아니라면 Album은 일단 종료시킨다. 파일 삭제됨.
    else Album1.Stop (cmd);
end;


procedure TMainForm.Client1DoneFile (cmd, FileName: string);
begin
    Memo_Out_Detail ('--MainForm.ClientDoneFile 진입: cmd='+cmd+', FileName='+FileName);
    Client1.SendTextToServer ('DoneFileDownload');

    // PPT 파일 다운완료시
    if (cmd = 'SEND_PPT') or (cmd = 'SEND_PPTX') then Album1.RunPpt (FileName) else

    // 추가파일들 다운완료시: FileName = AdditionalFileName
    if (cmd = 'SEND_ADDLIST') then Album1.RunPptFiles else

    // 스케줄 관련파일들 다운완료시: FileName = ScheduleFileName
    if (cmd = 'SEND_SCHEDULE') then Album1.RunPptSchedule else

    // 매직앨범 관련파일들 다운완료시: FileName = AlbumFileName
    if (cmd = 'SEND_ALBUM') then Album1.RunAlbum;
end;

end.

