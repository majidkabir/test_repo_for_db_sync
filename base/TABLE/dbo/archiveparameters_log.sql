CREATE TABLE [dbo].[archiveparameters_log]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [ArchiveKey] nvarchar(10) NOT NULL,
    [FieldName] nvarchar(60) NULL DEFAULT (''),
    [OldValue] nvarchar(60) NULL DEFAULT (''),
    [NewValue] nvarchar(60) NULL DEFAULT (''),
    [ProgramName] nvarchar(128) NULL DEFAULT (object_name(@@procid)),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKARCHIVEPARAMETERS_LOG] PRIMARY KEY ([RowRef])
);
GO
