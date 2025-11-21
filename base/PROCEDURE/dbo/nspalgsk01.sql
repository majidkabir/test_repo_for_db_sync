SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALGSK01                                         */
/* Creation Date: 04-JUL-2014                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 313793-GSK PH Allocation                                    */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 27-Feb-2017  TLTING  1.1  Variable Nvarchar                          */
/************************************************************************/

CREATE PROC [dbo].[nspALGSK01] 
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(20) = ''         
AS
BEGIN
   SET NOCOUNT ON 
   
	 DECLARE @c_OrderKey        NVARCHAR(10),
	         @c_OrderLineNumber NVARCHAR(5),
           @c_OrderType       NVARCHAR(10),  
           @c_StrategyType    NVARCHAR(10)  

   SET @c_StrategyType = 'NORMAL'     
   SET @c_HostWHCode = ''          
	         	                    
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)

      SELECT @c_OrderType = ORDERS.Type, @c_HostWHCode = ORDERDETAIL.Userdefine01
      FROM   ORDERS WITH (NOLOCK)  
      JOIN   ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
      WHERE  ORDERS.OrderKey = @c_OrderKey
      AND ORDERDETAIL.OrderLineNumber = @c_OrderLineNumber

      IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'ORDERTYPE' AND Code = @c_OrderType AND Long = 'REPLEN')
      	 SET @c_StrategyType = 'REPLEN'
      ELSE
         SET @c_StrategyType = 'NORMAL'                                                        
   END   

   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK)
   JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
   JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                            AND LOTxLOCxID.Loc = SKUxLOC.Loc
   JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOC.Facility = @c_Facility
   AND LOC.Locationflag <>'HOLD'
   AND LOC.Locationflag <> 'DAMAGE'
   AND LOC.Status <> 'HOLD'
   AND ID.Status = 'OK'      
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase 
   AND LOC.HostWHCode = @c_HostWHCode
   ORDER BY CASE WHEN @c_StrategyType = 'NORMAL' AND SKUXLOC.LocationType IN ('PICK','CASE') THEN 1 
                 WHEN @c_StrategyType = 'NORMAL' AND SKUXLOC.LocationType NOT IN ('PICK','CASE') THEN 2 
                 WHEN @c_StrategyType = 'REPLEN' AND SKUXLOC.LocationType IN ('PICK','CASE') THEN 2 
                 WHEN @c_StrategyType = 'REPLEN' AND SKUXLOC.LocationType NOT IN ('PICK','CASE') THEN 1 
            END, 
            LOC.LogicalLocation, LOC.LOC   	
END

GO