CREATE TABLE [dbo].[voiceassignmentdetail]
(
    [AssignmentID] bigint NOT NULL,
    [SeqNo] int NOT NULL,
    [TaskDetailKey] nvarchar(10) NULL,
    [Status] char(1) NULL,
    [ContainerID] nvarchar(20) NULL DEFAULT (''),
    [LabelPrinted] nchar(1) NULL DEFAULT ('N'),
    [Qty] int NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(20) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(20) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_VoiceAssignmentDetail] PRIMARY KEY ([AssignmentID], [SeqNo])
);
GO
