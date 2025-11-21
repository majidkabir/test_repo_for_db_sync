CREATE TABLE [rdt].[rdtprintjob_log_dellog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [RowRefSource] int NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_name()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_RDTPrintJob_Log_Dellog] PRIMARY KEY ([RowRef])
);
GO
