CREATE TABLE [rdt].[rdtloginlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [UserName] nvarchar(128) NOT NULL,
    [ClientIP] nvarchar(15) NOT NULL,
    [Remarks] nvarchar(40) NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [SessionID] nvarchar(60) NULL,
    CONSTRAINT [PK_RDTLoginLog] PRIMARY KEY ([RowRef])
);
GO
