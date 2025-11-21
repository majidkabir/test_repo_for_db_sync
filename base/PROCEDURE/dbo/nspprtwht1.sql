SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: nspPRTWHT1                                          */  
/* Creation Date:                                                        */  
/* Copyright: LF                                                         */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:  346270-TW HHT-Preallocation from bulk                       */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 10-Sep-2015  NJOW01   1.0  Fix not to return extra available qty      */
/*************************************************************************/   

CREATE PROC [dbo].[nspPRTWHT1]
   @c_storerkey NVARCHAR(15) ,
   @c_sku NVARCHAR(20) ,
   @c_lot NVARCHAR(10) ,
   @c_lottable01 NVARCHAR(18) ,
   @c_lottable02 NVARCHAR(18) ,
   @c_lottable03 NVARCHAR(18) ,
   @d_lottable04 datetime ,
   @d_lottable05 datetime ,
   @c_uom NVARCHAR(10) ,
   @c_facility NVARCHAR(10), 
   @n_uombase int ,
   @n_qtylefttofulfill int,
   @c_OtherParms NVARCHAR(20) = '' 
AS
BEGIN   
   DECLARE @n_ConsigneeMinShelfLife INT,
           @n_QtyAvailable INT,
           @c_Condition NVARCHAR(1500),
           @c_OrderKey  NVARCHAR(10), 
   				 @c_OrderType NVARCHAR(10),
           @c_key1      NVARCHAR(10),    
           @c_key2      NVARCHAR(5),    
           @c_key3      NCHAR(1),
           @c_SQL       NVARCHAR(MAX),
           @n_QtyToTake INT --NJOW01

	 IF ISNULL(LTRIM(RTRIM(@c_lot)) ,'') <> '' AND LEFT(@c_LOT ,1) <> '*'
	 BEGIN   
       /* Get Storer Minimum Shelf Life */
       SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife, 0)
       FROM   STORER (NOLOCK)
       WHERE  STORERKEY = @c_lottable03
   
       SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_ConsigneeMinShelfLife /100) * -1)
       FROM  Sku (nolock)
       WHERE Sku.Sku = @c_SKU
       AND   Sku.Storerkey = @c_Storerkey
   
       DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
       FOR 
          SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
                 QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
          FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
          WHERE LOT.LOT = @c_lot 
          AND Lot.Lot = Lotattribute.Lot 
	        AND LOTXLOCXID.Lot = LOT.LOT
 	        AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
   	      AND LOTXLOCXID.LOC = LOC.LOC
    	    AND LOC.Facility = @c_facility
          AND DateAdd(Day, @n_ConsigneeMinShelfLife, Lotattribute.Lottable04) > GetDate() 
          ORDER BY Lotattribute.Lottable04, Lot.Lot   
    END
    ELSE
    BEGIN
  	   IF LEFT(@c_LOT,1) = '*'
   	   BEGIN
		   	  IF LEN(@c_OtherParms) > 0 
   	   	  BEGIN
             SET @c_OrderKey = LEFT(@c_OtherParms,10) 
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
                
           	 IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' 
           	 BEGIN
           	 	 SET @c_Orderkey = ''
                SELECT TOP 1 @c_Orderkey = O.Orderkey
                FROM ORDERS O (NOLOCK) 
                JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                WHERE O.Userdefine09 = @c_key1
                AND OD.Sku = @c_SKU
                ORDER BY O.Orderkey, OD.OrderLineNumber
             END        	     
	        	 	
   	   	  	 SET @c_OrderType = ''
   	   	  	 SELECT @c_OrderType = TYPE 
   	   	  	 FROM   ORDERS WITH (NOLOCK)
   	   	  	 WHERE  OrderKey = @c_OrderKey
	        	 
		   	  	 IF RTRIM(ISNULL(@c_OrderType,'')) = 'VAS'
   	   	  	 BEGIN
   	   	  	 	  SELECT @c_Condition = RTRIM(@c_Condition) + " AND RIGHT(RTRIM(Lotattribute.Lottable02),1) <> 'Z' " 
   	   	  	 END
   	   	  END
          
		   	  IF LEN(ISNULL(@c_LOT,'')) > 1
		   	  BEGIN   			
	        		SELECT @n_ConsigneeMinShelfLife = CASE WHEN ISNUMERIC(RIGHT(@c_LOT, LEN(@c_LOT) - 1)) = 1 
                                                           THEN CAST(RIGHT(@c_LOT, LEN(@c_LOT) - 1) AS INT) * -1
                                                        ELSE 0
                                                   END
		   	  END       
		   END

       /* Get Storer Minimum Shelf Life */
       /* Lottable03 = Consignee Key */
		   IF ISNULL(@n_ConsigneeMinShelfLife,0) = 0
		   BEGIN 			
		   	  SELECT @n_ConsigneeMinShelfLife = ISNULL(STORER.MinShelflife, 0)
		   	  FROM   STORER (NOLOCK) 
		   	  WHERE  Storerkey = ISNULL(@c_lottable03,'')
          
		   	  SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_ConsigneeMinShelfLife /100) * -1)
		   	  FROM  Sku (nolock)
		   	  WHERE Sku.Sku = @c_SKU
		   	  AND   Sku.Storerkey = @c_Storerkey 
          
		   	  IF @n_ConsigneeMinShelfLife IS NULL
		   	  	 SELECT @n_ConsigneeMinShelfLife = 0 
		   END
       
       -- lottable01 is used for loc.HostWhCode -- modified by Jeff
       IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
       BEGIN
          SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOC.HostWhCode = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + "' "
       END
       
       IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
       BEGIN
          SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "' "
       END
       
       IF CONVERT(char(8), @d_Lottable04, 112) <> '19000101' AND @d_Lottable04 IS NOT NULL
       BEGIN
          SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND ( Lotattribute.Lottable04 >= N'" + dbo.fnc_RTrim(CONVERT(char(8), @d_Lottable04, 112)) + "' ) " 
       END
       ELSE
       BEGIN
          SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND ( DateAdd(Day, " + CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() " 
          SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " OR Lotattribute.Lottable04 IS NULL ) "
       END
                        
       SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05 "
       --SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) >= "  + CAST(@n_uombase AS NVARCHAR) + " "
       SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0 "  
       SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " ORDER BY Lotattribute.Lottable04,LOTATTRIBUTE.Lottable05, Lot.Lot "
       
       SELECT @c_SQL = " DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR " +                                              
                       " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +                                                                               
                       " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) " +        
                       " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (nolock), LOC (Nolock), ID (NOLOCK), SKUxLOC (NOLOCK) " +            
                       " WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " +                                                                         
                       " AND LOT.SKU = N'" + @c_SKU + "' " +                                                                                       
                       " AND LOT.STATUS = 'OK' " +                                                                                                 
                       " AND LOT.LOT = LOTATTRIBUTE.LOT " +                                                                                        
                       " AND LOT.LOT = LOTXLOCXID.Lot " +                                                                                          
                       " AND LOTXLOCXID.Loc = LOC.Loc " +                                                                                          
                       " AND LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +                                                                                 
                       " AND LOTXLOCXID.ID = ID.ID " +                                                                                             
                       " AND ID.STATUS <> 'HOLD' " +                                                                                               
                       " AND LOC.Status = 'OK' " +                                                                                                 
                       " AND LOC.Facility = N'" + @c_facility + "' " +                                                                             
                       " AND LOC.LocationFlag <> 'HOLD' " +                                                                                        
                       " AND LOC.LocationFlag <> 'DAMAGE' " +                                                                                      
                       " AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " +                                       
                       --" AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE') " +                                             
                       " AND SKUxLOC.SKU = LOTxLOCxID.SKU " +                                                                                      
                       " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +                                                                                      
                       " AND LOTxLOCxID.STORERKEY = N'" + @c_storerkey + "' " +                                                                    
                       " AND LOTxLOCxID.SKU = N'" + @c_SKU + "' " +                                                                                
                       " AND LOTATTRIBUTE.STORERKEY = N'" + @c_storerkey + "' " +                                                                  
                       " AND LOTATTRIBUTE.SKU = N'" + @c_SKU + "' " +                                                                              
                       @c_Condition                                                                                                             

       EXEC(@c_SQL)
              
       SET @c_SQL = ''
       SET @n_QtyToTake = 0
       
       OPEN CURSOR_AVAILABLE                    
       FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @n_QtyAvailable   
              
       WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
       BEGIN    
       	
       	  --NJOW01
       	  IF @n_QtyAvailable > @n_QtyLeftToFulfill
       	     SET @n_QtyToTake = @n_QtyLeftToFulfill
       	  ELSE
       	     SET @n_QtyToTake = @n_QtyAvailable       	           	  
       	        	  
          IF ISNULL(@c_SQL,'') = ''
          BEGIN
             SET @c_SQL = N'   
                   DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                   SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ' + CAST(@n_QtyToTake AS NVARCHAR(10))
          END
          ELSE
          BEGIN
             SET @c_SQL = @c_SQL + N'  
                   UNION ALL
                   SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ' + CAST(@n_QtyToTake AS NVARCHAR(10))
          END

       	  SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake 
                 
          FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @n_QtyAvailable 
       END -- END WHILE FOR CURSOR_AVAILABLE     
       
       EXIT_SP:
       
       IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
       BEGIN          
          CLOSE CURSOR_AVAILABLE          
          DEALLOCATE CURSOR_AVAILABLE          
       END    
       
       IF ISNULL(@c_SQL,'') <> ''
       BEGIN
          EXEC sp_ExecuteSQL @c_SQL
       END
       ELSE
       BEGIN
          DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
          SELECT TOP 0 NULL, NULL, NULL, NULL    
       END   
      
       /*
       EXEC (" DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
             " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
             " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) " + 
             " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (nolock), LOC (Nolock), ID (NOLOCK), SKUxLOC (NOLOCK) " + 
             " WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " +
             " AND LOT.SKU = N'" + @c_SKU + "' " +
             " AND LOT.STATUS = 'OK' " +
             " AND LOT.LOT = LOTATTRIBUTE.LOT " +
             " AND LOT.LOT = LOTXLOCXID.Lot " +
             " AND LOTXLOCXID.Loc = LOC.Loc " +
             " AND LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " + 
             " AND LOTXLOCXID.ID = ID.ID " +
             " AND ID.STATUS <> 'HOLD' " +  
             " AND LOC.Status = 'OK' " + 
             " AND LOC.Facility = N'" + @c_facility + "' " +
             " AND LOC.LocationFlag <> 'HOLD' " +
             " AND LOC.LocationFlag <> 'DAMAGE' " +
             " AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE') " + 
             " AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " +
             " AND SKUxLOC.SKU = LOTxLOCxID.SKU " + 
             " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +
             " AND LOTxLOCxID.STORERKEY = N'" + @c_storerkey + "' " +
             " AND LOTxLOCxID.SKU = N'" + @c_SKU + "' " + 
             " AND LOTATTRIBUTE.STORERKEY = N'" + @c_storerkey + "' " +
             " AND LOTATTRIBUTE.SKU = N'" + @c_SKU + "' " + 
             @c_Condition  ) 
         */
   END
END


GO