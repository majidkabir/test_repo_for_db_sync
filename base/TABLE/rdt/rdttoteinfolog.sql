CREATE TABLE [rdt].[rdttoteinfolog]
(
    [PIKNo] int NOT NULL,
    [Store] nvarchar(4) NOT NULL DEFAULT (''),
    [ToteNo] int NOT NULL DEFAULT ((0)),
    [StoreName] nvarchar(30) NULL,
    [ToteDate] datetime NULL,
    [Who] nvarchar(10) NULL,
    [Status] nvarchar(5) NULL DEFAULT ('0'),
    [Trailer] nvarchar(10) NULL,
    [ManifestNo] nvarchar(10) NULL,
    [MarshalDate] datetime NULL,
    [MarshalWho] nvarchar(18) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKrdtToteInfoLog] PRIMARY KEY ([PIKNo], [Store], [ToteNo])
);
GO
