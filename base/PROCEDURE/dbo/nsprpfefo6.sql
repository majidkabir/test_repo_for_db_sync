SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nspRPFEFO6                                          */
/* Creation Date: 30-Sep-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  353735 - ID - Replenishment pickcode                       */
/*           Sort by lottable04, lottable02 & lottable05                */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
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

CREATE PROC [dbo].[nspRPFEFO6] 
   @c_StorerKey NVARCHAR(15),
   @c_SKU       NVARCHAR(20),
   @c_LOC       NVARCHAR(10),
   @c_Facility  NVARCHAR(10),
   @c_Lot       NVARCHAR(10)  
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
	   
   SELECT LOTxLOCxID.LOT, IDENTITY(INT,1,1) AS rowid
   INTO #TMP_LOT
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK) 
   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
   AND LOTxLOCxID.SKU = @c_SKU
   AND LOTxLOCxID.LOC = LOC.LOC
   AND LOC.LocationFlag <> 'DAMAGE'
   AND LOC.LocationFlag <> 'HOLD'
   AND LOC.Status <> 'HOLD'
   AND LOC.Facility = @c_Facility
   AND LOT.LOT = LOTxLOCxID.LOT           
   AND LOT.Status <> 'HOLD'               
   AND LOTxLOCxID.LOC <> @c_LOC
   AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
   AND LOTxLOCxID.LOT <> ISNULL(@c_Lot, '')
   AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
   GROUP BY LOTxLOCxID.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05
   ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05
   
   SELECT Lot, RIGHT('0000000000'+CAST(rowid AS NVARCHAR),10)
   FROM #TMP_LOT
END

GO