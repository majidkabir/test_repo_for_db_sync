CREATE TABLE [rdt].[rdtprereceivesort2log]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Facility] nvarchar(10) NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [ReceiptKey] nvarchar(10) NULL,
    [UCCNo] nvarchar(20) NOT NULL,
    [SKU] nvarchar(20) NULL,
    [Qty] int NULL,
    [LOC] nvarchar(10) NOT NULL,
    [ID] nvarchar(18) NULL,
    [UDF01] nvarchar(20) NULL,
    [UDF02] nvarchar(20) NULL,
    [UDF03] nvarchar(20) NULL,
    [UDF04] nvarchar(20) NULL,
    [UDF05] nvarchar(20) NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PKPreReceiveSortLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_rdtPreReceiveSort2Log_UCCNo_StorerKey] ON [rdt].[rdtprereceivesort2log] ([UCCNo], [StorerKey]);
GO