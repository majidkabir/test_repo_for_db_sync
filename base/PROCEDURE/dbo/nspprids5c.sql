SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspPRIDS5C                                         */  
/* Creation Date: 08-JUL-2014                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: New Allocation Strategy for FEFO SOS315461                  */  
/*                                                                      */  
/* Called By: Exceed Allocate Orders                                    */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version:                                                             */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */
/* 17-Jan-2020  Wan01   1.1   Dynamic SQL review, impact SQL cache log  */     
/************************************************************************/  
  
CREATE PROC [dbo].[nspPRIDS5C]  
@c_storerkey NVARCHAR(15) ,  
@c_sku NVARCHAR(20) ,  
@c_lot NVARCHAR(10) ,  
@c_lottable01 NVARCHAR(18) ,  
@c_lottable02 NVARCHAR(18) ,  
@c_lottable03 NVARCHAR(18) ,  
@d_lottable04 datetime,  
@d_lottable05 datetime,  
@c_uom NVARCHAR(10),  
@c_facility NVARCHAR(10)  ,  
@n_uombase int ,  
@n_qtylefttofulfill int,  
@c_OtherParms NVARCHAR(200)  
AS  
BEGIN  
   SET NOCOUNT ON  
  
   DECLARE @c_SQLParms        NVARCHAR(4000) = ''        --(Wan01)  

   Declare @b_debug int  
   SELECT @b_debug= 0  
  
   IF ISNULL(LTRIM(RTRIM(@c_lot)),'') <> '' AND LEFT(@c_lot, 1) <> '*'  
   BEGIN  
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
      FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)  
      WHERE LOT.LOT = LOTATTRIBUTE.LOT  
      AND LOTXLOCXID.Lot = LOT.LOT  
      AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
      AND LOTXLOCXID.LOC = LOC.LOC  
      AND LOC.Facility = @c_facility  
      AND LOT.LOT = @c_lot  
      ORDER BY LOTATTRIBUTE.LOTTABLE04  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
         QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
         FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)  
         WHERE LOT.LOT = LOTATTRIBUTE.LOT  
         AND LOTXLOCXID.Lot = LOT.LOT  
         AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
         AND LOTXLOCXID.LOC = LOC.LOC  
         AND LOC.Facility = @c_facility  
         AND LOT.LOT = @c_lot  
         ORDER BY LOTATTRIBUTE.LOTTABLE04  
      END  
   END  
   ELSE  
   BEGIN  
      -- Get OrderKey and line Number  
      DECLARE @c_OrderKey        NVARCHAR(10),  
              @c_OrderLineNumber NVARCHAR(5)  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT '@c_OtherParms' = @c_OtherParms  
      END  
  
      IF ISNULL(RTRIM(@c_OtherParms),'') <> ''  
      BEGIN  
         SELECT @c_OrderKey = LEFT(ISNULL(RTRIM(@c_OtherParms),''), 10)  
         SELECT @c_OrderLineNumber = SUBSTRING(ISNULL(RTRIM(@c_OtherParms),''), 11, 5)  
      END  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT '@c_OrderKey' = @c_OrderKey, '@c_OrderLineNumber' = @c_OrderLineNumber  
      END  
      -- Get MinShelfLife  
      DECLARE @n_ConsigneeMinShelfLife int,  
              @n_SKUShelfLife          int,  
              @c_LimitString           nvarchar(512)  
  
      SELECT @n_ConsigneeMinShelfLife = 0  
      SELECT @c_Limitstring = ''  
  
      IF ISNULL(RTRIM(@c_OrderKey),'') <> ''  
      BEGIN  
         SELECT @n_ConsigneeMinShelfLife = ISNULL(STORER.MinShelfLife,0)  
         FROM   ORDERS (NOLOCK)  
         JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)  
         WHERE ORDERS.OrderKey = @c_OrderKey  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT '@n_ConsigneeMinShelfLife' = @n_ConsigneeMinShelfLife  
         END  
  
         -- Modified By SHONG on 8th Apr 2003  
         -- Change condition greater or equal to..  
         IF @n_ConsigneeMinShelfLife > 0  
         BEGIN  
            SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND ( DATEDIFF(day, GETDATE(), Lottable04) >= @n_ConsigneeMinShelfLife OR Lottable04 IS NULL) "  
  
            IF @b_debug = 1  
            BEGIN  
               SELECT '@c_Limitstring' = @c_Limitstring  
            END  
         END  
         ELSE  
         BEGIN  
            SELECT @n_SKUShelfLife = SKU.ShelfLife--ISNULL(SKU.ShelfLife,0)  
            FROM  SKU (NOLOCK)   
            WHERE StorerKey = @c_storerkey   
              AND SKU   = @c_sku   
  
            IF @b_debug = 1  
            BEGIN  
               SELECT '@n_SKUShelfLife' = @n_SKUShelfLife  
            END  
  
            IF ISNULL(@n_SKUShelfLife,0) > 0  
            BEGIN  
               SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND ( DATEDIFF(day, GETDATE(), Lottable04) >= @n_SKUShelfLife OR Lottable04 IS NULL) "  
  
               IF @b_debug = 1  
               BEGIN  
                  SELECT '@c_Limitstring' = @c_Limitstring  
               END  
            END
              
            IF @n_SKUShelfLife IS NULL
            BEGIN
                SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND 1=2 "  
            END
         END  
      END  
      
      DECLARE @c_Condition NVARCHAR(2000)
      
      IF RTrim(LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = @c_Lottable01 "
      END
      IF RTrim(LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE02 = @c_Lottable02 "
      END
      IF RTrim(LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE03 = @c_Lottable03 "
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE04 = @d_Lottable04 "
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = RTrim(@c_Condition) + " AND LOTTABLE05 = @d_Lottable05 "
      END
      
      IF @c_UOM = '1' --Pallet
      BEGIN
          SELECT @c_Condition = RTrim(@c_Condition) + " AND SKUXLOC.LocationType NOT IN ('PICK','CASE') "
      END
       
      DECLARE @c_SQLStatement nvarchar(max)  
  
      SELECT @c_SQLStatement = "DECLARE  PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY FOR " +  
      " SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT," +  
      -- Start : SOS24348  
      -- " QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD)" +  
      " QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) - MIN(LOT.QTYONHOLD) " +  
      -- End : SOS24348  
      " FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), SKUXLOC (NOLOCK) "  +  
      " WHERE LOT.LOT = LOTATTRIBUTE.LOT " +  
      " AND LOTXLOCXID.Lot = LOT.LOT " +  
      " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +  
      " AND LOTXLOCXID.LOC = LOC.LOC " +  
      " AND LOTXLOCXID.Storerkey = SKUXLOC.Storerkey " +  
      " AND LOTXLOCXID.Sku = SKUXLOC.Sku " +  
      " AND LOTXLOCXID.Loc = SKUXLOC.Loc " +  
      " AND LOC.Facility = @c_facility" +  
      " AND LOT.STORERKEY = @c_storerkey" +  
      " AND LOT.SKU = @c_sku" +  
      " AND LOT.STATUS = 'OK' " +  
      -- SOS24348  
      -- " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 " +  
      ISNULL(RTRIM(@c_Limitstring),'') +  ISNULL(RTRIM(@c_Condition),'') + 
      -- Start : SOS24348  
      " GROUP BY LOT.STORERKEY,LOT.SKU,LOT.LOT, LOTATTRIBUTE.LOTTABLE04,LOTATTRIBUTE.LOTTABLE05 " +  
      " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) - MIN(QTYONHOLD) > 0 " +  
      -- End : SOS24348  
      " ORDER BY LOTATTRIBUTE.LOTTABLE04,  LOTATTRIBUTE.LOTTABLE05"  
  
      --(Wan02) - START
      --EXECUTE(@c_SQLStatement)
      SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                     + ',@c_storerkey  NVARCHAR(15)'
                     + ',@c_SKU        NVARCHAR(20)'
                     + ',@c_Lottable01 NVARCHAR(18)'
                     + ',@c_Lottable02 NVARCHAR(18)'
                     + ',@c_Lottable03 NVARCHAR(18)'
                     + ',@d_lottable04 datetime'
                     + ',@d_lottable05 datetime'
                     + ',@n_ConsigneeMinShelfLife  int'
                     + ',@n_SKUShelfLife           int'
 
      
      EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                        ,@n_ConsigneeMinShelfLife, @n_SKUShelfLife   
    --(Wan02) - END


      IF @b_debug = 1  
      BEGIN  
         SELECT '@c_SQLStatement' = @c_SQLStatement  
      END  
  
   END  
END  

GO