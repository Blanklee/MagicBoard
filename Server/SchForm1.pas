unit SchForm1;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms,
  StdCtrls, Dialogs, FileDrop, BlankUtils, Globals;

type
  TSchForm = class(TForm)
	GroupBox1: TGroupBox;
	Label1: TLabel;
	Label2: TLabel;
	pMemo: TMemo;
	openButton: TButton;
	saveButton: TButton;
	FileDrop1: TFileDrop;
	OpenDialog1: TOpenDialog;
	sendButton: TButton;
	OpenDialog0: TOpenDialog;
	procedure FormCreate(Sender: TObject);
	procedure FileDrop1Drop(Sender: TObject);
	procedure openButtonClick(Sender: TObject);
	procedure saveButtonClick(Sender: TObject);
	procedure sendButtonClick(Sender: TObject);
  private
	FTotalSize: int64;
	FFolderName: string;
	function getTotalSize: int64;
	procedure AddFileToMemo (AFileName: string);
  public
	{ Public declarations }
  end;

var
  SchForm: TSchForm;

implementation

// uses PreviewForm1;

{$R *.DFM}


// ----------------------------------------------------------------------------
// 여기서부터 초기화 및 종료관련 함수
// ----------------------------------------------------------------------------

procedure TSchForm.FormCreate(Sender: TObject);
begin
	FTotalSize:= 0;
	FFolderName:= ExtractFilePath(Application.ExeName);

	// PlayList를 불러온다
	if FileExists (FFolderName+ScheduleFileName) then
	pMemo.Lines.LoadFromFile (FFolderName+ScheduleFileName);
end;



// ----------------------------------------------------------------------------
// 여기서부터 내부 Private 함수
// ----------------------------------------------------------------------------

function TSchForm.getTotalSize: int64;
var
	i: integer;
	s: string;
	ts: int64;
begin
	// 보낼 파일들의 총 용량을 구한다
	Result:= 0;
	for i:= 1 to pMemo.Lines.Count do begin
		s:= pMemo.Lines[i-1];
		if (s = '') then continue;
		if (s[1] = '/') then continue;
		ts:= File_Size (s, 0);
		// 실제로 보내지는 Header Size 등을 감안하여 150을 추가로 더해준다
		if (ts > 0) then Result:= Result + ts + 150;
	end;
end;

procedure TSchForm.AddFileToMemo (AFileName: string);
var
	s: string;
begin
	// if File_Size (FileDrop1.Files[i-1]) > 0 then
	// if 확장자가 jpg wmv ppt 등의 미디어일 때만 추가한다
	s:= UpperCase (ExtractFileExt (AFileName));
	if (s='.JPG') or (s='.BMP') or (s='.JPEG') or (s='.WMF') or
	   (s='.WMV') or (s='.AVI')  or (s='.MP4') or (s='.MPG') or (s='.ASF') or
	   (s='.PPT') or (s='.PPTX') or (s='.PPS') or (s='.POT') then
	pMemo.Lines.Add (AFileName);
end;




// ----------------------------------------------------------------------------
// 여기서부터 Button Click 및 기본 Event 함수
// ----------------------------------------------------------------------------

procedure TSchForm.FileDrop1Drop(Sender: TObject);
var
	i: integer;
begin
	for i:= 1 to FileDrop1.FileCount do AddFileToMemo (FileDrop1.Files[i-1]);
end;

procedure TSchForm.openButtonClick(Sender: TObject);
var
	i: integer;
begin
	if (OpenDialog1.Execute) then
	for i:= 1 to OpenDialog1.Files.Count do AddFileToMemo (OpenDialog1.Files[i-1]);
end;

procedure TSchForm.saveButtonClick(Sender: TObject);
begin
	pMemo.Lines.SaveToFile (FFolderName+ScheduleFileName)
end;

procedure TSchForm.sendButtonClick(Sender: TObject);
begin
	// 작성했던 내용을 파일로 저장한다.
	saveButtonClick (Sender);

	// 보낼 파일의 총용량을 구한다.
	FTotalSize:= getTotalSize;
	if (FTotalSize <= 0) then Close;
end;

end.

