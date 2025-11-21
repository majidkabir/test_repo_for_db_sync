SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Stored Procedure: nspALHM01                                          */  
/* Creation Date: 08-Feb-2018                                           */  
/* Copyright: LFL                                                       */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-3888 - [CN] H&M Allocation Strategy Change Request      */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver.  Purposes                                  */  
/* 15-MAR-2018  Wan01   1.1   Not allow allocate from LotxLocxId if     */  
/*                            Any BUFFER locationtype is qtyallcoated & */  
/*                            replenishing to PICK Face                 */    
/* 23-Aug-2018  TLTING01 1.2  Dynamic SQL Cache recompile               */  
/* 11-Nov-2018  James    1.3  Add -QtyReplen (james01) (NJOW)           */  
/* 27-Aug-2019  AikLiang 1.4  Add new filtr Lottable03='STD'  (AL01)    */ 
/* 11-Sep-2019  CSCHONG  1.4  WMS-10492 add sorting logic (CS01)        */
/* 30-Dec-2019  WLChooi  1.5  INC0988639 - Filter out Orders where      */
/*                            Orders.SOStatus =  'PENDCANC' (WL01)      */
/* 13-Jan-2020  WLChooi  1.6  INC0988639 - Filter out Orders where      */
/*                            Orders.SOStatus =  'CANC' (WL02)          */
/************************************************************************/  

CREATE PROCEDURE [dbo].[nspALHM01]  
    @c_Orderkey   NVARCHAR(10)    
   ,@c_Facility   NVARCHAR(5)       
   ,@c_StorerKey  NVARCHAR(15)       
   ,@c_SKU        NVARCHAR(20)      
   ,@c_Lottable01 NVARCHAR(18)      
   ,@c_Lottable02 NVARCHAR(18)      
   ,@c_Lottable03 NVARCHAR(18)      
   ,@d_Lottable04 DATETIME      
   ,@d_Lottable05 DATETIME      
   ,@c_Lottable06 NVARCHAR(30)      
   ,@c_Lottable07 NVARCHAR(30)      
   ,@c_Lottable08 NVARCHAR(30)      
   ,@c_Lottable09 NVARCHAR(30)      
   ,@c_Lottable10 NVARCHAR(30)      
   ,@c_Lottable11 NVARCHAR(30)      
   ,@c_Lottable12 NVARCHAR(30)      
   ,@d_Lottable13 DATETIME      
   ,@d_Lottable14 DATETIME      
   ,@d_Lottable15 DATETIME      
   ,@c_UOM        NVARCHAR(10)      
   ,@c_HostWHCode NVARCHAR(10)      
   ,@n_UOMBase    INT      
   ,@n_QtyLeftToFulfill INT  
   ,@c_OtherParms NVARCHAR(200)=''  
