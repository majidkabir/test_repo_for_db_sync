SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [RDT].[V_rdtMessage]
AS
SELECT ISNULL(RTRIM(M.StoredProcName),'') AS StoredProcName
     , H.*
FROM rdt.rdtMessage H WITH (NOLOCK)
LEFT JOIN rdt.rdtMsg M WITH (NOLOCK)
ON (H.InFunc = M.Message_Id AND M.Message_Type <> 'DSP' AND Lang_Code = 'ENG')

GO