CREATE TABLE [ptl].[lightinput]
(
    [SerialNo] bigint IDENTITY(1,1) NOT NULL,
    [IPAddress] nvarchar(40) NOT NULL,
    [DevicePosition] nvarchar(10) NOT NULL,
    [InputStatus] nvarchar(10) NULL,
    [InputData] nvarchar(30) NULL DEFAULT (''),
    [Status] nvarchar(1) NULL DEFAULT ('0'),
    [ErrorMessage] nvarchar(250) NULL DEFAULT (''),
    [NoOfTry] int NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [OutputData] nvarchar(30) NULL DEFAULT (''),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    [Facility] nvarchar(5) NULL DEFAULT (''),
    CONSTRAINT [PK_LightInput] PRIMARY KEY ([SerialNo])
);
GO

CREATE INDEX [IX_LightInput_01] ON [ptl].[lightinput] ([IPAddress], [DevicePosition], [Status]);
GO