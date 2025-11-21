SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nspALstdE1                                         */  
/* Copyright: IDS                                                       */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver.  Purposes                                  */  
/* 26-Mar-2020  NJOW01  1.0   WMS-12671 TW Conditional filter hostwhcode*/
/************************************************************************/

CREATE PROC    [dbo].[nspALSTDE2]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) , 
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN 
   SET NOCOUNT ON 
   
   DECLARE @c_Storerkey NVARCHAR(15)

   SELECT @c_Storerkey = Storerkey
   FROM LOT (NOLOCK)
   WHERE Lot = @c_Lot   
    
   IF (dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> '') 
   	 OR (EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
   					     WHERE CL.Storerkey = @c_Storerkey  
   					     AND CL.Code = 'NOFILTERHWCODE'  
   					     AND CL.Listname = 'PKCODECFG'  
   					     AND CL.Long = 'nspALstdE2'  
   					     AND ISNULL(CL.Short,'') = 'N'))  --NJOW01
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK) 
      WHERE LOTxLOCxID.Lot = @c_lot 
      AND LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey 
      AND LOTxLOCxID.Sku = SKUxLOC.Sku
      AND LOTxLOCxID.Loc = SKUxLOC.Loc
      AND SKUxLOC.Locationtype NOT IN ('CASE', 'PICK')
      AND LOC.Facility = @c_Facility 
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND ISNULL(LOC.HostWhCode,'') = @c_HostWHCode  
      ORDER BY SKUxLOC.QTY, LOC.LOC
   END
   ELSE
   BEGIN					        
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK) 
      WHERE LOTxLOCxID.Lot = @c_lot 
      AND LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey 
      AND LOTxLOCxID.Sku = SKUxLOC.Sku
      AND LOTxLOCxID.Loc = SKUxLOC.Loc
      AND SKUxLOC.Locationtype NOT IN ('CASE', 'PICK')
      AND LOC.Facility = @c_Facility 
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      ORDER BY SKUxLOC.QTY, LOC.LOC
   END 
END





GO