SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspAL02_01                                         */
/* Creation Date: 23-07-2010                                            */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose: New Allocation Strategy for E1 CN SOS181973                 */
/*          (Refered nspAL02_02)                                        */
/*                                                                      */
/* Called By: Exceed Allocate Orders                                    */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 31-Mac-2011  AQSKC     1.4 CR - Order allocation by logicallocation  */
/*                            (Kc01)                                    */
/* 20-Apr-2012  SPChin    1.5 SOS242181 - Bug Fixed - Add filter by ID  */
/* 26-Mar-2013  TLTING01  1.6 Add Other Parameter default value         */ 
/************************************************************************/

CREATE PROC    [dbo].[nspAL02_01]
         @c_lot NVARCHAR(10) ,
         @c_uom NVARCHAR(10) ,
         @c_HostWHCode NVARCHAR(10),
         @c_Facility NVARCHAR(5),
         @n_uombase int ,
         @n_qtylefttofulfill int,
			@c_OtherParms NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON 
    
   Declare @b_debug			int,  
			  @c_LimitString  nvarchar(1000),
			  @c_SQLStatement nvarchar(4000) 

   SELECT @b_debug			= 0
	SELECT @c_LimitString	= ''
	SELECT @c_SQLStatement	= ''

	-- Get OrderKey and line Number
	DECLARE @c_OrderKey		 NVARCHAR(10),
			  @c_OrderLineNumber NVARCHAR(5),
           @c_Userdefine03	 NVARCHAR(18)

	IF ISNULL(RTrim(@c_OtherParms), '') <> ''
	BEGIN
		SELECT @c_OrderKey = LEFT(LTrim(@c_OtherParms), 10)
		SELECT @c_OrderLineNumber = SUBSTRING(LTrim(@c_OtherParms), 11, 5)

		SELECT @c_Userdefine03 = Userdefine03 
		FROM OrderDetail (NOLOCK)
		WHERE OrderKey = @c_OrderKey
		AND OrderLineNumber = @c_OrderLineNumber

		IF ISNULL(RTRIM(@c_Userdefine03),'') <> ''
		BEGIN
			SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND LOC.HOSTWHCODE= N'" + LTrim(RTrim(@c_Userdefine03)) + "'"
		END
	END
   
	SELECT @c_SQLStatement = " DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
									 " SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID, " +
									 " QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' " +
									 " FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK) " + 
									 " WHERE LOTxLOCxID.Lot = N'" + ISNULL(RTrim(@c_lot),'') + "'" +  
									 " AND LOTxLOCxID.Loc = LOC.LOC " +
									 " AND LOTxLOCxID.ID = ID.ID " +
									 " AND ID.STATUS <> 'HOLD' " +  --SOS242181
									 " AND LOC.Locationflag IN ('NONE', 'DAMAGE') " +
									 " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 " + 
									 " AND LOC.Status = 'OK' " +									
									 " AND LOC.Facility = N'" + ISNULL(RTrim(@c_facility),'') + "'" +  
									 ISNULL(RTrim(@c_Limitstring),'') + 
									 " ORDER BY Loc.LogicalLocation, QTYAVAILABLE, LOC.LOC, LOTxLOCxID.ID "       --(Kc01)
	EXEC(@c_SQLStatement)

	IF @b_debug = 1  
	BEGIN  
		SELECT '@c_SQLStatement' = @c_SQLStatement  
	END  
END

GO