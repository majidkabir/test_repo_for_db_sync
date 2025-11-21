CREATE TABLE [dbo].[geekplusrbt_invsync]
(
    [ID] bigint IDENTITY(1,1) NOT NULL,
    [TranID] nvarchar(20) NOT NULL DEFAULT (''),
    [MsgCode] nvarchar(10) NOT NULL DEFAULT (''),
    [Message] nvarchar(60) NOT NULL DEFAULT (''),
    [SkuAmount] int NOT NULL DEFAULT ((0)),
    [TotalPageNum] int NOT NULL DEFAULT ((0)),
    [CurrentPage] int NOT NULL DEFAULT ((0)),
    [PageSize] int NOT NULL DEFAULT ((0)),
    [OwnerCode] nvarchar(16) NOT NULL DEFAULT (''),
    [SkuCode] nvarchar(64) NOT NULL DEFAULT (''),
    [SkuLevel] int NOT NULL DEFAULT ((0)),
    [Amount] int NOT NULL DEFAULT ((0)),
    [AuditDate] bigint NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKGeekPlusRBT_InvSync] PRIMARY KEY ([ID])
);
GO
