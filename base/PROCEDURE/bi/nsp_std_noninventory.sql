SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************
TITLE: BBW PACKING LIST https://jiralfl.atlassian.net/browse/WMS-21466

CREATED DATE	AUTHOR		VER		PURPOSE
1/3/2023		CRISNAH		1.0		FOR OUTBOUND LOADING GUIDE (FOM)
1/9/2023		Jareklim	1.1		Create the sp in phwms prod & uat
********************************************************************************/
-- EXEC BI.nsp_STD_NonInventory 'BBW'
CREATE     PROC [BI].[nsp_STD_NonInventory]
	@PARAM_GENERIC_STORERKEY NVARCHAR (15) = ''
AS
BEGIN
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS ON    ;   SET ANSI_WARNINGS ON   ;

   DECLARE @Debug		BIT = 0
	   , @LogId		INT
	   , @LinkSrv   NVARCHAR(128)
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
	   , @cParamIn  NVARCHAR(4000)= '{ "Param_Generic_StorerKey":"'  +@PARAM_GENERIC_STORERKEY+'"'
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_STORERKEY
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

--DECLARE
--	@Stmt NVARCHAR(1000) = ''

Set @Stmt = 'SELECT TOP (10000) 
	  [Facility]
      ,[Storerkey]
      ,[NonInvSku]
      ,[Descr]
      ,[InvType]
      ,[MaintainBalances]
      ,[LastLoc]
      ,[CurrentBalance]
      ,[AddWho]
      ,[AddDate]
      ,[EditWho]
      ,[EditDate]
  FROM [PHWMS].[BI].[V_NonInv]
  WHERE
	STORERKEY='''+@PARAM_GENERIC_STORERKEY+''' 
	'


 PRINT @Stmt
EXEC BI.dspExecStmt @Stmt = @stmt
   , @LinkSrv = @LinkSrv
   , @LogId = @LogId
   , @Debug = @Debug;

END -- Procedure 

GO