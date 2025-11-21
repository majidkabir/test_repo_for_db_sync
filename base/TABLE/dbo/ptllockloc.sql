CREATE TABLE [dbo].[ptllockloc]
(
    [PTLLockLocKey] int IDENTITY(1,1) NOT NULL,
    [IPAddress] nvarchar(40) NOT NULL,
    [DeviceID] nvarchar(20) NOT NULL,
    [DevicePosition] nvarchar(10) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [LockType] nvarchar(10) NULL DEFAULT (''),
    [NextLoc] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_PTLLockLoc] PRIMARY KEY ([PTLLockLocKey])
);
GO

CREATE INDEX [IDX_PTLLockLoc_01] ON [dbo].[ptllockloc] ([DeviceID], [AddWho]);
GO