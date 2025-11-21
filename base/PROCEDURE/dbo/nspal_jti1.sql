SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: nspAL_JTI1                                            */
/* Creation Date: 12-01-2011                                               */
/* Copyright: IDS                                                          */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: If OrderDetail.MinShelfLife > 0, Take from Bulk 1st then       */
/*          only look for pick location                                    */
/*                                                                         */
/* Called By: Exceed Allocate Orders                                       */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author     Ver   Purposes                                  */
/* 27-Aug-2013  Shong      1.0   SOS#292318 Special Allocation Strategy    */
/*                               for JTI Project                           */
/* 20-Jan-2014  Shong      1.1   Changing Sorting Order                    */
/* 01-Dec-2014  Leong      1.2   SOS# 327423 - Change Loc.HostWHCode to    */
/*                                             LotAttribute.Lottable01.    */
/***************************************************************************/

CREATE PROC [dbo].[nspAL_JTI1]
     @c_LOT              NVARCHAR(10)
   , @c_UOM              NVARCHAR(10)
   , @c_HostWHCode       NVARCHAR(10)
   , @c_Facility         NVARCHAR(5)
   , @n_UOMBASE          INT
   , @n_qtylefttofulfill INT
   , @c_OtherParms       NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON

   DECLARE @b_debug          INT
         , @nMinShelfLife    INT
         , @cOrdDetUOM       NVARCHAR(10)

   SELECT @b_debug = 0

   -- Get OrderKey and line Number
   DECLARE @c_OrderKey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)

   IF ISNULL(RTRIM(@c_OtherParms),'') <> ''
   BEGIN
      SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)
      SELECT @c_OrderLineNumber = SUBSTRING(LTRIM(@c_OtherParms), 11, 5)

      SET @nMinShelfLife = 0
      SET @cOrdDetUOM = ''

      SELECT @cOrdDetUOM = ISNULL(UOM,'')
      FROM OrderDetail (NOLOCK)
      WHERE OrderKey = @c_OrderKey
      AND OrderLineNumber = @c_OrderLineNumber
   END

   IF RTrim(@c_HostWHCode) IS NOT NULL AND RTrim(@c_HostWHCode) <> ''
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
             --QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
             QTYAVAILABLE = CASE
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -
                                (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE
                            THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)
                              - (LOTXLOCXID.QTYPICKED)  )
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -
                                (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0
                     THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)
                              - (LOTXLOCXID.QTYPICKED)  )
                  ELSE
                     ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )
                     -  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %
                     @n_UOMBASE
                 END
           , 1
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN SKUxLOC (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND
                             LOTxLOCxID.SKU = SKUxLOC.SKU AND
                             LOTxLOCxID.Loc = SKUxLOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOTATTRIBUTE (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot -- SOS# 327423
                                 AND LOTxLOCxID.StorerKey = LOTATTRIBUTE.StorerKey
                                 AND LOTxLOCxID.Sku = LOTATTRIBUTE.Sku)
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Locationflag <> 'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND LOC.Facility = @c_Facility
      AND ID.STATUS <> 'HOLD'
      AND 1 = CASE WHEN @cOrdDetUOM = 'CAR' AND SKUxLOC.LocationType NOT IN ('CASE','PICK') THEN 2
                   ELSE 1
              END
      --AND LOC.HostWhCode = @c_HostWHCode
      AND LOTATTRIBUTE.Lottable01 = @c_HostWHCode -- SOS# 327423
      AND CASE
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -
                                (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE
                            THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)
                              - (LOTXLOCXID.QTYPICKED)  )
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -
                                (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0
                     THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)
                              - (LOTXLOCXID.QTYPICKED)  )
                  ELSE
                     ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )
                     -  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %
                     @n_UOMBASE
                 END > 0
      ORDER BY
         CASE WHEN @c_UOM = '1' AND SKUxLOC.LocationType NOT IN ('CASE','PICK') THEN 1 ELSE 5 END,
         LOC.LogicalLocation,
         LOC.LOC
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
      --QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED)
             QTYAVAILABLE = CASE
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -
                                (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE
                            THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)
                              - (LOTXLOCXID.QTYPICKED)  )
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -
                                (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0
                     THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)
                              - (LOTXLOCXID.QTYPICKED)  )
                  ELSE
                     ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )
                     -  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %
                     @n_UOMBASE
                 END

      , '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN SKUxLOC (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND
                             LOTxLOCxID.SKU = SKUxLOC.SKU AND
                             LOTxLOCxID.Loc = SKUxLOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Locationflag <> 'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND LOC.Facility = @c_Facility
      AND ID.STATUS <> 'HOLD'
      AND 1 = CASE WHEN @cOrdDetUOM = 'CAR' AND SKUxLOC.LocationType NOT IN ('CASE','PICK') THEN 2
                   ELSE 1
              END
            AND CASE
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -
                                (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE
                            THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)
                              - (LOTXLOCXID.QTYPICKED)  )
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -
                                (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0
                     THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)
                              - (LOTXLOCXID.QTYPICKED)  )
                  ELSE
                     ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )
                     -  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %
                     @n_UOMBASE
                 END > 0
      ORDER BY
         CASE WHEN @c_UOM = '1' AND SKUxLOC.LocationType NOT IN ('CASE','PICK') THEN 1 ELSE 5 END,
         LOC.LogicalLocation,
         LOC.LOC
   END
END

GO