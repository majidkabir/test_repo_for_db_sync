SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPRUKD06                                         */
/* Creation Date: 29-Sep-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 345748-UK JackW-prellocate piece from PPA without replen    */   
/*                 For Store Order Only. UOM 6(PPA)                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 25-Jul-2016  NJOW02   1.0  373644-Add lottable07 filtering           */
/* 25-Nov-2016  NJOW03   1.2  Performance tuning                        */
/************************************************************************/

CREATE PROC [dbo].[nspPRUKD06]
     @c_StorerKey        NVARCHAR(15)
   , @c_sku              NVARCHAR(20)
   , @c_lot              NVARCHAR(10)
   , @c_lottable01       NVARCHAR(18)
   , @c_lottable02       NVARCHAR(18)
   , @c_lottable03       NVARCHAR(18)
   , @d_lottable04       DATETIME
   , @d_lottable05       DATETIME
   , @c_lottable06 NVARCHAR(30)   
   , @c_lottable07 NVARCHAR(30)   
   , @c_lottable08 NVARCHAR(30)   
   , @c_lottable09 NVARCHAR(30)   
   , @c_lottable10 NVARCHAR(30)   
   , @c_lottable11 NVARCHAR(30)   
   , @c_lottable12 NVARCHAR(30)   
   , @d_lottable13 DATETIME      
   , @d_lottable14 DATETIME      
   , @d_lottable15 DATETIME      
   , @c_uom              NVARCHAR(10)
   , @c_facility         NVARCHAR(10) -- added By Ricky for IDSV5
   , @n_uombase          INT
   , @n_QtyLeftToFulfill INT
   , @c_OtherParms       NVARCHAR(200) = ''

