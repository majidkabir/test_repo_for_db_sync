SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_RDSStyleColorSize]
as
SElect
SeqNo	,
Storerkey	,
UPC	,
Style	,
Color	,
Sizes	,
Measurement	,
Status	,
AddDate	,
AddWho	,
EditDate	,
EditWho	,
ArchiveCop	,
TrafficCop	
FROM RDSStyleColorSize with (NOLOCK)


GO