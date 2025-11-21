SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nspPRIDS18                                         */
/* Creation Date: -                                                     */
/* Copyright: IDS                                                       */
/* Written by: -                                                        */
/*                                                                      */
/* Purpose:  Full Pallet Preallocation for BULK Location                */
/*                                                                      */
/* Input Parameters:                                                    */
/* Output Parameters:                                                   */
/*                                                                      */
/* Called By:  nspPreallocateOrderProcessing                            */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Nov-2008  Leong     1.1   SOS#122073 - Bug fix                    */
/* 18-AUG-2015 YTWan      1.2   SOS#350432 - Project Merlion -          */
/*                              Allocation Strategy (Wan01)             */
/************************************************************************/
CREATE PROC [dbo].[nspPRIDS18]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_lottable06 NVARCHAR(30) ,  --(Wan01)  
@c_lottable07 NVARCHAR(30) ,  --(Wan01)  
@c_lottable08 NVARCHAR(30) ,  --(Wan01)
@c_lottable09 NVARCHAR(30) ,  --(Wan01)
@c_lottable10 NVARCHAR(30) ,  --(Wan01)
@c_lottable11 NVARCHAR(30) ,  --(Wan01)
@c_lottable12 NVARCHAR(30) ,  --(Wan01)
@d_lottable13 DATETIME ,      --(Wan01)
@d_lottable14 DATETIME ,      --(Wan01)   
@d_lottable15 DATETIME ,      --(Wan01)
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(5),     
@n_uombase int ,
@n_qtylefttofulfill int 
,@c_OtherParms NVARCHAR(200)=''--(Wan01)
AS
BEGIN
SET CONCAT_NULL_YIELDS_NULL OFF  
SET NOCOUNT ON

--(Wan01) - START
DECLARE @c_SQLStatement NVARCHAR(4000) 
      , @c_Condition    NVARCHAR(4000)   
      
SET @c_SQLStatement = ''
--(Wan01) - END

IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
         QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
         FROM LOT (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)  
         WHERE LOTXLOCXID.Lot = LOT.LOT
         AND LOTXLOCXID.LOC = LOC.LOC
         And LOC.LocationFlag <> 'DAMAGE' And LOC.LocationFlag <> 'HOLD'
         AND LOC.Facility = @c_facility
         AND LOT.LOT = @c_lot
         ORDER BY LOT.LOT
   END
ELSE
   BEGIN
       /* Below Modified by CYOU on 24 Jul 2000 - Qualify only Location with Qty >= Pallet Qty */
      DECLARE @n_palletqty int
      SELECT @n_palletqty = ISNULL(Pack.Pallet,0)
      FROM Sku (nolock), Pack (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.PackKey = Pack.PackKey

      IF @n_palletqty > @n_qtylefttofulfill
        SELECT @n_palletqty = 1
      /* Above Modified by CYOU on 24 Jul 2000 - Qualify only Location with Qty >= Pallet Qty */

      --(Wan01) - START
      SET @c_Condition = ''

      IF RTRIM(@c_Lottable01) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable01 = N''' + RTRIM(@c_Lottable01) + '''' 
      END   

      IF RTRIM(@c_Lottable02) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable02 = N''' + RTRIM(@c_Lottable02) + '''' 
      END   

      IF RTRIM(@c_Lottable03) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable03 = N''' + RTRIM(@c_Lottable03) + '''' 
      END   

      IF CONVERT(CHAR(10), @d_Lottable04, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable04 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + ''''
      END

      IF CONVERT(CHAR(10), @d_Lottable05, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable05 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + ''''
      END
      
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable09 = N''' + RTRIM(@c_Lottable09) + '''' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable10 = N''' + RTRIM(@c_Lottable10) + '''' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
      END  

      IF CONVERT(CHAR(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
      END

      IF CONVERT(CHAR(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
      END

      IF CONVERT(CHAR(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
      END
      
      SET @c_SQLStatement = N'DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   -- SOS#122073
         SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,
         QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )
         FROM LOTATTRIBUTE (NOLOCK)
         JOIN LOT (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT 
         JOIN LOTxLOCxID (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT 
         JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC 
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
         JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.StorerKey = SKUxLOC.StorerKey
                            AND LOTxLOCxID.SKU = SKUxLOC.SKU
                            AND LOTxLOCxID.LOC = SKUxLOC.LOC 
         WHERE LOT.STORERKEY = ''' + @c_storerkey + '''
         AND LOT.SKU = ''' + @c_sku + '''
         AND LOT.STATUS = ''OK''
         AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  
         AND SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'')
         And LOC.LocationFlag <> ''DAMAGE'' And LOC.LocationFlag <> ''HOLD''
         AND LOC.Facility = ''' + @c_facility + '''' +
         @c_Condition + '
         GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT 
         HAVING (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) ) >= ' + CONVERT(VARCHAR(10),@n_palletqty) + '
         ORDER BY LOT.LOT' 
         EXEC(@c_SQLStatement)
         --(Wan01) - END
   END
END

GO