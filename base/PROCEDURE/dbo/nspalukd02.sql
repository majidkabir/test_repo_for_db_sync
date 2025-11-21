SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspALUKD02                                         */    
/* Creation Date: 28-Jun-2010                                           */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.5                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author  Ver   Purposes                                   */    
/* 28-Jun-2010 Shong   1.0   For IDSUK Diana Project                    */    
/*                           Should Filter By QtyReplen                 */ 
/*                           Pick From Loc.LocationType = 'PICK'        */   
/* 29-Sep-2015 NJOW01  1.1   345748 - Skip if not ecom order            */  
/************************************************************************/    
    
CREATE PROC [dbo].[nspALUKD02]    
@c_lot NVARCHAR(10) ,    
@c_uom NVARCHAR(10) ,    
@c_HostWHCode NVARCHAR(10),    
@c_Facility NVARCHAR(5),    
@n_uombase INT ,    
@n_qtylefttofulfill INT,
@c_OtherParms NVARCHAR(200)=''               
AS    
BEGIN    
    SET NOCOUNT ON     

    --NJOW01 Start
    DECLARE @c_OrderKey                  NVARCHAR(10)        
           ,@c_OrderType                 NVARCHAR(10)      
           ,@c_Storerkey                 NVARCHAR(15)
           ,@c_LoadKey                   NVARCHAR(10)      
           ,@c_LoadConsoAllocationOParms NVARCHAR(10)
           ,@b_Success                   INT   
           ,@n_err                       INT  
           ,@c_errmsg                    NVARCHAR(250)               
           
    SELECT @c_Storerkey = Storerkey
    FROM LOT (NOLOCK)
    WHERE Lot = @c_Lot                   
    
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
       SELECT @c_OrderType = CASE WHEN (ISNULL(ORDERS.UserDefine01,'') <> '') THEN 'ECOM' ELSE 'STORE' END,     
              @c_LoadKey = LoadKey  
       FROM   ORDERS WITH (NOLOCK)              
       WHERE  OrderKey = @c_OrderKey              
    END             
             
    IF @c_OrderType<>'ECOM'        
    BEGIN      
       DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR              
       SELECT LOTXLOCXID.Loc,
              LOTXLOCXID.ID,
              QTYAVAILABLE = 0,
              '1'
       FROM LOTXLOCXID (NOLOCK)            
       WHERE 1=2            
                   
       RETURN                   	
    END        
    --NJOW01 End
            
    DECLARE CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY     
    FOR    
        SELECT LOTxLOCxID.LOC    
              ,LOTxLOCxID.ID    
              ,QTYAVAILABLE    = (    
                   LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED -   
                     (CASE WHEN LOTxLOCxID.QtyReplen < 0 THEN 0 ELSE LOTxLOCxID.QtyReplen END)    
               )    
              ,'1'    
        FROM   LOTxLOCxID (NOLOCK)    
        JOIN   LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC     
        JOIN   ID  (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
        JOIN   SKUxLOC (NOLOCK) ON LOTxLOCxID.StorerKey = SKUxLOC.StorerKey  
                        AND LOTxLOCxID.Sku = SKUxLOC.Sku 
                        AND LOTxLOCxID.Loc = SKUxLOC.Loc    
        JOIN   LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT    
        WHERE  LOTxLOCxID.Lot = @c_lot    
         AND ID.Status<>'HOLD'    
         AND LOC.Facility = @c_Facility    
         AND LOC.Locationflag<>'HOLD'    
         AND LOC.Locationflag<>'DAMAGE'    
         AND ( LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED -   
                (CASE WHEN LOTxLOCxID.QtyReplen < 0 THEN 0 ELSE LOTxLOCxID.QtyReplen END)) >= @n_uombase    
         AND LOC.Status<>'HOLD'    
         AND LOT.STATUS<>'HOLD'      
         AND LOC.LocationType IN ('PICK' ,'CASE')    
         AND SKUxLOC.LocationType NOT IN ('PICK' ,'CASE') 
         AND LOC.LocationType NOT IN ('DynPickP', 'DYNPICKR')   
        ORDER BY LOC.LogicalLocation, LOC.LOC                       
END


GO