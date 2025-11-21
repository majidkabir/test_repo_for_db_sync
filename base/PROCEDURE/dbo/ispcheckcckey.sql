SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispCheckCCkey                         					*/
/* Creation Date: 07.Nov.06                                             */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: Check CCkey in StockTake module (SOS55261).       				*/
/*			   Disallow to regenerate stocktake if previous data not clear */
/*                                                                      */
/* Called By: PB object nep_n_cst_stocktake_parm_new                    */
/*                                                                      */
/* PVCS Version: 1.6		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[ispCheckCCkey] (
@c_StockTakeKey NVARCHAR(10)
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @n_continue INT
SET 	  @n_continue = 1

IF @n_continue = 1 OR @n_continue = 2 
BEGIN  
	EXEC ( 'SELECT Count(*) ' 
       + 'FROM CCDETAIL (NOLOCK) '
       + 'WHERE CCKEY = N''' + @c_StockTakeKey + ''' ' )
END     

GO