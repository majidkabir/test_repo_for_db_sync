SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nspRPFEFO2] 
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
	
   DECLARE @nOutGoingShelfLife int

   SELECT @nOutGoingShelfLife = CASE WHEN ISNUMERIC(SUSR2) = 1 Then CAST(SUSR2 as int) * -1
                                ELSE 0
                                END 
   FROM   SKU (NOLOCK)
   WHERE  StorerKey = @c_StorerKey
   AND    SKU       = @c_SKU 

   SELECT DISTINCT LOTxLOCxID.LOT, 
          CASE WHEN LOTTABLE04 IS NULL THEN ''
          ELSE CONVERT(char(4), DATEPART(year, LOTTABLE04)) +
               RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(month, LOTTABLE04))),2) +
               RIGHT( '0' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(day, LOTTABLE04))),2) 
          END as ExpiryDate
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
   AND DateAdd(day, @nOutGoingShelfLife, LOTATTRIBUTE.Lottable04) > Convert(Datetime, Convert(char(12), GetDate(),106))
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