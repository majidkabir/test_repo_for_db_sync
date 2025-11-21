SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***********************************************************************
TITLE: PH_LogiReport - New Report - SKU Advance RDT Config - UNILEVER - https://jiralfl.atlassian.net/browse/WMS-20420

DATE				VER		CREATEDBY       PURPOSE
18-AUG-2022			1.0		RenielSuarez    Created New report 
18-AUG-2022			1.1		JarekLim        Fine Tune  
************************************************************************/

CREATE PROC [BI].[nsp_Generic_SKUAdvanceConfig] --NAME OF SP
			@PARAM_GENERIC_STORERKEY NVARCHAR(30)=''
AS
BEGIN
   SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   -- DECLARE @PARAM_GENERIC_STORERKEY NVARCHAR(30)='PH01', @PARAM_GENERIC_FACILITY NVARCHAR(30)='PH53',@PARAM_GENERIC_ADDDATEFROM DATETIME='2021-01-01',@PARAM_GENERIC_ADDDATETO DATETIME='2021-10-31'

	IF ISNULL(@PARAM_GENERIC_STORERKEY, '') = ''
		SET @PARAM_GENERIC_STORERKEY = ''

   DECLARE @Debug BIT = 0, @LogId   INT
       , @Proc      NVARCHAR(128) = 'nsp_Generic_SKUAdvanceConfig' --NAME OF SP
       , @ParamOut NVARCHAR(4000)= ''
       , @ParamIn  NVARCHAR(4000)= CONCAT('{ "PARAM_GENERIC_STORERKEY":"', @PARAM_GENERIC_STORERKEY, '", '
                                    , ' }');

   EXEC BI.dspExecInit @PARAM_GENERIC_STORERKEY, @Proc, @ParamIn, @LogId OUTPUT, @Debug OUTPUT;

	DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
         , @LinkSrv NVARCHAR(128);

	SET @Stmt = CONCAT(
	'
     SELECT A.Storerkey
	 ,A.SKU
	 ,B.ConfigType
	 ,B.Data
     FROM SKU as A WITH (NOLOCK)
     LEFT JOIN SKUConfig as B WITH (NOLOCK)
     ON A.SKU = B.SKU AND A.Storerkey = B.Storerkey
     where A.Storerkey = ''', @PARAM_GENERIC_STORERKEY, '''
	')

   EXEC BI.dspExecStmt @Stmt, @LinkSrv, @LogId, @Debug;

END


GO