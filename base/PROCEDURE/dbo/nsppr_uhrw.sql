SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspPR_UHRW                                         */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 07-May-2009  Shong     1.1   Bug Fixing                              */  
/* 07-May-2009  Shong     Change the Logic to get Pallet from Bulk &    */  
/*                        Case from Pick Location                       */  
/* 29-Apr-2010  SHONG     SOS168515 New Allocation Strategy for Unilever*/
/*                        Food / HPC items                              */
/* 28-Oct-2010  TLTING    SKU Shelf life from Codelkup.Long             */ 
/************************************************************************/  
  
CREATE PROC  [dbo].[nspPR_UHRW]    
 @c_storerkey NVARCHAR(15) ,    
 @c_sku NVARCHAR(20) ,    
 @c_lot NVARCHAR(10) ,    
 @c_lottable01 NVARCHAR(18) ,    
 @c_lottable02 NVARCHAR(18) ,    
 @c_lottable03 NVARCHAR(18) ,    
 @d_lottable04 DATETIME ,    
 @d_lottable05 DATETIME ,    
 @c_uom NVARCHAR(10) ,     
 @c_facility NVARCHAR(10)  ,    
 @n_uombase INT ,    
 @n_qtylefttofulfill INT,    
 @c_OtherParms    NVARCHAR(200)=NULL  
