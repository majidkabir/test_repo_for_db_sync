CREATE TABLE [dbo].[buildprewave]
(
    [RowID] int IDENTITY(1,1) NOT NULL,
    [BuildParmKey] nvarchar(10) NOT NULL DEFAULT (''),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [NoOfOrders] int NOT NULL DEFAULT ((0)),
    [Column01] nvarchar(100) NULL DEFAULT (''),
    [Column02] nvarchar(100) NULL DEFAULT (''),
    [Column03] nvarchar(100) NULL DEFAULT (''),
    [Column04] nvarchar(100) NULL DEFAULT (''),
    [Column05] nvarchar(100) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_BUILDPREWAVE] PRIMARY KEY ([BuildParmKey], [RowID])
);
GO
