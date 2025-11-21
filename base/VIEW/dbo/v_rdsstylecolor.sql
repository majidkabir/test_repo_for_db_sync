SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_RDSStyleColor]
as
SElect
LinesNo	,
Storerkey	,
Style	,
Color	,
Descr	,
Status	,
AddDate	,
AddWho	,
EditDate	,
EditWho	,
ArchiveCop	,
TrafficCop	
FROM RDSStyleColor with (NOLOCK)


GO