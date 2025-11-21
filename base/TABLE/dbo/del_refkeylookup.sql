CREATE TABLE [dbo].[del_refkeylookup]
(
    [PickDetailkey] nvarchar(10) NOT NULL,
    [Pickslipno] nvarchar(10) NULL,
    [OrderKey] nvarchar(10) NULL,
    [OrderLineNumber] nvarchar(5) NULL,
    [Loadkey] nvarchar(10) NULL,
    [EditWho] nvarchar(128) NULL,
    [EditDate] datetime NULL,
    [DeleteWho] nvarchar(60) NULL,
    [DeleteDate] datetime NULL
);
GO
