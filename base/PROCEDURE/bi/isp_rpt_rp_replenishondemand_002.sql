SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Title: isp_RPT_RP_REPLENISHONDEMAND_002                               */

/* Date         Author   Ver  Purposes                                   */
/* 09-Mar-2023  WLChooi  1.0  DevOps Combine Script                      */
/*************************************************************************/

CREATE   PROC [BI].[isp_RPT_RP_REPLENISHONDEMAND_002] --NAME OF SP
         @c_Storerkey     NVARCHAR(15)  = 'NIKEMY'
         , @dt_deliveryfrom DATETIME = ''
         , @dt_deliveryto   DATETIME = ''
         , @c_SKUGroup      NVARCHAR(10) = ''
         , @c_Lottable01    NVARCHAR(18) = ''  
         , @c_Lottable02    NVARCHAR(18) = ''  
         , @c_Lottable03    NVARCHAR(18) = ''  
         , @c_Facility      NVARCHAR(5)  = ''  
         , @c_PAZoneFrom    NVARCHAR(10) = ''  
         , @c_PAZoneTo      NVARCHAR(10) = ''  
         , @c_ShowBCode     NVARCHAR(1)  = 'N'  
         , @c_EmptyPickLOC  NVARCHAR(1)  = 'N'  

AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= CONCAT('{ "@c_Storerkey":"'    ,@c_Storerkey,'"'
                                    , ', "@dt_deliveryfrom":"'    ,CONVERT(NVARCHAR(19),@dt_deliveryfrom,121),'"'
									         , ', "@dt_deliveryto":"'    ,CONVERT(NVARCHAR(19),@dt_deliveryto,121),'"'
                                    , ', "@c_SKUGroup":"',@c_SKUGroup,'"'
                                    , ', "@c_Lottable01":"',@c_Lottable01,'"'
                                    , ', "@c_Lottable02":"',@c_Lottable02,'"'
                                    , ', "@c_Lottable03":"',@c_Lottable03,'"'
                                    , ', "@c_Facility":"',@c_Facility,'"'
                                    , ', "@c_PAZoneFrom":"',@c_PAZoneFrom,'"'
                                    , ', "@c_PAZoneTo":"',@c_PAZoneTo,'"'
                                    , ', "@c_ShowBCode":"',@c_ShowBCode,'"'
                                    , ', "@c_EmptyPickLOC":"',@c_EmptyPickLOC,'"'
                                    , ' }')

   EXEC BI.dspExecInit @ClientId = @c_Storerkey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/

SET @stmt = CONCAT(@stmt , '
   EXEC dbo.isp_RPT_RP_REPLENISHONDEMAND_002 ''',@c_Storerkey,''',''',CONVERT(NVARCHAR(19),@dt_deliveryfrom,121),''',''',CONVERT(NVARCHAR(19),@dt_deliveryto,121),''',
   ''',@c_SKUGroup,''',''',@c_Lottable01,''',''',@c_Lottable02,''',
   ''',@c_Lottable03,''',''',@c_Facility,''',''',@c_PAZoneFrom,''',
   ''',@c_PAZoneTo,''',''',@c_ShowBCode,''',''',@c_EmptyPickLOC,'''

');

/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO