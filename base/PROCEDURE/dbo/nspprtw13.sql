SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRTW13                                          */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1112 TW LOR preallocate one lottable04 per sku          */
/*                                                                      */
/* Called By: Exceed Allocate Orders                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 15-Aug-2019  WLChooi  1.1 WMS-10216 Add lottable06-15, exclude empty */ 
/*                           lottable02 filter by codelkup config (WL01)*/
/* 26-Nov-2019  Wan01    1.3 Dynamic SQL review, impact SQL cache log   */ 
/************************************************************************/

CREATE PROC  [dbo].[nspPRTW13]  
@c_storerkey NVARCHAR(15) ,  
@c_sku NVARCHAR(20) ,  
@c_lot NVARCHAR(10) ,  
@c_lottable01 NVARCHAR(18) ,  
@c_lottable02 NVARCHAR(18) ,  
@c_lottable03 NVARCHAR(18) ,  
@d_lottable04 datetime ,  
@d_lottable05 datetime , 
@c_lottable06 NVARCHAR(30),  --WL01 Start
@c_lottable07 NVARCHAR(30),
@c_lottable08 NVARCHAR(30),
@c_lottable09 NVARCHAR(30),
@c_lottable10 NVARCHAR(30),
@c_lottable11 NVARCHAR(30),
@c_lottable12 NVARCHAR(30),
@d_lottable13 datetime,
@d_lottable14 datetime,
@d_lottable15 datetime,     --WL01 End   
@c_uom NVARCHAR(10) ,   
@c_facility NVARCHAR(10)  ,  
@n_uombase int ,  
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200)  = ''  
AS  
BEGIN  
  
   SET NOCOUNT ON  
  
   DECLARE @n_StorerMinShelfLife INT,  
           @n_OrderMinShelfLife INT,
           @c_Condition NVARCHAR(510),                        
           @c_Orderkey NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_ODUserdefine04 NVARCHAR(18),
           @c_SQL NVARCHAR(MAX),
           @c_SQLDYN NVARCHAR(MAX),
           @d_Prevlottable04 DATETIME 

   DECLARE @c_SQLParms  NVARCHAR(3999)  = ''       --(Wan01)                      
  
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
         IF LEN(@c_OtherParms) > 0
         BEGIN
            SET @c_OrderKey = LEFT(@c_OtherParms ,10)
            SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
            
            SELECT @c_ODUserdefine04 = Userdefine04,
                   @n_OrderMinShelfLife = MinShelfLife             
            FROM ORDERDETAIL(NOLOCK)
            WHERE Orderkey = @c_Orderkey
            AND OrderLineNumber = @c_OrderLineNumber            

            IF @n_OrderMinShelfLife IS NULL  
               SELECT @n_OrderMinShelfLife = 0                                         
         END

         IF @c_ODUserdefine04 = "MOMO"     
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
                  SELECT @c_Condition = " AND LOC.HostWhCode = RTRIM(@c_Lottable01) "                          --(Wan01)   
               END  
            
            IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL  
               BEGIN  
                  SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = RTRIM(@c_Lottable02) "--(Wan01)   
               END  
            
            IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_Lottable04 IS NOT NULL  
               BEGIN  
                  SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 >= @d_Lottable04 "      --(Wan01)  
               END  
            
            IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_Lottable05 IS NOT NULL  
               BEGIN  
                  SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = @d_Lottable05 "       --(Wan01)  
               END
            
            --WL01 Start
            IF ISNULL(@c_Lottable10,'') <> '' 
            BEGIN
               SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE10 = RTRIM(@c_Lottable10) '   --(Wan01) 
            END
            ELSE
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                                WHERE CL.Storerkey = @c_Storerkey
                                AND CL.Code = 'NOFILTEREMPTYLOT10'
                                AND CL.Listname = 'PKCODECFG' 
                                AND CL.Long = 'nspPRTW13'
                                AND CL.Code2 = 'nspPRTW13'
                                AND ISNULL(CL.Short,'') <> 'N')
               BEGIN
                  SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE10 = '''' '
               END
            END
            --WL01 End  
            
            IF @n_OrderMinShelfLife <> 0
            BEGIN
               --IF CONVERT(char(10), @d_Lottable04, 103) = "01/01/1900" OR @d_Lottable04 IS NULL  
               --   BEGIN  
                      SELECT @n_OrderMinShelfLife = @n_OrderMinShelfLife * -1
                     SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND ( DateAdd(Day, @n_OrderMinShelfLife, Lotattribute.Lottable04) > GetDate() "  --(Wan01)   
                     SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " OR Lotattribute.Lottable04 IS NULL ) "  
               --   END  
            END
            ELSE IF @n_StorerMinShelfLife <> 0   
            BEGIN  
              -- if lottable04 is blank, then get candidate based on expiry date based on the following conversion.  
               --IF CONVERT(char(10), @d_Lottable04, 103) = "01/01/1900" OR @d_Lottable04 IS NULL  
               --   BEGIN  
                     SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND ( DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() " --(Wan01)   
                     SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " OR Lotattribute.Lottable04 IS NULL ) "  
               --   END  
            END  
             
            --check if previous uom preallocation already found lottable04 can fulfill the sku
            SELECT TOP 1 @d_PrevLottable04 = LA.Lottable04
            FROM PREALLOCATEPICKDETAIL PA (NOLOCK)
            JOIN LOTATTRIBUTE LA (NOLOCK) ON PA.Lot = LA.Lot
            WHERE PA.Orderkey = @c_Orderkey
            AND PA.Sku = @c_Sku
            --AND PA.OrderLineNumber = @c_OrderLineNumber  
              
            --check if previous allocation(partial) already found lottable04 can fulfill the sku
            IF @@ROWCOUNT = 0
            BEGIN
               SELECT TOP 1 @d_PrevLottable04 = LA.Lottable04
               FROM PICKDETAIL PD (NOLOCK)
               JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.Orderkey = @c_Orderkey
               AND PD.Sku = @c_Sku                 
               --AND PD.OrderLineNumber = @c_OrderLineNumber  
            END
                    
            IF CONVERT(char(10), @d_PrevLottable04, 103) <> "01/01/1900" AND @d_PrevLottable04 IS NOT NULL  
            BEGIN
               --Get back the same lottable04
               SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = @d_PrevLottable04 "     --(Wan01)                   
            END
            ELSE
            BEGIN
                --find the lottable04 can fulfill the order line, the following uom preallocation of the order line will follow the same lottable04 
                SELECT @c_SQLDYN = " SELECT TOP 1 @d_PrevLottable04 = LOTATTRIBUTE.Lottable04 " +  
                                   " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (nolock), LOC (Nolock), ID (NOLOCK) " +  
                                   " WHERE LOT.STORERKEY = @c_storerkey " +                                    --(Wan01)
                                   " AND LOT.SKU = @c_SKU " +                                                  --(Wan01)
                                   " AND LOT.STATUS = 'OK' " +  
                                   " AND LOT.LOT = LOTATTRIBUTE.LOT " +  
                                   " AND LOT.LOT = LOTXLOCXID.Lot " +  
                                   " AND LOTXLOCXID.Loc = LOC.Loc " +  
                                   " AND LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +   
                                   " AND LOTXLOCXID.ID = ID.ID " +  
                                   " AND ID.STATUS <> 'HOLD' " +    
                                   " AND LOC.Status = 'OK' " +   
                                   " AND LOC.Facility = @c_facility " +                                        --(Wan01) 
                                   " AND LOC.LocationFlag <> 'HOLD' " +  
                                   " AND LOC.LocationFlag <> 'DAMAGE' " +  
                                   " AND LOC.Locationtype <> 'PICK' " +
                                   @c_Condition  + " " +
                                   " GROUP BY LOTATTRIBUTE.Lottable04 " +
                                   " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) >= @n_qtylefttofulfill " +  --(Wan01) 
                                   " ORDER BY LOTATTRIBUTE.Lottable04 "  
                   
               --(Wan01) - START
               SET @c_SQLParms =N'@c_Facility   NVARCHAR(5)'
                              + ',@c_Storerkey  NVARCHAR(15)'
                              + ',@c_SKU        NVARCHAR(20)'     
                              + ',@c_Lottable01 NVARCHAR(18)'
                              + ',@c_Lottable02 NVARCHAR(18)' 
                              + ',@d_Lottable04 DATETIME'
                              + ',@d_Lottable05 DATETIME'
                              + ',@c_Lottable10 NVARCHAR(30)' 
                              + ',@n_OrderMinShelfLife  INT'  
                              + ',@n_StorerMinShelfLife INT'
                              + ',@n_qtylefttofulfill   INT'  
                              + ',@d_PrevLottable04 DATETIME OUTPUT'
                                                              
               EXEC sp_ExecuteSQL @c_SQLDYN
                              , @c_SQLParms
                              , @c_Facility
                              , @c_storerkey
                              , @c_SKU
                              , @c_Lottable01
                              , @c_Lottable02
                              , @d_Lottable04
                              , @d_Lottable05
                              , @c_Lottable10
                              , @n_OrderMinShelfLife
                              , @n_StorerMinShelfLife
                              , @n_qtylefttofulfill  
                              , @d_PrevLottable04  OUTPUT
                               
               --(Wan01) - END                                                                                                                    
          
               IF CONVERT(char(10), @d_PrevLottable04, 103) <> "01/01/1900" AND @d_PrevLottable04 IS NOT NULL  
               BEGIN
                  --get the lottable04
                 SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = @d_PrevLottable04 "                                        
               END     
            END
              
            SELECT @c_SQL = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +  
             " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +  
             " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) " +   
             " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (nolock), LOC (Nolock), ID (NOLOCK) " +  
             " WHERE LOT.STORERKEY = @c_storerkey " +          --(Wan01)  
             " AND LOT.SKU = @c_SKU " +                        --(Wan01) 
             " AND LOT.STATUS = 'OK' " +  
             " AND LOT.LOT = LOTATTRIBUTE.LOT " +  
             " AND LOT.LOT = LOTXLOCXID.Lot " +  
             " AND LOTXLOCXID.Loc = LOC.Loc " +  
             " AND LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +   
             " AND LOTXLOCXID.ID = ID.ID " +  
             " AND ID.STATUS <> 'HOLD' " +    
             " AND LOC.Status = 'OK' " +   
             " AND LOC.Facility = @c_facility " +              --(Wan01)   
             " AND LOC.LocationFlag <> 'HOLD' " +  
             " AND LOC.LocationFlag <> 'DAMAGE' " +  
             " AND LOC.Locationtype <> 'PICK' " +             
             @c_Condition  + " " +
             " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04 " +
             " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0 "  +
             " ORDER BY LOTATTRIBUTE.Lottable04, 4 DESC, LOT.Lot "  
         END           
                                                   
         IF ISNULL(@c_SQL,'') <> ''
         BEGIN
            --(Wan01) - START
            SET @c_SQLParms =N' @c_Facility   NVARCHAR(5)'
                           + ',@c_Storerkey  NVARCHAR(15)'
                           + ',@c_SKU        NVARCHAR(20)'     
                           + ',@c_Lottable01 NVARCHAR(18)'
                           + ',@c_Lottable02 NVARCHAR(18)' 
                           + ',@d_Lottable04 DATETIME'
                           + ',@d_Lottable05 DATETIME'
                           + ',@c_Lottable10 NVARCHAR(30)' 
                           + ',@d_PrevLottable04 DATETIME'
                           + ',@n_OrderMinShelfLife  INT '  
                           + ',@n_StorerMinShelfLife INT '       
      
            EXEC sp_ExecuteSQL @c_SQL
                           , @c_SQLParms
                           , @c_Facility
                           , @c_storerkey
                           , @c_SKU
                           , @c_Lottable01
                           , @c_Lottable02
                           , @d_Lottable04
                           , @d_Lottable05
                           , @c_Lottable10
                           , @d_PrevLottable04
                           , @n_OrderMinShelfLife
                           , @n_StorerMinShelfLife

            --(Wan01) - END
         END
         ELSE
         BEGIN
            DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT TOP 0 NULL, NULL, NULL, 0     
         END            
   END  
END 

GO