AS
BEGIN
   DECLARE @n_ConsigneeMinShelfLife  INT
          ,@c_Condition              NVARCHAR(1500)

   DECLARE @c_OrderKey   NVARCHAR(10)
          ,@c_OrderType  NVARCHAR(10)
          ,@c_LoadConsoAllocationOParms NVARCHAR(1)--  tlitng01
          ,@b_Success    INT
          ,@n_err        INT
          ,@c_errmsg     NVARCHAR(250)
          ,@c_LoadKey    NVARCHAR(10)
          ,@c_SQL        NVARCHAR(4000)
          ,@c_SQL2       NVARCHAR(4000)  
          ,@n_QTYAVAILABLE INT
          ,@n_TotalQty   INT --NJOW03

   IF LEN(@c_OtherParms) > 0
   BEGIN
      SELECT @b_Success = 0
      EXECUTE nspGetRight NULL,  -- facility
               @c_StorerKey,     -- StorerKey
               NULL,             -- Sku
               'LoadConsoAllocationOParms',         -- Configkey
               @b_Success                    OUTPUT,
               @c_LoadConsoAllocationOParms  OUTPUT,
               @n_err                        OUTPUT,
               @c_errmsg                     OUTPUT

      SET @c_LoadKey = ''
      SET @c_OrderKey = ''
      SET @c_OrderType = ''

      IF @c_LoadConsoAllocationOParms = '1'
      BEGIN
         SET @c_LoadKey = LEFT(@c_OtherParms ,10)
         SELECT TOP 1 @c_OrderType = CASE WHEN (ISNULL(ORDERS.UserDefine01,'') <> '') THEN 'ECOM' ELSE 'STORE' END
         FROM   ORDERS WITH (NOLOCK)
         WHERE  LoadKey = @c_LoadKey
      END
      ELSE
      BEGIN
         SET @c_OrderKey = LEFT(@c_OtherParms ,10)
         SELECT @c_OrderType = CASE WHEN (ISNULL(ORDERS.UserDefine01,'') <> '') THEN 'ECOM' ELSE 'STORE' END,
                @c_Loadkey = ORDERS.Loadkey
         FROM   ORDERS WITH (NOLOCK)
         WHERE  OrderKey = @c_OrderKey
      END

      IF @c_OrderType<>'STORE'
      BEGIN
         DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT LOT.StorerKey
                  ,LOT.SKU
                  ,LOT.LOT
                  ,QTYAVAILABLE = 0
            FROM   LOT (NOLOCK)
            WHERE 1=2

         RETURN
      END            
   END

   SET @n_ConsigneeMinShelfLife = 0

   IF ISNULL(LTRIM(RTRIM(@c_LOT)), '') <> '' AND LEFT(@c_LOT, 1) <> '*'
   BEGIN
      /* Get Storer Minimum Shelf Life */
      DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOT.StorerKey
               ,LOT.SKU
               ,LOT.LOT
               ,QTYAVAILABLE= (LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED)
                FROM   LOT (NOLOCK)
               ,Lotattribute (NOLOCK)
               ,LOTxLOCxID (NOLOCK)
               ,LOC (NOLOCK)
         WHERE  LOT.LOT = @c_lot
                AND Lot.Lot = Lotattribute.Lot
                AND LOTxLOCxID.Lot = LOT.LOT
                AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                AND LOTxLOCxID.LOC = LOC.LOC
                AND LOC.Facility = @c_facility
                AND DATEADD(DAY ,@n_ConsigneeMinShelfLife ,Lotattribute.Lottable04) > GETDATE()
         ORDER BY Lotattribute.Lottable04, Lot.Lot
   END
   ELSE
   BEGIN
      SET @c_Condition = ''

      IF @c_Lottable01 <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = @c_Condition + ' AND LOTTABLE01 = "'+@c_Lottable01+'" '
      END

      IF @c_Lottable02 <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = @c_Condition + ' AND LOTTABLE02 = "'+@c_Lottable02+'" '
      END

      IF @c_Lottable03 <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = @c_Condition + ' AND LOTTABLE03 = "'+@c_Lottable03+'" '
      END

      IF CONVERT(VARCHAR(8) ,@d_Lottable04 ,112)<>'19000101'
      AND @d_Lottable04 IS NOT NULL
      BEGIN
         SELECT @c_Condition = @c_Condition + ' AND (Lotattribute.Lottable04 >= "'+CONVERT(VARCHAR(8) ,@d_Lottable04 ,112)+'") '
      END
      ELSE
      BEGIN
         SELECT @c_Condition = @c_Condition + ' AND (DateAdd(Day, '+CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10))
                                            + ', Lotattribute.Lottable04) > GetDate() '

         SELECT @c_Condition = @c_Condition + ' OR Lotattribute.Lottable04 IS NULL) '
      END

      IF @c_Lottable07 <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SELECT @c_Condition = @c_Condition + ' AND LOTTABLE07 = "'+@c_Lottable07+'" '
      END
      
      /*
      SELECT @c_SQL = ' SELECT @n_QTYAVAILABLE = SUM(CASE WHEN LOC.Locationflag="HOLD" AND LOC.LOC <> "WS01" THEN 0 ELSE LOTxLOCxID.QTY END) ' +                                      
                                       ' - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN ' +                                                                                    
                                           ' CASE WHEN LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY ' +                                                 
                                           '      THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) + LOTxLOCxID.QTYALLOCATED ' +                                                
                                           '      ELSE 0 ' +                                                                                                                
                                           ' END ' +                                                                                                                       
                                           ' ELSE LOTxLOCxID.QTYALLOCATED END) ' +                                                                                          
                                       '- SUM(CASE WHEN LOC.Locationflag="HOLD" THEN ' +                                                                                     
                                             ' CASE WHEN LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY ' +
                                             '     THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) ' +
                                             '      ELSE 0 ' +                                                                                                              
                                             ' END ' +                                                                                                                      
                                             ' ELSE LOTxLOCxID.QTYPICKED END) ' +  
                                       ' - MIN(ISNULL(P.QtyPreAllocated ,0)) '  +                                                                                       
                      ' FROM LOT (NOLOCK) ' +                                                                                                                           
                      ' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) ' +                                                                                  
                      ' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) ' +                                                
                      ' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) ' +                                                                                             
                      ' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' +                                                                                                 
                      ' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) ' +       
                      ' LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' +                                                                
                                       ' FROM  PreallocatePickdetail P (NOLOCK), ORDERS (NOLOCK) ' +                                                                   
                                       ' WHERE P.Orderkey = ORDERS.Orderkey ' +                                                                                        
                                       ' AND P.StorerKey = "' + @c_StorerKey + '" ' +                                                                                
                                       ' AND P.SKU = "' + @c_sku +  '" ' +                                                                                           
                                       ' AND ORDERS.FACILITY = "' + @c_facility + '" ' +                                                                                
                                       ' AND P.qty > 0 ' +                                                                                                           
                                       ' AND P.UOM IN("6") ' + 
                                       ' GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility ' +                                 
                      ' WHERE LOTxLOCxID.StorerKey = "' + @c_StorerKey + '" ' +                                                                                         
                      ' AND LOTxLOCxID.SKU = "' + @c_sku +  '" ' +                                                                                                      
                      ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" ' +                                                                            
                      ' AND LOC.Locationflag NOT IN ("DAMAGE") ' +                                                                                                      
                      ' AND LOC.FACILITY = "' + @c_facility + '" ' + @c_Condition + ' ' +                                                                               
                      ' AND EXISTS(SELECT 1 FROM LOT WITH (NOLOCK) WHERE LOT.LOT = LOTxLOCxID.Lot ' +                                                                   
                                 ' AND LOT.Qty - LOT.QtyPreAllocated - LOT.QtyAllocated - LOT.QtyPicked - ' +                                                           
                                 ' ISNULL((SELECT SUM(LLI.QTy) ' +                                                                                                      
                                 '         FROM LOTXLOCXID LLI with (NOLOCK) ' +                                                                                        
                                 '         WHERE ( EXISTS ( SELECT 1 from LOC L with (NOLOCK) WHERE L.LOC = LLI.LOC and  ' +                                            
                                 '                        ( L.STATUS <> "OK" OR L.Locationflag = "DAMAGE") ) ' +                                                        
                                 '                 OR EXISTS ( SELECT 1 from ID  I with (NOLOCK) WHERE I.ID  = LLI.ID and I.STATUS <> "OK" ) ) ' +                      
                                 '         AND LLI.LOT =  LOTxLOCxID.LOT ), 0) ' +                                                                                      
                                 ' > 0) ' +                                                                                                                             
                      ' AND LOC.LocationType IN ("PICK","CASE","DynPickP", "DYNPICKR") ' + 
                      ' HAVING (SUM(CASE WHEN LOC.Locationflag="HOLD" AND LOC.LOC <> "WS01" THEN 0 ELSE LOTxLOCxID.QTY END) ' +                                           
                           '  - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN ' +                                                                                              
                           '                CASE WHEN LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY ' +                                                   
                           '   THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) + LOTxLOCxID.QTYALLOCATED ' +                                                                   
                           '                     ELSE 0 ' +                                                                                                                 
                           '                END ' +                                                                                                                        
                           '      ELSE LOTxLOCxID.QTYALLOCATED END) ' +                                                                                                     
                           ' - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN ' +                                                                                               
                           '                CASE WHEN LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY ' +                                                                             
                           '                     THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) ' +                                                                            
                           '                     ELSE 0 ' +                                                                                                                 
                           '                END ' +                                                                                                                         
                           '            ELSE LOTxLOCxID.QTYPICKED END) ' +                                                                                               
                           ' - MIN(ISNULL(P.QtyPreAllocated ,0)) ) > 0 '
                           
      EXEC sp_executesql @c_SQL,
            N'@n_QTYAVAILABLE INT OUTPUT', 
            @n_QTYAVAILABLE OUTPUT                           

      IF @n_QTYAVAILABLE < @n_QtyLeftToFulfill
      BEGIN
         DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT LOT.StorerKey
                  ,LOT.SKU
                  ,LOT.LOT
                  ,QTYAVAILABLE = 0
            FROM   LOT (NOLOCK)
            WHERE 1=2

         RETURN
      END     
      */       
      
      SELECT @c_SQL2 = ' DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR  FOR ' +                                                                                    
                      ' SELECT MIN(LOTxLOCxID.StorerKey) , MIN(LOTxLOCxID.SKU), LOT.LOT, ' +                                                                            
                      ' QTYAVAILABLE = SUM(CASE WHEN LOC.Locationflag="HOLD" AND LOC.LOC <> "WS01" THEN 0 ELSE LOTxLOCxID.QTY END) ' +                                     
                                      ' - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN ' +                                                                                     
                                             ' CASE WHEN LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY ' +                                                 
                                             '      THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) + LOTxLOCxID.QTYALLOCATED ' +                                                
                                             '      ELSE 0 ' +                                                                                                               
                                             ' END ' +                                                                                                                       
                                             ' ELSE LOTxLOCxID.QTYALLOCATED END) ' +                                                                                         
                                      ' - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN ' +                                                                                    
                                             ' CASE WHEN LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY ' +                                                                          
                                             '      THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) ' +                                                                       
                                             '      ELSE 0 ' +                                                                                                             
                                             ' END ' +                                                                                                                       
                                             ' ELSE LOTxLOCxID.QTYPICKED END) ' +                                                                                        
                                      -- - CASE WHEN SUM(ISNULL(LOTxLOCxID.QtyReplen,0)) < 0 THEN 0 ELSE SUM(ISNULL(LOTxLOCxID.QtyReplen,0)) END                        
                                      ' - MIN(ISNULL(P.QtyPreAllocated ,0)) ' +                                                                                         
                      ' FROM LOT (NOLOCK) ' +                                                                                                                           
                      ' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) ' +                                                                                  
                      ' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) ' +                                                
                      ' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) ' +                                                                                             
                      ' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' +                                                                                                 
                      ' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) ' +       
                      ' LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' +                                                                
                                       ' FROM PreallocatePickdetail P (NOLOCK), ORDERS (NOLOCK) ' +                                                                   
                                       ' WHERE P.Orderkey = ORDERS.Orderkey ' +                                                                                        
                                       ' AND P.StorerKey = "' + @c_StorerKey + '" ' +                                                                                
                                       ' AND P.SKU = "' + @c_sku +  '" ' +                                                                                           
                                       ' AND ORDERS.FACILITY = "' + @c_facility + '" ' +                                                                                
                                       ' AND P.qty > 0 ' +                                                                                                           
                                       ' GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility ' +                                 
                      ' WHERE LOTxLOCxID.StorerKey = "' + @c_StorerKey + '" ' +                                                                                         
                      ' AND LOTxLOCxID.SKU = "' + @c_sku +  '" ' +                                                                                                      
                      ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" ' +                                                                            
                      ' AND LOC.Locationflag NOT IN ("DAMAGE") ' +                                                                                                      
                      ' AND LOC.FACILITY = "' + @c_facility + '" ' + @c_Condition + ' ' +                                                                               
                      ' AND EXISTS(SELECT 1 FROM LOT WITH (NOLOCK) WHERE LOT.LOT = LOTxLOCxID.Lot ' +                                                                   
                                 ' AND LOT.Qty - LOT.QtyPreAllocated - LOT.QtyAllocated - LOT.QtyPicked - ' +                                                           
                                 ' ISNULL((SELECT SUM(LLI.QTy) ' +                                                                                                      
                                 '         FROM LOTXLOCXID LLI with (NOLOCK) ' +                                                                                        
                                 '         WHERE ( EXISTS ( SELECT 1 from LOC L with (NOLOCK) WHERE L.LOC = LLI.LOC and  ' +                                            
                                 '                        ( L.STATUS <> "OK" OR L.Locationflag = "DAMAGE") ) ' +                                                        
                                 '                 OR EXISTS ( SELECT 1 from ID  I with (NOLOCK) WHERE I.ID  = LLI.ID and I.STATUS <> "OK" ) ) ' +                      
                                 '         AND LLI.LOT =  LOTxLOCxID.LOT ), 0) ' +                                                                                      
                                 ' > 0) ' +                                                                                                                             
                      -- LOT.QtyOnHold > 0) ' +                    -- Recalculate ON HOLD QTY                                                                           
                      ' AND LOC.LocationType IN ("PICK","CASE","DynPickP", "DYNPICKR") ' + 
                      ' GROUP BY LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ' +                                                 
                      ' HAVING (SUM(CASE WHEN LOC.Locationflag="HOLD" AND LOC.LOC <> "WS01" THEN 0 ELSE LOTxLOCxID.QTY END) ' +                                             
                           '  - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN ' +                                                                                              
                           '                CASE WHEN LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY ' +                                                   
                           '   THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) + LOTxLOCxID.QTYALLOCATED ' +                                                                   
                           '                     ELSE 0 ' +                                                                                                                 
                           '                END ' +                                                                                                                          
                           '      ELSE LOTxLOCxID.QTYALLOCATED END) ' +                                                                                                      
                           ' - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN ' +                                                                                               
                           '                CASE WHEN LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY ' +                                                                              
                           '                     THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) ' +                                                                            
                           '                     ELSE 0 ' +                                                                                                                  
                           '                END ' +                                                                                                                          
                           '            ELSE LOTxLOCxID.QTYPICKED END) ' +                                                                                               
                            -- - CASE WHEN SUM(ISNULL(LOTxLOCxID.QtyReplen,0)) < 0 THEN 0 ELSE SUM(ISNULL(LOTxLOCxID.QtyReplen,0)) END                                  
                           ' - MIN(ISNULL(P.QtyPreAllocated ,0)) ) > 0 ' +                                                                                              
                      ' ORDER BY ' +                                                                                                                                    
                      ' MIN(CASE WHEN LOC.LocationType IN ("DYNPICKP", "DYNPICKR") ' +                                                                                  
                      '     OR SKUxLOC.LocationType IN ("CASE" ,"PICK") ' +                                                                                             
                      '     OR LOC.LocationType = "PICK" THEN 2 ' +                                                                                                     
                      '     WHEN  LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked-LOTxLOCxID.QtyAllocated <= 0 THEN 1 ' +                                                           
                      '     ELSE 0 END), ' +                                                                                                                            
                      ' LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 '                                                                  

      EXEC (@c_SQL2)
      
      --NJOW03
      OPEN PREALLOCATE_CURSOR_CANDIDATES
      FETCH NEXT FROM PREALLOCATE_CURSOR_CANDIDATES INTO @c_Storerkey, @c_Sku, @c_Lot, @n_QTYAVAILABLE
      SET @n_totalqty = 0      
      WHILE @@FETCH_STATUS = 0  
      BEGIN       
      	 SET @n_totalqty = @n_totalqty + @n_QTYAVAILABLE
      	       	 
         FETCH NEXT FROM PREALLOCATE_CURSOR_CANDIDATES INTO @c_Storerkey, @c_Sku, @c_Lot, @n_QTYAVAILABLE
      END
      CLOSE PREALLOCATE_CURSOR_CANDIDATES              
      
      IF @n_totalqty < @n_QtyLeftToFulfill
      BEGIN
         DEALLOCATE PREALLOCATE_CURSOR_CANDIDATES
         DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT LOT.StorerKey
                  ,LOT.SKU
                  ,LOT.LOT
                  ,QTYAVAILABLE = 0
            FROM   LOT (NOLOCK)
            WHERE 1=2         
         RETURN
      END      	 
   END
END

GO