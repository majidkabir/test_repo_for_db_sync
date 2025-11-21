CREATE TABLE [rdt].[rdtptlpiecelog_dellog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [RowRefSource] int NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_name()),
    CONSTRAINT [PK_rdtPTLPieceLog_Dellog] PRIMARY KEY ([RowRef])
);
GO
