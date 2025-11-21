SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRTW                                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: New Preallocation Strategy                                  */
/*                                                                      */
/* Called By: Exceed Allocate Orders                                    */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver Purposes                                   */
/* 26-Mar-2013  TLTING01 1.1 Add new Parameter default value            */
/* 22-Mar-2017  NJOW01   1.2 WMS-1112 Skip if OD.userdefine04='MOMO'    */
/* 26-Nov-2019  Wan01    1.3 Dynamic SQL review, impact SQL cache log   */ 
/************************************************************************/

CREATE PROC  [dbo].[nspPRTW]  
@c_storerkey NVARCHAR(15) ,  
@c_sku NVARCHAR(20) ,  
@c_lot NVARCHAR(10) ,  
@c_lottable01 NVARCHAR(18) ,  
@c_lottable02 NVARCHAR(18) ,  
@c_lottable03 NVARCHAR(18) ,  
@d_lottable04 datetime ,  
@d_lottable05 datetime ,  
@c_uom NVARCHAR(10) ,   
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5  
@n_uombase int ,  
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200)  = ''  
AS  
BEGIN  
  
   SET NOCOUNT ON  
  
   DECLARE @n_StorerMinShelfLife int,  
           @c_Condition NVARCHAR(510),
           @c_Orderkey NVARCHAR(10), --NJOW01
            @c_OrderLineNumber NVARCHAR(5), --NJOW01
            @c_ODUserdefine04 NVARCHAR(18) --NJOW01

   DECLARE @c_SQL       NVARCHAR(3999)  = ''       --(Wan01) 
         , @c_SQLParms  NVARCHAR(3999)  = ''       --(Wan01) 
             
   --NJOW01
   IF LEN(@c_OtherParms) > 0
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms ,10)
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
      
      SELECT @c_ODUserdefine04 = Userdefine04
      FROM ORDERDETAIL(NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND OrderLineNumber = @c_OrderLineNumber            
      
      IF @c_ODUserdefine04 = "MOMO"     
      BEGIN    
          DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
          SELECT TOP 0 NULL, NULL, NULL, 0     
          
          RETURN
      END
   END      
            
   IF ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)),'') <> '' AND LEFT(@c_LOT,1) <> '*' 
   BEGIN  
      /* Get Storer Minimum Shelf Life */  
      SELECT @n_StorerMinShelfLife = ISNULL(Storer.MinShelflife, 0)  
      FROM   STORER (NOLOCK)  
      WHERE  STORERKEY = @c_lottable03  
    
      SELECT @n_StorerMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_StorerMinShelfLife /100) * -1)  
      FROM  Sku (nolock)  
      WHERE Sku.Sku = @c_SKU  
      AND   Sku.Storerkey = @c_Storerkey  
  
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY   
      FOR   
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
      FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK)   
      WHERE LOT.LOT = LOTATTRIBUTE.LOT    
      AND LOTXLOCXID.Lot = LOT.LOT  
      AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
      AND LOTXLOCXID.LOC = LOC.LOC  
      AND LOC.Facility = @c_facility  
      AND LOT.LOT = @c_lot   
      AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate()   
      ORDER BY Lotattribute.Lottable04, Lot.Lot  
   END  
   ELSE  
   BEGIN                      
      /* Get Storer Minimum Shelf Life */  
      /* Lottable03 = Consignee Key */  
      SELECT @n_StorerMinShelfLife = ISNULL(Storer.MinShelflife, 0)  
      FROM   STORER (NOLOCK)  
      WHERE  STORERKEY = dbo.fnc_RTrim(@c_lottable03)  
  
      SELECT @n_StorerMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_StorerMinShelfLife /100) * -1)  
      FROM  Sku (nolock)  
      WHERE Sku.Sku = @c_SKU  
      AND   Sku.Storerkey = @c_Storerkey  
  
      IF @n_StorerMinShelfLife IS NULL  
         SELECT @n_StorerMinShelfLife = 0  
  
      -- lottable01 is used for loc.HostWhCode -- modified by Jeff  
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL  
      BEGIN  
         SELECT @c_Condition = " AND LOC.HostWhCode = @c_Lottable01 "                           --(Wan01)  
      END  
  
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL  
      BEGIN  
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = @c_Lottable02 " --(Wan01)  
      END  
  
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_Lottable04 IS NOT NULL  
      BEGIN  
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = @d_Lottable04 " --(Wan01)  
      END  
  
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_Lottable05 IS NOT NULL  
      BEGIN  
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = @d_Lottable05 " --(Wan01)  
      END  
  
      -- if lottable04 is blank, then get candidate based on expiry date based on the following conversion.  
      IF @n_StorerMinShelfLife <> 0   
      BEGIN  
         IF CONVERT(char(10), @d_Lottable04, 103) = "01/01/1900" OR @d_Lottable04 IS NULL  
         BEGIN  
            SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND ( DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() " --(Wan01)  
            SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " OR Lotattribute.Lottable04 IS NULL ) "  
         END  
      END  
  
      SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04 "  
      SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0  "  
      SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot"  
  
      SET @c_SQL ="DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +  
      " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +  
      " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) " +   
      " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (nolock), LOC (Nolock), ID (NOLOCK) " +  
      " WHERE LOT.STORERKEY = @c_storerkey " +        --(Wan01)  
      " AND LOT.SKU =  @c_SKU " +                     --(Wan01)  
      " AND LOT.STATUS = 'OK' " +  
      " AND LOT.LOT = LOTATTRIBUTE.LOT " +  
      " AND LOT.LOT = LOTXLOCXID.Lot " +  
      " AND LOTXLOCXID.Loc = LOC.Loc " +  
      " AND LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +   
      " AND LOTXLOCXID.ID = ID.ID " +  
      " AND ID.STATUS <> 'HOLD' " +    
      " AND LOC.Status = 'OK' " +   
      " AND LOC.Facility = @c_facility " +            --(Wan01)  
      " AND LOC.LocationFlag <> 'HOLD' " +  
      " AND LOC.LocationFlag <> 'DAMAGE' " +  
      -- " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 " +   
      -- " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 " +   
      @c_Condition   
      --(Wan01) - START
      SET @c_SQLParms=N' @c_Facility   NVARCHAR(5)'
                     + ',@c_Storerkey  NVARCHAR(15)'
                     + ',@c_SKU        NVARCHAR(20)'     
                     + ',@c_Lottable01 NVARCHAR(18)'
                     + ',@c_Lottable02 NVARCHAR(18)' 
                     + ',@d_Lottable04 DATETIME'
                     + ',@d_Lottable05 DATETIME'
                     + ',@n_StorerMinShelfLife INT '       
      
      EXEC sp_ExecuteSQL @c_SQL
                     , @c_SQLParms
                     , @c_Facility
                     , @c_Storerkey
                     , @c_SKU
                     , @c_Lottable01
                     , @c_Lottable02
                     , @d_Lottable04
                     , @d_Lottable05
                     , @n_StorerMinShelfLife
      --(Wan01) - END
   END        
END 


GO