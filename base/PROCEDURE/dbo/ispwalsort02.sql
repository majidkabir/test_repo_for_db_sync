SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: ispWALSort02                                        */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage: WMS-12445  CN Porsche Wave allocation orders sorting          */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: WAVE allocation (WaveALOrderSort_SP)                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[ispWALSort02] 
   @c_Wavekey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
       
   SELECT O.Orderkey 
   FROM WAVEDETAIL WD (NOLOCK) 
   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   WHERE WD.Wavekey = @c_Wavekey   
   GROUP BY O.Userdefine10, O.OrderDate, O.Orderkey
   ORDER BY O.Userdefine10, O.OrderDate, O.Orderkey
   
END

GO