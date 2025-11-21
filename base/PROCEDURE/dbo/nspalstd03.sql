SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALSTD03                                         */
/* Creation Date: 05-Aug-2002                                           */
/* Copyright: LF                                                        */
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
/* Date        Author   Rev  Purposes                                   */      
/* 14-Oct-2004 Mohit		1.0	 Change cursor type								          */
/* 18-Jul-2005 Loon			1.1	 Add Drop Object statement					      	*/
/* 11-Aug-2005 MaryVong	1.2	 Remove SET ANSI WARNINGS which caused      */
/*						    				   error in DX									          		*/
/* 26-Apr-2015 TLTING01 1.3  Add Other Parameter default value          */
/* 22-Jul-2015 NJOW01   1.4  347486 - filter by id                      */
/************************************************************************/

CREATE PROC    [dbo].[nspALSTD03]
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

   DECLARE @c_Orderkey        NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_ID              NVARCHAR(18)                                 

   IF LEN(@c_OtherParms) > 0 
   BEGIN
   	  SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
   	  SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
   	  
   	  SELECT @c_ID = ID
   	  FROM ORDERDETAIL(NOLOCK)
   	  WHERE Orderkey = @c_Orderkey
   	  AND OrderLineNumber = @c_OrderLineNumber   	  
   END
      
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),'1'
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Id = ID.ID
   AND LOC.Facility = @c_Facility
   AND LOC.Locationflag <>"HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
   AND LOC.Status <> "HOLD"
   AND ID.STATUS <> "HOLD"
   AND LOTxLOCxID.Id = CASE WHEN ISNULL(@c_ID,'') <> '' THEN @c_ID ELSE LOTxLOCxID.Id END
   ORDER BY LOC.LOC
END



GO