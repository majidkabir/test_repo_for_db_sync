SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispALADSFC                                              */
/* Creation Date: 2021-07-08                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17271 - RG - Adidas Allocation Strategy                 */
/*        : FUll Case - UCCNo PickCode                                  */
/* Called By: ispPRALC06                                                */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-08  Wan      1.0   Created.                                  */
/* 2021-10-06  Wan      1.0   DevOps Combine Script                     */
/* 2021-10-22  Wan01    1.1   Exclude Normal Replen UCC for UOM 2 & 6   */
/*                            where UCC.Status = '1'                    */
/* 2022-02-09  Wan02    1.2   CR 1.5. Exclude Lot & ID Hold Inventory   */
/* 2022-07-13  Wan04    1.4   Fix Issue for UOM = '7' and reallocate UCC*/
/*                            that has been allocated for UOM ='6'      */
/************************************************************************/
CREATE PROC [dbo].[ispALADSFC]
      @c_Wavekey           NVARCHAR(10)  
   ,  @c_Facility          NVARCHAR(5)     
   ,  @c_StorerKey         NVARCHAR(15)     
   ,  @c_SKU               NVARCHAR(20)    
   ,  @c_Lottable01        NVARCHAR(18)    
   ,  @c_Lottable02        NVARCHAR(18)    
   ,  @c_Lottable03        NVARCHAR(18)    
   ,  @dt_Lottable04       DATETIME
   ,  @dt_Lottable05       DATETIME    
   ,  @c_Lottable06        NVARCHAR(30)    
   ,  @c_Lottable07        NVARCHAR(30)    
   ,  @c_Lottable08        NVARCHAR(30)    
   ,  @c_Lottable09        NVARCHAR(30)    
   ,  @c_Lottable10        NVARCHAR(30)    
   ,  @c_Lottable11        NVARCHAR(30)    
   ,  @c_Lottable12        NVARCHAR(30)    
   ,  @dt_Lottable13       DATETIME    
   ,  @dt_Lottable14       DATETIME    
   ,  @dt_Lottable15       DATETIME    
   ,  @c_UOM               NVARCHAR(10)   = '' 
   ,  @c_HostWHCode        NVARCHAR(10)   = '' 
   ,  @n_UOMBase           INT            = 1
   ,  @n_QtyLeftToFulfill  INT            = 0
   ,  @c_OtherParms        NVARCHAR(250)  = ''
   ,  @b_debug             INT = 0
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF

   DECLARE @c_SQL                NVARCHAR(MAX)  = ''
         , @c_SQLParms           NVARCHAR(MAX)  = ''
         , @c_AllocateType       NVARCHAR(1)    = ''
         , @c_fOrderkey          NVARCHAR(10)   = ''
         
         , @c_LocationType       NVARCHAR(10)   = 'OTHER'
         , @c_LocationCategory   NVARCHAR(10)   = 'BULK'
         , @c_LocationHandling   NVARCHAR(10)   = '2' -- 2:Case, Adidas only setup Location Handling 2 

   DECLARE @t_LLIxUCC            TABLE
         (  RowID                INT            IDENTITY(1,1)
         ,  Lot                  NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  Loc                  NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  ID                   NVARCHAR(18)   NOT NULL DEFAULT('')
         ,  QtyAvailable         INT            NOT NULL DEFAULT(0)
         ,  uccQty               INT            NOT NULL DEFAULT(0)  
         ,  ASumUCCQty           INT            NOT NULL DEFAULT(0) 
         ,  UCCNo                NVARCHAR(20)   NOT NULL DEFAULT('')
         )

   IF OBJECT_ID('tempdb..#ALLOCATE_DROPID','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #ALLOCATE_DROPID;  
   END  
  
   CREATE TABLE #ALLOCATE_DROPID  
   (  DropID         NVARCHAR(20)   NOT NULL DEFAULT('')  PRIMARY KEY
   ,  QtyAllocated   INT            NOT NULL DEFAULT(0)  
   )  
      
   -- UOM = 2, 1 UCC Share Among 1 Order, UOM = 6, 1 UCC Share Among Multiple Orders in Wave/Load
   SET @c_AllocateType = SUBSTRING(@c_OtherParms,16,1)
   SET @c_fOrderkey    = SUBSTRING(@c_OtherParms,17,10)

   -- If Consolidate Order & Discreate Allocation Type AND uom 6 
   IF @c_AllocateType IN ('O', 'D') AND @c_UOM IN ('6','7')
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @c_AllocateType IN ('W') AND @c_UOM IN ('2')
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @c_UOM IN ('7')
   BEGIN
      --(WAN04) 2022-07-13 Fixed - Select ALL UCC that with Status = '3' and only get those UCC with UCC.qty - allocated qty > 0 below <START>--
    SELECT @c_Storerkey '@c_Storerkey', @c_Sku '@c_Sku'
   	SELECT p.DropID  
               ,QtyAllocated = SUM(p.Qty) OVER(PARTITION BY p.DropID ORDER BY PickdetailKey)   
         FROM dbo.PICKDETAIL AS p WITH (NOLOCK)   
         WHERE p.Storerkey = @c_Storerkey  
         AND p.DropID <> ''  
         --AND p.UOM = '7'                               
         AND p.[Status] < '9' AND p.ShipFlag <> 'Y'  
         AND EXISTS (SELECT 1 FROM dbo.UCC AS u WITH (NOLOCK)   
                     WHERE u.Storerkey = @c_Storerkey  
                     AND u.Sku = @c_Sku  
                     AND u.UCCNo = p.DropID  
                     AND u.[Status] = '3'  
                     )
      ; WITH ad AS
      (  SELECT p.DropID
               ,QtyAllocated = SUM(p.Qty) OVER(PARTITION BY p.DropID ORDER BY PickdetailKey) 
         FROM dbo.PICKDETAIL AS p WITH (NOLOCK) 
         WHERE p.Storerkey = @c_Storerkey
         AND p.DropID <> ''
         --AND p.UOM = '7'
         AND p.[Status] < '9' AND p.ShipFlag <> 'Y'
         AND EXISTS (SELECT 1 FROM dbo.UCC AS u WITH (NOLOCK) 
                     WHERE u.Storerkey = @c_Storerkey
                     AND u.Sku = @c_Sku
                     AND u.UCCNo = p.DropID
                     AND u.[Status] = '3'
                     )
       )
	   --(WAN04) 2022-07-13 Fixed - Select ALL UCC that with Status = '3' and only get those UCC with UCC.qty - allocated qty > 0 below <END>--
      INSERT INTO #ALLOCATE_DROPID (DropID, QtyAllocated)
      SELECT TOP 1 WITH TIES 
            ad.DropID
         ,  ad.QtyAllocated 
      FROM ad
      ORDER BY ROW_NUMBER() OVER(PARTITION BY ad.DropID ORDER BY ad.QtyAllocated DESC)
      
      IF @b_debug <> 0
      BEGIN
         SELECT * FROM #ALLOCATE_DROPID
      END
   END
   
   -- UCCNo
   SET @c_SQL = N'SELECT lli.lot, lli.Loc, lli.ID, QtyAvailable = lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen'
              + CASE WHEN @c_UOM = '7' THEN ', QtyAvailable_UCC=u.Qty - ISNULL(ad.QtyAllocated,0)' ELSE ', QtyAvailable_UCC=u.Qty' END
              + CASE WHEN @c_UOM = '7'
                     THEN ', ASumUCCQty = SUM(u.Qty - ISNULL(ad.QtyAllocated,0)) OVER 
                             (ORDER BY u.[Status] DESC, CASE WHEN td.taskdetailkey IS NOT NULL THEN 1 ELSE 9 END
                              , l.LogicalLocation, l.Loc, l2.Lottable05, u.UCC_RowRef)' 
                     ELSE ', ASumUCCQty = SUM(u.Qty) OVER (ORDER BY l.LogicalLocation, l.Loc, l2.Lottable05, u.UCC_RowRef)' 
                     END              
              + ', u.UCCNo'
              + ' FROM dbo.LOTxLOCxID AS lli WITH (NOLOCK)' 
              + ' JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = lli.Loc AND l.[Status] NOT IN (''HOLD'')'               --(Wan02)
              + ' JOIN dbo.UCC AS u WITH (NOLOCK) ON u.Lot = lli.Lot'
              +                                 ' AND u.loc= lli.LOC'
              +                                 ' AND u.ID = lli.ID'
              +  CASE WHEN @c_UOM = '7' THEN ' AND u.[Status] IN ( ''1'',''3'')' ELSE ' AND u.[Status] = ''1''' END
              + ' JOIN dbo.LOTATTRIBUTE AS l2 WITH (NOLOCK) ON l2.Lot = lli.Lot' 
              + ' JOIN dbo.LOT AS l3 WITH (NOLOCK) ON l3.Lot = lli.Lot AND l3.[Status] NOT IN (''HOLD'')'            --(Wan02)
              + ' JOIN dbo.ID AS i WITH (NOLOCK) ON i.ID = lli.ID AND i.[Status] NOT IN (''HOLD'')'                  --(Wan02)   
              + ' LEFT OUTER JOIN TASKDETAIL AS td WITH (NOLOCK) ON td.storerkey = u.storerkey AND td.caseid = u.uccno'    --Wan01. Need LEFT JOIN Taskdetail for UOM '2', '6', ,'7'     
              +  CASE WHEN @c_UOM = '7' THEN 
                ' LEFT OUTER JOIN #ALLOCATE_DROPID AS ad ON u.UCCNo = ad.DropID'
                                        ELSE '' 
                                        END       
              + ' WHERE lli.StorerKey = @c_StorerKey'
              + ' AND lli.Sku = @c_SKU'
              + ' AND l.Facility = @c_Facility'
              + ' AND l.LocationType = @c_LocationType'
              + ' AND l.LocationCategory = @c_LocationCategory'
              + ' AND l.LocationHandling = @c_LocationHandling'
              + ' AND l.LocationFlag NOT IN (''HOLD'', ''DAMAGE'')'
              + ' AND u.Qty > 0'
              + CASE WHEN @c_UOM = '7' THEN ' AND u.Qty - ISNULL(ad.QtyAllocated,0) > 0' ELSE ' AND u.Qty <= @n_QtyLeftToFulfill' END
              + ' AND lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen > 0'
              + CASE WHEN @c_UOM IN ('2','6') THEN ' AND td.Taskdetailkey IS NULL' ELSE '' END                             --Wan01. Need to exclude Replen UCC that UCC.Status = '1'
              + CASE WHEN @c_Lottable01 = '' THEN '' ELSE N' AND l2.Lottable01 = @c_Lottable01' END
              + CASE WHEN @c_Lottable02 = '' THEN '' ELSE N' AND l2.Lottable02 = @c_Lottable02' END  
              + CASE WHEN @c_Lottable03 = '' THEN '' ELSE N' AND l2.Lottable03 = @c_Lottable03' END
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable04, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable04 = @dt_Lottable04' END              
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable05, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable05 = @dt_Lottable05' END
              + CASE WHEN @c_Lottable06 = '' THEN '' ELSE N' AND l2.Lottable06 = @c_Lottable06' END              
              + CASE WHEN @c_Lottable07 = '' THEN '' ELSE N' AND l2.Lottable07 = @c_Lottable07' END    
              + CASE WHEN @c_Lottable08 = '' THEN '' ELSE N' AND l2.Lottable08 = @c_Lottable08' END              
              + CASE WHEN @c_Lottable09 = '' THEN '' ELSE N' AND l2.Lottable09 = @c_Lottable09' END  
              + CASE WHEN @c_Lottable10 = '' THEN '' ELSE N' AND l2.Lottable10 = @c_Lottable10' END     
              + CASE WHEN @c_Lottable11 = '' THEN '' ELSE N' AND l2.Lottable11 = @c_Lottable11' END
              + CASE WHEN @c_Lottable12 = '' THEN '' ELSE N' AND l2.Lottable12 = @c_Lottable12' END  
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable13, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable13 = @dt_Lottable13' END
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable14, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable14 = @dt_Lottable14' END              
              + CASE WHEN CONVERT(NCHAR(10), @dt_Lottable15, 121) = '1900-01-01' THEN '' ELSE N' AND l2.Lottable15 = @dt_Lottable15' END  
              + ' ORDER BY'
              + CASE WHEN @c_UOM = '7' THEN ' u.[Status] DESC, CASE WHEN td.taskdetailkey IS NOT NULL THEN 1 ELSE 9 END,' ELSE '' END
              +          ' l.LogicalLocation'
              +         ', l.Loc'  
              +         ', l2.Lottable05'   
   
   IF @b_debug IN (1,2,3)
   BEGIN
      PRINT @c_SQL
   END   
              
   SET @c_SQLParms = N'@c_Storerkey          NVARCHAR(15)'
                   + ',@c_Sku                NVARCHAR(20)'
                   + ',@c_facility           NVARCHAR(5)' 
                   + ',@c_LocationType       NVARCHAR(10)'
                   + ',@c_LocationCategory   NVARCHAR(10)'  
                   + ',@c_LocationHandling   NVARCHAR(10)'                                     
                   + ',@n_QtyLeftToFulfill   INT'                 
                   + ',@c_Lottable01         NVARCHAR(18)'    
                   + ',@c_Lottable02         NVARCHAR(18)'    
                   + ',@c_Lottable03         NVARCHAR(18)'    
                   + ',@dt_Lottable04        DATETIME'
                   + ',@dt_Lottable05        DATETIME'
                   + ',@c_Lottable06         NVARCHAR(30)'    
                   + ',@c_Lottable07         NVARCHAR(30)'    
                   + ',@c_Lottable08         NVARCHAR(30)'    
                   + ',@c_Lottable09         NVARCHAR(30)'    
                   + ',@c_Lottable10         NVARCHAR(30)'    
                   + ',@c_Lottable11         NVARCHAR(30)'    
                   + ',@c_Lottable12         NVARCHAR(30)'    
                   + ',@dt_Lottable13        DATETIME'
                   + ',@dt_Lottable14        DATETIME'
                   + ',@dt_Lottable15        DATETIME'
   
      INSERT INTO @t_LLIxUCC   
         (  Lot                
         ,  Loc                
         ,  ID                 
         ,  QtyAvailable       
         ,  uccQty 
         ,  ASumUCCQty                      
         ,  UCCNo              
         )
      EXEC sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_Storerkey          
                        , @c_Sku                
                        , @c_facility           
                        , @c_LocationType       
                        , @c_LocationCategory   
                        , @c_LocationHandling   
                        , @n_QtyLeftToFulfill   
                        , @c_Lottable01         
                        , @c_Lottable02         
                        , @c_Lottable03         
                        , @dt_Lottable04       
                        , @dt_Lottable05       
                        , @c_Lottable06         
                        , @c_Lottable07         
                        , @c_Lottable08         
                        , @c_Lottable09         
                        , @c_Lottable10         
                        , @c_Lottable11         
                        , @c_Lottable12         
                        , @dt_Lottable13       
                        , @dt_Lottable14       
                        , @dt_Lottable15  
 
   IF @b_Debug = 0
   BEGIN
      INSERT INTO #ALLOCATE_CANDIDATES (Lot, Loc, Id, QtyAvailable, OtherValue)
      SELECT tliu.Lot, tliu.Loc, tliu.Id, tliu.uccQty, tliu.UCCNo
      FROM @t_LLIxUCC AS tliu
      WHERE tliu.uccQty <= tliu.QtyAvailable
      ORDER BY tliu.RowID
   END
   ELSE
   BEGIN
      SELECT tliu.Lot, tliu.Loc, tliu.Id, tliu.uccQty, tliu.UCCNo
      FROM @t_LLIxUCC AS tliu
      WHERE tliu.uccQty <= tliu.QtyAvailable
      ORDER BY tliu.RowID
   END    
       
   QUIT_SP:
   IF @b_Debug = 0
   BEGIN
      EXEC isp_Cursor_Allocate_Candidates
         @n_SkipPreAllocationFlag = 1   --1: Return Lot Column, 0:Do not return Lot Column   
   END
END -- procedure

GO