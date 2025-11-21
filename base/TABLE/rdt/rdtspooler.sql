CREATE TABLE [rdt].[rdtspooler]
(
    [SpoolerGroup] nvarchar(20) NOT NULL,
    [Description] nvarchar(60) NOT NULL DEFAULT (''),
    [IPAddress] nvarchar(40) NOT NULL DEFAULT (''),
    [PortNo] nvarchar(5) NOT NULL DEFAULT (''),
    [Command] nvarchar(1024) NOT NULL DEFAULT (''),
    [IniFilePath] nvarchar(200) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [Spooler] nvarchar(50) NOT NULL DEFAULT (''),
    [TCPSpoolerVersion] nvarchar(50) NULL DEFAULT (''),
    CONSTRAINT [PK_rdtSpooler] PRIMARY KEY ([SpoolerGroup])
);
GO
