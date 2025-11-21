SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALIDS07                                         */
/* Creation Date: 07-Apr-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: AllocateStrategy : First Expired First Out               	*/
/* 			Only allocate where UOM is 7=Piece/Each (special)				*/
/*				& Lottable03 has value. 												*/
/* 			Use with Preallocate Strategy nspPRFEFO3							*/
/*                                                                      */
/* Called By: nspOrderProcessing		                                    */
/*                                                                      */
/* PVCS Version: 1.2		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 01-Aug-2008  YokeBeen  SOS#113059 - Modified new requirements for    */
/*                        allocation. - (YokeBeen01)                    */
/* 07-Aug-2008  YokeBeen  Modified for SQL2005 Compatible.              */
/* 12-Aug-2008  TLTING    Remove Some SET option                        */
/************************************************************************/

CREATE PROC [dbo].[nspALIDS07]
            @c_lot NVARCHAR(10) ,
            @c_uom NVARCHAR(10) ,
            @c_HostWHCode NVARCHAR(10),
            @c_Facility NVARCHAR(5),
            @n_uombase int ,
            @n_qtylefttofulfill int,
            @c_OtherParms NVARCHAR(200)

AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
	SET NOCOUNT ON    
   DECLARE @b_debug int
   SET @b_debug = 0 

   -- Get OrderKey and line Number
   DECLARE @c_OrderKey        NVARCHAR(10) 
         , @c_OrderLineNumber NVARCHAR(5) 
			, @c_Lottable03      NVARCHAR(18)   

   -- (YokeBeen01) - Start 
   DECLARE @c_Conditions            NVARCHAR(510) 
         , @c_SQLStatement          NVARCHAR(3999) 	   	

   SET @c_Conditions = ''  
   SET @c_SQLStatement = ''
   -- (YokeBeen01) - End 

   IF ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OtherParms)),'') <> ''
   BEGIN
      SELECT @c_OrderKey = LEFT(dbo.fnc_LTrim(@c_OtherParms), 10)
      SELECT @c_OrderLineNumber = SUBSTRING(dbo.fnc_LTrim(@c_OtherParms), 11, 5)
   END

   -- Get Lottable03 
	SET @c_Lottable03 = ''
   IF  ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderKey)),'') <> '' AND 
	    ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderLineNumber)),'') <> ''
   BEGIN
       SELECT @c_Lottable03 = ISNULL(Lottable03,'') 
       FROM   ORDERDETAIL WITH (NOLOCK)
       WHERE  OrderKey = @c_OrderKey
		 AND    OrderLineNumber = @c_OrderLineNumber
   END

   IF @b_debug = 1 
      SELECT '@c_OtherParms - ', @c_OtherParms

	SELECT @c_SQLStatement = 
          ' DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY ' +
	       ' FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
	       ' QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), ''1'' ' +
	       ' FROM LOTxLOCxID WITH (NOLOCK) ' + 
	       ' JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC) ' + 
	       ' JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND ' + 
			 ' SKUxLOC.SKU = LOTxLOCxID.SKU AND ' + 
			 ' SKUxLOC.LOC = LOTxLOCxID.LOC) ' +  
	       ' JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' +  
          ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOTxLOCxID.LOT ' +  -- (YokeBeen01)
	       ' WHERE LOTxLOCxID.Lot = N''' + ISNULL(dbo.fnc_RTrim(@c_lot),'') + '''' + 
	       ' AND ID.Status <> ''HOLD'' ' + 
	       ' AND LOC.Locationflag <> ''HOLD'' ' + 
	       ' AND LOC.Locationflag <> ''DAMAGE'' ' + 
	       ' AND LOC.Status <> ''HOLD'' ' + 
	       ' AND LOC.Facility = N''' + ISNULL(dbo.fnc_RTrim(@c_Facility),'') + '''' + 
          ' AND LOTATTRIBUTE.Lottable03 <> '''' ' +  -- (YokeBeen01)
            ISNULL(dbo.fnc_RTrim(@c_Conditions),'')  + 
	       ' ORDER BY LOTxLOCxID.LOC ' 

	EXEC(@c_SQLStatement)
END

GO