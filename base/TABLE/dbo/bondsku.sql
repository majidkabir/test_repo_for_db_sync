CREATE TABLE [dbo].[bondsku]
(
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [itrnkey] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [busr5] nvarchar(30) NULL DEFAULT (' '),
    [itemclass] nvarchar(10) NULL DEFAULT (' '),
    [style] nvarchar(20) NULL DEFAULT (' '),
    [color] nvarchar(10) NULL DEFAULT (' '),
    [size] nvarchar(5) NULL DEFAULT (' '),
    [measurement] nvarchar(5) NULL DEFAULT (' '),
    [status] nvarchar(1) NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [SKUGROUP] nvarchar(10) NOT NULL DEFAULT (' '),
    CONSTRAINT [PK_bondsku] PRIMARY KEY ([SeqNo])
);
GO
