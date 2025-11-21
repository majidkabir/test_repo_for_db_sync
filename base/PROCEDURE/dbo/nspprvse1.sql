SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRVSE1                                          */
/* Creation Date: 07-Apr-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: PreAllocateStrategy : WMS-1577 CN Victoria Secret Ecom      */
/*                                UOM 6 - locationcategory MEZZANINE    */
/*                                UOM 7 - locationcategory VNA          */
/*                                Locationtype - Other                  */
/*                                                                      */
/* Called By: nspOrderProcessing                                        */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Rev   Purposes                                  */      
/* 28-Jun-2017 NJOW01   1.0   WMS-1577 UCC allocation                   */
/* 02-Oct-2017 NJOW02   1.1   WMS-3101 remove lot from sorting          */
/* 06-Mar-2018 NJOW03   1.2   WMS-4004 Remove allocate UCC              */
/* 02-Jan-2020 Wan01    1.3   Dynamic SQL review, impact SQL cache log  */ 
/************************************************************************/

CREATE PROC [dbo].[nspPRVSE1]
            @c_storerkey  NVARCHAR(15) ,
            @c_sku        NVARCHAR(20) ,
            @c_lot        NVARCHAR(10) ,
            @c_lottable01 NVARCHAR(18) ,
            @c_lottable02 NVARCHAR(18) ,
            @c_lottable03 NVARCHAR(18) ,
            @d_lottable04 datetime ,
            @d_lottable05 datetime ,
            @c_lottable06 NVARCHAR(30) ,
            @c_lottable07 NVARCHAR(30) ,
            @c_lottable08 NVARCHAR(30) ,
            @c_lottable09 NVARCHAR(30) ,
            @c_lottable10 NVARCHAR(30) ,
            @c_lottable11 NVARCHAR(30) ,
            @c_lottable12 NVARCHAR(30) ,
            @d_lottable13 DATETIME ,    
            @d_lottable14 DATETIME ,    
            @d_lottable15 DATETIME ,    
            @c_uom        NVARCHAR(10) ,
            @c_facility   NVARCHAR(5),     
            @n_uombase    INT ,
            @n_qtylefttofulfill INT,
            @c_OtherParms NVARCHAR(200)=''
