SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/        
/* Store procedure: nspPRUKD01                                               */        
/* Copyright      : IDS                                                      */        
/*                                                                           */        
/* Purpose: Pre-Allocation Strategy for UK Diana                             */        
/*          Only works for E-Com Order (UserDefine01 <> BLANK)               */        
/*                                                                           */        
/*                                                                           */        
/* Modifications log:                                                        */        
/*                                                                           */        
/* Date        Author  Rev   Purposes                                        */        
/* 2010-06-28  Shong   1.0   Created                                         */        
/* 2010-09-02  James   1.1   Allow to pick from PPA first and remove location*/        
/*                           flag filtering (james01)                        */    
/* 2010-11-24  NJOW01  1.2   196932 Change to allow the setting of the       */    
/*                           X Factor at Load Plan level                     */    
/* 21-Nov-2010 TLTING  1.3   Load Allocation - pass LoadKey in(TLTING01)     */  
/*                           StorerConfig - LoadConsoAllocationOParms        */  
/*                           OnHold Qty Calculation                          */  
/* 2014-10-02  James   1.4   Bug fix. Extend var for ordergroup (james02)    */
/* 2014-11-20  Shong   1.5   Make WS01 Qty as Qty Available                  */      
/* 2015-09-29  NJOW02  1.6   345748 - Skip if not ecom order                 */  
/* 2016-07-25  NJOW03  1.7   373644-Add lottable07 filtering                 */
/* 2017-04-21  NJOW04  1.8   WMS-1714 Change sorting to lottable05           */
/*****************************************************************************/        
CREATE  PROC [dbo].[nspPRUKD01]        
@c_StorerKey  NVARCHAR(15) ,        
@c_sku        NVARCHAR(20) ,        
@c_lot        NVARCHAR(10) ,        
@c_lottable01 NVARCHAR(18) ,        
@c_lottable02 NVARCHAR(18) ,        
@c_lottable03 NVARCHAR(18) ,        
@d_lottable04 DATETIME ,        
@d_lottable05 DATETIME ,        
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
@c_facility   NVARCHAR(10)  ,  -- added By Ricky for IDSV5        
@n_uombase    INT ,        
@n_QtyLeftToFulfill INT,        
@c_OtherParms NVARCHAR(20)=''         
AS        
BEGIN        
   DECLARE @n_ConsigneeMinShelfLife  INT        
          ,@c_Condition              NVARCHAR(MAX)        
        
   DECLARE @c_OrderKey      NVARCHAR(10)        
          ,@c_OrderType     NVARCHAR(10)      
          ,@c_OrderGroup    NVARCHAR(20)    -- (james02)  
          ,@c_LoadKey       NVARCHAR(10)      
          ,@nTotOpenQty     INT      
          ,@nCaseQtyXFactor INT           
          ,@nPreAllocatedQty INT      
          ,@nAllocatedQty    INT       
          ,@nTotalAllocated  INT      
          ,@nQtyFromPPA      INT      
          ,@cQtyString       NVARCHAR(10)      
          ,@nCaseQtyXFactorConfig  INT    --NJOW01          
          ,@c_LoadConsoAllocationOParms NVARCHAR(1)--  tlitng01        
          ,@b_Success    INT   
          ,@n_err        INT  
          ,@c_errmsg     NVARCHAR(250)                           
         
      
   SELECT @n_ConsigneeMinShelfLife = 0      
   SET @nQtyFromPPA = 0      
   SET @c_LoadConsoAllocationOParms = ''     
    
        
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
         SELECT TOP 1 @c_OrderType = CASE WHEN (ISNULL(ORDERS.UserDefine01,'') <> '') THEN 'ECOM' ELSE 'STORE' END,        
                @c_OrderGroup = OrderGroup         
         FROM   ORDERS WITH (NOLOCK)              
         WHERE  LoadKey = @c_LoadKey              
      END  
      ELSE  
      BEGIN   
         SET @c_OrderKey = LEFT(@c_OtherParms ,10)   
         SELECT @c_OrderType = CASE WHEN (ISNULL(ORDERS.UserDefine01,'') <> '') THEN 'ECOM' ELSE 'STORE' END,      
              @c_OrderGroup = OrderGroup,      
              @c_LoadKey    = LoadKey  
         FROM   ORDERS WITH (NOLOCK)              
         WHERE  OrderKey = @c_OrderKey              
      END         
       
       --NJOW02
       IF @c_OrderType<>'ECOM'        
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
        
       IF @c_OrderType<>'ECOM'        
       BEGIN        
          SET @nCaseQtyXFactor=0      
          SET @nQtyFromPPA = 0       
      
