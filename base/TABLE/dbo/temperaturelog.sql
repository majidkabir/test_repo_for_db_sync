CREATE TABLE [dbo].[temperaturelog]
(
    [TemperatureLogID] nvarchar(10) NOT NULL DEFAULT (' '),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Facility] nvarchar(5) NOT NULL DEFAULT (' '),
    [ReceiptKey] nvarchar(10) NULL DEFAULT (' '),
    [MbolKey] nvarchar(10) NULL DEFAULT (' '),
    [PalletId] nvarchar(30) NOT NULL DEFAULT (' '),
    [UCCNo] nvarchar(30) NULL DEFAULT (' '),
    [Temperature] decimal(5, 2) NULL,
    [TempCheckPoint] nvarchar(1) NOT NULL DEFAULT ('R'),
    [CheckDate] datetime NULL DEFAULT (getdate()),
    [CheckUser] nvarchar(128) NULL DEFAULT (suser_sname()),
    [UserDefine01] nvarchar(20) NULL DEFAULT (' '),
    [Userdefine02] nvarchar(20) NULL DEFAULT (' '),
    [Userdefine03] nvarchar(20) NULL DEFAULT (' '),
    [Userdefine04] nvarchar(20) NULL DEFAULT (' '),
    [Userdefine05] nvarchar(20) NULL DEFAULT (' '),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_TemperatureLog] PRIMARY KEY ([TemperatureLogID]),
    CONSTRAINT [UQ_temperaturelog_Facility_PalletId_UCCNo_CheckDate] UNIQUE ([Facility], [PalletId], [UCCNo], [CheckDate]),
    CONSTRAINT [FK_MBOL_MbolKey] FOREIGN KEY ([MbolKey]) REFERENCES [dbo].[MBOL] ([MbolKey]),
    CONSTRAINT [FK_Receipt_ReceiptKey] FOREIGN KEY ([ReceiptKey]) REFERENCES [dbo].[RECEIPT] ([ReceiptKey])
);
GO

CREATE INDEX [IDX_TemperatureLog_Facility_PalletID_UCCNo_CheckDate] ON [dbo].[temperaturelog] ([Facility], [PalletId], [UCCNo], [CheckDate]);
GO
CREATE INDEX [IDX_TemperatureLog_UCCNo] ON [dbo].[temperaturelog] ([UCCNo]);
GO