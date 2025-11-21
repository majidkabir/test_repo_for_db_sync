SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: nspPR_PM01                                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: PH PM Allocation Strategy (SOS79803)                        */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/************************************************************************/

CREATE PROC [dbo].[nspPR_PM01]
  	@c_StorerKey NVARCHAR(15) ,
  	@c_SKU NVARCHAR(20) ,
  	@c_LOT NVARCHAR(10) ,
  	@c_LOTtable01 NVARCHAR(18) ,
  	@c_LOTtable02 NVARCHAR(18) ,
  	@c_LOTtable03 NVARCHAR(18) ,
  	@d_Lottable04 datetime,
  	@d_Lottable05 datetime,
  	@c_UOM NVARCHAR(10),
   @c_Facility NVARCHAR(10)  ,
  	@n_UOMBase int ,
  	@n_QtyLeftToFulfill int,
   @c_OtherParms NVARCHAR(200)
AS
BEGIN
   SET NOCOUNT ON 
    
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) IS NOT NULL
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
             QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK) 
      WHERE LOT.LOT = LOTATTRIBUTE.LOT  
      AND LOTxLOCxID.Lot = LOT.LOT
      AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
      AND LOTxLOCxID.LOC = LOC.LOC
      AND LOC.Facility = @c_Facility
      AND LOT.LOT = @c_LOT
      ORDER BY LOTATTRIBUTE.LOTTABLE04
   END
   ELSE
   BEGIN
      -- Get OrderKey and line Number
      DECLARE @c_OrderKey        NVARCHAR(10),
              @c_OrderLineNumber NVARCHAR(5), 
              @n_SKU_OutGoingShelfLife int 
      
      IF dbo.fnc_RTrim(@c_OtherParms) IS NOT NULL AND dbo.fnc_RTrim(@c_OtherParms) <> ''
      BEGIN
         SELECT @c_OrderKey = LEFT(dbo.fnc_LTrim(@c_OtherParms), 10)
         SELECT @c_OrderLineNumber = SUBSTRING(dbo.fnc_LTrim(@c_OtherParms), 11, 5)
      END
   
       -- Get BillToKey
       DECLARE @n_ConsigneeMinShelfLife int,
               @c_LimitString           NVARCHAR(1024) 

      DECLARE @c_SQLStatement NVARCHAR(2048), 
              @n_Pallet       int,
              @n_CaseCnt      int 
    
       IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND dbo.fnc_RTrim(@c_OrderKey) <> ''
       BEGIN
          SELECT @n_ConsigneeMinShelfLife = ISNULL(STORER.MinShelfLife,0) 
          FROM   ORDERS (NOLOCK) 
          JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
          WHERE ORDERS.OrderKey = @c_OrderKey
   
          SELECT @n_SKU_OutGoingShelfLife = CAST(CASE WHEN ISNUMERIC(BUSR2) = 1 THEN BUSR2 ELSE '0' END AS Integer), 
                 @n_Pallet = PACK.Pallet, 
                 @n_CaseCnt = PACK.CaseCnt  
          FROM   SKU WITH (NOLOCK)
          JOIN PACK WITH (NOLOCK) ON SKU.PackKey = Pack.PackKey 
          WHERE  STORERKEY = @c_StorerKey 
          AND    SKU = @c_SKU 
   
          IF @n_SKU_OutGoingShelfLife > 0 
          BEGIN
             SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND DATEDIFF(day, Lottable04, GETDATE()) > " + CAST(@n_SKU_OutGoingShelfLife as NVARCHAR(10))
          END 
          IF @n_ConsigneeMinShelfLife > 0 
          BEGIN 
             SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND DATEDIFF(day, Lottable04, GETDATE()) <= " + CAST(@n_ConsigneeMinShelfLife as NVARCHAR(10))
          END 

          IF @n_QtyLeftToFulfill >= @n_Pallet 
             SET @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND SKUxLOC.LocationType NOT IN ('CASE', 'PICK') "
          ELSE IF @n_QtyLeftToFulfill < @n_CaseCnt 
             SET @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND SKUxLOC.LocationType = 'PICK' " 

      END
   

   
      SELECT @c_SQLStatement = "DECLARE  PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY FOR " +
      " SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT," +
      " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) " +
      " FROM LOTxLOCxID WITH (NOLOCK) " + 
      " JOIN LOT WITH (NOLOCK) ON LOTxLOCxID.Lot = LOT.LOT AND LOT.STATUS = 'OK' " +
      " JOIN LOC WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC AND LOC.Status <> 'HOLD' AND LOC.LocationFlag NOT IN ('DAMAGE','HOLD') " + 
      " JOIN ID WITH (NOLOCK) ON LOTxLOCxID.ID = ID.ID AND ID.Status <> 'HOLD' " +    
      " JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT " + 
      " JOIN SKUxLOC WITH (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND SKUxLOC.SKU = LOTxLOCxID.SKU " + 
      " AND SKUxLOC.LOC = LOTxLOCxID.LOC " + 
      " WHERE LOC.Facility = N'" + dbo.fnc_RTrim(@c_Facility) + "'" + 
      " AND LOT.STORERKEY = N'" + dbo.fnc_RTrim(@c_StorerKey) + "'" +
      " AND LOT.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "'" +
      dbo.fnc_RTrim(@c_Limitstring) +
   	" GROUP BY LOT.STORERKEY,LOT.SKU,LOT.LOT, LOTATTRIBUTE.LOTTABLE04 " +
      " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) - MIN(QTYONHOLD) > 0 " +
      " ORDER BY LOTATTRIBUTE.LOTTABLE04"
   
      EXEC ( @c_SQLStatement )

   END
END

GO