--          SELECT @nCaseQtyXFactor = CASE WHEN ISNUMERIC(ISNULL(Cl.Short,'0')) = 1 THEN CONVERT(INT, Cl.Short) ELSE 0 END    
--          FROM   SKU WITH (NOLOCK)     
--          JOIN   CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'PRODMODEL' AND CL.Code = SKU.ProductModel     
--          WHERE  SKU.Sku = @c_sku     
--          AND    SKU.StorerKey = @c_StorerKey    
              
          IF @nCaseQtyXFactor = 0     
          BEGIN                 
             /*SELECT @nCaseQtyXFactor = CASE WHEN ISNUMERIC(ISNULL(sValue,'0')) = 1 THEN CONVERT(INT, sValue) ELSE 0 END       
             FROM   StorerConfig WITH (NOLOCK)       
             WHERE  StorerConfig.Storerkey = @c_StorerKey       
             AND    ConfigKey = 'CaseQtyXFactor'    */  
                 
             --NJOW01    
             SELECT @nCaseQtyXFactorConfig  = CASE WHEN ISNUMERIC(ISNULL(sValue,'0')) = 1 THEN CONVERT(INT, sValue) ELSE 0 END       
             FROM   StorerConfig WITH (NOLOCK)       
             WHERE  StorerConfig.Storerkey = @c_StorerKey       
             AND    ConfigKey = 'CaseQtyXFactor'    
                 
             IF @nCaseQtyXFactorConfig > 0     
             BEGIN    
                SELECT @nCaseQtyXFactor = CASE WHEN ISNUMERIC(ISNULL(CONVERT(char(255),Load_Userdef1),'0')) = 1 THEN CONVERT(INT, CONVERT(CHAR(255),Load_Userdef1)) ELSE 0 END       
                FROM LOADPLAN (NOLOCK)    
                WHERE LOADKEY = @c_LoadKey     
             END                
          END    
  
          SET @nTotOpenQty = 0       
          SET @nPreAllocatedQty = 0      
          SET @nAllocatedQty    = 0       
          SET @nTotalAllocated  = 0       
      
          IF @nCaseQtyXFactor > 0  AND ISNULL(RTRIM(@c_OrderGroup),'') <> ''       
          BEGIN       
             SELECT @nTotOpenQty = SUM(OD.OpenQty)       
             FROM   ORDERS O WITH (NOLOCK)       
             JOIN   ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey        
             WHERE  OD.StorerKey = @c_StorerKey       
             AND    OD.SKU = @c_SKU       
             AND    O.OrderGroup = @c_OrderGroup       
  
             IF @nTotOpenQty < @nCaseQtyXFactor       
             BEGIN       
                SET @nPreAllocatedQty = 0      
                SELECT @nPreAllocatedQty = ISNULL(SUM(Qty),0)       
                FROM   ORDERS O WITH (NOLOCK)        
                JOIN PreAllocatePickDetail PD WITH (NOLOCK) ON O.OrderKey = PD.OrderKey       
                     AND PreAllocatePickCode = 'nspPRUKD01'      
                WHERE  PD.StorerKey = @c_StorerKey       
                AND    PD.SKU = @c_SKU       
                AND    O.OrderGroup = @c_OrderGroup       
    
      
                SELECT @nAllocatedQty = ISNULL(SUM(Qty),0)       
                FROM   ORDERS O WITH (NOLOCK)        
              JOIN   PickDetail PD WITH (NOLOCK , INDEX(IDX_PICKDETAIL_ORDERKEY)) ON O.OrderKey = PD.OrderKey       
--                JOIN   PickDetail PD WITH (NOLOCK) ON O.OrderKey = PD.OrderKey                       
                JOIN   LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC AND LOC.LocationType = 'PICK'          
                WHERE  PD.StorerKey = @c_StorerKey       
                AND    PD.SKU = @c_SKU       
                AND    O.OrderGroup = @c_OrderGroup       
                AND    PD.UOM = '7'      
      
                SET @nTotalAllocated = @nPreAllocatedQty + @nAllocatedQty      
      
                SET @nQtyFromPPA = @nTotOpenQty - @nTotalAllocated      
             END       
          END -- @nCaseQtyXFactor > 0  AND ISNULL(RTRIM(@c_OrderGroup),'') <> ''  
