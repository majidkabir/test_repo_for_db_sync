SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/            
/* Stored Procedure: ispAL_CN09                                          */            
/* Creation Date: 15-Aug-2022                                            */            
/* Copyright: LFL                                                        */            
/* Written by: WLChooi                                                   */            
/*                                                                       */            
/* Purpose: WMS-20519 - [CN] Yonex_B2B_Allocation                        */            
/*          For UOM 2, 6 & 7                                             */
/*                                                                       */            
/* Called By:                                                            */            
/*                                                                       */            
/* GitLab Version: 1.0                                                   */            
/*                                                                       */            
/* Version: 7.0                                                          */            
/*                                                                       */            
/* Data Modifications:                                                   */            
/*                                                                       */            
/* Updates:                                                              */            
/* Date         Author  Ver.  Purposes                                   */   
/* 15-Aug-2022  WLChooi 1.0   DevOps Combine Script                      */
/*************************************************************************/            
CREATE PROC [dbo].[ispAL_CN09]
   @c_DocNo      NVARCHAR(10),  
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 DATETIME,    
   @d_Lottable05 DATETIME,    
   @c_Lottable06 NVARCHAR(30),    
   @c_Lottable07 NVARCHAR(30),    
   @c_Lottable08 NVARCHAR(30),    
   @c_Lottable09 NVARCHAR(30),    
   @c_Lottable10 NVARCHAR(30),    
   @c_Lottable11 NVARCHAR(30),    
   @c_Lottable12 NVARCHAR(30),    
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
   DECLARE @c_Condition          NVARCHAR(MAX),
           @c_SQL                NVARCHAR(MAX),
           @c_OrderBy            NVARCHAR(1000), 
           @n_QtyToTake          INT,
           @n_QtyAvailable       INT,
           @c_Lot                NVARCHAR(10),
           @c_Loc                NVARCHAR(10), 
           @c_ID                 NVARCHAR(18),
           @c_UCCQty             INT,
           @n_PackQty            INT,
           @c_OtherValue         NVARCHAR(20),
           @n_UCCQty             INT,
           @c_Wavekey            NVARCHAR(10),
           @c_key1               NVARCHAR(10),    
           @c_key2               NVARCHAR(5),  
           @c_key3               NCHAR(1),
           @c_WaveType           NVARCHAR(18),
           @n_LotQty             INT,
           @c_UserDefine01       NVARCHAR(50) = '',
           @c_Strategykey        NVARCHAR(50) = '',
           @n_Count              INT,
           @n_QtyLocationMin     INT,
           @c_LocationType       NVARCHAR(10)
                        
   EXEC isp_Init_Allocate_Candidates      
          
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0)
   )       
                               
   IF ISNULL(RTRIM(@c_OtherParms) ,'')<>''          
   BEGIN        
      SET @c_WaveKey = LEFT(@c_OtherParms,10) 
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber              
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave             
      
      IF ISNULL(@c_key2,'') = '' AND ISNULL(@c_key3,'') = '' 
      BEGIN
          SET @c_Wavekey = ''
          SELECT TOP 1 @c_Wavekey = O.Userdefine09
          FROM ORDERS O (NOLOCK) 
          JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
          WHERE O.Loadkey = @c_key1
          AND OD.Sku = @c_SKU
          ORDER BY O.Userdefine09
      END 
       
      IF ISNULL(@c_key2,'') <> ''
      BEGIN
         SELECT TOP 1 @c_Wavekey = O.Userdefine09
         FROM ORDERS O (NOLOCK)
         WHERE O.Orderkey = @c_Key1
      END                      
   END        

   SET @c_OrderBy = ' ORDER BY LOTATTRIBUTE.Lottable05, LOC.LogicalLocation, LOC.Loc, QtyAvailable DESC '

   IF @n_UOMBase = 0
      SET @n_UOMBase = 1

   --Check if overallocation
   --IF @c_UOM = '7'
   --BEGIN
   --   SET @c_SQL = ' SELECT @n_Count = COUNT(1) ' +
   --                ' FROM LOTATTRIBUTE (NOLOCK) ' +
   --                ' JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT ' +
   --                ' JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' + 
   --                ' JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc ' +
   --                ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
   --                ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' + 
   --                ' WHERE LOT.STORERKEY = @c_storerkey ' +
   --                ' AND LOT.SKU = @c_SKU ' +
   --                ' AND LOT.STATUS = ''OK'' ' +
   --                ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
   --                ' AND LOC.LocationFlag <> ''HOLD'' ' + 
   --                ' AND LOC.Facility = @c_facility ' + 
   --                ' AND LOTATTRIBUTE.STORERKEY = @c_storerkey ' +
   --                ' AND LOTATTRIBUTE.SKU = @c_SKU ' +
   --                ' AND SKUXLOC.LocationType IN (''PICK'') ' +
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END + 
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END + 
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END + 
   --                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END + 
   --                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END + 
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +                                                                                      
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +                                                                                      
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +                                                                                      
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +                                                                                      
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +                                                                                      
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +                                                                                      
   --                CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +                                                                                      
   --                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END + 
   --                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END + 
   --                CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END + 
   --                ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 '

   --   EXEC sp_executesql @c_SQL 
   --      , N'@c_Storerkey     NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), 
   --          @c_Lottable01    NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18),
   --          @d_Lottable04    DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), 
   --          @c_Lottable07    NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), 
   --          @c_Lottable10    NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30),
   --          @d_Lottable13    DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME,
   --          @n_QtyLeftToFulfill INT, @n_Count INT OUTPUT '
   --      , @c_StorerKey
   --      , @c_Sku
   --      , @c_Facility
   --      , @c_Lottable01
   --      , @c_Lottable02
   --      , @c_Lottable03
   --      , @d_Lottable04
   --      , @d_Lottable05
   --      , @c_Lottable06
   --      , @c_Lottable07
   --      , @c_Lottable08
   --      , @c_Lottable09
   --      , @c_Lottable10
   --      , @c_Lottable11
   --      , @c_Lottable12
   --      , @d_Lottable13
   --      , @d_Lottable14
   --      , @d_Lottable15
   --      , @n_QtyLeftToFulfill
   --      , @n_Count OUTPUT

   --      --if @n_Count >= 1, Pick Loc have qty, else need overallocation
   --      SELECT @n_Count = ISNULL(@n_Count,0)
   --      --SELECT @n_Count
   --END

   IF @c_UOM IN ('2')  
   BEGIN
      SET @c_SQL = ' DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR ' +
                   ' SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
                   --' QtyAvailable = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN), 0, '''', ' +
                   ' QtyAvailable = UCC.Qty, 0, '''', ' +
                   ' UCC.UCCNo ' +
                   ' FROM LOTATTRIBUTE (NOLOCK) ' +
                   ' JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT ' +
                   ' JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' + 
                   ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
                   ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' + 
                   ' JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND ' +
                   '                       UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < ''3'') ' +
                   ' WHERE LOT.STORERKEY = @c_storerkey ' +
                   ' AND LOT.SKU = @c_SKU ' +
                   ' AND LOT.STATUS = ''OK'' ' +
                   ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
                   ' AND LOC.LocationFlag <> ''HOLD'' ' + 
                   ' AND LOC.Facility = @c_facility ' + 
                   ' AND LOTATTRIBUTE.STORERKEY = @c_storerkey ' +
                   ' AND LOTATTRIBUTE.SKU = @c_SKU ' +
                   ' AND LOC.LocationType IN (''OTHER'') ' +
                   CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END + 
                   CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END + 
                   CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END + 
                   CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +                                                                                      
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END + 
                   ' AND UCC.Qty > 0 ' +
                   ' GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LOTATTRIBUTE.Lottable05, LOC.LocationType, UCC.UCCNo, UCC.Qty ' +
                   ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 ' + 
                   RTRIM(ISNULL(@c_OrderBy,''))
   
      EXEC sp_executesql @c_SQL 
         , N'@c_Storerkey     NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), 
             @c_Lottable01    NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18),
             @d_Lottable04    DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), 
             @c_Lottable07    NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), 
             @c_Lottable10    NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30),
             @d_Lottable13    DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME '
         , @c_StorerKey
         , @c_Sku
         , @c_Facility
         , @c_Lottable01
         , @c_Lottable02
         , @c_Lottable03
         , @d_Lottable04
         , @d_Lottable05
         , @c_Lottable06
         , @c_Lottable07
         , @c_Lottable08
         , @c_Lottable09
         , @c_Lottable10
         , @c_Lottable11
         , @c_Lottable12
         , @d_Lottable13
         , @d_Lottable14
         , @d_Lottable15
   END    
   ELSE IF @c_UOM = '6' --OR (@c_UOM = '7' AND @n_Count >=1)
   BEGIN
      SET @c_SQL = ' DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR ' +
                   ' SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
                   ' QtyAvailable = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN), 0, '''', '''' ' +
                   ' FROM LOTATTRIBUTE (NOLOCK) ' +
                   ' JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT ' +
                   ' JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' + 
                   ' JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc ' +
                   ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
                   ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' + 
                   ' WHERE LOT.STORERKEY = @c_storerkey ' +
                   ' AND LOT.SKU = @c_SKU ' +
                   ' AND LOT.STATUS = ''OK'' ' +
                   ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
                   ' AND LOC.LocationFlag <> ''HOLD'' ' + 
                   ' AND LOC.Facility = @c_facility ' + 
                   ' AND LOTATTRIBUTE.STORERKEY = @c_storerkey ' +
                   ' AND LOTATTRIBUTE.SKU = @c_SKU ' +
                   ' AND SKUXLOC.LocationType IN (''PICK'') ' +
                   CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END + 
                   CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END + 
                   CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END + 
                   CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +                                                                                      
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END + 
                   ' GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LOTATTRIBUTE.Lottable05, SKUxLOC.LocationType ' +
                   ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0 ' + 
                   ' AND @n_QtyLeftToFulfill <= SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) - MAX(SKUXLOC.QtyLocationMinimum) '  +
                   RTRIM(ISNULL(@c_OrderBy,''))

      EXEC sp_executesql @c_SQL 
         , N'@c_Storerkey     NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), 
             @c_Lottable01    NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18),
             @d_Lottable04    DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), 
             @c_Lottable07    NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), 
             @c_Lottable10    NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30),
             @d_Lottable13    DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME,
             @n_QtyLeftToFulfill INT '
         , @c_StorerKey
         , @c_Sku
         , @c_Facility
         , @c_Lottable01
         , @c_Lottable02
         , @c_Lottable03
         , @d_Lottable04
         , @d_Lottable05
         , @c_Lottable06
         , @c_Lottable07
         , @c_Lottable08
         , @c_Lottable09
         , @c_Lottable10
         , @c_Lottable11
         , @c_Lottable12
         , @d_Lottable13
         , @d_Lottable14
         , @d_Lottable15
         , @n_QtyLeftToFulfill
   END
   ELSE
   BEGIN
      SET @c_SQL = ' DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR ' +
                   ' SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
                   ' QtyAvailable = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN), ' +
                   ' QtyLocationMinimum = MAX(SKUXLOC.QtyLocationMinimum), ' +
                   ' LocationType = CASE WHEN SKUXLOC.LocationType = ''PICK'' THEN ''PICK'' ELSE '''' END, '''' ' +
                   ' FROM LOTATTRIBUTE (NOLOCK) ' +
                   ' JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT ' +
                   ' JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' + 
                   ' JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc ' +
                   ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
                   ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' + 
                   ' WHERE LOT.STORERKEY = @c_storerkey ' +
                   ' AND LOT.SKU = @c_SKU ' +
                   ' AND LOT.STATUS = ''OK'' ' +
                   ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
                   ' AND LOC.LocationFlag <> ''HOLD'' ' + 
                   ' AND LOC.Facility = @c_facility ' + 
                   ' AND LOTATTRIBUTE.STORERKEY = @c_storerkey ' +
                   ' AND LOTATTRIBUTE.SKU = @c_SKU ' +
                   ' AND (SKUXLOC.LocationType IN (''PICK'') OR LOC.LocationType IN (''OTHER'') ) ' +
                   CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END + 
                   CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END + 
                   CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END + 
                   CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +                                                                                      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +                                                                                      
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END + 
                   CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END + 
                   ' GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOC.Loc, LOC.LogicalLocation, LOTATTRIBUTE.Lottable05, SKUxLOC.LocationType, LOC.LocationType ' +
                   ' ORDER BY CASE WHEN SKUXLOC.LocationType IN (''PICK'') THEN 1 WHEN LOC.LocationType IN (''OTHER'') THEN 2 ELSE 3 END, LOTATTRIBUTE.Lottable05, LOC.LogicalLocation, LOC.Loc, QtyAvailable '

      EXEC sp_executesql @c_SQL 
         , N'@c_Storerkey     NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), 
             @c_Lottable01    NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18),
             @d_Lottable04    DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), 
             @c_Lottable07    NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), 
             @c_Lottable10    NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30),
             @d_Lottable13    DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME,
             @n_QtyLeftToFulfill INT '
         , @c_StorerKey
         , @c_Sku
         , @c_Facility
         , @c_Lottable01
         , @c_Lottable02
         , @c_Lottable03
         , @d_Lottable04
         , @d_Lottable05
         , @c_Lottable06
         , @c_Lottable07
         , @c_Lottable08
         , @c_Lottable09
         , @c_Lottable10
         , @c_Lottable11
         , @c_Lottable12
         , @d_Lottable13
         , @d_Lottable14
         , @d_Lottable15
         , @n_QtyLeftToFulfill
   END

   SET @c_SQL = ''
   
   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable, @n_QtyLocationMin, @c_LocationType, @c_OtherValue
      
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN
      --@n_QtyLeftToFulfill > SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) - MAX(SKUXLOC.QtyLocationMinimum)
      IF @c_UOM = '7' AND @c_LocationType = 'PICK'
      BEGIN
         IF @n_QtyLeftToFulfill <= @n_QtyAvailable - @n_QtyLocationMin  --(ONLY FOR UOM 6)
            GOTO NEXT_LLI
      END

      IF @c_UOM = '7' AND @c_LocationType <> 'PICK'
      BEGIN
         IF NOT EXISTS (SELECT 1
                        FROM UCC (NOLOCK)
                        WHERE UCC.Storerkey = @c_Storerkey
                        AND UCC.SKU = @c_Sku
                        AND UCC.Lot = @c_LOT
                        AND UCC.Loc = @c_Loc
                        AND UCC.ID  = @c_ID
                        AND UCC.[Status] < '3'
                       )
         GOTO NEXT_LLI
      END

      IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
      BEGIN
         INSERT INTO #TMP_LOT (Lot, QtyAvailable)
         SELECT Lot, Qty - QtyAllocated - QtyPicked
         FROM LOT (NOLOCK)
         WHERE LOT = @c_LOT            
      END
      SET @n_LotQty = 0
      
      SELECT @n_LotQty = QtyAvailable
      FROM #TMP_LOT 
      WHERE Lot = @c_Lot         

      IF @n_LotQty < @n_QtyAvailable   
      BEGIN  
         IF @c_UOM IN ('1', '2')   
            SET @n_QtyAvailable = 0  
         ELSE  
            SET @n_QtyAvailable = @n_LotQty  
      END     

      SET @n_QtyToTake = 0

      IF @c_UOM <> '2' SET @c_OtherValue = '1'

      --SET @n_PackQty = @n_UOMBase
      --SET @n_UCCQty = 0
      --SET @c_OtherValue = '1'
      
      --IF @c_UOM = '2'
      --BEGIN
      --   SELECT TOP 1 @n_UCCQty = Qty  --Expect the location have same UCC qty
      --              , @c_UCCNo = UCCNo
      --   FROM UCC (NOLOCK)
      --   WHERE Storerkey = @c_Storerkey
      --   AND Sku = @c_Sku
      --   AND Lot = @c_Lot
      --   AND Loc = @c_Loc
      --   AND Id = @c_Id
      --   AND Status < '3'     
      --   ORDER BY Qty ASC

      --   IF @n_UCCQty > 0
      --   BEGIN
      --      SET @n_PackQty = @n_UCCQty
      --      SET @c_OtherValue = 'UOM=' + LTRIM(CAST(@n_UCCQty AS NVARCHAR)) --instruct the allocation to take this as casecnt
      --   END
      --   ELSE
      --   BEGIN
      --      GOTO NEXT_LLI
      --   END
      --END
                                                
       --IF @n_QtyAvailable > @n_QtyLeftToFulfill
       --   SET @n_QtyToTake = FLOOR(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
       --ELSE
       --   SET @n_QtyToTake = FLOOR(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase                           
       
      IF @n_QtyLeftToFulfill >= @n_QtyAvailable  
      BEGIN  
         SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase  
      END  
      ELSE  
      BEGIN  
        SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase  
      END
      
      IF @c_UOM = '2'
      BEGIN
         IF @n_QtyLeftToFulfill < @n_QtyAvailable   
         BEGIN
            SET @n_QtyToTake = 0
         END 
      END

      IF @n_QtyToTake > 0                         
      BEGIN
         UPDATE #TMP_LOT
         SET QtyAvailable = QtyAvailable - @n_QtyToTake
         WHERE Lot = @c_Lot
         
         EXEC isp_Insert_Allocate_Candidates
            @c_Lot = @c_Lot
         ,  @c_Loc = @c_Loc
         ,  @c_ID  = @c_ID
         ,  @n_QtyAvailable = @n_QtyToTake
         ,  @c_OtherValue = @c_OtherValue

      END
      SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake                     

NEXT_LLI:     
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable, @n_QtyLocationMin, @c_LocationType, @c_OtherValue
   END -- END WHILE FOR CURSOR_AVAILABLE                
         
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column 
   
   EXIT_SP:
END

GO