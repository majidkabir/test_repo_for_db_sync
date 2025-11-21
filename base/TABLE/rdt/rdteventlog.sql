CREATE TABLE [rdt].[rdteventlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StartDate] datetime NOT NULL DEFAULT (getdate()),
    [UserID] nvarchar(128) NOT NULL DEFAULT (''),
    [Activity] nvarchar(20) NOT NULL DEFAULT (''),
    [FunctionID] int NOT NULL DEFAULT ((0)),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKRDTEventLog] PRIMARY KEY ([RowRef])
);
GO
