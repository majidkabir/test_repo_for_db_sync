SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspAL_TH08                                          */
/* Creation Date: 27-Apr-2022                                            */
/* Copyright: LFL                                                        */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-19416 - TH RMBL Allocate LOC = OVER3183 for certain      */
/*          condition (UOM1 & UOM 3 & UOM4 & UOM5)                       */
/*          Combine nspALIDS01, nspALSTD01, nspALSTD03, nspALSTD04       */
/*                                                                       */
/* Called By: Exceed Allocate Orders (Discrete Only)                     */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author     Ver   Purposes                                */
/* 27-Apr-2022  WLChooi    1.0   DevOps Combine Script                   */
/*************************************************************************/

CREATE PROC [dbo].[nspAL_TH08]
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
           @c_ID              NVARCHAR(20)
   
   IF LEN(@c_OtherParms) > 0
   BEGIN   
      SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
      SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)  
      
      SELECT @c_OrderType = ISNULL(OH.[Type],'')
      FROM ORDERS OH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey

      SELECT @c_ID = ID
      FROM ORDERDETAIL(NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND OrderLineNumber = @c_OrderLineNumber   
   END

   IF @c_OrderType = 'SCPO' AND @c_Facility = '3181'
   BEGIN
      IF @c_uom = '3'
      BEGIN
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,    
                QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),
                '1'    
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
         WHERE LOTxLOCxID.Lot = @c_lot   
         AND LOC.Facility = @c_Facility     
         AND LOC.Locationflag NOT IN ('HOLD','DAMAGE')
         AND LOC.Loc = @c_Loc
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
         AND LOTxLOCxID.Id = CASE WHEN ISNULL(@c_ID,'') <> '' THEN @c_ID ELSE LOTxLOCxID.Id END
         ORDER BY LOC.LOC  
      END
      ELSE
      BEGIN
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,    
                QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),
                '1'    
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
         JOIN LOT (NOLOCK) ON LOT.Lot = LOTxLOCxID.Lot
         WHERE LOTxLOCxID.Lot = @c_lot  
         AND LOC.Facility = @c_Facility     
         AND LOC.Locationflag NOT IN ('HOLD','DAMAGE')
         AND LOC.Loc = @c_Loc 
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
         ORDER BY LOC.LOC  
      END
   END
   ELSE
   BEGIN
      IF @c_uom = '3'
      BEGIN
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,    
                QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),
                '1'    
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
         JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Sku = SKUxLOC.Sku 
                           AND LOTxLOCxID.Loc = SKUxLOC.Loc
                           AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
         WHERE LOTxLOCxID.Lot = @c_lot
         AND ID.[Status] = 'OK'      
         AND LOC.Facility = @c_Facility     
         AND LOC.Locationflag NOT IN ('HOLD','DAMAGE')
         AND LOC.[Status] <> 'HOLD' 
         AND SKUxLOC.Locationtype IN ('PICK') 
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
         AND LOTxLOCxID.Id = CASE WHEN ISNULL(@c_ID,'') <> '' THEN @c_ID ELSE LOTxLOCxID.Id END
         ORDER BY LOC.LOC  
      END
      ELSE IF @c_uom = '1'
      BEGIN
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,    
                QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),
                '1'    
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
         JOIN LOT (NOLOCK) ON LOT.Lot = LOTxLOCxID.Lot
         WHERE LOTxLOCxID.Lot = @c_lot
         AND ID.[Status] = 'OK'      
         AND LOC.Facility = @c_Facility     
         AND LOC.Locationflag NOT IN ('HOLD','DAMAGE')
         AND LOC.[Status] <> 'HOLD'    
         AND LOT.[Status] <> 'HOLD'   
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
         ORDER BY LOC.LOC  
      END
      ELSE   --UOM 2
      BEGIN
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,    
                QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),
                '1'    
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
         JOIN LOT (NOLOCK) ON LOT.Lot = LOTxLOCxID.Lot
         JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Sku = SKUxLOC.Sku 
                           AND LOTxLOCxID.Loc = SKUxLOC.Loc
                           AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
         WHERE LOTxLOCxID.Lot = @c_lot
         AND ID.[Status] = 'OK'      
         AND LOC.Facility = @c_Facility     
         AND LOC.Locationflag NOT IN ('HOLD','DAMAGE')
         AND LOC.[Status] <> 'HOLD'    
         AND LOT.[Status] <> 'HOLD'   
         AND SKUxLOC.Locationtype IN ('PICK') 
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
         ORDER BY LOC.LOC  
      END 
   END
END

GO