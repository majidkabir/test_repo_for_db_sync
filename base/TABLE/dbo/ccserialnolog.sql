CREATE TABLE [dbo].[ccserialnolog]
(
    [CountSerialKey] bigint IDENTITY(1,1) NOT NULL,
    [CCKey] nvarchar(10) NOT NULL,
    [CCDetailKey] nvarchar(10) NOT NULL,
    [CCSheetNo] nvarchar(10) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SerialNo] nvarchar(30) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NULL DEFAULT ((0)),
    [Lot] nvarchar(10) NOT NULL,
    [Loc] nvarchar(10) NOT NULL,
    [ID] nvarchar(18) NOT NULL,
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(18) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(18) NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PK_CCSerialNoLog] PRIMARY KEY ([CountSerialKey])
);
GO
