CREATE TABLE [dbo].[containerdetail]
(
    [ContainerKey] nvarchar(20) NOT NULL,
    [ContainerLineNumber] nvarchar(5) NOT NULL,
    [PalletKey] nvarchar(30) NOT NULL,
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [TimeStamp] nvarchar(18) NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [Userdefine01] nvarchar(30) NULL,
    [Userdefine02] nvarchar(30) NULL,
    [Userdefine03] nvarchar(30) NULL,
    [Userdefine04] nvarchar(30) NULL,
    [Userdefine05] nvarchar(30) NULL,
    CONSTRAINT [PKContainerDetail] PRIMARY KEY ([ContainerKey], [ContainerLineNumber])
);
GO