AS    
BEGIN
    SET NOCOUNT ON    
    
    DECLARE @b_debug INT    
    SELECT @b_debug = 0 
    
    -- user will key in as DDMMYYYY in lottable01 field, take d oldest date  
    DECLARE @n_SkuMinShelfLife     INT
           ,@n_StorerMinShelfLife  INT
           ,@c_orderkey            NVARCHAR(10)
           ,@n_TotalShelfLife      INT
           ,@c_Condition           NVARCHAR(MAX)
           ,@c_Lottable04Label     NVARCHAR(20)      
           ,@n_OutGoingShelfLife   INT
           ,@c_Contact2            NVARCHAR(45)            
    
    SET @n_StorerMinShelfLife = 0  
    SET @n_SkuMinShelfLife = 0  
    SET @n_TotalShelfLife = 0  
    SET @c_orderkey = ''
    SET @n_OutGoingShelfLife = 0 
    
    -- Find STORER Minshelflife -Start  
    IF ISNULL(RTRIM(@c_OtherParms) ,'')<>''
        SET @c_orderkey = SUBSTRING(RTRIM(@c_OtherParms) ,1 ,10)  
    
    IF ISNULL(RTRIM(@c_orderkey) ,'')<>''
    BEGIN
        SELECT @n_StorerMinShelfLife = ISNULL(Storer.MinShelfLife ,0),
               @c_Contact2 = ISNULL(Storer.Contact2,'')
        FROM   Storer(NOLOCK)
        JOIN   Orders(NOLOCK) ON Storer.Storerkey = Orders.Consigneekey
        WHERE  Orders.Orderkey = @c_Orderkey 
    END 
    -- Find STORER Minshelflife -End  
    
    -- IF Storer.Minshelflife blank Don't Allocate  
    IF @n_StorerMinShelfLife>0
    BEGIN
        -- Find SKU Minshelflife -Start  
        SELECT @n_SkuMinShelfLife = ISNULL(Sku.Shelflife ,0)
        FROM   Sku(NOLOCK)
        WHERE  Sku.Sku = @c_SKU
               AND Sku.Storerkey = @c_Storerkey 
        -- Find SKU Minshelflife -End  
        
        SET @n_TotalShelfLife = @n_SkuMinShelfLife- @n_StorerMinShelfLife  
        SET @n_StorerMinShelfLife = 0 - @n_StorerMinShelfLife
        
        IF ISNULL(RTRIM(@c_lot) ,'')<>''
           AND LEFT(ISNULL(RTRIM(@c_lot) ,'') ,1)<>'*'
        BEGIN
            DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY 
            FOR
                SELECT LOT.STORERKEY
                      ,LOT                         .SKU
                      ,LOT                         .LOT
                      ,QTYAVAILABLE                = (
                           LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED
                       )
                FROM   LOT(NOLOCK)
                      ,Lotattribute                (NOLOCK)
                      ,LOTXLOCXID                  (NOLOCK)
                      ,LOC                         (NOLOCK)
                WHERE  LOT.LOT = LOTATTRIBUTE.LOT
                       AND LOTXLOCXID.Lot = LOT.LOT
                       AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
                       AND LOTXLOCXID.LOC = LOC.LOC
                       AND LOC.Facility = @c_facility
                       AND LOTATTRIBUTE.Lottable03<>'QI'
                       AND LOTATTRIBUTE.Lottable03<>'BL'
                       AND LOTATTRIBUTE.Lottable03 = 'UR'
                       AND LOT.LOT = @c_lot
                       AND ISNULL(RTRIM(Lotattribute.Lottable01) ,'')<>''
                       AND ISDATE(
                               SUBSTRING(Lotattribute.Lottable01 ,5 ,4)+
                               SUBSTRING(Lotattribute.Lottable01 ,3 ,2)+
                               SUBSTRING(Lotattribute.Lottable01 ,1 ,2)
                           ) = 1
                       AND DATEADD(
                               DAY
                              ,@n_TotalShelfLife
                              ,(
                                   CONVERT(
                                       DATETIME
                                      ,LEFT(
                                           RTRIM(
                                               SUBSTRING(Lotattribute.Lottable01 ,5 ,4)
                                              +SUBSTRING(Lotattribute.Lottable01 ,3 ,2)
                                              +SUBSTRING(Lotattribute.Lottable01 ,1 ,2)
                                           )
                                          ,8
                                       )
                                      ,112
                                   )
                               )
                           )>= GETDATE()
                ORDER BY
                       (
                           CONVERT(
                               DATETIME
                              ,LEFT(
                                   RTRIM(
                                       SUBSTRING(Lotattribute.Lottable01 ,5 ,4)+
                                       SUBSTRING(Lotattribute.Lottable01 ,3 ,2)+
                                       SUBSTRING(Lotattribute.Lottable01 ,1 ,2)
                                   )
                                  ,8
                               )
                              ,112
                           )
                       )
                      ,Lot                         .Lot
        END
        ELSE
        BEGIN
            IF ISNULL(RTRIM(@c_Lottable01) ,'')<>''
                SELECT @c_Condition = " AND LOTTABLE01 = N'"+ISNULL(RTRIM(@c_Lottable01) ,'') 
                      +"' "    
            
            IF ISNULL(RTRIM(@c_Lottable02) ,'')<>''
                SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+
                       " AND LOTTABLE02 = N'"+ISNULL(RTRIM(@c_Lottable02) ,'')+
                       "' "    
            
            IF CONVERT(CHAR(10) ,@d_Lottable04 ,103)<>"01/01/1900"
               AND @d_Lottable04 IS NOT NULL
                SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+
                       " AND LOTTABLE04 = N'"+ISNULL(RTRIM(CONVERT(CHAR(20) ,@d_Lottable04 ,106)) ,'') 
                      +"' "    
            
            IF CONVERT(CHAR(10) ,@d_Lottable05 ,103)<>"01/01/1900"
               AND @d_Lottable05 IS NOT NULL
                SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+
                       " AND LOTTABLE05 = N'"+ISNULL(RTRIM(CONVERT(CHAR(20) ,@d_Lottable05 ,106)) ,'') 
                      +"' "    
            

            IF EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK) 
                      WHERE c.LISTNAME = 'ULMSKUALOC' 
                      AND c.[Description] = @c_sku 
                      AND c.short = @c_Contact2)
            BEGIN
               -- tlting01
               SET @n_OutGoingShelfLife = 0
               SELECT @n_OutGoingShelfLife = CAST( (CASE WHEN ISNumeric(C.Long) = 1 THEN C.Long ELSE '0' END ) AS INT)
               FROM CODELKUP c WITH (NOLOCK) 
               WHERE c.LISTNAME = 'ULMSKUALOC' 
                AND c.[Description] = @c_sku 
                AND c.short = @c_Contact2

               SET @n_OutGoingShelfLife = 0 - @n_OutGoingShelfLife                 
               SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+
                      " AND ( DateAdd(Day, "+CAST(@n_OutGoingShelfLife AS NVARCHAR(10)) 
                     +", Lotattribute.Lottable04) > GetDate()) "                
            END
            ELSE
            BEGIN
               SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+
                      " AND ( DateAdd(Day, "+CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) 
                     +", Lotattribute.Lottable04) > GetDate()) " 
                                           
            END 
                        
            IF @c_uom='1'
            BEGIN
                SET @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') 
                   +" AND SKUxLOC.LocationType NOT IN ('PICK','CASE') "
            END
            ELSE
            BEGIN
                IF @c_facility<>'RWE'
                   AND @c_facility<>'RWL'
                BEGIN
                    SET @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') 
                       +" AND SKUxLOC.LocationType IN ('PICK','CASE') "
                END
            END  
            
            
            SELECT @c_condition = ISNULL(RTRIM(@c_Condition) ,'') 
                  +" GROUP BY LOT.STORERKEY, "+
                  +" LOT.SKU,"+
                  +
                   " (convert (datetime, LEFT(RTRIM(SUBSTRING(Lotattribute.Lottable01,5,4)+SUBSTRING(Lotattribute.Lottable01,3,2)+SUBSTRING(Lotattribute.Lottable01,1,2)), 8), 112) ), LOT.Lot, P.QTYPREALLOCATED" 
                  +
                  +
                   " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0) >= " 
                  +RTRIM(CAST(@n_uombase AS NVARCHAR(10))) -- 03-Jul-09: Add >= To allow same uombase allocated. (Vanessa)  
            
            
            SELECT @c_condition = ISNULL(RTRIM(@c_Condition) ,'')+
                   " ORDER BY (convert (datetime, LEFT(RTRIM(SUBSTRING(Lotattribute.Lottable01,5,4)+SUBSTRING(Lotattribute.Lottable01,3,2)+SUBSTRING(Lotattribute.Lottable01,1,2)), 8), 112) ), LOT.Lot"       
            
            EXEC (
                     " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " 
                    +
                     " SELECT LOT.STORERKEY, "+
                     "        LOT.SKU, "+
                     "        LOT.LOT, "+
                     "        QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0))  " 
                    +
                     " FROM  LOTxLOCxID (NOLOCK) "+
                     "       JOIN LOT (nolock) ON LOT.LOT = LOTxLOCxID.Lot  "+
                     "       JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT) " 
                    +
                     "       JOIN LOC (Nolock) ON LOTxLOCxID.Loc = LOC.Loc "+
                     "       JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  "+
                     "       JOIN SKUxLOC (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND SKUxLOC.SKU = LOTxLOCxID.SKU " 
                    +
                     "          AND SKUxLOC.LOC = LOTxLOCxID.LOC "+
                     "       LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " 
                    +
                     "                   FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " 
                    +
                     "                   WHERE  p.Orderkey = ORDERS.Orderkey "+
                     "                        AND p.UOM = N'"+@c_uom+"' "+
                     "                   GROUP BY p.Lot, ORDERS.Facility) As P ON LOTXLOCXID.Lot = P.Lot AND LOC.Facility = P.Facility " 
                    +
                     " WHERE LOT.STORERKEY = N'"+@c_storerkey+"' "+
                     " AND LOT.SKU = N'"+@c_SKU+"' "+
                     " AND LOT.STATUS = 'OK' "+
                     " AND ID.STATUS <> 'HOLD' "+
                     " AND LOC.Status = 'OK' "+
                     " AND LOC.Facility = N'"+@c_facility+"' "+
                     " AND LOC.LocationFlag <> 'HOLD' "+
                     " AND LOC.LocationFlag <> 'DAMAGE' "+
                     " AND LOTATTRIBUTE.Lottable03 <> 'QI' "+
                     " AND LOTATTRIBUTE.Lottable03 <> 'BL' "+
                     " AND LOTATTRIBUTE.Lottable03 = 'UR' "+
                     " AND ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'') <> ''  "+
                     " AND ISDATE(SUBSTRING(LOTATTRIBUTE.Lottable01,5,4)+SUBSTRING(LOTATTRIBUTE.Lottable01,3,2)+SUBSTRING(LOTATTRIBUTE.Lottable01,1,2)) = 1 " 
                    +
                     @c_Condition
                 )    
            
            IF @b_debug=1
            BEGIN
                PRINT " SELECT LOT.STORERKEY, "+
                "        LOT.SKU, "+
                "        LOT.LOT, "+
                "        QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - ISNULL(P.QTYPREALLOCATED,0))  " 
               +
                " FROM  LOTxLOCxID (NOLOCK) "+
                "       JOIN LOT (nolock) ON LOT.LOT = LOTxLOCxID.Lot  "+
                "       JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT) " 
               +
                "       JOIN LOC (Nolock) ON LOTxLOCxID.Loc = LOC.Loc "+
                "       JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  "+
                "       JOIN SKUxLOC (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND SKUxLOC.SKU = LOTxLOCxID.SKU " 
               +
                "          AND SKUxLOC.LOC = LOTxLOCxID.LOC "+
                "       LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " 
               +
                "                   FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " 
               +
                "                   WHERE  p.Orderkey = ORDERS.Orderkey "+
                "                        AND p.UOM = N'"+@c_uom+"' "+
                "                   GROUP BY p.Lot, ORDERS.Facility) As P ON LOTXLOCXID.Lot = P.Lot AND LOC.Facility = P.Facility " 
               +
                " WHERE LOT.STORERKEY = N'"+@c_storerkey+"' "+
                " AND LOT.SKU = N'"+@c_SKU+"' "+
                " AND LOT.STATUS = 'OK' "+
                " AND ID.STATUS <> 'HOLD' "+
                " AND LOC.Status = 'OK' "+
                " AND LOC.Facility = N'"+@c_facility+"' "+
                " AND LOC.LocationFlag <> 'HOLD' "+
                " AND LOC.LocationFlag <> 'DAMAGE' "+
                " AND LOTATTRIBUTE.Lottable03 <> 'QI' "+
                " AND LOTATTRIBUTE.Lottable03 <> 'BL' "+
                " AND LOTATTRIBUTE.Lottable03 = 'UR' "+
                " AND ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'') <> ''  "+
                " AND ISDATE(SUBSTRING(LOTATTRIBUTE.Lottable01,5,4)+SUBSTRING(LOTATTRIBUTE.Lottable01,3,2)+SUBSTRING(LOTATTRIBUTE.Lottable01,1,2)) = 1 " 
               +
                @c_Condition
            END
        END
    END-- IF Storer.Minshelflife blank Don't Allocate
    ELSE
    BEGIN
        -- Dummy Cursor when storer.minshelflife is zero/blank  
        DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY 
        FOR
            SELECT LOT.STORERKEY
                  ,LOT                         .SKU
                  ,LOT                         .LOT
                  ,QTYAVAILABLE                = (
                       LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED
                   )
            FROM   LOT(NOLOCK)
            WHERE  GETDATE()>GETDATE()
            ORDER BY
                   Lot.Lot
    END
END   
  

GO