AS  
BEGIN  
   DECLARE --@c_Orderkey           NVARCHAR(10)  
           @c_OrderLineNumber    NVARCHAR(5)  
  
   DECLARE @c_MinShelfLife60Mth  NVARCHAR(1)  
         , @c_ShelfLifeInDays    NVARCHAR(1)  
  
   DECLARE @b_success            INT  
         , @n_err                INT  
         , @c_errmsg             NVARCHAR(250)  
         , @b_debug              BIT  
  
         , @c_SQL                NVARCHAR(MAX)  
  
   DECLARE @c_manual             NVARCHAR(1)  
   DECLARE @c_LimitString        NVARCHAR(255) -- To limit the where clause based on the user input  
   DECLARE @c_lottable04label    NVARCHAR(20)  
  
   DECLARE @n_shelflife          INT  
  
   DECLARE @c_UOMBase            NVARCHAR(10)  
   DECLARE @c_SQLStatement       NVARCHAR(4000),  
           @c_ExecArgument       NVARCHAR(4000),
           @c_SQLSorting         NVARCHAR(250),      --CS01
           @c_CUDF01             NVARCHAR(20),       --CS01     
           @c_Status             NVARCHAR(10),       --WL01
           @n_continue           INT                 --WL01
  
   SET @b_success = 0  
   SET @n_err     = 0  
   SET @c_errmsg  = ''  
   SET @b_debug   = 0  
   SET @c_manual  = 'N'  
   SET @c_CUDF01 = ''     --CS01
   SET @c_SQLSorting = ''
   SET @n_continue = 1  --WL01
  
   IF @b_debug = 1  
   BEGIN  
      SELECT @c_OtherParms  
   END  
  
   SET @c_UOMBase = @n_uombase  
  
   IF ISNULL(@c_OtherParms,'') <> ''  
   BEGIN  
      SET @c_Orderkey = LEFT(@c_OtherParms,10)  
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11,5)  
  
      SELECT @n_shelflife = MinShelfLife  
      FROM ORDERDETAIL WITH (NOLOCK)  
      WHERE Orderkey =@c_Orderkey  
      AND OrderLineNumber = @c_OrderLineNumber  
      
      --WL01 Start
      SELECT @c_Status = [SOStatus]
      FROM ORDERS (NOLOCK)
      WHERE ORDERKEY = @c_Orderkey

      IF @c_Status IN ('PENDCANC','CANC')  --WL02
      BEGIN
         SET @n_continue = 3
         GOTO QUIT_SP
      END
      --WL01 End
   END  


  
   SET @b_Success = 0  
   EXECUTE nspGetRight NULL                 -- Facility  
         ,  @c_StorerKey                    -- Storer  
         ,  NULL                            -- Sku  
         ,  'MinShelfLife60Mth'   
         ,  @b_Success           OUTPUT  
         ,  @c_MinShelfLife60Mth OUTPUT   
         ,  @n_err               OUTPUT   
         ,  @c_errmsg            OUTPUT  
  
   SET @b_Success = 0  
   EXECUTE nspGetRight NULL               -- Facility  
         ,  @c_StorerKey                  -- Storer  
         ,  NULL                          -- Sku  
         ,  'ShelfLifeInDays'   
         ,  @b_Success           OUTPUT   
         ,  @c_ShelfLifeInDays   OUTPUT  
         ,  @n_err               OUTPUT   
         ,  @c_errmsg            OUTPUT  


		 --CS01 START
		 SELECT TOP 1 @c_CUDF01 = ISNULL(C.UDF01,'')
		 FROM CODELKUP C WITH (NOLOCK)
		 WHERE storerkey=@c_storerkey AND listname='HMALLOC'


		 IF ISNULL(@c_CUDF01,'0') = '0' 
		 BEGIN
		 SET @c_SQLSorting = N'ORDER BY LOC.LocationGroup'  
						+ '   ,  LOTATTRIBUTE.Lottable02'  
						+ '   ,  QtyAvailable'  -- v2.1 - change sorting  
						+ '   ,  LOC.LocLevel'  -- v2.1 - change sorting  
						+ '   ,  LOC.LogicalLocation'     
						+ '   ,  LOC.Loc'  
          END
		  ELSE IF ISNULL(@c_CUDF01,'0') = '1' 
		  BEGIN

		  SET @c_SQLSorting = N'ORDER BY LOC.LocationGroup'   
						+ '   ,  QtyAvailable'  -- v2.1 - change sorting  
						+ '   ,  LOC.LocLevel'  -- v2.1 - change sorting  
						+ '   ,  LOC.LogicalLocation'     
						+ '   ,  LOC.Loc'  

		  END
		 --CS01 END
  
   IF @n_ShelfLife IS NULL  
   BEGIN  
      SET @n_ShelfLife = 0  
   END  
   ELSE IF @c_MinShelfLife60Mth = '1'  
   BEGIN  
      IF @n_ShelfLife < 61  
         SET @n_ShelfLife = @n_ShelfLife * 30  
   END  
   ELSE IF @c_ShelfLifeInDays = '1'  
   BEGIN  
      SET @n_ShelfLife = @n_ShelfLife  -- No conversion, only in days  
   END                                 -- End Changes - FBR18050 NZMM  
   ELSE IF @n_ShelfLife < 13  
   BEGIN  
      SET @n_ShelfLife = @n_ShelfLife * 30  
   END  
  
   IF @d_lottable04 = '1900-01-01'  
   BEGIN  
      SET @d_lottable04 = null  
   END  
  
   IF @d_lottable05 = '1900-01-01'  
   BEGIN  
      SET @d_lottable05 = null  
   END  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'nspALHM01 : Before Lot Lookup .....'  
      SELECT '@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03  
      SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  , '@c_sku' = @c_sku  
      SELECT '@c_storerkey' = @c_storerkey, '@c_facility' = @c_facility  
   END  
  
   -- when any of the lottables is supplied, get the specific lot  
   IF (@c_lottable01<>'' OR @c_lottable02<>'' OR @c_lottable03<>'' OR  
   @d_lottable04 IS NOT NULL OR @d_lottable05 IS NOT NULL) OR @n_ShelfLife > 0  
   BEGIN  
      SET @c_manual = 'Y'  
   END  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'nspALHM01 : After Lot Lookup .....'  
      SELECT '@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03  
      SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  
      SELECT '@c_storerkey' = @c_storerkey  
   END  
  
   /* Everything Else when no lottable supplied */  
   IF @c_manual = 'N'  
   BEGIN  
      IF @b_debug = 1  
      BEGIN  
         SELECT 'MANUAL = N'  
      END  
  
      SELECT @n_shelflife = convert(int, SKU.SUSR2)  
      FROM SKU (NOLOCK)  
      WHERE SKU = @c_sku  
      AND STORERKEY = @c_storerkey  
  
      SELECT @c_lottable04label = SKU.Lottable04label  
      FROM SKU (NOLOCK)  
      WHERE SKU = @c_sku  
      AND STORERKEY = @c_storerkey  
  
      SET @c_LimitString = ''  
  
      IF @c_lottable04label = 'MANDATE'  
      BEGIN  
         IF @n_shelflife > 0  
         BEGIN  
            SET @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + ' AND lottable04  > DateAdd(day, - @n_shelflife, getdate()) '  
         END  
      END  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT 'Manual = N'  
         select 'limitstring' , @c_limitstring  
      END  
   END  
   ELSE  
   BEGIN  
      IF @b_debug =1  
      BEGIN  
         SELECT 'MANUAL = Y'  
      END  
  
      SET @c_LimitString = ''  
  
      IF @c_lottable01 <> ' '  
      SET @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND Lottable01= @c_lottable01 '  
  
      IF @c_lottable02 <> ' '  
      SET @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable02= @c_lottable02 '  
  
      IF @c_lottable03 <> ' '  
      SET @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable03= @c_lottable03 '  
  
      IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'  
      SET @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable04 = @d_lottable04 '  
  
      IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'  
      SET @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable05= @d_lottable05 '  
  
      IF @n_ShelfLife <> 0  
      BEGIN  
         --SET @n_shelflife = convert(int, substring(@c_lot, 2, 9))  
  
         IF @n_shelflife < 13  
         -- it's month  
         BEGIN  
            SET @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + ' AND lottable04  > dateadd(month, @n_shelflife, getdate()) '  
         END  
         ELSE  
         BEGIN  
            SET @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + ' AND lottable04  > DateAdd(day, @n_shelflife, getdate()) '  
         END  
      END  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT 'c_limitstring', @c_limitstring  
      END  
   END  
  
   SET @c_StorerKey = isnull(RTrim(@c_StorerKey),'')  
   SET @c_Sku = isnull(RTrim(@c_SKU),'')  
  
   SET @c_SQLStatement = N' DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  ' +  
   +      ' SELECT LOTXLOCXID.Lot'  
   +      ',LOTXLOCXID.Loc '   
   +      ',LOTXLOCXID.ID '   
   +      ',QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)'  
   +      ',''1'''  
   + ' FROM LOT (NOLOCK)'  
   + ' JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT)'  
   + ' JOIN LOTXLOCXID   (NOLOCK) ON (LOT.LOT = LOTXLOCXID.LOT)'  
   + ' JOIN LOC (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC)'  
   + ' JOIN ID  (NOLOCK) ON (LOTXLOCXID.ID = ID.ID)'   
   + ' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) '   
   +                       ' AND(SKUxLOC.SKU = LOTxLOCxID.SKU)'  
   +                       ' AND(SKUxLOC.LOC = LOTxLOCxID.LOC)'   
   + ' JOIN (SELECT LLI.Lot, LotQtyAvail = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen)'  
   +            ' FROM LOTxLOCxID LLI WITH (NOLOCK)'  
   +            ' JOIN LOC WITH (NOLOCK) ON (LLI.Loc = Loc.Loc)'      
   +            ' WHERE LLI.Storerkey = @c_storerkey '   
   +            ' AND LLI.SKU = @c_sku '     
   +            ' AND LOC.Facility = @c_facility '  
   +            ' GROUP BY LLI.Lot'  
   +            ' HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0 '  
   +            ') FLOT ON FLOT.Lot = LOT.Lot'  
   + ' LEFT JOIN (SELECT PLOT.Lot, QtyPreAllocated = SUM(PLOT.Qty)'  
   +            ' FROM PREALLOCATEPICKDETAIL PLOT WITH (NOLOCK)'  
   +            ' JOIN ORDERS OH WITH (NOLOCK) ON (PLOT.Orderkey = OH.Orderkey)'      
   +            ' WHERE PLOT.Storerkey = @c_storerkey '   
   +            ' AND PLOT.SKU =  @c_sku '    
   +            ' AND OH.Facility = @c_facility '  
   +            ' GROUP BY PLOT.Lot'  
   +            ') P ON P.Lot = LOT.Lot'  
   + ' WHERE LOT.STORERKEY = @c_storerkey '   
   + ' AND LOT.SKU = @c_sku '     
   + ' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'''  
   + ' And LOC.LocationFlag = ''NONE'' '   
   + ' AND LOC.Locationflag <> ''HOLD'''  
   + ' AND LOC.Locationflag <> ''DAMAGE'''  
   + ' AND LOC.LocationType IN(''PICK'', ''PND'', ''BUFFER'')'  
   + ' AND LOTATTRIBUTE.Lottable03 =''STD'''  --AL01
   + ' AND SKUxLOC.LocationType NOT IN (''PICK'', ''CASE'', ''IDZ'', ''FLOW'')'  
   + ' AND LOC.FACILITY = @c_facility '   
   + ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 '  
   + ' AND (FLOT.LotQtyAvail - ISNULL(P.QTYPREALLOCATED,0)) > 0'  
   + ' ' + @c_LimitString   
   --CS01 START
   + '' + @c_SQLSorting 
   --+ ' ORDER BY LOC.LocationGroup'  
   --+ '   ,  LOTATTRIBUTE.Lottable02'  
   --+ '   ,  QtyAvailable'  -- v2.1 - change sorting  
   --+ '   ,  LOC.LocLevel'  -- v2.1 - change sorting  
   --+ '   ,  LOC.LogicalLocation'     
   --+ '   ,  LOC.Loc'    
   
   --CS01 END   
  
   SET @c_ExecArgument =   
         N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +     
          '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +  
          '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +  
         N'@n_shelflife    int  '    
  
   EXEC sp_executesql @c_SQLStatement, @c_ExecArgument,   
                      @c_facility, @c_storerkey, @c_SKU,  @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                      @d_Lottable04, @d_Lottable05, @n_shelflife                                 
                           
QUIT_SP:
   IF @n_continue = 3
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL  
   END 
END  

GO