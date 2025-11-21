CREATE TABLE [dbo].[docstatustrack]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [TableName] nvarchar(30) NOT NULL DEFAULT (''),
    [DocumentNo] nvarchar(20) NOT NULL DEFAULT (''),
    [Key1] nvarchar(20) NOT NULL DEFAULT (''),
    [Key2] nvarchar(20) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [DocStatus] nvarchar(10) NULL DEFAULT ((0)),
    [TransDate] datetime NULL DEFAULT (getdate()),
    [Userdefine01] nvarchar(30) NULL,
    [Userdefine02] nvarchar(30) NULL,
    [Userdefine03] nvarchar(30) NULL,
    [Userdefine04] nvarchar(30) NULL,
    [Userdefine05] nvarchar(30) NULL,
    [Userdefine06] datetime NULL,
    [Userdefine07] datetime NULL,
    [Userdefine08] nvarchar(30) NULL,
    [Userdefine09] nvarchar(30) NULL,
    [Userdefine10] nvarchar(30) NULL,
    [Finalized] nchar(1) NULL DEFAULT ('N'),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    [HashValue] tinyint NOT NULL DEFAULT (abs(checksum(newid())%(256))),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_DocStatusTrack] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_DocStatusTrack] ON [dbo].[docstatustrack] ([TableName], [DocumentNo], [Key1], [Key2]);
GO
CREATE UNIQUE INDEX [IX_DocStatusTrack_HASHVALUE] ON [dbo].[docstatustrack] ([HashValue], [RowRef]);
GO