AS
BEGIN   
   DECLARE @n_StorerMinShelfLife INT,
           @c_Condition          NVARCHAR(4000),      
           @c_SQLStatement       NVARCHAR(3999) 

   DECLARE @c_SQLParms        NVARCHAR(4000) = ''  --(Wan01) 

   DECLARE @c_Orderkey           NVARCHAR(10),
           @c_OrderLineNumber    NVARCHAR(5),
           @c_ID                 NVARCHAR(18),
           @c_Key1               NVARCHAR(10),
           @c_Key2               NVARCHAR(5),
           @c_key3               NCHAR(1)
                                                        
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4PreAllocation' and 'WaveConsoAllocationOParms'  is turned on
   BEGIN
      SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
      SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)

      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber             
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave          
      
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='' 
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE O.Loadkey = @c_key1
         AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END                       
      ELSE IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' 
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey  --(Wan01) Fixed to Retrieve By Index instead on O.Userdefine09  
         WHERE WD.WaveKey = @c_key1                               --(Wan01) Fixed to Retrieve By Index instead on O.Userdefine09
         AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END              
      ELSE
      BEGIN
         SELECT @c_ID = ORDERDETAIL.ID
         FROM ORDERS (NOLOCK)
         JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
         WHERE ORDERS.Orderkey = @c_Orderkey
         AND ORDERDETAIL.OrderLineNumber = @c_OrderLineNumber                                      
      END                                                            
      
      --NJOW03      
      /*
      IF EXISTS(SELECT 1
                FROM ORDERS O (NOLOCK)
                JOIN WAVE W (NOLOCK) ON O.Userdefine09 = W.Wavekey
                WHERE O.Orderkey = @c_Orderkey
                AND W.Wavetype = 'B2B')
      BEGIN
         DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT TOP 0 NULL, NULL, NULL, NULL          
         RETURN
      END
      */                
   END
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      /* Get Storer Minimum Shelf Life */
      
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey
      
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (Nolock), Lotattribute (Nolock)
      WHERE LOT.LOT = @c_lot 
      AND Lot.Lot = Lotattribute.Lot 
      AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
      ORDER BY Lotattribute.Lottable05, Lot.Lot
   END
   ELSE
   BEGIN
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey
   
      IF @n_StorerMinShelfLife IS NULL
         SELECT @n_StorerMinShelfLife = 0
   
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = @c_Lottable01 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = @c_Lottable02 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = @c_Lottable03 "
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = @d_Lottable04 "
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = @d_Lottable05 "
      END

      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable06 = @c_Lottable06' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable07 = @c_Lottable07' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable08 = @c_Lottable08' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable09 = @c_Lottable09' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable10 = @c_Lottable10' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable11 = @c_Lottable11' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable12 = @c_Lottable12' 
      END  

      IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable13 = @d_Lottable13'
      END

      IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable14 = @d_Lottable14'
      END

      IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable15 = @d_Lottable15'
      END

      IF @n_StorerMinShelfLife <> 0 
      BEGIN
         SET @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() " 
      END 
   
      IF ISNULL(@c_ID,'') <> ''
      BEGIN
          SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTxLOCxID.Id = @c_ID "
      END
      
      IF @c_UOM = '6'
      BEGIN
          SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOC.LocationType = 'OTHER' AND LOC.LocationCategory = 'MEZZANINE' "

          SELECT @c_SQLStatement =  " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
                " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
                " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QTYREPLEN) - MAX(ISNULL(P.QTYPREALLOCATED,0)) )  " +
                " FROM LOT WITH (NOLOCK) " +
                " JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.lot = LOTATTRIBUTE.lot) " +   
                " JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) " +    
                " JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) " +    
                " JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) " +        
                " LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +    
                "                FROM   PreallocatePickdetail P (NOLOCK) " +
                "                JOIN   ORDERS (NOLOCK) ON P.Orderkey = ORDERS.Orderkey " +  
                "                JOIN   ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey AND P.OrderLineNumber = ORDERDETAIL.OrderLineNumber " +  
                "                WHERE  P.Storerkey = @c_storerkey " +     
                "                AND    P.SKU = @c_SKU " +
                "                AND    ORDERS.FACILITY = @c_facility " +   
                "                AND    P.qty > 0 " +    
                CASE WHEN ISNULL(@c_ID,'') <> '' THEN " AND ORDERDETAIL.ID = @c_ID " ELSE " " END + 
                "                GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility " +
                " WHERE LOT.STORERKEY = @c_storerkey " +   
                " AND LOT.SKU = @c_SKU " +
                " AND LOT.STATUS = 'OK'  " +   
                " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' " +     
                " AND LOC.LocationFlag = 'NONE' " +  
                " AND LOC.Facility = @c_facility "  +
                ISNULL(RTRIM(@c_Condition),'')  + 
                " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable04, LOC.LogicalLocation, LOC.Loc " +
                " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QTYREPLEN) - MAX(ISNULL(P.QTYPREALLOCATED,0)) >= @n_UOMBase " + 
                " ORDER BY Lotattribute.Lottable04, LOC.LogicalLocation, LOC.Loc "           
      END
      
      IF @c_UOM = '7'
      BEGIN
          SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOC.LocationType = 'OTHER' AND LOC.LocationCategory = 'VNA' "

          SELECT @c_SQLStatement =  " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
                " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
                " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QTYREPLEN) - MAX(ISNULL(P.QTYPREALLOCATED,0)) )  " +
                --" QTYAVAILABLE = SUM(ISNULL(UCC.QTY,0)) - MAX(ISNULL(P.QTYPREALLOCATED,0)) " +
                " FROM LOT WITH (NOLOCK) " +
                " JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.lot = LOTATTRIBUTE.lot) " +   
                " JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) " +    
                " JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) " +    
                " JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) " +        
                " LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +    
                "                FROM   PreallocatePickdetail P (NOLOCK) " +
                "                JOIN   ORDERS (NOLOCK) ON P.Orderkey = ORDERS.Orderkey " +  
                "                JOIN   ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey AND P.OrderLineNumber = ORDERDETAIL.OrderLineNumber " +  
                "                WHERE  P.Storerkey = @c_storerkey " +     
                "                AND    P.SKU = @c_SKU " +
                "                AND    ORDERS.FACILITY = @c_facility " +   
                "                AND    P.qty > 0 " +    
                CASE WHEN ISNULL(@c_ID,'') <> '' THEN " AND ORDERDETAIL.ID = @c_ID " ELSE " " END + 
                "                GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility " +
                --" JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND " + 
                --"                            UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < '3') " +    
                " WHERE LOT.STORERKEY = @c_storerkey " +   
                " AND LOT.SKU = @c_SKU " +
                " AND LOT.STATUS = 'OK'  " +   
                " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' " +     
                " AND LOC.LocationFlag = 'NONE' " +  
                " AND LOC.Facility = @c_facility "  +
                ISNULL(RTRIM(@c_Condition),'')  + 
                " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable04, Lotattribute.Lottable05 " +
                " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QTYREPLEN) - MAX(ISNULL(P.QTYPREALLOCATED,0)) >= @n_UOMBase" +
                --" HAVING SUM(ISNULL(UCC.QTY,0)) - MAX(ISNULL(P.QTYPREALLOCATED,0)) >= " + CAST(@n_UOMBase AS VARCHAR(10)) + 
                " ORDER BY Lotattribute.Lottable04, 4, MIN(LOC.LogicalLocation), MIN(LOC.Loc) "           

          /*
          SELECT @c_SQLStatement =  " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
                " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
                --" QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QTYREPLEN) - MAX(ISNULL(P.QTYPREALLOCATED,0)) )  " +
                " QTYAVAILABLE = SUM(ISNULL(UCC.QTY,0)) - MAX(ISNULL(P.QTYPREALLOCATED,0)) " +
                " FROM LOT WITH (NOLOCK) " +
                " JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.lot = LOTATTRIBUTE.lot) " +   
                " JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) " +    
                " JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) " +    
                " JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) " +        
                " LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +    
                "                FROM   PreallocatePickdetail P (NOLOCK) " +
                "                JOIN   ORDERS (NOLOCK) ON P.Orderkey = ORDERS.Orderkey " +  
                "                JOIN   ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey AND P.OrderLineNumber = ORDERDETAIL.OrderLineNumber " +  
                "                WHERE  P.Storerkey = N'" + RTRIM(@c_storerkey) + "' " +     
                "                AND    P.SKU = N'" + RTRIM(@c_SKU) + "' " +
                "                AND    ORDERS.FACILITY = N'" + RTRIM(@c_facility) + "' " +   
                "                AND    P.qty > 0 " +    
                CASE WHEN ISNULL(@c_ID,'') <> '' THEN " AND ORDERDETAIL.ID = N'" + RTRIM(@c_ID) + "' " ELSE " " END + 
                "                GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility " +
                " JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND " + 
                "                            UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < '3') " +    
                " WHERE LOT.STORERKEY = N'" + RTRIM(@c_storerkey) + "' " +   
                " AND LOT.SKU = N'" + RTRIM(@c_SKU) + "' " +
                " AND LOT.STATUS = 'OK'  " +   
                " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' " +     
                " AND LOC.LocationFlag = 'NONE' " +  
                " AND LOC.Facility = N'" + RTRIM(@c_facility) + "' "  +
                ISNULL(RTRIM(@c_Condition),'')  + 
                " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable04, Lotattribute.Lottable05 " +
                " HAVING SUM(ISNULL(UCC.QTY,0)) - MAX(ISNULL(P.QTYPREALLOCATED,0)) >= " + CAST(@n_UOMBase AS VARCHAR(10)) + 
                " ORDER BY Lotattribute.Lottable04, 4, MIN(LOC.LogicalLocation), MIN(LOC.Loc) "           
           */
      END
                        
      --Wan01 - START
      --EXEC(@c_SQLStatement)
      SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                     + ',@c_storerkey  NVARCHAR(15)'
                     + ',@c_SKU        NVARCHAR(20)'
                     + ',@c_Lottable01 NVARCHAR(18)'
                     + ',@c_Lottable02 NVARCHAR(18)'
                     + ',@c_Lottable03 NVARCHAR(18)'
                     + ',@d_lottable04 datetime'
                     + ',@d_lottable05 datetime'
                     + ',@c_Lottable06 NVARCHAR(30)'
                     + ',@c_Lottable07 NVARCHAR(30)'
                     + ',@c_Lottable08 NVARCHAR(30)'
                     + ',@c_Lottable09 NVARCHAR(30)'
                     + ',@c_Lottable10 NVARCHAR(30)'
                     + ',@c_Lottable11 NVARCHAR(30)'
                     + ',@c_Lottable12 NVARCHAR(30)'
                     + ',@d_lottable13 datetime'
                     + ',@d_lottable14 datetime'
                     + ',@d_lottable15 datetime'
                     + ',@n_StorerMinShelfLife  int'
                     + ',@n_UOMBase    int'
                     + ',@c_ID         NVARCHAR(18)'
      
      EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                        ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                        ,@n_StorerMinShelfLife, @n_UOMBase, @c_ID 
      --Wan01 - END  
                  
   END
END

GO