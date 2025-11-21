CREATE TABLE [dbo].[inventoryqc]
(
    [QC_Key] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Reason] nvarchar(10) NOT NULL,
    [TradeReturnKey] nvarchar(10) NOT NULL,
    [Refno] nvarchar(10) NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [from_facility] nvarchar(5) NULL,
    [to_facility] nvarchar(5) NULL,
    [UserDefine01] nvarchar(20) NULL DEFAULT (' '),
    [UserDefine02] nvarchar(20) NULL DEFAULT (' '),
    [UserDefine03] nvarchar(20) NULL DEFAULT (' '),
    [UserDefine04] nvarchar(20) NULL DEFAULT (' '),
    [UserDefine05] nvarchar(20) NULL DEFAULT (' '),
    [UserDefine06] datetime NULL,
    [UserDefine07] datetime NULL,
    [UserDefine08] nvarchar(10) NULL DEFAULT ('N'),
    [UserDefine09] nvarchar(10) NULL DEFAULT (' '),
    [UserDefine10] nvarchar(10) NULL DEFAULT (' '),
    [Notes] nvarchar(4000) NULL,
    [FinalizeFlag] nvarchar(1) NULL DEFAULT ('N'),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_InventoryQC] PRIMARY KEY ([QC_Key])
);
GO
