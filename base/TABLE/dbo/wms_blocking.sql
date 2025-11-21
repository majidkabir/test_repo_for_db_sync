CREATE TABLE [dbo].[wms_blocking]
(
    [EventType] nvarchar(30) NOT NULL,
    [parameters] int NOT NULL,
    [Eventinfo] nvarchar(4000) NULL,
    [CurrentTime] datetime NULL,
    [spid] int NULL,
    [blocking_ID] int NULL,
    [hostname] nvarchar(128) NULL,
    [program_name] nvarchar(128) NULL
);
GO

CREATE INDEX [ind] ON [dbo].[wms_blocking] ([CurrentTime], [spid]);
GO