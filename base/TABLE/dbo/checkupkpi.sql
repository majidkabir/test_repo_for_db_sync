CREATE TABLE [dbo].[checkupkpi]
(
    [KPI] int IDENTITY(1,1) NOT NULL,
    [KPICode] nvarchar(100) NOT NULL,
    [Category] nvarchar(30) NOT NULL,
    [Description] nvarchar(500) NOT NULL,
    [TypeOfSymbol] nvarchar(10) NOT NULL DEFAULT (''),
    [Enabled] nvarchar(1) NOT NULL DEFAULT ('N'),
    [DisplayOnDashboard] nvarchar(2) NOT NULL DEFAULT ('  '),
    [PrimaryWidgetFlag] nvarchar(1) NOT NULL DEFAULT ('N'),
    [YlMin] int NOT NULL,
    [YlMax] int NOT NULL,
    [SQL] nvarchar(4000) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [LastRunDate] datetime NULL,
    [SQL_DrillDown] nvarchar(4000) NULL DEFAULT (''),
    CONSTRAINT [PK_CheckUpKPI] PRIMARY KEY ([KPI])
);
GO
