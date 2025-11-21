CREATE TABLE [wm].[wms_error_list]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [ErrGroupKey] int NOT NULL DEFAULT ((0)),
    [TableName] nvarchar(50) NOT NULL DEFAULT (''),
    [SourceType] nvarchar(50) NOT NULL DEFAULT (''),
    [RefKey1] nvarchar(20) NOT NULL DEFAULT (''),
    [RefKey2] nvarchar(20) NOT NULL DEFAULT (''),
    [RefKey3] nvarchar(20) NOT NULL DEFAULT (''),
    [LogWarningNo] int NOT NULL DEFAULT (''),
    [WriteType] nvarchar(20) NOT NULL DEFAULT ('ERROR'),
    [ErrCode] int NOT NULL DEFAULT (''),
    [ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_WMS_Error_List] PRIMARY KEY ([RowRefNo])
);
GO
