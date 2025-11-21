CREATE TABLE [rdt].[rdtserialnolog]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [Status] nvarchar(2) NOT NULL DEFAULT ('0'),
    [SerialType] nvarchar(10) NOT NULL DEFAULT ('0'),
    [FromSerialNo] nvarchar(20) NULL DEFAULT (''),
    [ToSerialNo] nvarchar(20) NULL DEFAULT (''),
    [ParentSerialNo] nvarchar(20) NULL DEFAULT (''),
    [FromSKU] nvarchar(20) NULL DEFAULT (''),
    [ToSKU] nvarchar(20) NULL DEFAULT (''),
    [SourceKey] nvarchar(10) NULL DEFAULT (''),
    [SourceType] nvarchar(10) NULL DEFAULT (''),
    [BatchKey] nvarchar(10) NULL DEFAULT (''),
    [BatchKey2] nvarchar(10) NULL DEFAULT (''),
    [Remarks] nvarchar(500) NULL DEFAULT (''),
    [Func] int NULL DEFAULT ((0)),
    [Func2] int NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_rdtSerialNoLog] PRIMARY KEY ([RowRef])
);
GO
