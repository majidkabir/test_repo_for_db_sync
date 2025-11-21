SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspAL_XD01                                         */
/* Creation Date: 10-Jul-2013                                           */
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
/* Date         Author        Purposes                                  */
/* 08-Jul-2013  Shong    1.0  SOS# 283166 - Change to suit NIKESG XDOCK */
/* 13-SEP-2018  NJOW01   1.1  WMS-6255 Include the ID checking only     */
/*                            for XDOCK orders                          */
/* 23-JUL-2020  WLChooi  1.2  WMS-13929 - Allow allocation for <> XDOCK */
/*                            (WL01)                                    */
/* 16-Jun-2021  WLChooi  1.3  WMS-17302 - Modify Sorting (WL02)         */
/************************************************************************/

CREATE PROC [dbo].[nspAL_XD01]  -- rename from IDSTW:nspALIDS02
   @c_lot              NVARCHAR(10),
   @c_uom              NVARCHAR(10),
   @c_HostWHCode       NVARCHAR(10),
   @c_Facility         NVARCHAR(5),
   @n_uombase          INT,
   @n_qtylefttofulfill INT,
   @c_OtherParms       NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON

    DECLARE @c_OrderKey            NVARCHAR(10)
           ,@c_OrderLineNumber     NVARCHAR(5)
           ,@c_ID                  NVARCHAR(18)
           ,@c_OrderType           NVARCHAR(10) --NJOW01

    IF ISNULL(RTRIM(@c_OtherParms) ,'') <> ''
    BEGIN
       SET @c_OrderKey = SUBSTRING(RTRIM(@c_OtherParms), 1, 10)
       SET @c_OrderLineNumber = SUBSTRING(RTRIM(@c_OtherParms), 11, 5)

       --NJOW01
       SELECT @c_OrderType = Type
       FROM ORDERS (NOLOCK)
       WHERE Orderkey = @c_Orderkey            
    END


    IF ISNULL(RTRIM(@c_OrderKey), '') <> '' AND ISNULL(RTRIM(@c_OrderLineNumber), '') <> ''
    BEGIN
       SET @c_ID = ''

       IF @c_OrderType = 'XDOCK'  --NJOW01
       BEGIN
          SELECT @c_ID = ISNULL(RTRIM(OD.UserDefine01),'') + ISNULL(RTRIM(OD.UserDefine02),'') -- SOS#283166
          FROM   OrderDetail OD WITH (NOLOCK)
          WHERE  OD.OrderKey = @c_OrderKey
          AND    OD.OrderLineNumber = @c_OrderLineNumber
       END
    END

   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
          QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '6' Type
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
   AND LOTxLOCxID.Sku = SKUxLOC.Sku
   AND LOTxLOCxID.Loc = SKUxLOC.Loc
   AND LOTXLOCXID.ID = ID.ID
   AND ID.Status <> 'HOLD'
   AND LOC.Locationflag <>'HOLD'
   AND LOC.Locationflag <> 'DAMAGE'
   AND LOC.Status <> 'HOLD'
   AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
   AND LOC.Facility = @c_Facility
   AND LOTxLOCxID.Id = CASE WHEN ISNULL(@c_ID,'') = '' THEN LOTxLOCxID.Id ELSE @c_ID END   --WL01
   ORDER BY Type, LOC.LogicalLocation, LOTxLOCxID.LOC   --WL02
END

GO