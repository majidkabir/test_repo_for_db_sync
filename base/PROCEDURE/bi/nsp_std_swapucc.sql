SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************************************/  
--PH_JReport - RDT Swap UCC - Stored Procedure (PHWMS) https://jiralfl.atlassian.net/browse/WMS-17685
/* Updates:                                                                                    */  
/* Date            Author      Ver.    Purposes                                                */  
/* 06-Aug-2021     gywong       1.0     Created                                                */
/* 08-Jun-2022		JAM			1.1		Added pre-defined date filter and parameters	    	*/
/* 08-Mar-2022		JayCanete	1.1		Change condition https://jiralfl.atlassian.net/browse/WMS-21816	*/
/***********************************************************************************************/  
-- Test EXEC BI.nsp_STD_SwapUCC 'UNILEVER', 'UMDC'
 --      EXEC BI.nsp_STD_SwapUCC NULL, NULL
 --      EXEC BI.nsp_STD_SwapUCC '', ''
CREATE     PROC [BI].[nsp_STD_SwapUCC]
     @Param_Generic_UCC NVARCHAR(50) 
    ,@Param_Generic_NewUCC NVARCHAR(50) 
	
AS
BEGIN
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS ON    ;   SET ANSI_WARNINGS ON   ;
		
	
	IF ISNULL(@PARAM_GENERIC_UCC, '') = ''
		SET @PARAM_GENERIC_UCC = ''
	IF ISNULL(@PARAM_GENERIC_NewUCC, '') = ''
		SET @PARAM_GENERIC_NewUCC = ''
	

   DECLARE @Debug	BIT = 0
			, @LogId   INT
			, @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
			, @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
			, @cParamOut NVARCHAR(4000)= ''
			, @cParamIn  NVARCHAR(4000)= '{ "Param_Generic_UCC":"'  +@PARAM_GENERIC_UCC+'"'
                                    + ',"Param_Generic_NewUCC":"'    +@PARAM_GENERIC_NewUCC+'"'
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @Param_Generic_UCC
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/

      SET @Stmt ='
		SELECT 
		  AL1.Func, 
		  AL1.UCC, 
		  AL1.NewUCC, 
		  AL1.ReplenGroup, 
		  AL1.AddDate, 
		  AL1.AddWho, 
		  AL1.UCCStatus, 
		  AL1.NewUCCStatus 
		FROM 
		  BI.V_SWAPUCC AL1 (nolock) 
		WHERE 
			  AL1.UCC IN ('''+@Param_Generic_UCC+''') 
			  OR AL1.NewUCC IN ('''+@PARAM_GENERIC_NewUCC+''')

		'
/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END -- Procedure 

GO