SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspRpLIFO]
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
          END as ReceiptDate
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
   ORDER BY 
          CASE WHEN LOTTABLE05 IS NULL THEN ''
          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE05)) +
               RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(month, LOTTABLE05))),2) +
               RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(day, LOTTABLE05))),2) 
          END DESC, 
          LOTxLOCxID.LOT
END

GO