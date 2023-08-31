object MagicInfoForm: TMagicInfoForm
  Left = 375
  Top = 368
  Width = 273
  Height = 165
  Caption = #47588#51649#51064#54252' '#49440#53469
  Color = clBtnFace
  Font.Charset = HANGEUL_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #44404#47548
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 12
  object RadioGroup1: TRadioGroup
    Left = 8
    Top = 8
    Width = 249
    Height = 81
    Caption = #47588#51649#51064#54252' '#51333#47448' '#49440#53469
    Items.Strings = (
      #47588#51649#51064#54252' Pro'
      #47588#51649#51064#54252' Premium-i')
    TabOrder = 2
  end
  object Button1: TButton
    Left = 48
    Top = 104
    Width = 75
    Height = 25
    Caption = #54869#51064
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
  object Button2: TButton
    Left = 136
    Top = 104
    Width = 75
    Height = 25
    Cancel = True
    Caption = #52712#49548
    ModalResult = 2
    TabOrder = 1
  end
end
