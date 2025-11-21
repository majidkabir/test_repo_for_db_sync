SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
	TITLE: ULP Wave Replent Health Check - Static PF

DATE				VER		CREATEDBY   PURPOSE
2023-05-18			1.0		JAM			MIGRATE FROM HYPERION
************************************************************************/

CREATE   PROC [BI].[nsp_ULP_WaveReplenHC_StaticPF] --NAME OF SP */ Declare
			@PARAM_GENERIC_STORERKEY NVARCHAR(30)='UNILEVER'
AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

	IF ISNULL(@PARAM_GENERIC_STORERKEY, '') = ''
		SET @PARAM_GENERIC_STORERKEY = ''

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_STORERKEY":"'    +@PARAM_GENERIC_STORERKEY+'" '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
DECLARE @Stmt NVARCHAR(2000) = ''
SET @Stmt = '
SELECT
SL.Sku [Sku]
, S.Descr [Description]
, SL.Loc [Loc]
, SUM ( SL.Qtylocationminimum ) [Minimum-PC]
, SUM( SL.Qtylocationminimum / NULLIF(P.Casecnt,0) ) [Minimum-CS]
, SUM ( SL.Qtylocationlimit ) [Maximum-PC]
, SUM(SL.Qtylocationlimit / NULLIF(P.Casecnt,0)) [Maximum-CS]
, P.Casecnt [Casecnt]
, P.Pallet [Pallet]

FROM
	BI.V_Skuxloc SL (NOLOCK)
	INNER JOIN BI.V_Sku S (NOLOCK) ON SL.StorerKey=S.StorerKey AND SL.Sku=S.Sku
	INNER JOIN BI.V_Pack P (NOLOCK) ON P.PackKey=S.PACKKey
WHERE
	SL.StorerKey = '''+@PARAM_GENERIC_STORERKEY+'''
	AND SL.LocationType = ''CASE''
GROUP BY
SL.Sku
, S.Descr
, SL.Loc
, P.Casecnt
, P.Pallet
'
EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO