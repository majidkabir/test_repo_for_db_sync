SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspRPLOTT2                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspRPLOTT2]
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

   SELECT DISTINCT LOTxLOCxID.LOT, Lottable02
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
   AND LOTxLOCxID.SKU = @c_SKU
   AND LOTxLOCxID.LOC = LOC.LOC
   AND LOC.LocationFlag <> "DAMAGE"
   AND LOC.LocationFlag <> "HOLD"
   AND LOC.Status <> "HOLD"
   AND LOC.Facility = @c_Facility
   AND LOTxLOCxID.LOC <> @c_LOC
   AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
   AND LOTxLOCxID.LOT <> ISNULL(@c_Lot, '')
   AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0
   ORDER BY Lottable02, LOTxLOCxID.LOT
END

GO