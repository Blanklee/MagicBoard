unit Globals;

interface

uses
  SysUtils, Classes, Forms, ComCtrls;

const
  // �������� ���Ǵ� �����
  AdditionalFileName = 'AddFile_List.txt';
  ScheduleFileName = 'Schedule_List.txt';
  AlbumFileName = 'AlbumFile_List.txt';

  // MainForm���� ���Ǵ� �����
  MAX_CLIENTS = 132;
  TrialVersion = '';
  IniFileName = 'MagicBoard.ini';
  MyCopyRight = '�����Խ��� v4.4e  for Samsung Display.'#13#10;

var
  // �������� ���Ǵ� ����������
  FolderName: string;       // ���α׷��� Ȱ���ϴ� ������
  ScheduleFolder: string;   // Client ���� ������ ��������
  ProgramFiles: string;		// C:\Program Files �Ǵ� C:\Program Files (x86)

type
  // ���� class���� �������� �ʿ��� �͵�
  TMemoOutEvent = procedure (msg: String) of object;
  TFileKind = (non, img, avi, ppt, setting);	// �̵�� ���� ���� or ���ð� ����

  PFileItem = ^TFileItem;
  TFileItem = record
	FileName: string;
	FileSize: int64;
	DateTime: integer;
	PlayTime: integer;
    GroupNode: TTreeNode;
  end;


// ���� �Լ���: BlackUtils�� �������� ����
function FileKind (AFileName: string): TFileKind;
procedure Delete_Files (ListFileName: string);



implementation


function FileKind (AFileName: string): TFileKind;
var
    s: string;
begin
	// ���� Ȯ���ڸ� �����Ѵ�: �������� �Ǻ�
	Result:= non;
	if (AFileName[1]='/') or (AFileName[1]='*') then Result:= setting
	else begin
		s:= UpperCase (ExtractFileExt (AFileName));
		if (s='.JPG') or (s='.BMP') or (s='.JPEG') or (s='.WMF') then Result:= img
		else if (s='.WMV') or (s='.AVI') or (s='.MP4') or (s='.MPG') or (s='.ASF') then Result:= avi
		else if (s='.PPT') or (s='.PPTX') or (s='.PPS') or (s='POT') then Result:= ppt;
	end;
end;

procedure Delete_Files (ListFileName: string);
var
	i: integer;
	s: string;
	st: TStringList;
begin
	if not FileExists (FolderName+ListFileName) then exit;

	// List�� �ִ� ��� File�� �����Ѵ�
	st:= TStringList.Create;
	try
		st.LoadFromFile (FolderName+ListFileName);
		for i:= 1 to st.Count do begin
			s:= Trim(st[i-1]);
			if (s='') then continue;
			if (s[1]='/') then continue;
			DeleteFile (FolderName + ExtractFileName (s));
		end;
	except
	end;
	st.Free;

	// List���� ��ü�� �����Ѵ�
	DeleteFile (FolderName+ListFileName);
end;


begin
    // �������� ����� ����������
	FolderName:= ExtractFilePath(Application.ExeName);
    // ������ ������ ���� ������ ����
    ScheduleFolder:= FolderName+'Schedules\';
    ForceDirectories (ScheduleFolder);
end.

