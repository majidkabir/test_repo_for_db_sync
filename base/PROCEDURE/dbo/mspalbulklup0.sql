SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: mspALBULKLUp0                                      */
/* Creation Date: 2024-05-13                                            */
/* Copyright: Maersk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* Version: V2                                                          */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */ 
/* 2024-05-20  Wan      1.0   Created.                                  */
/* 2024-07-02  Wan01    1.1   UWP-21429-Mattel Overallocation Enhancement*/
/*                            -Match LOC.HostWHCode at Allocate         */
/* 2024-07-05  Wan02    1.2   UWP-21429-Mattel Overallocation Enhancement*/
/*                            - Minus QtyReplen when find stock         */
/************************************************************************/

CREATE    PROC mspALBULKLUp0
   @c_lot               NVARCHAR(10)    
,  @c_uom               NVARCHAR(10)    
,  @c_HostWHCode        NVARCHAR(10) 
,  @c_Facility          NVARCHAR(5) 
,  @n_uombase           INT  
,  @n_qtylefttofulfill  INT
AS
BEGIN
   SET NOCOUNT ON 
  
   DECLARE @c_SQL                   NVARCHAR(MAX) = ''                              --(Wan01)-START               
         , @c_SQLParms              NVARCHAR(4000)= ''
         , @c_CLKCondition          NVARCHAR(4000)= ''
         , @c_Storerkey             NVARCHAR(15)  = ''
         , @c_Sku                   NVARCHAR(20)  = ''
         , @c_AllocateStrategykey   NVARCHAR(10)  = ''
         , @c_AllocQtyReplenFlag    NCHAR(1)      = 'N'                             --(Wan02)

   DECLARE @TMP_CODELKUP TABLE (
           [LISTNAME]      [nvarchar](10)   NOT NULL DEFAULT('') 
         , [Code]          [nvarchar](30)   NOT NULL DEFAULT('') 
         , [Description]   [nvarchar](250)  NULL 
         , [Short]         [nvarchar](10)   NULL 
         , [Long]          [nvarchar](250)  NULL 
         , [Notes]         [nvarchar](4000) NULL 
         , [Notes2]        [nvarchar](4000) NULL 
         , [Storerkey]     [nvarchar](50)   NOT NULL  DEFAULT('') 
         , [UDF01]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [UDF02]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [UDF03]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [UDF04]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [UDF05]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [code2]         [nvarchar](30)   NOT NULL  DEFAULT('')
       )

   SELECT @c_Storerkey = Storerkey
         ,@c_Sku = Sku
   FROM LOT (NOLOCK)
   WHERE Lot = @c_Lot

   SELECT @c_AllocateStrategykey = STRATEGY.AllocateStrategykey
   FROM SKU (NOLOCK)
   JOIN STRATEGY (NOLOCK) ON SKU.Strategykey = STRATEGY.Strategykey
   WHERE SKU.Storerkey = @c_Storerkey
   AND SKU.Sku = @c_Sku
   
   INSERT INTO @TMP_CODELKUP (Listname, Code, Description, Short, Long, Notes, Notes2, Storerkey, UDF01, UDF02, UDF03, UDF04, UDF05, Code2)
   SELECT CODELKUP.Listname,
          CODELKUP.Code,
          CODELKUP.Description,
          CODELKUP.Short,
          CODELKUP.Long,
          CODELKUP.Notes,
          CODELKUP.Notes2,
          CODELKUP.Storerkey,
          CODELKUP.UDF01,
          CODELKUP.UDF02,
          CODELKUP.UDF03,
          CODELKUP.UDF04,
          CODELKUP.UDF05,
          CODELKUP.Code2
   FROM CODELKUP (NOLOCK)
   WHERE CODELKUP.Listname = 'ALBULKLUp0'
   AND CODELKUP.Storerkey = CASE WHEN CODELKUP.Short = @c_AllocateStrategykey AND CODELKUP.Storerkey = '' THEN CODELKUP.Storerkey ELSE @c_Storerkey END --if setup short and no setup storer ignore storer otherwise by storer.
   AND CODELKUP.Short IN  ( CASE WHEN CODELKUP.Short NOT IN (NULL,'') THEN @c_AllocateStrategykey ELSE CODELKUP.Short END ) --if short setup must match Allocate strategykey
   AND Code2 IN (@c_UOM,'')
   AND UDF05 = 'mspALBULKLUp0' 

   SELECT TOP 1 @c_AllocQtyReplenFlag = ISNULL(UDF01,'')                            --(Wan02)-START MINUS QtyReplen If SET 'Y'  
   FROM @TMP_CODELKUP  
   WHERE Code = 'ALLOCATEQTYREPLEN' 
   AND Code2 IN (@c_UOM,'')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END                              --(Wan02)-END

   SELECT TOP 1 @c_CLKCondition = ISNULL(Notes,'')
   FROM @TMP_CODELKUP
   WHERE Code = 'CONDITION'   --retrieve addition conditions
   AND Code2 IN (@c_UOM,'')   --if defined uom in code2 only apply for the specific strategy uom
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END --consider matched uom first

   IF @c_CLKCondition <> '' AND LEFT(LTRIM(@c_CLKCondition),3) <> 'AND'
   BEGIN
      SET @c_CLKCondition = ' AND ' + RTRIM(LTRIM(@c_CLKCondition))
   END

   SET @c_SQL = N'DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR'
              + ' SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID'
              + ' ,QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED)'
              + ' ,''1'''
              + ' FROM LOTxLOCxID (NOLOCK) '
              + ' JOIN LOC (NOLOCK) ON LOC.LOC = LOTxLOCxID.Loc'
              + ' JOIN SKUxLOC (NOLOCK) ON  SKUxLOC.Storerkey = LOTxLOCxID.Storerkey'
              +                       ' AND SKUxLOC.Sku = LOTxLOCxID.Sku'
              +                       ' AND SKUxLOC.Loc = LOTxLOCxID.Loc'
              + ' JOIN LotAttribute (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.Lot'             
              + ' WHERE LOTxLOCxID.Lot = @c_lot'
              + ' AND SKUxLOC.Locationtype NOT IN (''CASE'',''PICK'')'
              + ' AND LOC.Locationflag NOT IN (''HOLD'',''DAMAGE'')'
              + ' AND LOC.Status <> ''HOLD'''
              + ' AND LOC.Facility = @c_facility'
              + ' AND LOC.LocLevel > 0'
              + CASE WHEN @c_AllocQtyReplenFlag ='Y' THEN                           --(Wan02) - START  
                ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED 
                      - LOTxLOCxID.QTYREPLEN) > 0'
                     ELSE
                ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0'
                     END                                                            --(Wan02) - END
              + ' ' + @c_CLKCondition
              + ' GROUP BY LOTxLOCxID.LOC, LOTxLOCxID.ID'
              + ' ORDER BY LOTXLOCXID.LOC'
   SET @c_SQLParms = N'@c_Lot       NVARCHAR(10)'
                   + ',@c_facility  NVARCHAR(5)'

   EXEC sp_executesql @c_SQL  
                     ,@c_SQLParms
                     ,@c_Lot
                     ,@c_facility                                                   --(Wan01)-END   
END


GO