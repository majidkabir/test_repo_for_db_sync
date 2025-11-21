CREATE TABLE [dbo].[waverelerrorreport]
(
    [SeqNo] bigint IDENTITY(1,1) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL,
    [LineText] nvarchar(MAX) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_WaveRelErrorReport] PRIMARY KEY ([SeqNo])
);
GO
