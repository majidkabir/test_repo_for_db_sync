CREATE TABLE [dbo].[simulationcriteria]
(
    [FunctionID] int NOT NULL DEFAULT ((0)),
    [NoOfUser] int NOT NULL DEFAULT ((0)),
    [NoOfOrderPerUser] int NOT NULL DEFAULT ((0)),
    [UserRangeFrom] int NOT NULL DEFAULT ((0)),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [MBOLKey] nvarchar(10) NOT NULL DEFAULT (''),
    [LoadKey] nvarchar(10) NOT NULL DEFAULT (''),
    [Status] nvarchar(2) NOT NULL DEFAULT ('0'),
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [LoginID] nvarchar(20) NULL DEFAULT ('')
);
GO
