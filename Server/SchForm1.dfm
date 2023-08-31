object SchForm: TSchForm
  Left = 290
  Top = 172
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsDialog
  Caption = ' '#54028#51068#47785#47197' '#48143' '#49828#52992#51460' '#51089#49457
  ClientHeight = 558
  ClientWidth = 539
  Color = clBtnFace
  Font.Charset = HANGEUL_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #44404#47548
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 12
  object GroupBox1: TGroupBox
    Left = 8
    Top = 8
    Width = 521
    Height = 537
    Caption = #51204#49569#54624' '#54028#51068#47785#47197' '#51089#49457
    TabOrder = 0
    object Label1: TLabel
      Left = 16
      Top = 24
      Width = 296
      Height = 12
      Caption = #48372#45244' '#54028#51068#46308#51012' Drag && Drop '#54616#50668' '#52628#44032#54616#49884#44592' '#48148#46989#45768#45796'.'
    end
    object Label2: TLabel
      Left = 16
      Top = 48
      Width = 292
      Height = 12
      Caption = #47700#47784#51109#50640#49436' '#51088#50976#47213#44172' '#51116#49373' '#49692#49436#47484' '#48320#44221#54624' '#49688' '#51080#49845#45768#45796'.'
    end
    object pMemo: TMemo
      Left = 16
      Top = 72
      Width = 489
      Height = 417
      ImeName = 'Microsoft Office IME 2007'
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
    end
    object openButton: TButton
      Left = 112
      Top = 500
      Width = 89
      Height = 25
      Caption = #54028#51068#52628#44032'...'
      TabOrder = 1
      OnClick = openButtonClick
    end
    object saveButton: TButton
      Left = 216
      Top = 500
      Width = 89
      Height = 25
      Caption = #47785#47197#51200#51109
      TabOrder = 2
      OnClick = saveButtonClick
    end
    object sendButton: TButton
      Left = 320
      Top = 500
      Width = 89
      Height = 25
      Caption = #47785#47197#51204#49569
      Default = True
      ModalResult = 1
      TabOrder = 3
      OnClick = sendButtonClick
    end
  end
  object FileDrop1: TFileDrop
    EnableDrop = True
    DropControl = Owner
    OnDrop = FileDrop1Drop
    Left = 104
    Top = 96
  end
  object OpenDialog1: TOpenDialog
    Filter = #54028#50892#54252#51064#53944' '#54028#51068' (ppt, pptx)|*.ppt; *.pptx'
    Options = [ofReadOnly, ofHideReadOnly, ofAllowMultiSelect, ofEnableSizing]
    Title = ' '#54028#50892#54252#51064#53944' '#54028#51068' '#52628#44032
    Left = 72
    Top = 96
  end
  object OpenDialog0: TOpenDialog
    Filter = 
      #54028#50892#54252#51064#53944' (ppt, pptx, pps, pot)|*.ppt; *.pptx; *.pps; *.pot|'#44536#47548#54028#51068' (jp' +
      'g, bmp, jpeg, wmf)|*.jpg; *.bmp; *.jpeg; *.wmf|'#46041#50689#49345' (wmv, avi, mp' +
      '4, mpg, asf)|*.mp4; *.avi; *.mp4; *.mpg; *.asf|'#47784#46304' '#54028#51068'|*.*'
    Options = [ofReadOnly, ofHideReadOnly, ofAllowMultiSelect, ofEnableSizing]
    Title = ' '#51333#47448#48324#47196' '#54596#53552' '#45796#51080#45716#44163
    Left = 40
    Top = 96
  end
end
