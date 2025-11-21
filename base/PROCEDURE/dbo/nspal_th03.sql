SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: nspAL_TH03                                          */
/* Creation Date: 31-Aug-2018                                            */
/* Copyright: LFL                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-6088 - TH SINOTH Filter by hostwhcode based on           */
/*          loadplan.Load_Userdef1 and codelkup                          */
/*                                                                       */
/* Called By: Exceed Allocate Orders                                     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author     Ver   Purposes                                */
/*************************************************************************/

CREATE PROC [dbo].[nspAL_TH03]
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

   DECLARE @c_key1             NVARCHAR(10),    
           @c_key2             NVARCHAR(5),    
           @c_key3             NCHAR(1),
           @c_Loadkey          NVARCHAR(10),
           @c_Load_Userdef1    NVARCHAR(20),
           @c_FilterHOSTWHCode NVARCHAR(10),
		       @c_Storerkey        NVARCHAR(10)    
   
   SELECT @c_FilterHOSTWHCode = 'N', @c_Load_Userdef1 = ''

   SELECT @c_Storerkey = Storerkey
   FROM LOT (NOLOCK)
   WHERE Lot = @c_Lot
           
   IF EXISTS (SELECT 1  
              FROM CODELKUP (NOLOCK)
              WHERE Listname = 'PKCODECFG'
              AND Storerkey = @c_Storerkey
              AND Code = 'FILTERHOSTWHCODE'
              AND (Code2 = @c_Facility OR ISNULL(Code2,'') = '')
              AND Long IN('nspPRFEFO1','nspAL_TH03')
              AND Short <> 'N')
   BEGIN           
      SET @c_FilterHOSTWHCode = 'Y'
   END                   
   
   IF LEN(@c_OtherParms) > 0 AND @c_FilterHOSTWHCode = 'Y'
   BEGIN   
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     
      
      IF @c_Key2 <> ''
      BEGIN
      	  SELECT @c_Loadkey = Loadkey
      	  FROM ORDERS (NOLOCK)
      	  WHERE Orderkey = @c_key1
      END 
      
      IF @c_key2 = '' AND @c_key3 = ''
      BEGIN
      	  SELECT @c_Loadkey = Loadkey
      	  FROM LOADPLAN (NOLOCK)
      	  WHERE Loadkey = @c_Key1
      END
   
      IF @c_key2 = '' AND @c_key3 = 'W'
      BEGIN
      	  SELECT TOP 1 @c_Loadkey = O.Loadkey
      	  FROM WAVEDETAIL WD (NOLOCK)
      	  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey 
      	  WHERE WD.Wavekey = @c_Key1
      END
      
      SELECT @c_Load_Userdef1 = Load_Userdef1
      FROM LOADPLAN (NOLOCK)
      WHERE Loadkey = @c_Loadkey   	    
   END

   IF @c_FilterHOSTWHCode = 'Y' AND ISNULL(@c_Load_Userdef1,'') <> ''
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.ID = ID.ID
      AND ID.Status <> "HOLD"
      AND LOC.Locationflag <> "HOLD"
      AND LOC.Locationflag <> "DAMAGE"
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
      AND LOC.Status <> "HOLD"
      AND LOC.Facility = @c_Facility
      AND LOC.HOSTWHCode = @c_Load_Userdef1
      ORDER BY LOTxLOCxID.LOC
   END
   ELSE
   BEGIN   
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.ID = ID.ID
      AND ID.Status <> "HOLD"
      AND LOC.Locationflag <> "HOLD"
      AND LOC.Locationflag <> "DAMAGE"
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
      AND LOC.Status <> "HOLD"
      AND LOC.Facility = @c_Facility
      ORDER BY LOTxLOCxID.LOC
   END
END


GO