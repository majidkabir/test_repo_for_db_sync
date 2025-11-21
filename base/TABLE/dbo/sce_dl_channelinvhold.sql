CREATE TABLE [dbo].[sce_dl_channelinvhold]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [HoldType] nvarchar(10) NOT NULL DEFAULT (''),
    [Sourcekey] nvarchar(10) NULL DEFAULT (''),
    [SourceLineNo] nvarchar(5) NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [Hold] nvarchar(1) NOT NULL DEFAULT ('0'),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Sku] nvarchar(20) NOT NULL DEFAULT (''),
    [Facility] nvarchar(15) NOT NULL DEFAULT (''),
    [Channel] nvarchar(20) NOT NULL DEFAULT (''),
    [C_Attribute01] nvarchar(30) NULL DEFAULT (''),
    [C_Attribute02] nvarchar(30) NULL DEFAULT (''),
    [C_Attribute03] nvarchar(30) NULL DEFAULT (''),
    [C_Attribute04] nvarchar(30) NULL DEFAULT (''),
    [C_Attribute05] nvarchar(30) NULL DEFAULT (''),
    [Channel_ID] bigint NOT NULL DEFAULT ((0)),
    [Remarks] nvarchar(255) NULL DEFAULT (''),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    [Adddate] datetime NOT NULL DEFAULT (getdate()),
    [Addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_SCE_DL_CHANNELINVHOLD] PRIMARY KEY ([RowRefNo])
);
GO
