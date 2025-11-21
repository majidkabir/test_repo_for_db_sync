SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_RDSSizeDetail]
as
SElect
RDSSizeLine	,
SeqNo	,
Storerkey	,
SizeCode	,
Sizes	,
Measurement	,
AddDate	,
AddWho	,
EditDate	,
EditWho	,
ArchiveCop	,
TrafficCop	
FROM RDSSizeDetail with (NOLOCK)


GO