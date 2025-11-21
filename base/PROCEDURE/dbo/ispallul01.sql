SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispALLul01                                         */
/* Creation Date: 21-AUG-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-HK CPI - Lululemon - Transfer Allocation                */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC  [dbo].[ispALLul01]
      @c_lot               NVARCHAR(10)
    , @c_Facility          NVARCHAR(5)  
    , @c_storerkey         NVARCHAR(15) 
    , @c_sku               NVARCHAR(20) 
    , @c_lottable01        NVARCHAR(18)   
    , @c_lottable02        NVARCHAR(18)    
    , @c_lottable03        NVARCHAR(18)   
    , @d_lottable04        DATETIME
    , @d_lottable05        DATETIME 
    , @c_lottable06        NVARCHAR(30)   
    , @c_lottable07        NVARCHAR(30)  
    , @c_lottable08        NVARCHAR(30)  
    , @c_lottable09        NVARCHAR(30) 
    , @c_lottable10        NVARCHAR(30)  
    , @c_lottable11        NVARCHAR(30)  
    , @c_lottable12        NVARCHAR(30)  
    , @d_lottable13        DATETIME   
    , @d_lottable14        DATETIME       
    , @d_lottable15        DATETIME  
    , @c_uom               NVARCHAR(10) 
    , @c_HostWHCode        NVARCHAR(10) 
    , @n_uombase           INT 
    , @n_qtylefttofulfill  INT
    , @c_OtherParms        NVARCHAR(200)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_CallSource   CHAR(1)

   SET @c_CallSource = ''

   IF  LEN(@c_OtherParms) >=  16
   BEGIN
      SET @c_CallSource = SUBSTRING(@c_OtherParms,16,1)
   END

   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.Lot, LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID   WITH (NOLOCK)
   JOIN LOT          WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
   JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
   JOIN ID           WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)
   JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot = LOTATTRIBUTE.Lot)
   JOIN CODELKUP     WITH (NOLOCK) ON (CODELKUP.ListName = 'LUTRFALLOC')
                                   AND(CODELKUP.Code = LOC.LocationCategory)
   WHERE LOTxLOCxID.Storerkey = @c_Storerkey 
   AND LOTxLOCxID.Sku = @c_Sku
   AND LOTATTRIBUTE.Lottable02 = @c_lottable02
   AND LOT.Status <> 'HOLD'
   AND ID.Status <> 'HOLD'
   AND LOC.Facility = @c_Facility
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0
   AND @c_CallSource = 'T'
   ORDER BY LOTATTRIBUTE.Lottable05
END

 

GO