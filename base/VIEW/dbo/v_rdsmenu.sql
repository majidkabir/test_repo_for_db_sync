SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_rdsMenu]
as
SElect
MenuID	,
SeqNo	,
Type	,
Descr	,
ObjectName	,
BitMap	,
PrevMenuID	,
NextMenuID	,
Visible	,
Enable	
FROM rdsMenu with (NOLOCK)


GO