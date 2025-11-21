SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_CH03                                         */
/* Creation Date: 03-12-2020                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15801 - [CN]_Profex_AllocStrategy_CR                    */
/*          (Refer nspAL02_01)                                          */
/*                                                                      */
/* Called By: Exceed Allocate Orders                                    */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[nspAL_CH03]
         @c_lot              NVARCHAR(10) ,
         @c_uom              NVARCHAR(10) ,
         @c_HostWHCode       NVARCHAR(10),
         @c_Facility         NVARCHAR(5),
         @n_uombase          INT ,
         @n_qtylefttofulfill INT,
         @c_OtherParms       NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON 
    
   Declare @b_debug			INT,  
           @c_LimitString  NVARCHAR(1000),
           @c_SQLStatement NVARCHAR(4000) 

   SELECT @b_debug			= 0
   SELECT @c_LimitString	= ''
   SELECT @c_SQLStatement	= ''

   -- Get OrderKey and line Number
   DECLARE @c_OrderKey		   NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_Userdefine03	   NVARCHAR(18),
           @c_Lottable02      NVARCHAR(18),
           @c_Sorting         NVARCHAR(4000)
   
   SET @c_Sorting = 'ORDER BY Loc.LogicalLocation, QTYAVAILABLE, LOC.LOC, LOTxLOCxID.ID '
   
   IF ISNULL(RTrim(@c_OtherParms), '') <> ''
   BEGIN
      SELECT @c_OrderKey = LEFT(LTrim(@c_OtherParms), 10)
      SELECT @c_OrderLineNumber = SUBSTRING(LTrim(@c_OtherParms), 11, 5)

      SELECT @c_Userdefine03 = OrderDetail.Userdefine03,
             @c_Lottable02   = ISNULL(OrderDetail.Lottable02,'') 
      FROM OrderDetail (NOLOCK)
      WHERE OrderDetail.OrderKey = @c_OrderKey
      AND OrderDetail.OrderLineNumber = @c_OrderLineNumber

      IF ISNULL(RTRIM(@c_Userdefine03),'') <> ''
      BEGIN
         SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND LOC.HOSTWHCODE= N'" + LTrim(RTrim(@c_Userdefine03)) + "'"
      END
          
      IF ISNULL(@c_Lottable02,'') = ''
      BEGIN
         SET @c_Sorting = ' ORDER BY LOTAttribute.Lottable01, Loc.LogicalLocation, QTYAVAILABLE, LOC.LOC, LOTxLOCxID.ID '
      END
   END
   
   SELECT @c_SQLStatement = " DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " + CHAR(13) +
                            " SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID, " + CHAR(13) +
                            " QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' " + CHAR(13) +
                            " FROM LOTxLOCxID (NOLOCK) " + CHAR(13) +
                            " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC" + CHAR(13) +
                            " JOIN ID (NOLOCK)  ON LOTxLOCxID.ID = ID.ID" + CHAR(13) +
                            " JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.LOT = LOTxLOCxID.LOT" + CHAR(13) +
                            " WHERE LOTxLOCxID.Lot = N'" + ISNULL(RTrim(@c_lot),'') + "'" + CHAR(13) +  
                            " AND ID.STATUS <> 'HOLD' " + CHAR(13) +
                            " AND LOC.Locationflag IN ('NONE', 'DAMAGE') " + CHAR(13) +
                            " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 " + CHAR(13) +
                            " AND LOC.Status = 'OK' " + CHAR(13) +									
                            " AND LOC.Facility = N'" + ISNULL(RTrim(@c_facility),'') + "'" + CHAR(13) + 
                            ISNULL(RTrim(@c_Limitstring),'') + CHAR(13) + 
                            ISNULL(RTrim(@c_Sorting),'')
   EXEC(@c_SQLStatement)

   IF @b_debug = 1  
   BEGIN  
      PRINT @c_SQLStatement  
   END  
END

GO