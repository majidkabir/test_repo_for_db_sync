SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRLOGI1                                         */
/* Creation Date: 24-Mar-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: PreAllocateStrategy : WMS-1413 CN/SG Logitech prallocation  */
/*                                FIFO with conditional partial carton  */
/*                                restriction                           */
/*                                                                      */
/* Called By: nspOrderProcessing                                        */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Rev  Purposes                                   */      
/* 03-Jul-2017 NJOW01   1.0  if same lottable 05 & 08 allocate uom 2    */
/*                           from case location first                   */ 
/* 02-Jan-2020 Wan01    1.1  Dynamic SQL review, impact SQL cache log   */ 
/* 07-Apr-2021 NJOW02   1.2  WMS-16775 Cater for ecom allocation        */
/************************************************************************/

CREATE PROC [dbo].[nspPRLOGI1]
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

   DECLARE @c_Orderkey           NVARCHAR(10),
           @c_OrderLineNumber    NVARCHAR(5),
           @c_ID                 NVARCHAR(18),
           @c_Type               NVARCHAR(10),
           @n_QtyToTake          INT,
           @n_QtyAvailable       INT,
           @n_PLTDays            INT,
           @n_Days               INT,
           @dt_Lottable05        DATETIME,
           @dt_FirstLottable05   DATETIME,
           @c_SQLParms           NVARCHAR(4000) = '',     --(Wan01)   
           @c_ECOM_Mode         NCHAR(1)

   SET @c_ECOM_Mode = 'N'
                                                         
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4PreAllocation' is turned on
   BEGIN
      SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
      SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
      
      SELECT @c_ID = ORDERDETAIL.ID, @c_Type = ORDERS.Type
      FROM ORDERS (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
      WHERE ORDERS.Orderkey = @c_Orderkey
      AND ORDERDETAIL.OrderLineNumber = @c_OrderLineNumber        
      
      --NJOW02
      IF ISNULL(@c_Lottable08,'') = 'AP1BCH'       
      BEGIN                              
         IF EXISTS(SELECT 1
                   FROM ORDERS O (NOLOCK)
                   JOIN CODELKUP CL (NOLOCK) ON O.Consigneekey = CL.Code AND CL.Listname = 'LOGICCLG'
                   WHERE O.Orderkey = @c_Orderkey)          
         BEGIN
         	  SET @c_ECOM_Mode = 'Y'
         END    
         ELSE
         BEGIN                  
            DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
               SELECT TOP 0 NULL, NULL, NULL, NULL    
         
            RETURN      
         END      
      END          
                  
      IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) 
                WHERE Listname = 'LOGIORDTYP' 
                AND Storerkey = @c_Storerkey
                AND Short = 'CASE'
                AND Code = @c_Type) AND @c_UOM IN('3','6','7') 
         AND @c_ECOM_Mode = 'N' --NJOW01
      BEGIN
      	  --Not allow loose allocation
          DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
             SELECT TOP 0 NULL, NULL, NULL, NULL    
          
          RETURN 
      END                
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
         SELECT @c_Condition = " AND LOTTABLE01 = @c_Lottable01 "                               --(Wan01)
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = @c_Lottable02 " --(Wan01)
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = @c_Lottable03 " --(Wan01)
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = @d_Lottable04 " --(Wan01)
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = @d_Lottable05 " --(Wan01)
      END

      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable06 = @c_Lottable06'                    --(Wan01) 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable07 = @c_Lottable07'                    --(Wan01)
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable08 = @c_Lottable08'                    --(Wan01)
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable09 = @c_Lottable09'                    --(Wan01)
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable10 = @c_Lottable10'                    --(Wan01)
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable11 = @c_Lottable11'                    --(Wan01)
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable12 = @c_Lottable12'                    --(Wan01)
      END  

      IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable13 = @d_Lottable13'                    --(Wan01)
      END

      IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable14 = @d_Lottable14'                    --(Wan01)
      END

      IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable15 = @d_Lottable15'                    --(Wan01)
      END

      IF @n_StorerMinShelfLife > 0 
      BEGIN
         SET @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() "   --(Wan01) 
      END 
   
      IF ISNULL(@c_ID,'') <> ''
      BEGIN
          SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTxLOCxID.Id = @c_ID "  --(Wan01)
      END
      
      IF @c_ECOM_Mode = 'Y' --NJOW02
      BEGIN
   	     SELECT @c_Condition = " AND LOC.LocationType= 'PICK' "
      END
      ELSE IF @c_UOM IN ('1','2')
      BEGIN
          SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOC.LocationType NOT IN ('DYNPPICK','PICK') AND LOC.LocationCategory <> 'DYNPPICK' "
      END
      
      IF @c_UOM = '1'
      BEGIN
      	 SELECT @n_PLTDays = CASE WHEN ISNUMERIC(SUSR2) = 1
      	                          THEN CAST(SUSR2 AS INT) 
      	                     ELSE 0 END
      	 FROM SKU(NOLOCK)
      	 WHERE Storerkey = @c_Storerkey
      	 AND Sku = @c_Sku
      END
       
      --(Wan01) - START                  
      SELECT @c_SQLStatement =  " DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
            CASE WHEN @c_UOM IN ('6','7') THEN
               " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QTYREPLEN) - MAX(ISNULL(P.QTYPREALLOCATED,0)) + SUM(LOTxLOCxID.QTYEXPECTED)),  "  
            ELSE 
               " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QTYREPLEN) - MAX(ISNULL(P.QTYPREALLOCATED,0)) ),  " 
            END +
            " LOTATTRIBUTE.Lottable05 " +
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
            " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable05, Lotattribute.Lottable08 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QTYREPLEN) - MAX(ISNULL(P.QTYPREALLOCATED,0)) > 0 " +  --CAST(@n_UOMBase AS VARCHAR(10)) + 
            " ORDER BY Lotattribute.Lottable05, Lotattribute.Lottable08, " +
            CASE WHEN @c_UOM = '1' THEN " CASE WHEN MIN(LOC.LocationHandling) = '1' THEN 1 ELSE 2 END, LOT.Lot " 
                 WHEN @c_UOM = '2' THEN " CASE WHEN MAX(LOC.LocationHandling) = '2' THEN 1 ELSE 2 END, LOT.Lot " 
                 ELSE ' LOT.Lot ' END  --NJOW01

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
                     + ',@n_StorerMinShelfLife int'
                     + ',@c_ID NVARCHAR(18)'
      
      EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                        ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                        ,@n_StorerMinShelfLife, @c_ID 
                           
      --EXEC(@c_SQLStatement)
      --(Wan01) - END
      SET @c_SQLStatement = ''
      SET @n_QtyToTake = 0
      
      OPEN CURSOR_AVAILABLE                    
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @n_QtyAvailable, @dt_Lottable05
      
      SET @dt_FirstLottable05 = @dt_Lottable05 
      
      --To prevent full pallet allocate from next lot if first lot can fulfill the order with other uom  
      --Except flexi FIFO by sku.susr2 > 0
      WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
      BEGIN           	
      	 IF @c_UOM = '1' AND @n_PLTDays > 0 --allow allocate pallet by lottable05 within the day range set at susr5
      	 BEGIN
      	 	  SELECT @n_Days = DATEDIFF(day, @dt_FirstLottable05, @dt_Lottable05)
      	 	  IF @n_Days > @n_PLTDays
      	 	  	 BREAK
      	 	  ELSE
      	       SET @n_QtyToTake = FLOOR(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase      	           	  
      	 END
      	 ELSE
      	 BEGIN 
      	    IF @n_QtyAvailable > @n_QtyLeftToFulfill
      	       SET @n_QtyToTake = FLOOR(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
      	    ELSE
      	       SET @n_QtyToTake = FLOOR(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase      	           	  

        	  SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake 
      	 END      
      	        	        	  
         IF ISNULL(@c_SQLStatement,'') = ''
         BEGIN
            SET @c_SQLStatement = N'   
                  DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                  SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ' + CAST(@n_QtyToTake AS NVARCHAR(10))
         END
         ELSE
         BEGIN
            SET @c_SQLStatement = @c_SQLStatement + N'  
                  UNION ALL
                  SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ' + CAST(@n_QtyToTake AS NVARCHAR(10))
         END
                
         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @n_QtyAvailable, @dt_Lottable05 
      END -- END WHILE FOR CURSOR_AVAILABLE                
            
      IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
      BEGIN          
         CLOSE CURSOR_AVAILABLE          
         DEALLOCATE CURSOR_AVAILABLE          
      END    
      
      IF ISNULL(@c_SQLStatement,'') <> ''
      BEGIN
         EXEC sp_ExecuteSQL @c_SQLStatement
      END
      ELSE
      BEGIN
         DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT TOP 0 NULL, NULL, NULL, NULL    
      END            
   END
END

GO