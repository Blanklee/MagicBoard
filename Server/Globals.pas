unit Globals;

interface

uses
  SysUtils, Classes, Forms, ComCtrls;

const
  // 공통으로 사용되는 상수들
  AdditionalFileName = 'AddFile_List.txt';
  ScheduleFileName = 'Schedule_List.txt';
  AlbumFileName = 'AlbumFile_List.txt';

  // MainForm에서 사용되는 상수들
  MAX_CLIENTS = 132;
  TrialVersion = '';
  IniFileName = 'MagicBoard.ini';
  MyCopyRight = '매직게시판 v4.4e  for Samsung Display.'#13#10;

var
  // 공통으로 사용되는 전역변수들
  FolderName: string;       // 프로그램이 활용하는 주폴더
  ScheduleFolder: string;   // Client 개별 스케줄 저장폴더
  ProgramFiles: string;		// C:\Program Files 또는 C:\Program Files (x86)

type
  // 여러 class에서 공통으로 필요한 것들
  TMemoOutEvent = procedure (msg: String) of object;
  TFileKind = (non, img, avi, ppt, setting);	// 미디어 파일 종류 or 세팅값 변경

  PFileItem = ^TFileItem;
  TFileItem = record
	FileName: string;
	FileSize: int64;
	DateTime: integer;
	PlayTime: integer;
    GroupNode: TTreeNode;
  end;


// 공통 함수들: BlackUtils에 넣을수도 있음
function FileKind (AFileName: string): TFileKind;
procedure Delete_Files (ListFileName: string);



implementation


function FileKind (AFileName: string): TFileKind;
var
    s: string;
begin
	// 파일 확장자를 조사한다: 파일종류 판별
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

	// List에 있는 모든 File을 삭제한다
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

	// List파일 자체를 삭제한다
	DeleteFile (FolderName+ListFileName);
end;


begin
    // 공통으로 사용할 현재폴더명
	FolderName:= ExtractFilePath(Application.ExeName);
    // 스케줄 저장할 폴더 강제로 생성
    ScheduleFolder:= FolderName+'Schedules\';
    ForceDirectories (ScheduleFolder);
end.

