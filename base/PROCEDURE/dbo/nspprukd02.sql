SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/          
/* Store procedure: nspPRUKD02                                               */          
/* Copyright      : IDS                                                      */          
/*                                                                           */          
/* Purpose: Pre-Allocation Strategy for UK Diana                             */          
/*          Only works for Store Order (UserDefine01 = BLANK)                */          
/*          Only take from Bulk                                              */          
/*                                                                           */          
/* Modifications log:                                                        */          
/*                                                                           */          
/* Date        Author  Rev   Purposes                                        */          
/* 2010-06-28  Shong   1.0   Created                                         */          
/* 2010-09-02  James   1.1   If qtyreplen < 0 then treat as 0 (james01)      */        
/* 2010-09-15  Shong   1.2   Cannot filter by LocationType, can only use the */        
/*                           Sort Order to control                           */   
/* 21-Nov-2010 TLTING  1.3   Load Allocation - pass LoadKey in(TLTING01)     */
/*                           StorerConfig - LoadConsoAllocationOParms        */    
/* 02-Aug-2011 SPChin  1.4   SOS# 222540 - Include LocationFlag <> 'HOLD'    */    
/* 2014-11-20  Shong   1.5   Make WS01 Qty as Qty Available                  */
/* 2015-01-21  Shong   1.6   Comment the QtyReplen. System alraedy included  */
/*                           Over Allocation                                 */
/*****************************************************************************/          
CREATE  PROC [dbo].[nspPRUKD02]            
@c_StorerKey NVARCHAR(15) ,            
@c_sku NVARCHAR(20) ,            
@c_lot NVARCHAR(10) ,            
@c_lottable01 NVARCHAR(18) ,            
@c_lottable02 NVARCHAR(18) ,            
@c_lottable03 NVARCHAR(18) ,            
@d_lottable04 DATETIME ,            
@d_lottable05 DATETIME ,            
@c_uom NVARCHAR(10) ,            
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5            
@n_uombase INT ,            
@n_QtyLeftToFulfill INT,            
@c_OtherParms NVARCHAR(20)=''      

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
  
   IF LEN(@c_OtherParms)>0            
   BEGIN       
      -- (tlting01)
      SELECT @b_Success = 0
      EXECUTE nspGetRight NULL,  -- facility
      @c_StorerKey,   -- StorerKey
      NULL,            -- Sku
      'LoadConsoAllocationOParms',         -- Configkey
      @b_Success    OUTPUT,
      @c_LoadConsoAllocationOParms      OUTPUT,
      @n_err        OUTPUT,
      @c_errmsg     OUTPUT
      
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
         SELECT @c_OrderType = CASE WHEN (ISNULL(ORDERS.UserDefine01,'') <> '') THEN 'ECOM' ELSE 'STORE' END             
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
                            
    IF ISNULL(LTRIM(RTRIM(@c_lot)) ,'')<>''            
       AND LEFT(@c_LOT ,1)<>'*'            
    BEGIN            
  
        /* Get Storer Minimum Shelf Life */            
        DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY             
        FOR            
            SELECT LOT.StorerKey            
                  ,LOT.SKU            
                  ,LOT.LOT            
                  ,QTYAVAILABLE                = (            
                       LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED            
                   )            
            FROM   LOT(NOLOCK)            
                  ,Lotattribute                (NOLOCK)            
                  ,LOTxLOCxID                  (NOLOCK)            
                  ,LOC           (NOLOCK)            
            WHERE  LOT.LOT = @c_lot            
                   AND Lot.Lot = Lotattribute.Lot     
                   AND LOTxLOCxID.Lot = LOT.LOT            
                   AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT            
                   AND LOTxLOCxID.LOC = LOC.LOC            
                   AND LOC.Facility = @c_facility            
                   AND DATEADD(DAY ,@n_ConsigneeMinShelfLife ,Lotattribute.Lottable04)             
                >GETDATE()            
            ORDER BY            
                   Lotattribute.Lottable04            
                  ,Lot.Lot     
    END            
    ELSE            
    BEGIN            
  
        SET @c_Condition = ''            
                    
        IF @c_Lottable01<>'' AND @c_Lottable01 IS NOT NULL            
        BEGIN            
            SELECT @c_Condition = @c_Condition+            
                   ' AND LOTTABLE01 = N'''+@c_Lottable01+''' '            
        END            
                    
      IF @c_Lottable02<>'' AND @c_Lottable02 IS NOT NULL            
        BEGIN            
            SELECT @c_Condition = @c_Condition+            
                   ' AND LOTTABLE02 = N'''+@c_Lottable02+''' '            
        END            
            
        IF @c_Lottable03<>'' AND @c_Lottable03 IS NOT NULL            
        BEGIN            
            SELECT @c_Condition = @c_Condition+            
                   ' AND LOTTABLE03 = N'''+@c_Lottable03+''' '            
        END            
            
                    
        IF CONVERT(VARCHAR(8) ,@d_Lottable04 ,112)<>'19000101'            
           AND @d_Lottable04 IS NOT NULL            
        BEGIN            
            SELECT @c_Condition = @c_Condition+            
                   ' AND (Lotattribute.Lottable04 >= N'''+CONVERT(VARCHAR(8) ,@d_Lottable04 ,112)             
                  +''') '            
        END            
        ELSE            
        BEGIN            
            SELECT @c_Condition = @c_Condition+            
                   ' AND (DateAdd(Day, '+CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10))             
                  +', Lotattribute.Lottable04) > GetDate() '            
                        
            SELECT @c_Condition = @c_Condition+            
                   ' OR Lotattribute.Lottable04 IS NULL) '            
        END            
                               
  
          EXEC (' DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR  FOR ' +              
                 ' SELECT MIN(LOTxLOCxID.StorerKey) , MIN(LOTxLOCxID.SKU), LOT.LOT, ' +              
                  ' QTYAVAILABLE = SUM(CASE WHEN LOC.Locationflag="HOLD" AND LOC.LOC <> "WS01" THEN 0 ELSE LOTxLOCxID.QTY END)   
                   - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN   
                                 CASE WHEN LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY   
                                      THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) + LOTxLOCxID.QTYALLOCATED   
                                      ELSE 0  
                                 END  
                       ELSE LOTxLOCxID.QTYALLOCATED END)   
                  - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN   
                                 CASE WHEN LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY   
                                      THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY)    
                                      ELSE 0  
                                 END   
                             ELSE LOTxLOCxID.QTYPICKED END) ' +  
                  -- - CASE WHEN SUM(ISNULL(LOTxLOCxID.QtyReplen,0)) < 0 THEN 0 ELSE SUM(ISNULL(LOTxLOCxID.QtyReplen,0)) END  
                  ' - MIN(ISNULL(P.QtyPreAllocated ,0)) ' +  
                  ' FROM LOT (NOLOCK) ' +             
      ' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) ' +             
      ' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) ' +             
      ' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) ' +             
      ' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' +             
      ' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) ' +             
      ' LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' +             
              ' FROM   PreallocatePickdetail P (NOLOCK), ORDERS (NOLOCK) ' +             
              ' WHERE  P.Orderkey = ORDERS.Orderkey ' +             
              ' AND    P.StorerKey = N''' + @c_StorerKey + ''' ' +              
              ' AND    P.SKU = N''' + @c_sku +  ''' ' +             
              ' AND    ORDERS.FACILITY = N''' + @c_facility + ''' ' +             
              ' AND    P.qty > 0 ' +             
              ' GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility ' +              
      ' WHERE LOTxLOCxID.StorerKey = N''' + @c_StorerKey + ''' ' +             
      ' AND LOTxLOCxID.SKU = N''' + @c_sku +  ''' ' +             
      ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" ' +          
      --' AND LOC.Locationflag NOT IN ("DAMAGE", "HOLD") ' + -- SOS# 222540        
      ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_Condition + ' ' +        
      ' AND   EXISTS(SELECT 1 FROM LOT WITH (NOLOCK) WHERE LOT.LOT = LOTxLOCxID.Lot ' +    
                    ' AND LOT.Qty - LOT.QtyPreAllocated - LOT.QtyAllocated - LOT.QtyPicked - ' +
                    ' ISNULL(( Select sum( LLI.QTy  ) ' +
                    ' FROM LOTXLOCXID LLI with (NOLOCK) ' +
                    ' WHERE ( EXISTS ( SELECT 1 from LOC L with (NOLOCK) WHERE L.LOC = LLI.LOC and  ' +
                    '        ( L.STATUS <> "OK" OR L.Locationflag = "DAMAGE") ) ' +
                    ' OR EXISTS ( SELECT 1 from ID  I with (NOLOCK) WHERE I.ID  = LLI.ID and I.STATUS <> "OK" ) ) ' +
                    ' AND LLI.LOT =  LOTxLOCxID.LOT ), 0) ' +            
                    ' > 0) ' +        
--                   LOT.QtyOnHold > 0) ' +                    -- Recalculate ON HOLD QTY                       
      ' GROUP BY LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ' +             
      ' HAVING (SUM(CASE WHEN LOC.Locationflag="HOLD" AND LOC.LOC <> "WS01" THEN 0 ELSE LOTxLOCxID.QTY END)   
                   - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN   
                                 CASE WHEN LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY   
                                      THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY) + LOTxLOCxID.QTYALLOCATED   
                                      ELSE 0  
                                 END  
                       ELSE LOTxLOCxID.QTYALLOCATED END)   
                  - SUM(CASE WHEN LOC.Locationflag="HOLD" THEN   
                                 CASE WHEN LOTxLOCxID.QTYPICKED > LOTxLOCxID.QTY   
                                      THEN (LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTY)    
                                      ELSE 0  
                                 END   
                             ELSE LOTxLOCxID.QTYPICKED END) ' +   
                  -- - CASE WHEN SUM(ISNULL(LOTxLOCxID.QtyReplen,0)) < 0 THEN 0 ELSE SUM(ISNULL(LOTxLOCxID.QtyReplen,0)) END  
                 ' - MIN(ISNULL(P.QtyPreAllocated ,0)) ) > 0 ' +             
      ' ORDER BY ' +        
      ' MIN(CASE WHEN LOC.LocationType IN ("DYNPICKP", "DYNPICKR") ' +         
                     ' OR SKUxLOC.LocationType IN ("CASE" ,"PICK") ' +          
                     ' OR LOC.LocationType = "PICK" THEN 2 ' +         
               ' WHEN  LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked-LOTxLOCxID.QtyAllocated <= 0 THEN 1 ' +       
               ' ELSE 0 END), ' +       
      ' LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ')              
   END  
  
END   

GO