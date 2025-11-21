SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************
TITLE: BBW PACKING LIST https://jiralfl.atlassian.net/browse/WMS-21466

CREATED DATE	AUTHOR		VER		PURPOSE
1/3/2023		CRISNAH		1.0		FOR OUTBOUND LOADING GUIDE (FOM)
********************************************************************************/
-- EXEC BI.nsp_BBW_PackingList '0000141723'
CREATE     PROC [BI].[nsp_BBW_PackingList]
	@PARAM_WMS_Wavekey NVARCHAR (15) = ''
AS
BEGIN
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS ON    ;   SET ANSI_WARNINGS ON   ;

DECLARE
	@param_Storerkey NVARCHAR(15) = ''

	SELECT TOP 1 @param_Storerkey = STORERKEY FROM ORDERS (NOLOCK) WHERE USERDEFINE09=@PARAM_WMS_Wavekey
	--PRINT(@c_Storerkey)

   DECLARE @Debug		BIT = 0
	   , @LogId		INT
	   , @LinkSrv   NVARCHAR(128)
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
	   , @cParamIn  NVARCHAR(4000)= '{ "Param_Generic_StorerKey":"'  +@param_Storerkey+'"'
                                    + ',"PARAM_WMS_c_Wavekey":"'    +@PARAM_WMS_Wavekey+'"'
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @param_storerkey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   --, @Schema = @Schema;

   DECLARE @Stmt     NVARCHAR(MAX) = ''
         , @Id       INT  = FLOOR(RAND()*99999)
         , @Success  INT  = 1
         , @Err      INT
         , @ErrMsg   NVARCHAR(250)

SET @Stmt = 'SELECT 
	W.WaveKey
	, MAX(M.SHIPDATE) [SHIPPED_DATE]
	, S.SUSR5
	, S.COMPANY
	, S.ADDRESS1
	, S.ADDRESS2
	, S.ADDRESS3
	, CASE WHEN S.SUSR5=''FOM'' THEN O.M_COMPANY ELSE O.EXTERNORDERKEY END [ORDER_ID]
	, CASE WHEN S.SUSR5=''FOM'' THEN O.C_contact1 ELSE O.C_Company END [CUSTOMER_NAME]
	, O.TrackingNo
	, SUM(PH.TTLCNTS)	[TOTAL_CTN]
	, COUNT(PD.SKU)		[TOTAL_SKU]
	, SUM(TOTCTNWEIGHT)	[TOTAL_WEIGHT]
	, SUM(PD.QTY)		[TOTAL_QTY]

FROM
	BI.V_ORDERS O (NOLOCK)
	JOIN BI.V_WAVE W (NOLOCK) ON O.USERDEFINE09=W.WAVEKEY
	JOIN BI.V_STORER S (NOLOCK) ON S.STORERKEY=O.STORERKEY
	JOIN BI.V_PACKHEADER PH (NOLOCK) ON PH.ORDERKEY=O.ORDERKEY
	JOIN BI.V_PACKDETAIL PD (NOLOCK) ON PH.PICKSLIPNO=PD.PICKSLIPNO
	JOIN BI.V_MBOL M (NOLOCK) ON M.MBOLKEY=O.MBOLKEY
WHERE
	O.USERDEFINE09 = '''+@PARAM_WMS_Wavekey+'''
GROUP BY
	W.WaveKey
	, S.SUSR5
	, S.COMPANY
	, S.ADDRESS1
	, S.ADDRESS2
	, S.ADDRESS3
	, CASE WHEN S.SUSR5=''FOM'' THEN O.M_COMPANY ELSE O.EXTERNORDERKEY END 
	, CASE WHEN S.SUSR5=''FOM'' THEN O.C_contact1 ELSE O.C_Company END 
	, O.TrackingNo
'

 PRINT @Stmt
EXEC BI.dspExecStmt @Stmt = @stmt
   , @LinkSrv = @LinkSrv
   , @LogId = @LogId
   , @Debug = @Debug;

END -- Procedure 

GO