SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspRPFIFO3         							            */
/* Creation Date: 																		*/
/* Copyright: IDS                                                       */
/* Written by: 			                                                */
/*                                                                      */
/* Purpose: 				                                                */
/*                                                                      */
/* Called By: nsp_ReplenishmentRpt_ByLoad_01- r_replenishment_by_load01	*/
/* 			  nsp_ReplenishmentRpt_ByLoad_02- r_replenishment_by_load02 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 01-Apr-2008  June 	  SOS101294. Replen by Lot02.							*/
/* 22-Oct-2009  Leong     SOS150962 - Bug fix for replen by Lot02       */
/************************************************************************/

CREATE PROC [dbo].[nspRPFIFO3]
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
	-- Start : SOS101294
	--IF @c_Lot = '*'                      -- SOS150962
	IF LEFT(RTRIM(LTRIM(@c_Lot)), 1) = '*' -- SOS150962
	BEGIN
		SELECT @c_Lot = RIGHT(RTRIM(LTRIM(@c_Lot)), LEN(@c_Lot) - 1)

	   SELECT DISTINCT LOTxLOCxID.LOT,
	          CASE WHEN LOTTABLE05 IS NULL THEN ''
	          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE05)) +
	               RIGHT( '0' + RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE05))),2) +
	               RIGHT( '0' + RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE05))),2)
	          END as ExpiryDate,
	          0 as Qty
	   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK)
	   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
	   AND LOTxLOCxID.SKU = @c_SKU
	   AND LOTxLOCxID.LOC = LOC.LOC
	   AND LOC.LocationFlag <> 'DAMAGE'
	   AND LOC.LocationFlag <> 'HOLD'
	   AND LOC.Status <> 'HOLD'
	   AND LOC.Facility = @c_Facility
	   AND LOTxLOCxID.LOC <> @c_LOC
	   AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
	   AND LOT.LOT = LOTxLOCxID.LOT
	   AND LOT.STATUS <> 'HOLD'
		AND LOTATTRIBUTE.Lottable02 = @c_Lot
	   AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0
	   ORDER BY
	      CASE WHEN LOTTABLE05 IS NULL
	           THEN ''
	      ELSE CONVERT(char(4), DATEPART(year, LOTTABLE05)) +
	           RIGHT( '0' + RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE05))),2) +
	           RIGHT( '0' + RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE05))),2)
	      END,
	      LOTxLOCxID.LOT
	END
	ELSE
	-- End : SOS101294
	BEGIN -- Existing
	   SELECT DISTINCT LOTxLOCxID.LOT,
	          CASE WHEN LOTTABLE05 IS NULL THEN ''
	          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE05)) +
	               RIGHT( '0' + RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE05))),2) +
	               RIGHT( '0' + RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE05))),2)
	          END as ExpiryDate,
	          0 as Qty
	   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK)
	   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
	   AND LOTxLOCxID.SKU = @c_SKU
	   AND LOTxLOCxID.LOC = LOC.LOC
	   AND LOC.LocationFlag <> 'DAMAGE'
	   AND LOC.LocationFlag <> 'HOLD'
	   AND LOC.Status <> 'HOLD'
	   AND LOC.Facility = @c_Facility
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
	           RIGHT( '0' + RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE05))),2) +
	           RIGHT( '0' + RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE05))),2)
	      END,
	      LOTxLOCxID.LOT
	END
END

GO