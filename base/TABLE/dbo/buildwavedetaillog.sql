CREATE TABLE [dbo].[buildwavedetaillog]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [BatchNo] bigint NOT NULL DEFAULT ((0)),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Wavekey] nvarchar(10) NOT NULL DEFAULT (''),
    [Duration] nvarchar(12) NOT NULL DEFAULT (''),
    [TotalOrderCnt] int NOT NULL DEFAULT ((0)),
    [TotalOrderQty] int NOT NULL DEFAULT ((0)),
    [TotalWeight] float NOT NULL DEFAULT ((0)),
    [TotalCube] float NOT NULL DEFAULT ((0)),
    [UDF01] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF02] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF03] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF04] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF05] nvarchar(30) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_buildwavedetaillog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_BuildWaveDetailLog_WaveKey] ON [dbo].[buildwavedetaillog] ([Wavekey]);
GO