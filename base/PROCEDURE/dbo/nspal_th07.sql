SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspAL_TH07                                          */
/* Creation Date: 27-Apr-2022                                            */
/* Copyright: LFL                                                        */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-19416 - TH RMBL Allocate LOC = OVER3183 for certain      */
/*          condition (UOM2)                                             */
/*          Copy and modify from nspALIDS02                              */
/*                                                                       */
/* Called By: Exceed Allocate Orders (Discrete Only)                     */
/*                                                                       */
/* GitLab Version: 1.1                                                   */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author     Ver   Purposes                                */
/* 27-Apr-2022  WLChooi    1.0   DevOps Combine Script                   */
/* 01-Dec-2022  WLChooi    1.1   Bug Fix - Remove HostWHCode filter(WL01)*/
/*************************************************************************/

CREATE PROC [dbo].[nspAL_TH07]
   @c_lot NVARCHAR(10) ,
   @c_uom NVARCHAR(10) ,
   @c_HostWHCode NVARCHAR(10),
   @c_Facility NVARCHAR(5),
   @n_uombase INT ,
   @n_qtylefttofulfill INT,  
   @c_OtherParms NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Orderkey        NVARCHAR(10),    
           @c_OrderLineNumber NVARCHAR(5),    
           @c_Storerkey       NVARCHAR(10),
           @c_OrderType       NVARCHAR(50),
           @c_Loc             NVARCHAR(20) = 'OVER3183',
           @c_ODUserdefine04  NVARCHAR(18)           
           
   IF LEN(@c_OtherParms) > 0
   BEGIN   
      SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
      SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)  
      
      SELECT @c_OrderType = ISNULL(OH.[Type],'')
      FROM ORDERS OH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey
      
      SELECT @c_ODUserdefine04 = Userdefine04
      FROM ORDERDETAIL(NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND OrderLineNumber = @c_OrderLineNumber   

      IF @c_ODUserdefine04 = 'MOMO'    
      BEGIN    
          DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
          SELECT TOP 0 NULL, NULL, 0, NULL    
          
          RETURN
      END
   END

   IF @c_OrderType = 'SCPO' AND @c_Facility = '3181'
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,    
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN),
             '1'    
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Facility = @c_Facility     
      AND LOC.Locationflag NOT IN ('HOLD','DAMAGE')
      --AND LOC.HostWhCode = @c_HostWHCode   --WL01
      AND LOC.Loc = @c_Loc
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN > 0)
      ORDER BY LOC.LogicalLocation, LOC.LOC  
   END
   ELSE
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,    
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN),
             '1'    
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Sku = SKUxLOC.Sku 
                           AND LOTxLOCxID.Loc = SKUxLOC.Loc
                           AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
      WHERE LOTxLOCxID.Lot = @c_lot
      AND ID.[Status] = 'OK'    
      AND SKUxLOC.Locationtype IN ('PICK')    
      AND LOC.Facility = @c_Facility     
      AND LOC.Locationflag NOT IN ('HOLD','DAMAGE')
      AND LOC.[Status] <> 'HOLD'    
      --AND LOC.HostWhCode = @c_HostWHCode   --WL01 
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN > 0)
      ORDER BY LOC.LogicalLocation, LOC.LOC 
   END
END

GO