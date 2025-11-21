CREATE TABLE [dbo].[dbstatustrack]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [ObjName] sysname NOT NULL,
    [Type] nvarchar(10) NOT NULL,
    [TSQL] nvarchar(MAX) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [Hostname] nvarchar(25) NOT NULL DEFAULT (host_name()),
    CONSTRAINT [PK_DBStatusTrack] PRIMARY KEY ([RowRef])
);
GO
