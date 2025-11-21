SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispVASSTD                                          */
/* Creation Date: 14-Dec-2012                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: AllocateStrategy                                            */
/*                                                                      */
/* Called By: nspOrderProcessing                                        */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 26-09-2014   CSCHONG  1.0  Added Lottables 06-15 (CS01)              */
/************************************************************************/ 
CREATE PROC  [dbo].[ispVASSTD]      
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
  
   DECLARE @b_success         INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(250)

   DECLARE @c_SQLStatement    NVARCHAR(4000)
         , @c_SQLArguements   NVARCHAR(4000)
         , @c_OtherStatement  NVARCHAR(4000)
         , @c_SortOrder       NVARCHAR(4000)

         , @c_Lottable04Label NVARCHAR(20)
         , @n_ShelfLife       INT

   SET @b_success          = 0
   SEt @n_err              = 0
   SET @c_errmsg           = ''

   SET @c_SQLStatement     = ''
   SET @c_SQLArguements    = ''
   SET @c_OtherStatement   = ''
   SET @c_SortOrder        = ''
   SET @c_Lottable04Label  = ''


   SET @c_OtherStatement = ''  

   IF RTRIM(@c_Lottable01) <> ''
   BEGIN  
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable01= N''' + RTRIM(@c_Lottable01) + ''''
   END  
      
   IF RTRIM(@c_Lottable02) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable02= N''' + RTRIM(@c_Lottable02) + ''''  
   END 

   IF RTRIM(@c_Lottable03) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable03= N''' + RTRIM(@c_Lottable03) + ''''   
   END 
   
   IF CONVERT(NVARCHAR(8),@d_Lottable04,112) <> '19000101'  
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable04 = ''' + CONVERT(NVARCHAR(20),@d_Lottable04,106) + ''''
   END  
   
   IF CONVERT(NVARCHAR(8),@d_Lottable05,112) <> '19000101' 
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable05 = ''' + CONVERT(NVARCHAR(20),@d_Lottable05,106) + '''' 
   END 

  /*CS01 start*/

  IF RTRIM(@c_Lottable06) <> ''
   BEGIN  
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable06= N''' + RTRIM(@c_Lottable06) + ''''
   END  
      
   IF RTRIM(@c_Lottable07) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable07= N''' + RTRIM(@c_Lottable07) + ''''  
   END 

   IF RTRIM(@c_Lottable08) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable08= N''' + RTRIM(@c_Lottable08) + ''''   
   END 

   IF RTRIM(@c_Lottable09) <> ''
   BEGIN  
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable09= N''' + RTRIM(@c_Lottable09) + ''''
   END  
      
   IF RTRIM(@c_Lottable10) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable10= N''' + RTRIM(@c_Lottable10) + ''''  
   END 

   IF RTRIM(@c_Lottable11) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable11= N''' + RTRIM(@c_Lottable11) + ''''   
   END 

   IF RTRIM(@c_Lottable12) <> ''
   BEGIN   
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable12= N''' + RTRIM(@c_Lottable12) + ''''   
   END 
   
   IF CONVERT(NVARCHAR(8),@d_Lottable13,112) <> '19000101'  
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable13 = ''' + CONVERT(NVARCHAR(20),@d_Lottable13,106) + ''''
   END
   
   IF CONVERT(NVARCHAR(8),@d_Lottable14,112) <> '19000101' 
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable14 = ''' + CONVERT(NVARCHAR(20),@d_Lottable14,106) + ''''
   END  
   
   IF CONVERT(NVARCHAR(8),@d_Lottable15,112) <> '19000101' 
   BEGIN 
      SET @c_OtherStatement =  RTRIM(@c_OtherStatement) + ' AND Lottable15 = ''' + CONVERT(NVARCHAR(20),@d_Lottable15,106) + '''' 
   END 

  /*Cs01 End*/

   SELECT @c_Lottable04Label = ISNULL(Lottable04Label, '') 
   FROM  SKU WITH (NOLOCK)
   WHERE Storerkey = @c_StorerKey
   AND   Sku = @c_sku
   
   SET @c_SortOrder = ' ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot'      


   -- Min Shelf Life Checking
   IF RTRIM(@c_Lottable04Label) IS NOT NULL AND RTRIM(@c_Lottable04Label) <> '' 
   BEGIN
      IF LEFT(@c_lot,1) = '*'
      BEGIN  
         SET @n_ShelfLife = REPLACE(@c_lot, '*', '') 
                
         DECLARE @c_MinShelfLife60Mth CHAR(1)
         SET @b_success = 0
         Execute nspGetRight
                  NULL                          -- Facility
               ,  @c_storerkey                  -- Storer
               ,  null                          -- Sku
               ,  'MinShelfLife60Mth'  
               ,  @b_success              OUTPUT   
               ,  @c_MinShelfLife60Mth    OUTPUT  
               ,  @n_err                  OUTPUT 
               ,  @c_errmsg               OUTPUT 

         IF @b_success <> 1
         BEGIN
            SET @c_errmsg = 'nspVAStd3 : ' + RTRIM(@c_errmsg)
         END            

         IF @c_MinShelfLife60Mth = '1' 
         BEGIN
            IF @n_ShelfLife < 61    
               SET @c_OtherStatement = RTRIM(@c_OtherStatement) + ' AND CONVERT(VARCHAR(8),ISNULL(Lottable04,''1900-01-01''), 112) >= ''' + CONVERT(VARCHAR(8), DATEADD(MONTH, @n_ShelfLife, GETDATE()), 112) + ''''
            ELSE
               SET @c_OtherStatement = RTRIM(@c_OtherStatement) + ' AND CONVERT(VARCHAR(8),ISNULL(Lottable04,''1900-01-01''), 112) >= ''' + CONVERT(VARCHAR(8), DATEADD(DAY, @n_ShelfLife, GETDATE()), 112) + ''''
         END
         ELSE
         BEGIN
            IF @n_ShelfLife < 13    
               SET @c_OtherStatement = RTRIM(@c_OtherStatement) + ' AND CONVERT(VARCHAR(8),ISNULL(Lottable04,''1900-01-01''), 112) >= ''' + CONVERT(VARCHAR(8), DATEADD(MONTH, @n_ShelfLife, GETDATE()), 112) + ''''
            ELSE
               SET @c_OtherStatement = RTRIM(@c_OtherStatement) + ' AND CONVERT(VARCHAR(8),ISNULL(Lottable04,''1900-01-01''), 112) >= ''' + CONVERT(VARCHAR(8), DATEADD(DAY, @n_ShelfLife, GETDATE()), 112) + ''''
         END            
      
      END
      ELSE
      BEGIN
         -- if Shelf Life not provided, filter Lottable04 < Today date 
         SET @c_OtherStatement = RTRIM(@c_OtherStatement) + ' AND CONVERT(VARCHAR(8),Lottable04, 112) >= ''' + CONVERT(VARCHAR(8), GETDATE(), 112) + ''''
      END 
   END

   SET @c_SQLStatement = N'DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR'
                       + ' SELECT LOTxLOCxID.LOT'
                       + ',LOTxLOCxID.LOC'
                       + ',LOTxLOCxID.ID'
                       + ',QTYAVAILABLE = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated -'
                       +                 ' LOTxLOCxID.QtyPicked)'
                       + ',''1'''
                       + ' FROM LOTxLOCxID WITH (NOLOCK)'
                       + ' JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)'
                       + ' JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')'
                       + ' JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')'
                       + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT'
                       + ' JOIN SKUxLOC s WITH (NOLOCK) ON s.StorerKey = LOTxLOCxID.StorerKey AND s.Sku = LOTxLOCxID.Sku AND s.Loc = LOTxLOCxID.Loc'
                       + ' JOIN SKU (NOLOCK) ON SKU.StorerKey = s.StorerKey AND SKU.Sku = s.Sku'
                       + ' LEFT OUTER JOIN (SELECT PP.lot, OH.facility, QtyPreallocated = ISNULL(SUM(PP.Qty),0)'  
                       +                  ' FROM PREALLOCATEPICKDETAIL PP WITH (NOLOCK)'
                       +                  ' JOIN  ORDERS OH WITH(NOLOCK) ON (PP.Orderkey = OH.Orderkey)'
                       +                  ' WHERE PP.Storerkey = @c_Storerkey'  
                       +                  ' AND   PP.SKU = @c_Sku'  
                       +                  ' AND   OH.Facility = @c_Facility' 
                       +                  ' GROUP BY PP.Lot, OH.Facility) p' 
                       +                  ' ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility' 
                       + ' WHERE LOC.LocationFlag <> ''HOLD'''
                       + ' AND LOC.LocationFlag <> ''DAMAGE'''
                       + ' AND LOC.Status <> ''HOLD'''
                       + ' AND LOC.Facility = @c_Facility'
                       + ' AND LOTxLOCxID.STORERKEY = @c_StorerKey'
                       + ' AND LOTxLOCxID.SKU = @c_SKU'
                       + ' AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked >= @n_UOMBase'
                       + ' AND LOT.Qty - ISNULL(p.QtyPreAllocated,0) >= @n_UOMBase'
                       + ' AND s.LocationType NOT IN (''PICK'',''CASE'')'
                       + ' ' + @c_OtherStatement  
                       + ' ' + @c_SortOrder

   SET @c_SQLArguements= N'@c_Facility    NVARCHAR(5)'
                       + ',@c_StorerKey   NVARCHAR(15)'
                       + ',@c_SKU         NVARCHAR(20)'
                       + ',@n_UOMBase     INT'

   EXEC sp_ExecuteSQL @c_SQLStatement
                     ,@c_SQLArguements
                     ,@c_Facility
                     ,@c_StorerKey
                     ,@c_SKU 
                     ,@n_UOMBase

 
END  

GO