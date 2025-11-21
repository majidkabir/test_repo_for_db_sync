SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure nspRPUBF : 
--

CREATE PROC [dbo].[nspRPUBF] 
   @c_StorerKey NVARCHAR(15),
   @c_SKU       NVARCHAR(20),
   @c_LOC       NVARCHAR(10),
	@c_hostwhcode NVARCHAR(10),
   @c_Lot       NVARCHAR(10),
   @c_Facility  NVARCHAR(10),
	@c_zone02	 NVARCHAR(10),
	@c_zone03	 NVARCHAR(10),
	@c_zone04	 NVARCHAR(10),
	@c_zone05	 NVARCHAR(10),
	@c_zone06	 NVARCHAR(10),
	@c_zone07	 NVARCHAR(10),
	@c_zone08	 NVARCHAR(10),
	@c_zone09	 NVARCHAR(10),
	@c_zone10	 NVARCHAR(10),
	@c_zone11	 NVARCHAR(10),
	@c_zone12	 NVARCHAR(10)

AS
BEGIN
	IF @c_zone02 = 'ALL'
	BEGIN
	   SELECT LOTxLOCxID.LOT, 
				 LOTTABLE03, 
	          CASE WHEN LOTTABLE04 IS NULL THEN ''
	          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE04)) +
	               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE04))),2) +
	               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE04))),2) 
	          END as ExpiryDate,
				 LOC.LocLevel, 
				 LOC.Loc
	   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK) 
	   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
	   AND LOTxLOCxID.SKU = @c_SKU
	   AND LOTxLOCxID.LOC = LOC.LOC
	   AND LOC.LocationFlag <> 'DAMAGE'
	   AND LOC.LocationFlag <> 'HOLD'
	   AND LOC.Status <> 'HOLD'
	   AND LOT.STATUS <> 'HOLD' 
	   AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
	   AND LOT.LOT = LOTxLOCxID.LOT 
	   AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
	   AND LOTxLOCxID.LOT <> ISNULL(@c_Lot, '')
	   AND LOTxLOCxID.LOC <> @c_LOC
	   AND LOC.Facility = @c_Facility
	   AND LOC.hostwhcode = @c_hostwhcode
		GROUP BY LOTxLOCxID.LOT, 
				 LOTTABLE03, 
	          CASE WHEN LOTTABLE04 IS NULL THEN ''
	          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE04)) +
	               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE04))),2) +
	               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE04))),2) 
	          END,
				 LOC.LocLevel, 
				 LOC.Loc 
		ORDER BY LOTTABLE03,
	      CASE WHEN LOTTABLE04 IS NULL 
	           THEN ''
	      ELSE CONVERT(char(4), DATEPART(year, LOTTABLE04)) +
	           RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE04))),2) +
	           RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE04))),2) 
	      END, 
			LOC.LOCLEVEL,
			LOC.LOC
	END
	ELSE
	BEGIN
	   SELECT LOTxLOCxID.LOT, 
				 LOTTABLE03, 
	          CASE WHEN LOTTABLE04 IS NULL THEN ''
	          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE04)) +
	               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE04))),2) +
	               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE04))),2) 
	          END as ExpiryDate,
				 LOC.LocLevel, 
				 LOC.Loc
	   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK) 
	   WHERE LOTxLOCxID.StorerKey = @c_StorerKey
	   AND LOTxLOCxID.SKU = @c_SKU
	   AND LOTxLOCxID.LOC = LOC.LOC
	   AND LOC.LocationFlag <> 'DAMAGE'
	   AND LOC.LocationFlag <> 'HOLD'
	   AND LOC.Status <> 'HOLD'
	   AND LOT.STATUS <> 'HOLD' 
	   AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
	   AND LOT.LOT = LOTxLOCxID.LOT 
	   AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
	   AND LOTxLOCxID.LOT <> ISNULL(@c_Lot, '')
	   AND LOTxLOCxID.LOC <> @c_LOC
	   AND LOC.Facility = @c_Facility
	   AND LOC.hostwhcode = @c_hostwhcode 
	   AND LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
		GROUP BY LOTxLOCxID.LOT, 
				 LOTTABLE03, 
	          CASE WHEN LOTTABLE04 IS NULL THEN ''
	          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE04)) +
	               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE04))),2) +
	               RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE04))),2) 
	          END,
				 LOC.LocLevel, 
				 LOC.Loc
		ORDER BY LOTTABLE03,
	      CASE WHEN LOTTABLE04 IS NULL 
	           THEN ''
	      ELSE CONVERT(char(4), DATEPART(year, LOTTABLE04)) +
	           RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(month, LOTTABLE04))),2) +
	           RIGHT( '0' + dbo.fnc_RTRIM(CONVERT(char(2), DATEPART(day, LOTTABLE04))),2) 
	      END, 
			LOC.LOCLEVEL,
			LOC.LOC
	END
END

GO