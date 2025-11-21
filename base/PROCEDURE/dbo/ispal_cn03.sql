SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispAL_CN03                                         */
/* Creation Date: 30-Jul-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-14345 - CN IKEA - Allocation Strategy                   */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.  Purposes                                 */
/************************************************************************/
CREATE PROC [dbo].[ispAL_CN03]
   @c_LoadKey    NVARCHAR(10),   
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 DATETIME,    
   @d_Lottable05 DATETIME,  
   @c_Lottable06 NVARCHAR(30) = '',       
   @c_Lottable07 NVARCHAR(30) = '',       
   @c_Lottable08 NVARCHAR(30) = '',       
   @c_Lottable09 NVARCHAR(30) = '',       
   @c_Lottable10 NVARCHAR(30) = '',       
   @c_Lottable11 NVARCHAR(30) = '',       
   @c_Lottable12 NVARCHAR(30) = '',       
   @d_Lottable13 DATETIME,     
   @d_Lottable14 DATETIME,     
   @d_Lottable15 DATETIME,     
   @c_UOM        NVARCHAR(10),    
   @c_HostWHCode NVARCHAR(10),    
   @n_UOMBase    INT,    
   @n_QtyLeftToFulfill INT,
   @c_OtherParms NVARCHAR(200)=''
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX),
           @c_SortBy      NVARCHAR(2000)
           --@n_PickBalance INT
          
   DECLARE @c_LocationType     NVARCHAR(10),    
           @c_LocationCategory NVARCHAR(10)
  
   IF @c_UOM = '6'
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN    
   END

   DECLARE @c_key1               NVARCHAR(10),    
           @c_key2               NVARCHAR(5),    
           @c_key3               NCHAR(1),
           @c_Orderkey           NVARCHAR(10),
           @c_UDF03              NVARCHAR(60)

   IF LEN(@c_OtherParms) > 0 
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms,10)  --if call by discrete
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	    
      
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='' --call by load conso
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE O.Loadkey = @c_key1
         AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END        	     
         
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' --call by wave conso
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
         WHERE WD.Wavekey = @c_key1
         AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END        	     
                 
      SELECT @c_UDF03 = LTRIM(RTRIM(ISNULL(COL.UDF03,''))) 
      FROM BuildLoadDetailLog BLDL (NOLOCK)
      JOIN BuildLoadLog BLL (NOLOCK) ON BLL.BatchNo = BLDL.Batchno
      JOIN CODELIST COL (NOLOCK) ON COL.Listgroup = BLL.BuildParmGroup AND COL.LISTNAME = BLL.BuildParmCode
      WHERE BLDL.Loadkey = @c_key1

      IF ISNULL(@c_UDF03,'') = '' SET @c_UDF03 = ''
   
   END

   IF @c_UOM = '2'
   BEGIN
      --SET @c_SortBy = 'ORDER BY LOC.LocationGroup, LOTATTRIBUTE.Lottable04, LOC.LocLevel, LOC.LogicalLocation, LOC.Loc' 
      SET @c_SortBy = 'ORDER BY QtyAvailable, LOTATTRIBUTE.Lottable04, LOC.LogicalLocation, LOC.Loc' 
      SET @c_SQL = N'      
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOT,    
                LOTxLOCxID.LOC,     
                LOTxLOCxID.ID,    
                SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) AS QtyAvailable, ''1'' 
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOTATTRIBUTE (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)                                                     
         JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)                                                      
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)                      
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
         JOIN SKUXLOC (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKUXLOC.Storerkey AND LOTxLOCxID.Sku = SKUXLOC.Sku AND LOTxLOCxID.Loc =  SKUXLOC.Loc)
         JOIN SKU (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKU.Storerkey AND SKU.Sku =  SKUXLOC.Sku)
         JOIN STORER (NOLOCK) ON (LOTxLOCxID.Storerkey =  STORER.Storerkey)
         JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE LOTxLOCxID.Storerkey = @c_Storerkey
         AND LOTxLOCxID.Sku = @c_Sku
         AND LOC.Facility = @c_Facility  
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) >= @n_uombase 
         AND LOT.STATUS = ''OK''   
         AND LOC.STATUS = ''OK'' 
         AND ID.STATUS = ''OK''  
         AND LOC.LocationFlag = ''NONE'' 
         AND LOC.LocationType <> ''PICK'' AND LOC.LocationCategory = ''OTHER'' ' + 
         CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' + CHAR(13) END +        
         CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' + CHAR(13) END +        
         CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' + CHAR(13) END +                  
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
         CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' + CHAR(13) END +         
         CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' + CHAR(13) END + 
         CASE WHEN ISNULL(RTRIM(@c_UDF03),'') = '' THEN '' ELSE ' AND LOC.HostWHCode IN (SELECT LTRIM(RTRIM(ColValue)) FROM dbo.FNC_Delimsplit ('','',@c_UDF03)) ' + CHAR(13) END + 
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
         'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.LogicalLocation, LOC.LOC, LOC.LocationHandling, LOC.LocationType, LOC.LocationGroup, LOTATTRIBUTE.Lottable04, LOC.LocLevel ' +    
         @c_SortBy
         
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +        
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                         '@c_Lottable12 NVARCHAR(30), @c_UDF03      NVARCHAR(60), @n_uombase    INT'
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                         @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @c_UDF03, @n_uombase
   END
   ELSE IF @c_UOM = '7'
   BEGIN
      --SET @c_SortBy = 'ORDER BY CASE WHEN LOC.LocationType = ''PICK'' THEN 1 ELSE 2 END, LOC.LocationGroup, LOTATTRIBUTE.Lottable04, LOC.LocLevel, LOC.LogicalLocation, LOC.Loc' 
      SET @c_SortBy = 'ORDER BY QtyAvailable, LOTATTRIBUTE.Lottable04, LOC.LogicalLocation, LOC.Loc' 
      SET @c_SQL = N'      
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOT,    
                LOTxLOCxID.LOC,     
                LOTxLOCxID.ID,    
                SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) AS QtyAvailable, ''1'' 
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOTATTRIBUTE (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)                                                     
         JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)                                                      
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)                      
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
         JOIN SKUXLOC (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKUXLOC.Storerkey AND LOTxLOCxID.Sku = SKUXLOC.Sku AND LOTxLOCxID.Loc =  SKUXLOC.Loc)
         JOIN SKU (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKU.Storerkey AND SKU.Sku =  SKUXLOC.Sku)
         JOIN STORER (NOLOCK) ON (LOTxLOCxID.Storerkey =  STORER.Storerkey)
         JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE LOTxLOCxID.Storerkey = @c_Storerkey
         AND LOTxLOCxID.Sku = @c_Sku
         AND LOC.Facility = @c_Facility
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) >= @n_uombase 
         AND LOT.STATUS = ''OK''  
         AND LOC.STATUS = ''OK''
         AND ID.STATUS = ''OK''  
         AND LOC.LocationFlag = ''NONE''   
         AND LOC.LocationCategory = ''OTHER'' ' + 
         CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' + CHAR(13) END +        
         CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' + CHAR(13) END +        
         CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' + CHAR(13) END +                  
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
         CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' + CHAR(13) END +         
         CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' + CHAR(13) END + 
         CASE WHEN ISNULL(RTRIM(@c_UDF03),'') = '' THEN '' ELSE ' AND LOC.HostWHCode IN (SELECT LTRIM(RTRIM(ColValue)) FROM dbo.FNC_Delimsplit ('','',@c_UDF03)) ' + CHAR(13) END + 
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
         CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
         'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.LogicalLocation, LOC.LOC, LOC.LocationHandling, LOC.LocationType, LOC.LocationGroup, LOTATTRIBUTE.Lottable04, LOC.LocLevel ' +    
         @c_SortBy
      
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +        
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                         '@c_Lottable12 NVARCHAR(30), @c_UDF03      NVARCHAR(60), @n_uombase    INT'  
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                         @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @c_UDF03, @n_uombase
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      
      RETURN 
   END
     

END -- Procedure

GO