SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALSTD07                                         */
/* Creation Date: 29-Nov-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: Created based on nspALSTD06 for WTC Indent Process.         */
/*          To allocate stocks with LOC.LocationCategory <> 'SELECTIVE' */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 26-Apr-2015  TLTING01 1.1  Add Other Parameter default value         */ 
/*																								*/
/************************************************************************/

CREATE PROC [dbo].[nspALSTD07]
       @c_lot NVARCHAR(10) ,
       @c_uom NVARCHAR(10) ,
       @c_HostWHCode NVARCHAR(10),
       @c_Facility NVARCHAR(5),
       @n_uombase int ,
       @n_qtylefttofulfill int,
       @c_OtherParms       NVARCHAR(200) = ''    
AS
BEGIN
   SET NOCOUNT ON 
    
   

   DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT LOTxLOCxID.LOC,  
          LOTxLOCxID.ID, 
          QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK)  
   JOIN LOC (NOLOCK) ON ( LOTxLOCxID.Loc = LOC.LOC AND LOC.Locationflag <> 'HOLD' AND 
                          LOC.Locationflag <> 'DAMAGE' AND LOC.Status <> 'HOLD' AND 
                          LOC.LocationCategory <> 'SELECTIVE' ) 
   JOIN SKUxLOC (NOLOCK) ON ( LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku AND 
                              LOTxLOCxID.Loc = SKUxLOC.Loc AND SKUxLOC.Locationtype ='PICK' ) 
   WHERE LOTxLOCxID.Lot = @c_lot 
   AND LOC.Facility = @c_Facility 
   ORDER BY  LOC.LogicalLocation, LOC.LOC 
END

GO