CREATE TABLE [rdt].[rdtmoveucclog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [RecNo] int NOT NULL,
    [UCCNo] nvarchar(20) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_name()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtMoveUCCLog] PRIMARY KEY ([RowRef])
);
GO
