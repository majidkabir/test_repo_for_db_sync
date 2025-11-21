SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure nspRPFIFO4 : 
--

/************************************************************************/
/* Stored Procedure: nspRPFIFO4                                         */
/* Creation Date: 24-Nov-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: SOS#62931 - Replensihment for IDSHK LOR principle           */
/*          - Replenish To Forward Pick Area (FPA) By WaveKey           */
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
/* Date         Author    Purposes                                      */
/************************************************************************/

CREATE PROC [dbo].[nspRPFIFO4] 
   @c_StorerKey  NVARCHAR(15),
   @c_SKU        NVARCHAR(20),
   @c_LOC        NVARCHAR(10),
   @c_Lot        NVARCHAR(10),
   @c_Facility01 NVARCHAR(5),
   @c_Facility02 NVARCHAR(5)  
AS
BEGIN
   SELECT DISTINCT LOTxLOCxID.LOT, 
          CASE WHEN LOTTABLE05 IS NULL THEN ''
          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE05)) +
               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE05))),2) +
               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE05))),2) 
          END as ExpiryDate
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK) 
   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
   AND LOTxLOCxID.SKU = @c_SKU
   AND LOTxLOCxID.LOC = LOC.LOC
   AND LOC.LocationFlag <> 'DAMAGE'
   AND LOC.LocationFlag <> 'HOLD'
   AND LOC.Status <> 'HOLD'
   AND LOC.LocationCategory <> 'SELECTIVE'
   AND LOC.Facility in (@c_Facility01, @c_Facility02)
   AND LOTxLOCxID.LOC <> @c_LOC
   AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
   AND LOT.LOT = LOTxLOCxID.LOT 
   AND LOT.STATUS <> 'HOLD' 
   AND LOTxLOCxID.LOT <> ISNULL(@c_Lot, '')
   AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
   ORDER BY       
      CASE WHEN LOTTABLE05 IS NULL 
           THEN ''
      ELSE CONVERT(char(4), DATEPART(year, LOTTABLE05)) +
           RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE05))),2) +
           RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE05))),2) 
      END, 
      LOTxLOCxID.LOT
END

GO