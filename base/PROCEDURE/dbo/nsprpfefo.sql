SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nspRPFEFO                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* 17 Feb 2012  MCTang    1.0   Filter Lot.status <> 'HOLD' (MC01)      */
/************************************************************************/

CREATE PROC [dbo].[nspRPFEFO] 
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
	
   SELECT DISTINCT LOTxLOCxID.LOT, 
          CASE WHEN LOTTABLE04 IS NULL THEN ''
          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE04)) +
               RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(month, LOTTABLE04))),2) +
               RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(day, LOTTABLE04))),2) 
          END as ExpiryDate
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK) 
   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
   AND LOTxLOCxID.SKU = @c_SKU
   AND LOTxLOCxID.LOC = LOC.LOC
   AND LOC.LocationFlag <> 'DAMAGE'
   AND LOC.LocationFlag <> 'HOLD'
   AND LOC.Status <> 'HOLD'
   AND LOC.Facility = @c_Facility
   AND LOT.LOT = LOTxLOCxID.LOT           --MC01
   AND LOT.Status <> 'HOLD'               --MC01
   AND LOTxLOCxID.LOC <> @c_LOC
   AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
   AND LOTxLOCxID.LOT <> ISNULL(@c_Lot, '')
   AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
   ORDER BY       
      CASE WHEN LOTTABLE04 IS NULL 
           THEN ''
      ELSE CONVERT(char(4), DATEPART(year, LOTTABLE04)) +
           RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(month, LOTTABLE04))),2) +
           RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(day, LOTTABLE04))),2) 
      END, 
      LOTxLOCxID.LOT
END

GO