CREATE TABLE [dbo].[skuxlocintegrity]
(
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Loc] nvarchar(10) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [ParentSKU] nvarchar(20) NOT NULL DEFAULT (''),
    [ID] nvarchar(18) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [EntryValue] nvarchar(30) NOT NULL DEFAULT (''),
    [Code] nvarchar(20) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [QtyCount] int NULL DEFAULT ((0)),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_SKUxLOCIntegrity] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [IDX_SLI_ID_LOC_EntryValue] ON [dbo].[skuxlocintegrity] ([ID], [Loc], [EntryValue]);
GO