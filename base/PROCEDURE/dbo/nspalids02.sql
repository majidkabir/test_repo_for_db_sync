SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Stored Procedure: nspALIDS02                                            */      
/* Creation Date:                                                          */      
/* Copyright:                                                              */      
/* Written by:                                                             */      
/*                                                                         */      
/* Purpose:                                                                */      
/*                                                                         */      
/*                                                                         */      
/* Called By: Exceed Allocate Orders                                       */      
/*                                                                         */      
/* PVCS Version: 1.1                                                       */      
/*                                                                         */      
/* Version: 5.4                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */      
/* 26-Jun-2014  YTWan   1.1   SOS#314000 - TW - Project Echo - Exclude     */
/*                            QtyReplen from QtyAvailable (Wan01)          */
/* 11-May-2017  NJOW    1.2   WMS-1112 Skip if OD.userdefine04='MOMO'      */
/*                            (NJOW01)                                     */
/***************************************************************************/      

CREATE PROC    [dbo].[nspALIDS02]    
@c_lot NVARCHAR(10) ,    
@c_uom NVARCHAR(10) ,    
@c_HostWHCode NVARCHAR(10),    
@c_Facility NVARCHAR(5),    
@n_uombase int ,    
@n_qtylefttofulfill int,   
@c_OtherParms       NVARCHAR(200) = ''      
AS    
BEGIN     
   SET NOCOUNT ON     
        
   --NJOW01
   DECLARE @c_Orderkey NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_ODUserdefine04 NVARCHAR(18)           
           
   IF LEN(@c_OtherParms) > 0
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms ,10)
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
      
      SELECT @c_ODUserdefine04 = Userdefine04
      FROM ORDERDETAIL(NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND OrderLineNumber = @c_OrderLineNumber            
      
      IF @c_ODUserdefine04 = "MOMO"     
      BEGIN    
          DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
          SELECT TOP 0 NULL, NULL, 0, NULL    
          
          RETURN
      END
   END      
             
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY    
   FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,    
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) --(Wan01)
   , '1'    
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK)    
   WHERE LOTxLOCxID.Lot = @c_lot    
   AND LOTxLOCxID.Loc = LOC.LOC    
   AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey    
   AND LOTxLOCxID.Sku = SKUxLOC.Sku    
   AND LOTxLOCxID.Loc = SKUxLOC.Loc    
   AND LOTxLOCxID.id = ID.id    
   AND id.status = 'OK'    
   AND (SKUxLOC.Locationtype = "PICK"    
   OR   SKUxLOC.Locationtype = "CASE")    
   AND LOC.Facility = @c_Facility     
   AND LOC.Locationflag <>"HOLD"    
   AND LOC.Locationflag <> "DAMAGE"    
   AND LOC.Status <> "HOLD"    
   AND LOC.HostWhCode = @c_HostWHCode    
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN > 0)    --(Wan01)
   ORDER BY LOC.LogicalLocation, LOC.LOC    
END 

GO