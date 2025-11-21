SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nspRPFEFO5                                          */
/* Creation Date: 23-FEB-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Filter Lot where Lottable04 - SKU.SUSR2 < CurrentDate       */
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

CREATE PROC [dbo].[nspRPFEFO5] 
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
   
   SELECT DISTINCT LOTxLOCxID.LOT
        , CASE WHEN LOTTABLE04 IS NULL THEN ''
          ELSE CONVERT(VARCHAR(8), LOTTABLE04, 112)
          END as ExpiryDate
   FROM LOT WITH (NOLOCK)  
   JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot = LOTATTRIBUTE.Lot)
   JOIN LOTxLOCxID WITH (NOLOCK) ON (LOT.Lot = LOTxLOCxID.Lot)
   JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
   JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.Storerkey = SKU.Storerkey)
                          AND(LOTxLOCxID.Sku = SKU.Sku)
   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
   AND LOTxLOCxID.SKU = @c_SKU
   AND LOC.Facility = @c_Facility
   AND LOC.LocationFlag <> 'DAMAGE'
   AND LOC.LocationFlag <> 'HOLD'
   AND LOC.Status <> 'HOLD'
   AND LOT.Status <> 'HOLD'               
   AND LOTxLOCxID.LOC <> @c_LOC
   AND LOTxLOCxID.LOT <> ISNULL(@c_Lot, '')
   AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
   AND ISNULL(LOTATTRIBUTE.Lottable04, CONVERT(DATETIME,'1900-01-01')) > 
       DATEADD ( DAY, CASE WHEN ISNUMERIC(SKU.SUSR2) = 1 THEN ISNULL(SKU.SUSR2,0) ELSE 0 END ,CONVERT(VARCHAR, GETDATE(),112))
   ORDER BY       
      CASE WHEN LOTTABLE04 IS NULL THEN ''
      ELSE CONVERT(VARCHAR(8), LOTTABLE04, 112)
      END 
     ,LOTxLOCxID.LOT
END

GO