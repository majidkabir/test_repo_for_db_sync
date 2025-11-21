SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALLOCE1                                         */
/* Creation Date: 12-APR-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose: Project Precision E1 Manufacturing                          */
/*          SOS#168120 Allocation Strategy                              */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspALLOCE1]
 @c_lot NVARCHAR(10) ,
 @c_uom NVARCHAR(10) ,
 @c_HostWHCode NVARCHAR(10),
 @c_Facility NVARCHAR(5),
 @n_uombase int ,
 @n_qtylefttofulfill int
AS
BEGIN
   SET NOCOUNT ON

   Declare @b_debug int
   SELECT @b_debug= 0  

   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT 
      LOTxLOCxID.LOC,  
      LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),  
      '1'  
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK)  
   WHERE LOTxLOCxID.Lot = RTRIM(@c_lot)   
   AND LOTxLOCxID.Loc = LOC.LOC  
   AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey  
   AND LOTxLOCxID.Sku = SKUxLOC.Sku  
   AND LOTxLOCxID.Loc = SKUxLOC.Loc  
   AND LOTxLOCxID.ID = ID.ID  
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
   AND LOC.Locationflag NOT IN ('HOLD', 'DAMAGE')   
   AND LOC.Facility = RTRIM(@c_Facility)  
   AND LOC.Status = 'OK'  
   AND ID.Status = 'OK'  
   ORDER BY CASE LOC.LocationCategory WHEN 'DRIVEIN' THEN 0 ELSE 1 END ASC, LOC.LOC
END

GO