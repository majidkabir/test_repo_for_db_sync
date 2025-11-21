CREATE TABLE [dbo].[tariff]
(
    [TariffKey] nvarchar(10) NOT NULL,
    [Descrip] nvarchar(30) NOT NULL DEFAULT (' '),
    [SupportFlag] nvarchar(1) NOT NULL DEFAULT ('A'),
    [InitialStoragePeriod] int NULL,
    [RecurringStoragePeriod] int NULL,
    [SplitMonthDay] int NOT NULL DEFAULT ((15)),
    [SplitMonthPercent] decimal(12, 6) NOT NULL DEFAULT ((0.50)),
    [PeriodType] nvarchar(1) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [CalendarGroup] nvarchar(10) NULL,
    [RSPeriodType] nvarchar(1) NULL,
    [SplitMonthPercentBefore] decimal(12, 6) NULL DEFAULT ((1.0)),
    [CaptureEndOfMonth] nvarchar(1) NULL DEFAULT ('1'),
    CONSTRAINT [PKTariff] PRIMARY KEY ([TariffKey]),
    CONSTRAINT [CK_Tariff_I_S_P] CHECK ([InitialStoragePeriod]>=(1) AND [InitialStoragePeriod]<=(999)),
    CONSTRAINT [CK_Tariff_R_S_P] CHECK ([RecurringStoragePeriod]>=(1) AND [RecurringStoragePeriod]<=(999)),
    CONSTRAINT [CK_Tariff_R_S_Type] CHECK ([PeriodType]='C' OR [PeriodType]='S' OR [PeriodType]='A' OR [PeriodType]='F'),
    CONSTRAINT [CK_Tariff_RSPerType] CHECK ([RSPeriodType]='S' OR [RSPeriodType]='A' OR [RSPeriodType]='C' OR [RSPeriodType]='F'),
    CONSTRAINT [CK_Tariff_Sp_Month_Per] CHECK ([SplitMonthPercent]>=(0.0)),
    CONSTRAINT [CK_Tariff_SplitMonthDay] CHECK ([SplitMonthDay]>=(1) AND [SplitMonthDay]<=(31)),
    CONSTRAINT [CK_Tariff_SpMonth_Before] CHECK ([SplitMonthPercentBefore]>=(0.0) AND [SplitMonthPercentBefore]<=(1.0)),
    CONSTRAINT [CK_Tariff_SupportFlag] CHECK ([SupportFLag]='D' OR [SupportFLag]='I' OR [SupportFLag]='A')
);
GO
