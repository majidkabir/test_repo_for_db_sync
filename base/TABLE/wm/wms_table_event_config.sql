CREATE TABLE [wm].[wms_table_event_config]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(128) NOT NULL DEFAULT ('ALL'),
    [Module] nvarchar(50) NOT NULL DEFAULT (''),
    [TableName] nvarchar(128) NOT NULL DEFAULT (''),
    [Event] varchar(10) NOT NULL DEFAULT (''),
    [StepNo] int NOT NULL DEFAULT ((1)),
    [StoredProcedure] nvarchar(128) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_WMS_TABLE_EVENT_CONFIG] PRIMARY KEY ([RowRefNo])
);
GO
