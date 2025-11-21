CREATE TABLE [dbo].[wms_trace]
(
    [EventType] nvarchar(30) NOT NULL,
    [parameters] int NOT NULL,
    [Eventinfo] nvarchar(4000) NULL,
    [CurrentTime] datetime NULL,
    [spid] int NULL,
    [RowNo] bigint IDENTITY(1,1) NOT NULL,
    CONSTRAINT [PK_WMS_Trace] PRIMARY KEY ([RowNo])
);
GO

CREATE INDEX [ind] ON [dbo].[wms_trace] ([CurrentTime], [spid]);
GO
CREATE INDEX [IX_wms_trace_spid] ON [dbo].[wms_trace] ([spid]);
GO