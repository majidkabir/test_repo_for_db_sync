CREATE TABLE [bi].[dashboard_hdr]
(
    [DB_HeaderID] int IDENTITY(1,1) NOT NULL,
    [DeviceID] nvarchar(20) NOT NULL,
    [DashboardID] nvarchar(60) NOT NULL,
    [CurrentPage] int NOT NULL DEFAULT ((1)),
    [TotalPages] int NOT NULL DEFAULT ((0)),
    [DataRefreshTime] datetime NOT NULL DEFAULT (getdate()),
    [ParameterValues] nvarchar(1000) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_Dashboard_HDR] PRIMARY KEY ([DB_HeaderID])
);
GO
