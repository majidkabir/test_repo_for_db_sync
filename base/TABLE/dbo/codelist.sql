CREATE TABLE [dbo].[codelist]
(
    [LISTNAME] nvarchar(10) NOT NULL,
    [DESCRIPTION] nvarchar(60) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    [ListGroup] nvarchar(30) NULL,
    [TYPE] nvarchar(10) NULL DEFAULT (''),
    [UDF01] nvarchar(60) NULL DEFAULT (''),
    [UDF02] nvarchar(60) NULL DEFAULT (''),
    [UDF03] nvarchar(60) NULL DEFAULT (''),
    [UDF04] nvarchar(60) NULL DEFAULT (''),
    [UDF05] nvarchar(60) NULL DEFAULT (''),
    CONSTRAINT [PKCodeList] PRIMARY KEY ([LISTNAME])
);
GO
