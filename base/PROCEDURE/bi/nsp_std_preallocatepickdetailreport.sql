SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
TITLE: PH_Unilever - LogiReport - Pre-allocation Pick Detail Report SP https://jiralfl.atlassian.net/browse/WMS-21813

DATE				VER		CREATEDBY   PURPOSE
17-FEB-2023			1.0		JOHREM		MIGRATE FROM HYPERION 
24-FEB-2023			1.1		JarekLim	Create sp in wms prod & uat.
************************************************************************/

CREATE     PROC [BI].[nsp_STD_PreAllocatePickDetailReport] --NAME OF SP
			@PARAM_GENERIC_STORERKEY NVARCHAR(30)=''
			, @PARAM_GENERIC_FACILITY NVARCHAR(10)=''

AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

	IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		SET @PARAM_GENERIC_Storerkey= ''
	IF ISNULL(@PARAM_GENERIC_Facility, '') = ''
		SET @PARAM_GENERIC_Facility= ''

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= CONCAT('{ "PARAM_GENERIC_StorerKey":"'    ,@PARAM_GENERIC_StorerKey,'"'
											, ', "PARAM_GENERIC_FACILITY":"'    ,@PARAM_GENERIC_FACILITY,'"'
											 , ' }')
		
   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/

SET @stmt = @stmt + '

SELECT

PR.PREALLOCATEPICKDETAILKEY AS ''PREALLOCATEPICKDETAILKEY'',
PR.ORDERKEY AS ''ORDERKEY'',
PR.ORDERLINENUMBER AS ''ORDERLINENUMBER'',
PR.STORERKEY AS ''STORERKEY'',
O.FACILITY AS ''FACILITY'',
O.USERDEFINE09 AS ''WAVEKEY'',
PR.SKU AS ''SKU'',
PR.LOT AS ''LOT'',
PR.UOM AS ''UOM'',
PR.UOMQTY AS ''UOMQTY'',
PR.QTY AS ''PREALLOCATEQTY_PC'',
'''' AS ''PREALLOCATEQTY_CS'',
PR.PACKKEY AS ''PACKKEY'',
PR.PREALLOCATESTRATEGYKEY AS ''PREALLOCATESTRATEGYKEY'',
PR.PREALLOCATEPICKCODE AS ''PREALLOCATEPICKCODE'',
PR.DOCARTONIZE AS ''DOCARTONIZE'',
PR.PICKMETHOD AS ''PICKMETHOD'',
PR.RUNKEY AS ''RUNKEY'',
PR.EFFECTIVEDATE AS ''EFFECTIVEDATE'',
PR.ADDDATE AS ''ADDDATE'',
PR.ADDWHO AS ''ADDWHO'',
PR.EDITDATE AS ''EDITDATE'',
PR.EDITWHO AS ''EDITWHO'',
PR.TRAFFICCOP AS ''TRAFFICCOP'',
PR.ARCHIVECOP AS ''ARCHIVECOP''
'

SET @stmt = @stmt + '

FROM 
BI.V_PREALLOCATEPICKDETAIL PR (NOLOCK) 
LEFT JOIN BI.V_ORDERS O ON (PR.ORDERKEY = O.ORDERKEY)

WHERE 
((PR.Storerkey = '''+@Param_Generic_Storerkey+'''
AND O.Facility= '''+@PARAM_GENERIC_FACILITY+'''))

ORDER BY  20

'
-- USE VIEW TABLES WITH BI SCHEMA : BI.V_DM_ORDERS for PH_DATAMART, BI.V_ORDERS for PHWMS

/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO