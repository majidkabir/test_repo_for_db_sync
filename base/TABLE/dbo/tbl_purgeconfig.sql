CREATE TABLE [dbo].[tbl_purgeconfig]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [Item] nvarchar(50) NOT NULL,
    [TBLName] nvarchar(100) NOT NULL,
    [Description] nvarchar(125) NOT NULL DEFAULT (''),
    [Threshold] int NOT NULL DEFAULT ('30'),
    [Date_Col] nvarchar(50) NOT NULL DEFAULT (''),
    [Condition] nvarchar(1000) NOT NULL DEFAULT (''),
    [PurgeGroup] nvarchar(50) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_tbl_purgeconfig] PRIMARY KEY ([Rowref])
);
GO
