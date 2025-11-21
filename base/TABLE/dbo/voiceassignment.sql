CREATE TABLE [dbo].[voiceassignment]
(
    [AssignmentID] bigint IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [GroupID] nvarchar(10) NOT NULL,
    [DocNo] nvarchar(20) NOT NULL,
    [TableName] nvarchar(20) NOT NULL,
    [UserName] nvarchar(20) NOT NULL DEFAULT (suser_sname()),
    [Status] char(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_VoiceAssignment] PRIMARY KEY ([AssignmentID])
);
GO
