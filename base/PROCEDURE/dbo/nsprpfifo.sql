SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: nspRPFIFO                                             */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Called By: isp_GenReplenishment                                         */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author     Ver   Purposes                                  */
/* 09-Nov-2009  ChewKP     1.1   SOS#152090  - Replenishment Process       */
/* 10-Feb-2017  NJOW01     1.2   WMS-1113 exclude hold lot                 */
/***************************************************************************/

CREATE PROC [dbo].[nspRPFIFO]
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
          CASE WHEN LOTTABLE05 IS NULL THEN ''
          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE05)) +
               RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(month, LOTTABLE05))),2) +
               RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(day, LOTTABLE05))),2) 
          END as ExpiryDate   
   FROM LOTxLOCxID WITH (NOLOCK) 
   JOIN LOC WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC 
   JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
   JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = LOTxLOCxID.StorerKey 
                                        AND SL.SKU = LOTxLOCxID.SKU 
                                        AND SL.LOC = LOTxLOCxID.LOC                
   JOIN LOT WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT --NJOW01
   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
   AND LOTxLOCxID.SKU = @c_SKU
   AND LOC.LocationFlag <> "DAMAGE"
   AND LOC.LocationFlag <> "HOLD"
   AND LOC.Status <> "HOLD"
   AND LOC.Facility = @c_Facility
   AND LOTxLOCxID.LOC <> @c_LOC
   AND LOTxLOCxID.LOT <> ISNULL(@c_Lot, '')
   AND SL.Locationtype <> 'CASE' --- SOS#152090 ---
   AND SL.Locationtype <> 'PICK' --- SOS#152090 ---
   AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
   AND LOT.STATUS <> 'HOLD'   --NJOW01
   ORDER BY 
      CASE WHEN LOTTABLE05 IS NULL 
           THEN ''
      ELSE CONVERT(char(4), DATEPART(year, LOTTABLE05)) +
           RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(month, LOTTABLE05))),2) +
           RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(day, LOTTABLE05))),2) 
      END, 
      LOTxLOCxID.LOT
END

GO