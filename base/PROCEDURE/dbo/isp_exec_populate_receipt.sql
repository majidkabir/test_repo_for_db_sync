SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_exec_populate_receipt                                  */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */ 
/***************************************************************************/   
CREATE PROCEDURE [dbo].[isp_exec_populate_receipt] (
@c_spname NVARCHAR(100),
@c_stdkey NVARCHAR(10),
@c_storer NVARCHAR(18),
@c_logwhse NVARCHAR(18),
@c_vessel NVARCHAR(10), 
@c_facility NVARCHAR(5),
@c_receiptkey NVARCHAR(10) OUTPUT
)

AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
	-- Created by MaryVong on 04-Feb-2004 (FBR18043: NZMM Project)
	
	DECLARE @c_SQLstmt nvarchar(3000)

	SELECT @c_SQLstmt = 'EXEC @ac_spname @ac_stdkey, @ac_storer, @ac_logwhse, @ac_vessel, @ac_facility, @ac_receiptkey OUTPUT'

	EXEC sp_executesql @c_SQLstmt, N'@ac_spname NVARCHAR(100), @ac_stdkey NVARCHAR(10), @ac_storer NVARCHAR(18), 
												@ac_logwhse NVARCHAR(18), @ac_vessel NVARCHAR(10), @ac_facility NVARCHAR(5), 
												@ac_receiptkey NVARCHAR(10) OUTPUT', 
												@ac_spname = @c_spname, @ac_stdkey = @c_stdkey, @ac_storer = @c_storer, 
												@ac_logwhse = @c_logwhse, @ac_vessel = @c_vessel, @ac_facility = @c_facility, 
												@ac_receiptkey = @c_receiptkey OUTPUT 

END

GO