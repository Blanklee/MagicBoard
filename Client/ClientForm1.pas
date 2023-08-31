unit ClientForm1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  StdCtrls, ExtCtrls, Registry, IniFiles, Dialogs, ShellApi, OleCtrls,
  WMPLib_TLB, BlankUtils, Globals, Client, Album;

const
  TrialVersion = '';
  MyCopyRight = '�����Խ��� v4.4e  for Samsung Display'#13#10;

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
// ���⼭���� TLogFile �Լ�
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
// ���⼭���� ������ �Լ�
// ----------------------------------------------------------------------------

procedure TMainForm.FormCreate(Sender: TObject);
begin
    ForceDirectories (FolderName);
    ChDir (FolderName);

    RegisterAutorunAtBoot;	// ���ý� �ڵ����� ����
    LoadFromIniFile;		// �������� �ҷ��´�
    SetScreenSize;			// ���� ȭ�鼳��
    Panel1.BringToFront;
    Memo1.BringToFront;

    // Trial Version
    if (TrialVersion = 'Trial') then begin
        TrialLabel.Left:= (Screen.Width - trialLabel.Width) div 2;
        TrialLabel.BringToFront;
        TrialLabel.Show;
    end;

    {$IFOPT D+}
    // LogFile ����� ���� Class
    LogFile1:= TLogFile.Create;
    {$ENDIF}

    // Server�� ����ϱ� ���� Client
    Client1:= TClient.Create;
    Client1.OnCommand:= Client1ProcessCommand;
    Client1.OnDoneFile:= Client1DoneFile;
    Client1.OnMemoOut:= Memo_Out_Detail;
    Client1.Number:= Edit2.Text;
    Client1.Server:= Edit1.Text;
    Client1.ServerPort:= strtoint32 (Edit3.Text, 51111);
    Client1.HttpPort:= Edit4.Text;

    // �ٹ����� �ϳ��� �����ش�.
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
            // ������ Windows�� 32bit���� 64bit���� Ȯ���Ѵ�
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
    // ini ������ ���ٸ� Registry���� �о�´�
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
            // ������ Windows�� 32bit���� 64bit���� Ȯ���Ѵ�
            if DirectoryExists('C:\Program Files (x86)') then WindowsBit:= 64 else WindowsBit:= 32;
            WindowsBit:= IniFile.ReadInteger ('Options', 'Windows Bit', WindowsBit);
            if (WindowsBit = 32) then ProgramFiles:= 'C:\Program Files\' else ProgramFiles:= 'C:\Program Files (x86)\';
            IniFile.WriteInteger('Options', 'Windows Bit', WindowsBit);
		except
		end;
	finally
		IniFile.Free;
	end;

	// ��ư�� Visible�� Menu�� ���󰣴�
	// ����� �ش���� ����
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
    // ���� �⺻������ ����������
    Color:= clBlack;

    // ȭ���� �ִ�� Ű���.
    Width:= Screen.Width;
    Height:= Screen.Height;

    // �̹��� ������ ũ��
    Image1.Align:= alClient;
    WMP1.Align:= alClient;

    // ũ������ ���Ŀ� Hide���Ѿ� �Ѵ�
    Image1.Hide;
    WMP1.Hide;

    // ���콺 Ŀ�� ġ��� �ʱ�ȭ (������ġ ����)
    // GetOffMouse (0, 0);

    // �����̸� ����� Label ��ġ
    curFile.Top:= Height - 50;

    // Debugâ ũ��
    Memo1.Width:= 640;
    Memo1.Height:= 540;
end;

procedure TMainForm.ImageFileFound (FileName: string);
begin
    // �ɼǿ� ���� Caption�� ǥ������ ���� �����Ҽ� �ְ��Ұ�
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
    // �����â���� Client�� �޼����� �����ش�
    if cbClient.Checked then
        Client1.OnMemoOut:= Memo_Out_Detail
    else Client1.OnMemoOut:= nil;

    // �����â���� Album�� �޼����� �����ش�
    if cbAlbum.Checked then
        Album1.OnMemoOut:= Memo_Out_Detail
    else Album1.OnMemoOut:= nil;
end;

procedure TMainForm.Album1State (AState: string);
begin
    Client1.AlbumState:= AState;
    // Album ����¸� Server�� �뺸�� �ش�
    Client1.SendTextToServer ('AlbumState=' + AState);
    Memo_Out_Detail ('����: AlbumState=' + AState);
end;





// ----------------------------------------------------------------------------
// ���⼭���� Event ���� �Լ�
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
    // �������� �����Ѵ�
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
    // �������� ��� => ��� �����Ѵ�
    if (cmd = 'PWR_OFF') then
        ShellExecute (0, nil, PChar('shutdown'), PChar('-s -f -t 3'), nil, SW_NORMAL)
    else if (cmd = 'PWR_REBOOT') then
        ShellExecute (0, nil, PChar('shutdown'), PChar('-r -f -t 3'), nil, SW_NORMAL)

    // �������� ���� => ��� �����Ѵ�. ������ ����� ������ �߰��� �޾ƾ� ��
    else if (cmd = 'RUN_MIP') or (cmd = 'RUN_MIIP') then begin
        Album1.RunMagicInfo (cmd);
        Edit5.Text:= Album1.MagicInfo;
        SaveToIniFile;  // MagicInfo=Pro/Premium ����
    end

    else if (cmd = 'STOP_MIP') or (cmd = 'STOP_MIIP') then begin
        Album1.StopMagicInfo;
        Edit5.Text:= Album1.MagicInfo;
        SaveToIniFile;  // MagicInfo=nil ����
    end

    // ���� ��찡 �ƴ϶�� Album�� �ϴ� �����Ų��. ���� ������.
    else Album1.Stop (cmd);
end;


procedure TMainForm.Client1DoneFile (cmd, FileName: string);
begin
    Memo_Out_Detail ('--MainForm.ClientDoneFile ����: cmd='+cmd+', FileName='+FileName);
    Client1.SendTextToServer ('DoneFileDownload');

    // PPT ���� �ٿ�Ϸ��
    if (cmd = 'SEND_PPT') or (cmd = 'SEND_PPTX') then Album1.RunPpt (FileName) else

    // �߰����ϵ� �ٿ�Ϸ��: FileName = AdditionalFileName
    if (cmd = 'SEND_ADDLIST') then Album1.RunPptFiles else

    // ������ �������ϵ� �ٿ�Ϸ��: FileName = ScheduleFileName
    if (cmd = 'SEND_SCHEDULE') then Album1.RunPptSchedule else

    // �����ٹ� �������ϵ� �ٿ�Ϸ��: FileName = AlbumFileName
    if (cmd = 'SEND_ALBUM') then Album1.RunAlbum;
end;

end.

