CREATE TABLE [dbo].[holidaydetail]
(
    [HolidayKey] nvarchar(10) NOT NULL,
    [HolidayDate] datetime NOT NULL,
    [HolidayDescr] nvarchar(60) NULL,
    [UserDefine01] nvarchar(20) NULL,
    [UserDefine02] nvarchar(20) NULL,
    [UserDefine03] nvarchar(20) NULL,
    [UserDefine04] datetime NULL,
    [UserDefine05] datetime NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_HolidayDetail] PRIMARY KEY ([HolidayKey], [HolidayDate])
);
GO
