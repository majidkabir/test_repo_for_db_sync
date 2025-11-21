CREATE TABLE [dbo].[sce_dl_channelinvhold_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [HoldType] nvarchar(10) NULL DEFAULT (''),
    [Sourcekey] nvarchar(10) NULL DEFAULT (''),
    [SourceLineNo] nvarchar(5) NULL DEFAULT (''),
    [Qty] int NULL DEFAULT ((0)),
    [Hold] nvarchar(1) NULL DEFAULT ('0'),
    [Storerkey] nvarchar(15) NULL DEFAULT (''),
    [Sku] nvarchar(20) NULL DEFAULT (''),
    [Facility] nvarchar(15) NULL DEFAULT (''),
    [Channel] nvarchar(20) NULL DEFAULT (''),
    [C_Attribute01] nvarchar(30) NULL DEFAULT (''),
    [C_Attribute02] nvarchar(30) NULL DEFAULT (''),
    [C_Attribute03] nvarchar(30) NULL DEFAULT (''),
    [C_Attribute04] nvarchar(30) NULL DEFAULT (''),
    [C_Attribute05] nvarchar(30) NULL DEFAULT (''),
    [Channel_ID] bigint NULL DEFAULT ((0)),
    [Remarks] nvarchar(255) NULL DEFAULT (''),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_SCE_DL_CHANNELINVHOLD_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_CHANNELINVHOLD_STG_Idx01] ON [dbo].[sce_dl_channelinvhold_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_CHANNELINVHOLD_STG_Idx02] ON [dbo].[sce_dl_channelinvhold_stg] ([STG_BatchNo], [STG_SeqNo]);
GO