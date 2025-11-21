CREATE TABLE [rdt].[rdtucc]
(
    [UCCNo] nvarchar(20) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [ReceiptKey] nvarchar(10) NULL DEFAULT (' '),
    [ExternKey] nvarchar(20) NULL,
    [Loc] nvarchar(10) NULL,
    [ID] nvarchar(18) NULL,
    [SKU] nvarchar(20) NOT NULL,
    [QTY] int NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [RowRef] int IDENTITY(1,1) NOT NULL,
    CONSTRAINT [PK_RDTUCC] PRIMARY KEY ([RowRef])
);
GO
