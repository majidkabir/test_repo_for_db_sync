SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Title: ADIDAS_SHOPEELABELRESPONSE                                       */
/* Updates:                                                                */
/* Date         Author      Ver.  Purposes                                 */
/* 05-May-2023  KunakorN      1.0   Created                                */
/***************************************************************************/

   CREATE   PROC [BI].[dspTH_Report_ADIDAS_SHOPEELABELRESPONSE]
         @PARAM_RG_StartDate DATETIME = NULL,
         @PARAM_RG_EndDate   DATETIME = NULL
   AS
   BEGIN
   SET NOCOUNT ON; 
      SET ANSI_NULLS OFF;
      SET QUOTED_IDENTIFIER OFF;
      SET CONCAT_NULL_YIELDS_NULL OFF;
   
   DECLARE @PARAM_RG_StorerKey NVARCHAR(15) = 'ADIDAS'
      IF ISNULL(@PARAM_RG_StartDate, '') = ''
         SET @PARAM_RG_StartDate = CONVERT(VARCHAR(10),getdate() -32 , 121)
      IF ISNULL(@PARAM_RG_EndDate, '') = ''
         SET @PARAM_RG_EndDate = GETDATE()

   DECLARE @Debug	BIT = 0
       , @nRowCnt INT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @Err     INT = 0
       , @ErrMsg  NVARCHAR(250)  = ''
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_StartDate":"'+CONVERT(NVARCHAR(19),@PARAM_RG_StartDate,121)+'",'
                                       + '"PARAM_EndDate":"'+CONVERT(NVARCHAR(19),@PARAM_RG_EndDate,121)+'"'
                                       + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_RG_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

   DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement
   
   set @stmt = 'select SH.ADDDATE as SHIPPED_ADDDATE,
   SH.XDOCKPOKEY as SHIPPED_XDOCKPOKEY,
   LH.ADDDATE as LABEL_IN_ADDDATE,
   LH.EXTERNORDERKEY as LABEL_IN_EXTERNORDERKEY ,
   SH.ExternOrderKey as SHIPPED_XDOCKPOKEY,
   DATEDIFF(HOUR,SH.ADDDATE,LH.ADDDATE) AS HOUR_DIFF,
   DATEDIFF(MINUTE,SH.ADDDATE,LH.ADDDATE) AS MINUTE_DIFF ,
   DATEDIFF(SECOND,SH.ADDDATE,LH.ADDDATE) AS SECOND_DIFF 
   from [BI].[V_WSDT_GENERIC_SHP_HDR] SH (nolock) LEFT OUTER JOIN [BI].[V_WSDT_GENERIC_LBL_HDR] LH (nolock)
   on SH.XDOCKPOKEY = LH.EXTERNORDERKEY
   where SH.storerkey= '''+@PARAM_RG_StorerKey+''' AND SH.Datastream=''6542'' AND SH.TableName = ''WSFALLOCLOGCD'' 
   AND LH.DATASTREAM=''5765''
   AND SH.BuyerPO  in (select code From BI.V_CODELKUP (nolock) where storerkey=''ADIDAS'' and listname=''PLATFLKUP'')
   AND SH.ADDDATE >= CONVERT(DATETIME, '''+CONVERT(NVARCHAR(19), @PARAM_RG_StartDate, 121)+''', 121)
   AND SH.ADDDATE < DATEADD(DAY, 1, CONVERT(DATETIME, '''+CONVERT(NVARCHAR(19), @PARAM_RG_EndDate, 121)+''', 121))'

   
      EXEC BI.dspExecStmt @Stmt = @Stmt
      , @LogId = @LogId
      , @Debug = @Debug;
   
END

GO