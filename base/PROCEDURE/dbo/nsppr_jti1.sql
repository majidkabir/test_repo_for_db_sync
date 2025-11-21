SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
          
/************************************************************************/            
/* Stored Procedure: nspPR_JTI1                                         */            
/* Creation Date:                                                       */            
/* Copyright: IDS                                                       */            
/* Written by:                                                          */            
/*                                                                      */            
/* Purpose:                                                             */            
/*                                                                      */            
/* Called By:                                                           */            
/*                                                                      */            
/* PVCS Version: 1.5                                                    */            
/*                                                                      */            
/* Version: 5.4                                                         */            
/*                                                                      */            
/* Data Modifications:                                                  */            
/*                                                                      */            
/* Updates:                                                             */            
/* Date         Author    Ver.  Purposes                                */            
/* 27-Aug-2013  Shong     1.0   Special Pre-Allocation Strategy design  */            
/*                              For JTI Project SOS#292318              */  
/* 18-Dec-2013  Shong     1.1   Changing the CountryOfOrigin Logic      */
/* 02-Jan-2014  Shong     1.2   Change GetDate to Orders.DeliveryDate   */
/* 09-Jan-2014  Shong     1.3   Force FEFO without consider Loc Type    */
/* 24-Nov-2014  NJOW01    1.4   326400-Add filter by lottable01 if not  */
/*                              empty.                                  */
/* 02-DEC-2019  Wan01     1.5   Dynamic SQL review, impact SQL cache log*/   
/************************************************************************/            
CREATE PROC  [dbo].[nspPR_JTI1]              
    @c_StorerKey NVARCHAR(15) ,              
    @c_SKU NVARCHAR(20) ,              
    @c_LOT NVARCHAR(10) ,              
    @c_Lottable01 NVARCHAR(18) ,              
    @c_Lottable02 NVARCHAR(18) ,              
    @c_Lottable03 NVARCHAR(18) ,              
    @d_Lottable04 DATETIME ,              
    @d_Lottable05 DATETIME ,              
    @c_uom NVARCHAR(10) ,               
    @c_Facility NVARCHAR(10)  ,              
    @n_UOMBase INT ,              
    @n_QtyLeftToFulfill INT,              
    @c_OtherParms    NVARCHAR(200)=NULL            
