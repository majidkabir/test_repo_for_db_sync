SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispInsertOriginAllocQty                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[ispInsertOriginAllocQty] (
 		@c_LoadKey	   NVARCHAR(10) = NULL,
      @c_OrderKey    NVARCHAR(10) = NULL 
 )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @c_OrderKey IS NOT NULL 
   BEGIN
      INSERT INTO OriginAllocQty (OrderKey, OrderLineNumber, QtyAllocated)
      SELECT OD.OrderKey, OD.OrderLineNumber, OD.QtyAllocated
      FROM   ORDERDETAIL OD (NOLOCK)
      LEFT OUTER JOIN OriginAllocQty OA ON (OD.OrderKey = OA.OrderKey and 
                                            OD.OrderLineNumber = OA.OrderLineNumber)
      WHERE OD.LoadKey = @c_LoadKey 
      AND   OD.OrderKey = @c_OrderKey 
      AND   OA.OrderKey IS NULL 
   END
   ELSE
   BEGIN
      INSERT INTO OriginAllocQty (OrderKey, OrderLineNumber, QtyAllocated)
      SELECT OD.OrderKey, OD.OrderLineNumber, OD.QtyAllocated
      FROM   ORDERDETAIL OD (NOLOCK)
      LEFT OUTER JOIN OriginAllocQty OA ON (OD.OrderKey = OA.OrderKey and 
                                            OD.OrderLineNumber = OA.OrderLineNumber)
      WHERE OD.LoadKey = @c_LoadKey 
      AND   OA.OrderKey IS NULL 
   END
END /* main procedure */


GO