SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create View [dbo].[V_TraceTM] as
Select Seqno,
SP,
TaskDetailKey,
UserKey,
AddDate
FROM TraceTM With (NOLOCK)


GO