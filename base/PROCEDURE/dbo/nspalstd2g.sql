SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: nspALSTD2G                                            */  
/* Creation Date: 19-11-2008                                               */  
/* Copyright: IDS                                                          */  
/* Written by: Vanessa                                                     */  
/*                                                                         */  
/* Purpose: New Allocation Strategy for GOLD SOS117139                     */  
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
/* Date         Author     Ver   Purposes                                  */  
/* 30-Nov-2010  Leong      1.1   SOS# 198259 - Include ID.Status <> 'HOLD' */  
/* 13-Jul-2010  SHONG01    1.2   SOS220901 Allocation Strategy requirement */
/*                               for Unilever U2K2 Cut-Over                */
/***************************************************************************/  
  
CREATE PROC [dbo].[nspALSTD2G]  
     @c_lot              NVARCHAR(10)  
   , @c_uom              NVARCHAR(10)  
   , @c_HostWHCode       NVARCHAR(10)  
   , @c_Facility         NVARCHAR(5)  
   , @n_uombase          Int  
   , @n_qtylefttofulfill Int  
   , @c_OtherParms       NVARCHAR(200)  
AS  
BEGIN  
   SET NOCOUNT ON  
  
   DECLARE @b_debug          Int  
         , @c_ord_lottable03 NVARCHAR(18)  
         -- SHONG01  
         ,@c_OrderType  NVARCHAR(10) 
         ,@c_FilterZone NVARCHAR(200)  
  
   SELECT @b_debug = 0  
  
   -- Get OrderKey and line Number  
   DECLARE @c_OrderKey        NVARCHAR(10)  
         , @c_OrderLineNumber NVARCHAR(5)  
  
   IF ISNULL(RTRIM(@c_OtherParms),'') <> ''  
   BEGIN  
      SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)  
      SELECT @c_OrderLineNumber = SUBSTRING(LTRIM(@c_OtherParms), 11, 5)  
  
      SELECT @c_ord_lottable03 = Lottable03  
      FROM OrderDetail (NOLOCK)  
      WHERE OrderKey = @c_OrderKey  
      AND OrderLineNumber = @c_OrderLineNumber  

       IF ISNULL(RTrim(@c_OrderKey),'') <> ''  
       BEGIN  
          -- SHONG01
          SELECT @c_OrderType = ORDERS.Type   
          FROM   ORDERS (NOLOCK)
          WHERE ORDERS.OrderKey = @c_OrderKey

          SET @c_FilterZone = ''

          IF EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP' AND Code = @c_OrderType)
          BEGIN
             SET @c_FilterZone = @c_OrderType
          END
          -- SHONG01
       END 
   END  
  
   IF ISNULL(RTRIM(@c_ord_lottable03),'') = 'GOLD'  
   BEGIN  
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK) -- SOS# 198259  
      WHERE LOTxLOCxID.Lot = @c_lot  
      AND LOTxLOCxID.ID = ID.ID -- SOS# 198259  
      AND ID.Status <> 'HOLD'   -- SOS# 198259  
      AND LOTxLOCxID.Loc = LOC.LOC  
      AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey  
      AND LOTxLOCxID.Sku = SKUxLOC.Sku  
      AND LOTxLOCxID.Loc = SKUxLOC.Loc  
      AND SKUxLOC.Locationtype = 'CASE'  
      AND LOC.Facility = @c_Facility  
      AND LOC.Locationflag <>'HOLD'  
      AND LOC.Locationflag <> 'DAMAGE'  
      AND LOC.Status <> 'HOLD'  
      AND LOC.PutAwayZone NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') -- SHONG01 
      ORDER BY CASE LOC.Putawayzone WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.LOC  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
         FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK) -- SOS# 198259  
         WHERE LOTxLOCxID.Lot = @c_lot  
         AND LOTxLOCxID.ID = ID.ID -- SOS# 198259  
         AND ID.Status <> 'HOLD'   -- SOS# 198259  
         AND LOTxLOCxID.Loc = LOC.LOC  
         AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey  
         AND LOTxLOCxID.Sku = SKUxLOC.Sku  
         AND LOTxLOCxID.Loc = SKUxLOC.Loc  
         AND SKUxLOC.Locationtype = 'CASE'  
         AND LOC.Facility = @c_Facility  
         AND LOC.Locationflag <>'HOLD'  
         AND LOC.Locationflag <> 'DAMAGE'  
         AND LOC.Status <> 'HOLD'  
         AND LOC.PutAwayZone NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') -- SHONG01 
         ORDER BY CASE LOC.Putawayzone WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.LOC  
      END  
   END  
   ELSE
   IF ISNULL(RTRIM(@c_FilterZone),'') <> ''  
   BEGIN  
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK) -- SOS# 198259  
      WHERE LOTxLOCxID.Lot = @c_lot  
      AND LOTxLOCxID.ID = ID.ID -- SOS# 198259  
      AND ID.Status <> 'HOLD'   -- SOS# 198259  
      AND LOTxLOCxID.Loc = LOC.LOC  
      AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey  
      AND LOTxLOCxID.Sku = SKUxLOC.Sku  
      AND LOTxLOCxID.Loc = SKUxLOC.Loc  
      AND SKUxLOC.Locationtype = 'CASE'  
      AND LOC.Facility = @c_Facility  
      AND LOC.Locationflag <>'HOLD'  
      AND LOC.Locationflag <> 'DAMAGE'  
      AND LOC.Status <> 'HOLD'  
      AND LOC.Putawayzone = @c_FilterZone 
      ORDER BY CASE LOC.Putawayzone WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.LOC  
   END
   ELSE  
   BEGIN  
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK) -- SOS# 198259  
      WHERE LOTxLOCxID.Lot = @c_lot  
      AND LOTxLOCxID.ID = ID.ID -- SOS# 198259  
      AND ID.Status <> 'HOLD'   -- SOS# 198259  
      AND LOTxLOCxID.Loc = LOC.LOC  
      AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey  
      AND LOTxLOCxID.Sku = SKUxLOC.Sku  
      AND LOTxLOCxID.Loc = SKUxLOC.Loc  
      AND SKUxLOC.Locationtype = 'CASE'  
      AND LOC.Facility = @c_Facility  
      AND LOC.Locationflag <>'HOLD'  
      AND LOC.Locationflag <> 'DAMAGE'  
      AND LOC.Status <> 'HOLD'  
      AND LOC.Putawayzone <> 'GOLD'  
      AND LOC.PutAwayZone NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') -- SHONG01 
      ORDER BY CASE LOC.Putawayzone WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.LOC  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
         FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK) -- SOS# 198259  
         WHERE LOTxLOCxID.Lot = @c_lot  
         AND LOTxLOCxID.ID = ID.ID -- SOS# 198259  
         AND ID.Status <> 'HOLD'   -- SOS# 198259  
         AND LOTxLOCxID.Loc = LOC.LOC  
         AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey  
         AND LOTxLOCxID.Sku = SKUxLOC.Sku  
         AND LOTxLOCxID.Loc = SKUxLOC.Loc  
         AND SKUxLOC.Locationtype = 'CASE'  
         AND LOC.Facility = @c_Facility  
         AND LOC.Locationflag <>'HOLD'  
         AND LOC.Locationflag <> 'DAMAGE'  
         AND LOC.Status <> 'HOLD'  
         AND LOC.Putawayzone <> 'GOLD'  
         AND LOC.PutAwayZone NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') -- SHONG01 
         ORDER BY CASE LOC.Putawayzone WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.LOC  
      END  
   END  
END

GO