CREATE TABLE [rdt].[rdtecomqabatchlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [BatchNo] nvarchar(10) NOT NULL,
    [Station] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [QTYExpected] int NOT NULL,
    [QTY] int NOT NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtECOMQABatchLog] PRIMARY KEY ([RowRef])
);
GO