AS              
BEGIN          
   SET NOCOUNT ON              
              
   DECLARE @b_debug INT              
   SELECT @b_debug = 0    
    
   DECLARE @c_SQL       NVARCHAR(4000)  = ''       --(Wan01)   
         , @c_SQLParms  NVARCHAR(4000)  = ''       --(Wan01)             
              
              
   -- user will key in as DDMMYYYY in Lottable01 field, take d oldest date            
   DECLARE @n_SkuMinShelfLife     INT          
         ,@n_StorerMinShelfLife  INT          
         ,@c_OrderKey            NVARCHAR(10)        
         ,@c_OrderLine           NVARCHAR(5)          
         ,@n_TotalShelfLife      INT          
         ,@c_Condition           NVARCHAR(MAX)          
         ,@c_OrderUOM            NVARCHAR(10)            
         ,@n_OutGoingShelfLife   INT          
         ,@c_CustType            NVARCHAR(20)         
         ,@c_ConsigneeGroup      NVARCHAR(20)        
         ,@c_CMA                 NVARCHAR(10)         
         ,@c_CountryOfOrigin     NVARCHAR(10)      
         ,@c_PackQty             VARCHAR(10)
         ,@c_DeliveryDate        VARCHAR(20) 
                                  
              
    SET @n_StorerMinShelfLife = 0            
    SET @n_SkuMinShelfLife = 0            
    SET @n_TotalShelfLife = 0            
    SET @c_OrderKey = ''          
    SET @n_OutGoingShelfLife = 0           
              
    -- Find STORER Minshelflife -Start            
    IF ISNULL(RTRIM(@c_OtherParms) ,'')<>''          
    BEGIN        
        SET @c_OrderKey  = SUBSTRING(RTRIM(@c_OtherParms) ,1 ,10)            
        SET @c_OrderLine = SUBSTRING(RTRIM(@c_OtherParms) ,11 ,5)               
    END        
              
    IF ISNULL(RTRIM(@c_OrderKey) ,'')<>'' AND ISNULL(RTRIM(@c_OrderLine) ,'')<>''        
    BEGIN         
      SELECT @c_CustType = ISNULL(Storer.SUSR3,''),         
             @c_ConsigneeGroup = ISNULL(Storer.SUSR1,''),  
             @c_DeliveryDate = CONVERT(VARCHAR(20), ISNULL(Orders.DeliveryDate, GETDATE()), 112)         
      FROM   Storer(NOLOCK)          
      JOIN   Orders(NOLOCK) ON Storer.StorerKey = Orders.Consigneekey          
      WHERE  Orders.OrderKey = @c_OrderKey           
        
      SET @n_StorerMinShelfLife = 0         
      SET @c_CountryOfOrigin = ''        
      SELECT @n_StorerMinShelfLife = ISNULL(O.MinShelfLife ,0),         
             @c_CountryOfOrigin = DLK.UserDefine01,         
             @c_OrderUOM = O.UOM         
      FROM ORDERDETAIL o WITH (NOLOCK)         
      LEFT OUTER JOIN DOCLKUP DLK (NOLOCK) ON DLK.SKUGroup = o.Sku AND DLK.ConsigneeGroup = @c_ConsigneeGroup         
      WHERE o.OrderKey = @c_OrderKey        
      AND o.OrderLineNumber = @c_OrderLine         

      IF ISNULL(RTRIM(@c_Lottable03) ,'')<>''           
      BEGIN        
         SET @c_CountryOfOrigin = @c_Lottable03         
      END  
              
      IF EXISTS(SELECT 1 FROM CODELKUP  WITH (NOLOCK)        
                WHERE  ListName = 'JTCMAPord'        
                AND    Code = @c_SKU) OR @c_CountryOfOrigin = 'TWN'          
         SET @c_CMA = 'Y'        
      ELSE        
          SET @c_CMA = 'N'        
         
      IF @n_StorerMinShelfLife = 0        
      BEGIN        
          IF @c_CMA = 'Y'        
          BEGIN        
              SELECT @n_StorerMinShelfLife = CASE WHEN ISNUMERIC(Long) = 1 THEN long ELSE 0 END        
              FROM   CODELKUP WITH (NOLOCK)        
              WHERE  ListName = 'JTCUSSHLF'        
              AND    Code = @c_CustType                        
          END          
          ELSE        
          BEGIN        
             SELECT @n_StorerMinShelfLife = CASE WHEN ISNUMERIC(Short) = 1 THEN Short ELSE 0 END        
             FROM   CODELKUP WITH (NOLOCK)        
             WHERE  ListName = 'JTCUSSHLF'        
             AND    Code = @c_CustType                        
          END        
      END -- IF @n_StorerMinShelfLife = 0        
    END           
    ELSE        
       GOTO SKIP_LOT         
    -- Find STORER Minshelflife -End              
              
                  
    IF ISNULL(RTRIM(@c_lot) ,'')<>'' AND LEFT(ISNULL(RTRIM(@c_lot) ,'') ,1)<>'*'          
    BEGIN          
      DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY           
      FOR          
          SELECT LOT.StorerKey          
                ,LOT.SKU          
                ,LOT.LOT          
                ,QTYAVAILABLE = (          
                     LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED          
                 )          
          FROM   LOT(NOLOCK)          
          JOIN   Lotattribute (NOLOCK) ON         
                 LOT.LOT = LOTATTRIBUTE.LOT          
          JOIN   LOTxLOCxID   (NOLOCK) ON         
                 LOTxLOCxID.Lot = LOT.LOT          
          JOIN   LOC (NOLOCK) ON          
                 LOTxLOCxID.LOC = LOC.LOC          
          WHERE  LOC.Facility = @c_Facility          
                 AND LOT.LOT = @c_lot          
          ORDER BY LOT.Lot          
     END          
     ELSE          
     BEGIN          
        --IF ISNULL(RTRIM(@c_Lottable01) ,'')<>''          
           --SELECT @c_Condition = " AND LOC.HostWhCode  = N'"+ISNULL(RTRIM(@c_Lottable01) ,'')           
           --     +"' "              
                        
        IF ISNULL(RTRIM(@c_Lottable01) ,'')<>''  --NJOW01        
           SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+          
                 " AND Lottable01 = RTRIM(@c_Lottable01) "                       --(Wan01)                
                
        IF ISNULL(RTRIM(@c_Lottable02) ,'')<>''          
           SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+          
                 " AND Lottable02 = RTRIM(@c_Lottable02) "                       --(Wan01)                 
                               
        IF ISNULL(RTRIM(@c_Lottable03) ,'')<>''          
        BEGIN        
           SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+          
                 " AND Lottable03 = RTRIM(@c_Lottable03) "                       --(Wan01)                  
        END        
                         
        IF @n_StorerMinShelfLife <> 0        
        BEGIN        
          IF CONVERT(CHAR(10) ,@d_Lottable04 ,103) = '01/01/1900' OR @d_Lottable04 IS NULL        
          BEGIN        
              SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND (Lotattribute.Lottable04 >= " +
                  " DateAdd(Month, @n_StorerMinShelfLife,DATEADD(mm, DATEDIFF(mm, '', CONVERT(DATETIME, @c_DeliveryDate)), '')) "   --(Wan01)
                           
                  --" DateAdd(Month," + CAST(@n_StorerMinShelfLife AS NVARCHAR(2)) + ",DATEADD(mm, DATEDIFF(mm, '', GETDATE()), '')) "           
                      
              SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " OR Lotattribute.Lottable04 IS NULL ) "        
          END        
        END           
                                  
        
        IF @c_UOM = '1'          
        BEGIN         
           IF @n_QtyLeftToFulfill < @n_UOMBase  OR   @n_UOMBase = 0  --(Wan01) -- Fix Devide by Zero error  
               GOTO SKIP_LOT      
                     
           --SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+          
           --      " AND SKUxLOC.LocationType <> N'PICK' "          
        END         
      
        SET @c_PackQty = CONVERT(VARCHAR(10), @n_UOMBase)      
                        
        SET @c_condition = ISNULL(RTRIM(@c_Condition) ,'') +         
             "GROUP BY LOT.StorerKey, LOT.SKU " +                   
             ",LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable03, LOT.Lot ,P.QTYPREALLOCATED " +        
             "HAVING CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - "+       
                  "                   SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) < @n_UOMBase " +     --(Wan01)        
                  "            THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) "+       
                  "                 - SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) "+       
                  "            WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - "+       
                  "                   SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) % @n_UOMBase = 0 " + --(Wan01)      
                  "            THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +      
                  "                 - SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) " +       
                  "           ELSE " +       
                  "           ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) " +       
                  "           -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) % @n_UOMBase " + --(Wan01)    
                  "       END >= @n_UOMBase "                                                                        --(Wan01)     
                   
        
        --IF @c_OrderUOM = 'CAR' OR @c_UOM = '2'         
        BEGIN          
           SET @c_condition = ISNULL(RTRIM(@c_Condition) ,'')+          
                  " ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable03, LOT.Lot"                  
                   --" ORDER BY SUM(CASE WHEN SKUxLOC.LocationType = 'PICK' THEN 1 ELSE 0 END) DESC, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable03, LOT.Lot"                  
                      
        END        
        --ELSE        
        --BEGIN        
        --   SET @c_condition = ISNULL(RTRIM(@c_Condition) ,'')+          
        --           " ORDER BY SUM(CASE WHEN SKUxLOC.LocationType = 'PICK' THEN 1 ELSE 0 END) DESC, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable03, LOT.Lot"         
        --END                         
              
    
              
        SET @c_SQL =                                                                                                 --(Wan01)            
                  " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +          
                  " SELECT LOT.StorerKey, "+          
                  "        LOT.SKU, "+          
                  "        LOT.LOT, "+          
                  --"        QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0))  "+          
                  "QTYAVAILABLE = CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - "+      
                  "   SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) < @n_UOMBase " +                     --(Wan01)      
                  "            THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) "+      
                  "                 - SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) "+      
                  "            WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - "+      
                  "                   SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) % @n_UOMBase = 0 " + --(Wan01)       
                  "            THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +      
                  "                 - SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) " +      
                  "           ELSE " +      
                  "           ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) " +      
                  "           -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) ) % @n_UOMBase " +--(Wan01)        
                  "       END " +                        
                  " FROM  LOTxLOCxID (NOLOCK) "+          
                  "       JOIN LOT (nolock) ON LOT.LOT = LOTxLOCxID.Lot  "+          
                  "       JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT) " +          
                  "       JOIN LOC (Nolock) ON LOTxLOCxID.Loc = LOC.Loc "+          
                  "       JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  "+          
                  "       JOIN SKUxLOC (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND SKUxLOC.SKU = LOTxLOCxID.SKU "+          
                  "          AND SKUxLOC.LOC = LOTxLOCxID.LOC "+          
                  "       LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +          
                  "                   FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +          
                  "                   WHERE  p.OrderKey = ORDERS.OrderKey "+          
                  "                   GROUP BY p.Lot, ORDERS.Facility) As P ON LOTxLOCxID.Lot = P.Lot AND LOC.Facility = P.Facility " +          
                  " WHERE LOT.StorerKey = @c_StorerKey "+               --(Wan01)            
                  " AND LOT.SKU = @c_SKU "+                             --(Wan01)  
                  " AND LOT.STATUS = 'OK' "+          
                  " AND ID.STATUS <> 'HOLD' "+          
                  " AND LOC.Status = 'OK' "+          
                  " AND LOC.Facility = @c_Facility "+                   --(Wan01)     
                  " AND LOC.LocationFlag <> 'HOLD' "+          
                  " AND LOC.LocationFlag <> 'DAMAGE' "+          
                  " AND ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'') <> ''  "+          
                  @c_Condition 
                     
      --(Wan01) - START
      SET @c_SQLParms=N' @c_Facility      NVARCHAR(5)'
                     + ',@c_Storerkey     NVARCHAR(15)'
                     + ',@c_SKU           NVARCHAR(20)'     
                     + ',@c_Lottable01    NVARCHAR(18)'
                     + ',@c_Lottable02    NVARCHAR(18)' 
                     + ',@c_Lottable03    NVARCHAR(18)' 
                     + ',@c_DeliveryDate  NVARCHAR(20)'
                     + ',@n_StorerMinShelfLife INT'
                     + ',@n_UOMBase INT '       
      
      EXEC sp_ExecuteSQL @c_SQL
                     , @c_SQLParms
                     , @c_Facility
                     , @c_Storerkey
                     , @c_SKU
                     , @c_Lottable01
                     , @c_Lottable02
                     , @c_Lottable03
                     , @c_DeliveryDate
                     , @n_StorerMinShelfLife
                     , @n_UOMBase
      --(Wan01) - END             
                      
                
    END -- IF Storer.Minshelflife blank Don't Allocate          
        
   RETURN         
        
SKIP_LOT:          
  -- Dummy Cursor when storer.minshelflife is zero/blank            
  DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY           
  FOR          
      SELECT LOT.StorerKey          
            ,LOT.SKU          
            ,LOT.LOT          
            ,QTYAVAILABLE                = (          
                 LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED          
             )          
      FROM   LOT(NOLOCK)          
      WHERE  1=2          
      ORDER BY          
             Lot.Lot          
         
END   

GO