--select * from traceinfo (nolock) order by timein desc    
          --select @nCaseQtyXFactor '@nCaseQtyXFactor', @nTotOpenQty '@nTotOpenQty', @nTotalAllocated '@nTotalAllocated',       
          --@nQtyFromPPA '@nQtyFromPPA'       
          IF @nQtyFromPPA = 0       
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
                         ' AND LOTTABLE03 = '''+@c_Lottable03+''' '        
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
                         ' AND (DateAdd(Day,'+CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10))         
                        +', Lotattribute.Lottable04) > GetDate() '        
                          
                  SELECT @c_Condition = @c_Condition+        
                         ' OR Lotattribute.Lottable04 IS NULL) '        
              END        

              IF @c_Lottable07<>'' AND @c_Lottable07 IS NOT NULL        
              BEGIN        
                  SELECT @c_Condition = @c_Condition+        
                         ' AND LOTTABLE07 = '''+@c_Lottable07+''' '        
              END                      
                
            SET @cQtyString = CAST(@nQtyFromPPA as NVARCHAR(10))      
            EXEC (' DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR ' +          
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
                     ELSE LOTxLOCxID.QTYPICKED END)    
               - MIN(ISNULL(P.QtyPreAllocated ,0)) ' +         
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
        ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" ' + -- (james01)        
        ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_Condition + ' ' +          
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
                 ELSE LOTxLOCxID.QTYPICKED END)    
      - MIN(ISNULL(P.QtyPreAllocated ,0))) > 0 ' +         
        ' ORDER BY LOTATTRIBUTE.LOTTABLE05, SUM( ' +       
        '  CASE WHEN SKUxLOC.LocationType NOT IN ("CASE" ,"PICK") AND LOC.LocationType = "PICK" THEN 0 ' +       
        '       WHEN SKUxLOC.LocationType IN ("CASE" ,"PICK") THEN 1 ' +        
        '       ELSE 2 END) ' + -- (james01)        
        ' , LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02 ') --NJOW04
--        ' ORDER BY SUM( ' +       
--        '  CASE WHEN SKUxLOC.LocationType NOT IN ("CASE" ,"PICK") AND LOC.LocationType = "PICK" THEN 0 ' +       
--        '       WHEN SKUxLOC.LocationType IN ("CASE" ,"PICK") THEN 1 ' +        
--        '       ELSE 2 END) ' + -- (james01)        
--        ' , LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ')       
         
             RETURN       
          END       
       END               
   END        
  
        
        
   IF ISNULL(LTRIM(RTRIM(@c_lot)) ,'')<>''        
       AND LEFT(@c_LOT ,1)<>'*'        
   BEGIN        
        /* Get Storer Minimum Shelf Life */        
    
        DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY         
        FOR        
            SELECT LOT.StorerKey        
                  ,LOT.SKU        
                  ,LOT.LOT        
                  ,QTYAVAILABLE = ( LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QtyPreAllocated )        
            FROM   LOT(NOLOCK)        
                  ,Lotattribute                (NOLOCK)        
                  ,LOTxLOCxID                  (NOLOCK)        
                  ,LOC                         (NOLOCK)        
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
                   ' AND (DateAdd(Day,'+CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10))         
                  +', Lotattribute.Lottable04) > GetDate() '        
                    
            SELECT @c_Condition = @c_Condition+        
                   ' OR Lotattribute.Lottable04 IS NULL) '        
        END        

        IF @c_Lottable07<>'' AND @c_Lottable07 IS NOT NULL        
        BEGIN        
            SELECT @c_Condition = @c_Condition+        
                   ' AND LOTTABLE07 = N'''+@c_Lottable07+''' '        
        END        
                
      EXEC (' DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR ' +          
      ' SELECT MIN(LOTxLOCxID.StorerKey) , MIN(LOTxLOCxID.SKU), LOT.LOT, ' +          
      ' QTYAVAILABLE = SUM(CASE WHEN LOC.Locationflag="HOLD" THEN 0 ELSE LOTxLOCxID.QTY END)     
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
                 ELSE LOTxLOCxID.QTYPICKED END)    
      - MIN(ISNULL(P.QtyPreAllocated ,0)) ' +         
      ' FROM LOT (NOLOCK) ' +         
      ' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) ' +         
      ' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) ' +         
      ' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) ' +         
      ' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' +         
      ' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) ' +         
      ' LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' +         
  ' FROM PreallocatePickdetail P (NOLOCK), ORDERS (NOLOCK) ' +         
  ' WHERE P.Orderkey = ORDERS.Orderkey ' +         
  ' AND P.StorerKey = N''' + @c_StorerKey + ''' ' +          
  ' AND P.SKU = N''' + @c_sku +  ''' ' +         
  ' AND ORDERS.FACILITY = N''' + @c_facility + ''' ' +         
  ' AND P.qty > 0 ' +         
  ' GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility ' +          
  ' WHERE LOTxLOCxID.StorerKey = N''' + @c_StorerKey + ''' ' +         
  ' AND LOTxLOCxID.SKU = N''' + @c_sku +  ''' ' +         
  ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" ' + -- (james01)        
  ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_Condition + ' ' +          
  ' GROUP BY LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ' +         
  ' HAVING (SUM(CASE WHEN LOC.Locationflag="HOLD" THEN 0 ELSE LOTxLOCxID.QTY END)     
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
                 ELSE LOTxLOCxID.QTYPICKED END)    
      - MIN(ISNULL(P.QtyPreAllocated ,0)) ) > 0 ' +         
    ' ORDER BY LOTATTRIBUTE.LOTTABLE05, SUM( ' +       
    '  CASE WHEN SKUxLOC.LocationType NOT IN ("CASE" ,"PICK") AND LOC.LocationType = "PICK" THEN 0 ' +       
    '       WHEN SKUxLOC.LocationType IN ("CASE" ,"PICK") THEN 1 ' +        
    '       ELSE 2 END) ' + -- (james01)        
    ' , LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02 ') --NJOW04
--  ' ORDER BY SUM( ' +       
--  ' CASE WHEN SKUxLOC.LocationType NOT IN ("CASE" ,"PICK") AND LOC.LocationType = "PICK" THEN 0 ' +       
--       ' WHEN SKUxLOC.LocationType IN ("CASE" ,"PICK") THEN 1 ' +        
--       ' ELSE 2 END) ' + -- (james01)        
--  ' ,LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ')              
    END        
END

GO