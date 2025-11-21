CREATE TABLE [dbo].[preallocatepickdetailkey]
(
    [PreallocatePickDetailKey] bigint IDENTITY(1,1) NOT NULL,
    [AddDate] datetime NULL,
    CONSTRAINT [PK_PREALLOCATEPICKDET] PRIMARY KEY ([PreallocatePickDetailKey])
);
GO
