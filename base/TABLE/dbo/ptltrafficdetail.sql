CREATE TABLE [dbo].[ptltrafficdetail]
(
    [UserID] nvarchar(128) NOT NULL,
    [PTLKey] bigint NOT NULL,
    [MonitorID] nvarchar(20) NOT NULL,
    [USERNO] int NOT NULL DEFAULT ('0'),
    [TrafficData] nvarchar(MAX) NULL DEFAULT (''),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_PTLTrafficDetail] PRIMARY KEY ([PTLKey], [MonitorID])
);
GO
