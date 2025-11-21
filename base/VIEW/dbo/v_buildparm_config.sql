SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_BUILDPARM_CONFIG]
AS

SELECT BPG.Storerkey
      ,BPG.Facility
      ,BPG.[Type]
      ,b.ParmGroup
      ,b.BuildParmKey
      ,BPD.BuildParmLineNo
      ,BPD.[Description]
      ,BPD.ConditionLevel
      ,BPD.FieldName
      ,BPD.OrAnd
      ,BPD.Operator
      ,BPD.[Value]
FROM   BUILDPARM             AS b WITH(NOLOCK)
JOIN BUILDPARMGROUPCFG BPG WITH (NOLOCK)
      ON  BPG.ParmGroup = b.ParmGroup
JOIN BUILDPARMDETAIL  AS BPD WITH(NOLOCK)
      ON  BPD.BuildParmKey = b.BuildParmKey


GO