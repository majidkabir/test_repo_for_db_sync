CREATE TABLE [dbo].[refkeylookup]
(
    [PickDetailkey] nvarchar(10) NOT NULL,
    [Pickslipno] nvarchar(10) NULL,
    [OrderKey] nvarchar(10) NULL,
    [OrderLineNumber] nvarchar(5) NULL,
    [Loadkey] nvarchar(10) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_RefKeyLookup] PRIMARY KEY ([PickDetailkey])
);
GO

CREATE INDEX [IX_RefKeyLookup_OrderInfo] ON [dbo].[refkeylookup] ([OrderKey], [OrderLineNumber]);
GO
CREATE INDEX [IX_RefKeyLookup_PickSlipno] ON [dbo].[refkeylookup] ([Pickslipno]);
GO