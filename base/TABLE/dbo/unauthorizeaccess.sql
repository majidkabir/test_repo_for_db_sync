CREATE TABLE [dbo].[unauthorizeaccess]
(
    [AddDate] datetime NOT NULL,
    [SPID] int NOT NULL,
    [ProgramName] nvarchar(128) NULL DEFAULT (''),
    [HostName] nvarchar(128) NULL DEFAULT (''),
    [Login_Time] datetime NULL,
    [Login_ID] nvarchar(50) NULL DEFAULT (' '),
    [Net_Address] nchar(24) NULL
);
GO
