SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispVASAL02                                         */
/* Creation Date: 21-MAY-2015                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: AllocateStrategy                                            */
/*                                                                      */
/* Called By: isp_WOInvReserveProcessing                                */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 11-JAN-2016  Wan01   1.1   SOS#315603 - Project Merlion - VAP SKU    */
/*                            Reservation Strategy - MixSku in 1 Pallet */
/*                            enhancement                               */	 
/************************************************************************/ 
CREATE PROC  [dbo].[ispVASAL02]     
     @c_Lot                NVARCHAR(10)
   , @c_Facility           NVARCHAR(5)
   , @c_StorerKey          NVARCHAR(15)
   , @c_SKU                NVARCHAR(20)  
   , @c_Lottable01         NVARCHAR(18)
   , @c_Lottable02         NVARCHAR(18)  
   , @c_Lottable03         NVARCHAR(18)
   , @d_Lottable04         DATETIME
   , @d_Lottable05         DATETIME
   , @c_Lottable06         NVARCHAR(30)
   , @c_Lottable07         NVARCHAR(30)  
   , @c_Lottable08         NVARCHAR(30)
   , @c_Lottable09         NVARCHAR(30)
   , @c_Lottable10         NVARCHAR(30)  
   , @c_Lottable11         NVARCHAR(30)
   , @c_Lottable12         NVARCHAR(30)
   , @d_Lottable13         DATETIME 
   , @d_Lottable14         DATETIME
   , @d_Lottable15         DATETIME
   , @c_UOM                NVARCHAR(10)
   , @c_HostWHCode         NVARCHAR(10)
   , @n_UOMBase            INT 
   , @n_QtyLeftToFulfill   INT
   , @c_OtherParms         NVARCHAR(200)=''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
   DECLARE @b_success            INT
         , @n_err                INT
         , @c_errmsg             NVARCHAR(250)

   DECLARE @c_SQLStatement       NVARCHAR(4000)
         , @c_SQLArguements      NVARCHAR(4000)
         , @c_OtherStatement     NVARCHAR(4000)
         , @c_SortOrder          NVARCHAR(4000)

			, @c_JobKey             NVARCHAR(10)
         , @c_TmpLoc             NVARCHAR(10)
         , @c_LocationCategory   NVARCHAR(10)
         , @c_Putawayzone        NVARCHAR(10)

   SET @b_success          = 0
   SEt @n_err              = 0
   SET @c_errmsg           = ''

   SET @c_SQLStatement     = ''
   SET @c_SQLArguements    = ''
   SET @c_OtherStatement   = ''
   SET @c_SortOrder        = ''

   SET @c_JobKey = ''
   SET @c_JobKey = SUBSTRING(@c_OtherParms,1,10)

   SET @c_TmpLoc = ''
   SET @c_TmpLoc = SUBSTRING(@c_OtherParms,16,10)

   SET @c_LocationCategory = 'ASRS'
   SET @c_Putawayzone      = 'CONVEYOR'
   --SELECT @c_LocationCategory = LocationCategory 
   --      ,@c_Putawayzone      = Putawayzone
   --FROM LOC WITH (NOLOCK)
   --WHERE Loc = @c_TmpLoc

   SET @c_OtherStatement = ''  

   IF RTRIM(@c_Lottable01) <> ''
   BEGIN  
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable01= N''' + RTRIM(@c_Lottable01) + ''''
   END  
      
   IF RTRIM(@c_Lottable02) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable02= N''' + RTRIM(@c_Lottable02) + ''''  
   END 

   IF RTRIM(@c_Lottable03) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable03= N''' + RTRIM(@c_Lottable03) + ''''   
   END 
   
   IF CONVERT(NVARCHAR(8),@d_Lottable04,112) <> '19000101' 
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable04 = ''' + @d_Lottable04 + ''''
   END  
   
   IF CONVERT(NVARCHAR(8),@d_Lottable05,112) <> '19000101'
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable05 = ''' + @d_Lottable05 + '''' 
   END 

  IF RTRIM(@c_Lottable06) <> ''
   BEGIN  
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable06= N''' + RTRIM(@c_Lottable06) + ''''
   END  
      
   IF RTRIM(@c_Lottable07) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable07= N''' + RTRIM(@c_Lottable07) + ''''  
   END 

   IF RTRIM(@c_Lottable08) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable08= N''' + RTRIM(@c_Lottable08) + ''''   
   END 

   IF RTRIM(@c_Lottable09) <> ''
   BEGIN  
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable09= N''' + RTRIM(@c_Lottable09) + ''''
   END  
      
   IF RTRIM(@c_Lottable10) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable10= N''' + RTRIM(@c_Lottable10) + ''''  
   END 

   IF RTRIM(@c_Lottable11) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable11= N''' + RTRIM(@c_Lottable11) + ''''   
   END 

   IF RTRIM(@c_Lottable12) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable12= N''' + RTRIM(@c_Lottable12) + ''''   
   END 
   
   IF CONVERT(NVARCHAR(8),@d_Lottable13,112) <> '19000101'
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable13 = ''' + @d_Lottable13 + ''''
   END
   
   IF CONVERT(NVARCHAR(8),@d_Lottable14,112) <> '19000101'
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable14 = ''' + @d_Lottable14 + ''''
   END  
   
   IF CONVERT(NVARCHAR(8),@d_Lottable15,112) <> '19000101'
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND LOTATTRIBUTE.Lottable15 = ''' + @d_Lottable15 + '''' 
   END 

   SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND SKU.BUSR3 = ''DGE-PKG'''
  
   SET @c_SQLStatement = N'DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR'
                       + ' SELECT LOTxLOCxID.LOT'
                       + ',LOTxLOCxID.LOC'
                       + ',LOTxLOCxID.ID'
                       + ',QTYAVAILABLE = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated -'
                       +                 ' LOTxLOCxID.QtyPicked - ISNULL(RSV.QtyReserved,0))'
                       + ',''1'''
                       + ' FROM LOTxLOCxID WITH (NOLOCK)'
                       + ' JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC) AND LOC.Status = ''OK'''
                       + ' JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)'       -- AND ID.STATUS = ''OK'')'      --(Wan01)
                       + ' JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS = ''OK'')'
                       + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT'
                       + ' JOIN SKUxLOC s WITH (NOLOCK) ON s.StorerKey = LOTxLOCxID.StorerKey AND s.Sku = LOTxLOCxID.Sku AND s.Loc = LOTxLOCxID.Loc'
                       + ' JOIN SKU (NOLOCK) ON SKU.StorerKey = s.StorerKey AND SKU.Sku = s.Sku'
                       --(Wan01) - START
                       + ' LEFT OUTER JOIN (SELECT PP.lot, OH.facility, QtyPreallocated = ISNULL(SUM(PP.Qty),0)'  
                       +                  ' FROM PREALLOCATEPICKDETAIL PP WITH (NOLOCK)'
                       +                  ' JOIN  ORDERS OH WITH(NOLOCK) ON (PP.Orderkey = OH.Orderkey)'
                       +                  ' WHERE PP.Storerkey = @c_Storerkey'  
                       +                  ' AND   PP.SKU = @c_Sku'  
                       +                  ' AND   OH.Facility = @c_Facility' 
                       +                  ' GROUP BY PP.Lot, OH.Facility) p' 
                       +                  ' ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility' 
                       + ' LEFT OUTER JOIN (SELECT WOJM.JobKey, WOJM.Lot, WOJM.ToLoc, WOJM.ID, WOJD.facility, QtyReserved = ISNULL(SUM(WOJM.Qty),0)'  
                       +                  ' FROM WORKORDERJOBMOVE   WOJM WITH (NOLOCK)'
                       +                  ' JOIN WORKORDERJOBDETAIL WOJD WITH(NOLOCK) ON (WOJM.JobKey = WOJD.JobKey)'
                       +                  ' WHERE WOJM.Jobkey = @c_JobKey'
                       +                  ' AND   WOJM.Storerkey = @c_Storerkey'  
                       +                 ' AND   WOJM.SKU = @c_Sku' 
                       +                  ' AND   WOJD.Facility = @c_Facility' 
                       +                  ' AND   WOJM.Status < ''9''' 
                       +                  ' GROUP BY WOJM.JobKey,  WOJM.Lot, WOJM.ToLoc, WOJM.ID, WOJD.Facility) RSV' 
                       +                  ' ON LOTXLOCXID.Lot = RSV.Lot AND LOTXLOCXID.Loc = RSV.ToLoc'
                       +                  ' AND LOTXLOCXID.ID = RSV.ID AND RSV.Facility = LOC.Facility' 
                       + ' LEFT OUTER JOIN (SELECT WOJM.JobKey, WOJM.ToLoc, WOJM.ID, WOJD.facility, QtyReserved = ISNULL(SUM(WOJM.Qty),0)'  
                       +                  ' FROM WORKORDERJOBMOVE   WOJM WITH (NOLOCK)'
                       +                  ' JOIN WORKORDERJOBDETAIL WOJD WITH(NOLOCK) ON (WOJM.JobKey = WOJD.JobKey)'
                       +                  ' WHERE WOJM.Jobkey = @c_JobKey'
                       +                  ' AND   WOJD.Facility = @c_Facility' 
                       +                  ' AND   WOJM.Status < ''9''' 
                       +                  ' GROUP BY WOJM.JobKey, WOJM.ToLoc, WOJM.ID, WOJD.Facility) RID' 
                       +                  ' ON  LOTXLOCXID.Loc = RID.ToLoc'
                       +                  ' AND LOTXLOCXID.ID = RID.ID  AND RID.Facility = LOC.Facility' 
                       + ' LEFT OUTER JOIN (SELECT LLI.ID, COUNT(DISTINCT LLI.Sku) NoOfSku'  
                       +                  ' FROM WORKORDERJOBOPERATION WOJO WITH (NOLOCK)'
                       +                  ' JOIN LOTxLOCxID LLI  WITH (NOLOCK) ON (WOJO.Storerkey = LLI.Storerkey)'
                       +                                                     ' AND(WOJO.Sku = LLI.Sku)'
                       +                  ' WHERE WOJO.Jobkey = @c_JobKey'
                       +                  ' AND   WOJO.WOOperation = ''ASRS Pull''' 
                       +                  ' AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  > 0' 
                       +                  ' GROUP BY LLI.ID) MS' 
                       +                  ' ON MS.ID = LOTxLOCxID.ID'
                       --(Wan01) - END
                       + ' WHERE LOC.LocationFlag <> CASE WHEN RID.Jobkey IS NULL THEN ''HOLD'' ELSE '''' END'
                       + ' AND LOC.LocationFlag <> ''DAMAGE'''
                       + ' AND LOC.Facility = @c_Facility'
                       + ' AND LOC.LocationCategory = CASE WHEN RID.Jobkey IS NULL THEN @c_LocationCategory ELSE LOC.LocationCategory END'
                       + ' AND LOC.Putawayzone <> @c_Putawayzone'
                       + ' AND LOTxLOCxID.STORERKEY = @c_StorerKey'
                       + ' AND LOTxLOCxID.SKU = @c_SKU'
                       + ' AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(RSV.QtyReserved,0) >= @n_UOMBase'	--(Wan01)
                       + ' AND LOT.Qty - ISNULL(p.QtyPreAllocated,0) >= @n_UOMBase'
                       + ' AND s.LocationType NOT IN (''PICK'',''CASE'')'
                       + ' AND ID.STATUS = CASE WHEN RID.Jobkey IS NULL THEN ''OK'' ELSE ''HOLD'' END'               				--(Wan01)
                       + ' ' + @c_OtherStatement  
                       + ' ORDER BY CASE WHEN LOTATTRIBUTE.Lottable03 = ''PREWORK'' THEN  LOTATTRIBUTE.Lottable03 ELSE '''' END DESC'
                       +          ',ISNULL(LOTATTRIBUTE.Lottable04,''1900-01-01'')'
                       +          ',ISNULL(LOTATTRIBUTE.Lottable05,''1900-01-01'')'
                       +         ' ,MS.NoOfSku DESC'                                                                             --(Wan01)


   SET @c_SQLArguements= N'@c_Facility          NVARCHAR(5)'
                       + ',@c_LocationCategory  NVARCHAR(10)'
                       + ',@c_Putawayzone       NVARCHAR(10)'
                       + ',@c_JobKey            NVARCHAR(10)'                       
                       + ',@c_StorerKey         NVARCHAR(15)'
                       + ',@c_SKU               NVARCHAR(20)'
                       + ',@n_UOMBase           INT'

   EXEC sp_ExecuteSQL @c_SQLStatement
                     ,@c_SQLArguements
                     ,@c_Facility
                     ,@c_LocationCategory 
                     ,@c_Putawayzone
                     ,@c_JobKey                     
                     ,@c_StorerKey
                     ,@c_SKU 
                     ,@n_UOMBase

 
END  

GO