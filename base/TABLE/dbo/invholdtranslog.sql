CREATE TABLE [dbo].[invholdtranslog]
(
    [StorerKey] nvarchar(15) NULL,
    [Sku] nvarchar(20) NULL,
    [Facility] nvarchar(10) NULL,
    [SourceKey] nvarchar(18) NULL,
    [SourceType] nvarchar(10) NULL,
    [UserID] nvarchar(128) NULL,
    [RowID] int IDENTITY(1,1) NOT NULL,
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [Msgtext] nvarchar(100) NULL,
    CONSTRAINT [PK_InvHoldTransLog] PRIMARY KEY ([RowID])
);
GO
