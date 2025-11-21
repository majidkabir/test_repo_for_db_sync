CREATE TABLE [dbo].[pickdetailkey]
(
    [PickDetailKey] bigint IDENTITY(1,1) NOT NULL,
    [AddDate] datetime NULL,
    CONSTRAINT [PK_PICKDETAILKEY] PRIMARY KEY ([PickDetailKey])
);
GO
