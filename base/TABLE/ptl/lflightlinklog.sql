CREATE TABLE [ptl].[lflightlinklog]
(
    [SerialNo] int IDENTITY(1,1) NOT NULL,
    [Application] nvarchar(50) NULL,
    [LocalEndPoint] nvarchar(50) NULL,
    [RemoteEndPoint] nvarchar(50) NULL,
    [DeviceIPAddress] nvarchar(40) NULL DEFAULT (''),
    [SourceKey] bigint NULL DEFAULT ((0)),
    [MessageType] nvarchar(10) NOT NULL,
    [Data] nvarchar(MAX) NULL,
    [ACKData] nvarchar(MAX) NULL DEFAULT (''),
    [StartTime] datetime NULL,
    [EndTime] datetime NULL,
    [ErrMsg] nvarchar(400) NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [NoOfTry] int NOT NULL DEFAULT ((0)),
    [EmailSent] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    [Facility] nvarchar(5) NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    CONSTRAINT [PK_LFLightLinkLOG] PRIMARY KEY ([SerialNo])
);
GO
