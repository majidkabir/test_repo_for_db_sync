CREATE TABLE [rdt].[rdtreceiveaudit]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NULL,
    [ReceiptKey] nvarchar(20) NULL,
    [UCCNo] nvarchar(20) NULL DEFAULT (''),
    [Sku] nvarchar(20) NULL,
    [Descr] nvarchar(60) NULL,
    [PQty] int NULL,
    [CQty] int NULL,
    [Position] nvarchar(20) NULL,
    [NoofCheck] int NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (getdate()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_RDTReceiveAudit] PRIMARY KEY ([RowRef])
);
GO
