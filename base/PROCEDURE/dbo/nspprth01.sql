SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: nspPRTH01                                          */    
/* Creation Date: 17-JUL-2012                                           */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: SOS#248737:06700-Diversey Hygience TH_CR_Allocation Strategy*/    
/*                                                                      */    
/* Called By: nspOrderProcessing                                        */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver. Purposes                                   */    
/* 24-Jul-2018  NJOW01  1.0  WMS-5836 Add more filtering                */    
/* 01-Oct-2018  CHEEMUN 1.1  INC0411478 - Lotattribute Lottables        */     
/* 28-Nov-2018  CSCHONG 1.2  WMS-7041 - Revised sorting rule (CS01)     */    
/* 29-Aug-2019  SPChin  1.3  INC0834464 - Bug Fixed                     */    
/* 14-Sep-2020  SPChin  1.4  INC1189002 - Bug Fixed                     */    
/************************************************************************/    
    
CREATE PROC [dbo].[nspPRTH01]    
         @c_Storerkey   NVARCHAR(15)     
      ,  @c_Sku         NVARCHAR(20)     
      ,  @c_Lot         NVARCHAR(10)     
      ,  @c_Lottable01  NVARCHAR(18)     
      ,  @c_Lottable02  NVARCHAR(18)     
      ,  @c_Lottable03  NVARCHAR(18)     
      ,  @d_Lottable04  DATETIME     
      ,  @d_Lottable05  DATETIME      
      ,  @c_lottable06 NVARCHAR(30)       
      ,  @c_lottable07 NVARCHAR(30)       
      ,  @c_lottable08 NVARCHAR(30)      
      ,  @c_lottable09 NVARCHAR(30)      
      ,  @c_lottable10 NVARCHAR(30)      
      ,  @c_lottable11 NVARCHAR(30)      
      ,  @c_lottable12 NVARCHAR(30)      
      ,  @d_lottable13 DATETIME         
      ,  @d_lottable14 DATETIME           
      ,  @d_lottable15 DATETIME         
      ,  @c_UOM         NVARCHAR(10)      
      ,  @c_Facility    NVARCHAR(5)     -- added By Vicky for IDSV5     
      ,  @n_UOMBase     INT      
      ,  @n_QtyLeftToFulfill INT    
      ,  @c_OtherParms  NVARCHAR(200) = ''    
    
AS    
BEGIN    
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF       
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @b_Success                  INT    
         , @n_Err                      INT    
         , @c_ErrMsg                   NVARCHAR(255)    
         , @n_StorerMinShelfLife       INT    
         , @c_AllocateByConsNewExpiry  NVARCHAR(10)    
         , @c_FromTableJoin            NVARCHAR(500)    
         , @c_Where                    NVARCHAR(500)    
         , @c_Condition                NVARCHAR(510)    
         , @c_SQLStatement             NVARCHAR(4000)     
    
   --NJOW01    
   DECLARE @c_Orderkey            NVARCHAR(10),    
           @c_OrderLineNumber     NVARCHAR(5),    
           @c_ID                  NVARCHAR(18),                                     
           @n_OutGoingShelfLife   INT,    
           @n_ConsShelfLife       INT,    
           @n_Shelflife           INT,    
     @c_SetSortingRule      NVARCHAR(10),       --CS01           
     @c_SortBy              NVARCHAR(4000),     --CS01    
     @c_ExecStatements      NVARCHAR(4000),     --CS01      
     @c_ExecArguments       NVARCHAR(4000)      --CS01    
    
    
   SELECT  @n_StorerMinShelfLife = 0,    
           @n_OutGoingShelfLife = 0,    
           @n_ConsShelfLife = 0,    
           @n_Shelflife = 0    
    
   SET @c_AllocateByConsNewExpiry= ''    
   SET @c_FromTableJoin          = ''    
   SET @c_Where                  = ''    
   SET @c_Condition              = ''    
   SET @c_SQLStatement           = ''    
   SET @c_SortBy   = ''    
    
    
   --CS01 Start    
    
    IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK)      
             WHERE ListName = 'PKCODECFG'      
             AND Storerkey = @c_Storerkey      
             AND Code = 'SetSortingRule'      
             AND Long = 'nspPRTH01'      
             AND ISNULL(Short,'') <> 'N')      
     BEGIN    
      SET @c_SetSortingRule = 'Y'      
   END    
   ELSE      
   BEGIN    
      SET @c_SetSortingRule = 'N'      
  END    
    
   --CS01 End    
    
   --NJOW01    
   IF LEN(@c_OtherParms) > 0     
   BEGIN    
      SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)    
      SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)    
          
      SELECT @c_ID = ID    
      FROM ORDERDETAIL(NOLOCK)    
      WHERE Orderkey = @c_Orderkey    
      AND OrderLineNumber = @c_OrderLineNumber          
   END    
    
   IF ISNULL(RTRIM(@c_Lot),'') = ''     
   BEGIN    
      /* Get Storer Minimum Shelf Life */    
      SELECT @n_StorerMinShelfLife = ((SKU.Shelflife * STORER.MinShelflife/100) * -1),    
             @n_OutGoingShelfLife = ISNULL(CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN    
                                         CAST(SKU.Susr2 AS INT)    
                                     ELSE 0 END, 0) * -1  --NJOW01    
      FROM STORER WITH (NOLOCK)    
      JOIN SKU WITH (NOLOCK) ON (STORER.Storerkey = SKU.Storerkey)    
      WHERE STORER.Storerkey = @c_Storerkey    
      AND SKU.Facility = @c_Facility    
      AND SKU.SKU = @c_Sku --INC1189002    
    
      IF @n_StorerMinShelfLife IS NULL SET @n_StorerMinShelfLife = 0    
       
      --NJOW01 Start    
      SELECT TOP 1 @n_ConsShelfLife = ISNULL(D.Shelflife,0) * -1    
      FROM ORDERS O (NOLOCK)    
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey    
      JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey    
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku    
      JOIN DOCLKUP D(NOLOCK) ON S.CustomerGroupCode = D.ConsigneeGroup AND SKU.SkuGroup = D.SkuGroup             
      WHERE O.Orderkey = @c_Orderkey    
      AND OD.Sku = @c_Sku    
    
      IF @n_ConsShelfLife <> 0    
         SELECT @n_Shelflife = @n_ConsShelfLife    
      ELSE IF @n_OutGoingShelfLife <> 0     
         SELECT @n_Shelflife = @n_OutGoingShelfLife           
      ELSE IF @n_StorerMinShelfLife <> 0    
         SELECT @n_Shelflife = @n_StorerMinShelfLife           
      ELSE    
         SELECT @n_Shelflife = 0                           
      --NJOW01 End          
          
      --INC0411478 (START)      
      IF ISNULL(RTRIM(@c_Lottable01),'') <> ''        
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE01 = N''' + RTRIM(@c_Lottable01) + ''''      
      END      
      IF ISNULL(RTRIM(@c_Lottable02),'') <> ''       
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE02 = N''' + RTRIM(@c_Lottable02) + ''''      
      END      
      IF ISNULL(RTRIM(@c_Lottable03),'') <> ''       
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE03 = N''' + RTRIM(@c_Lottable03) + ''''      
      END      
      IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> '01/01/1900' AND @d_Lottable04 IS NOT NULL      
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE04 = ''' + CONVERT(NVARCHAR(20), @d_Lottable04, 106) + ''''      
      END      
      IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> '01/01/1900' AND @d_Lottable05 IS NOT NULL      
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE05 = ''' + CONVERT(NVARCHAR(20), @d_Lottable05, 106) + ''''      
      END      
            
      --NJOW01      
      IF ISNULL(RTRIM(@c_Lottable06),'') <> ''       
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE06 = N''' + RTRIM(@c_Lottable06) + ''''  --INC0834464     
      END      
      IF ISNULL(RTRIM(@c_Lottable07),'') <> ''       
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE07 = N''' + RTRIM(@c_Lottable07) + ''''  --INC0834464    
      END      
      IF ISNULL(RTRIM(@c_Lottable08),'') <> ''       
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE08 = N''' + RTRIM(@c_Lottable08) + ''''  --INC0834464    
      END      
      IF ISNULL(RTRIM(@c_Lottable09),'') <> ''       
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE09 = N''' + RTRIM(@c_Lottable09) + ''''  --INC0834464    
      END      
      IF ISNULL(RTRIM(@c_Lottable10),'') <> ''       
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE10 = N''' + RTRIM(@c_Lottable10) + ''''  --INC0834464    
      END      
      IF ISNULL(RTRIM(@c_Lottable11),'') <> ''       
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE11 = N''' + RTRIM(@c_Lottable11) + ''''  --INC0834464    
      END      
      IF ISNULL(RTRIM(@c_Lottable12),'') <> ''       
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE12 = N''' + RTRIM(@c_Lottable12) + ''''  --INC0834464    
      END      
      IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL      
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE13 = ''' + CONVERT(NVARCHAR(20), @d_Lottable13, 106) + ''''      
      END      
      IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL      
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE14 = ''' + CONVERT(NVARCHAR(20), @d_Lottable14, 106) + ''''      
      END      
      IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL      
      BEGIN      
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE15 = ''' + CONVERT(NVARCHAR(20), @d_Lottable15, 106) + ''''      
      END      
      --INC0411478 (END)    
    
      --NJOW01    
      IF @n_ShelfLife <> 0    
      BEGIN    
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND DateAdd(Day, ' + CAST(@n_ShelfLife AS NVARCHAR(10)) + ', Lotattribute.Lottable04) > GetDate() '     
      END           
      IF ISNULL(@c_ID,'') <> ''    
      BEGIN    
        SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOTxLOCxID.Id = N''' + RTRIM(@c_ID) + ''' '    
      END    
    
      /*    
      IF @n_StorerMinShelfLife <> 0    
      BEGIN    
         SET @c_Condition = @c_Condition + ' AND DateAdd(Day, ' + CONVERT(NVARCHAR(10),@n_StorerMinShelfLife)     
                          + ', LOTATTRIBUTE.Lottable04) > GetDate()'     
      END     
      */    
    
   --CS01 Start    
   IF @c_SetSortingRule='N'    
   BEGIN    
     SET @c_SortBy = ' ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot'     
     END    
  ELSE    
  BEGIN    
    SET @c_SortBy = ' ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02,LOT.Lot'    
  END    
   --CS01 End    
    
      SET @b_success = 0    
      EXECUTE dbo.nspGetRight @c_facility    
            ,  @c_Storerkey                     -- Storerkey    
            ,  NULL                             -- Sku    
            ,  'AllocateByConsNewExpiry'        -- Configkey    
            ,  @b_Success                 OUTPUT    
            ,  @c_AllocateByConsNewExpiry OUTPUT     
            ,  @n_Err                     OUTPUT    
            ,  @c_errmsg                  OUTPUT    
          
      IF @c_AllocateByConsNewExpiry = '1'   
         AND EXISTS (SELECT 1      
                     FROM STORER WITH (NOLOCK)    
                     JOIN ORDERS WITH (NOLOCK) ON (STORER.Storerkey = ORDERS.Consigneekey)    
                     WHERE ORDERS.Orderkey = LEFT(RTRIM(@c_OtherParms),10)    
                     AND STORER.SUSR1 = 'nspPRTH01')    
      BEGIN    
         SET @c_FromTableJoin = ' FROM ORDERS WITH (NOLOCK)'    
                      + ' JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)'    
                      + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = LOTATTRIBUTE.Storerkey)'     
                      +                                 ' AND(ORDERDETAIL.Sku = LOTATTRIBUTE.Sku)'    
                      + ' LEFT JOIN CONSIGNEESKU WITH (NOLOCK) ON (ORDERS.Consigneekey = CONSIGNEESKU.Consigneekey)'    
                      +                                 ' AND(LOTATTRIBUTE.Sku = CONSIGNEESKU.ConsigneeSku)'    
         SET @c_Where = ' WHERE ORDERS.Orderkey = ''' + LEFT(RTRIM(@c_OtherParms),10) + ''''      
                      + ' AND ORDERDETAIL.OrderLineNumber = ''' + SUBSTRING(RTRIM(@c_OtherParms),11,5) + ''''     
                      + ' AND LOTATTRIBUTE.Storerkey = N''' + RTRIM(@c_Storerkey) + ''''    
                      + ' AND(LOTATTRIBUTE.Lottable04 >= ISNULL(CONSIGNEESKU.AddDate,CONVERT(DATETIME,''19000101'')))'    
    
      END    
      ELSE    
      BEGIN    
         SET @c_FromTableJoin = ' FROM LOTATTRIBUTE WITH (NOLOCK)'     
         SET @c_Where = ' WHERE LOTATTRIBUTE.Storerkey = N''' + RTRIM(@c_Storerkey) + ''''     
    
      END    
           
      SET @c_SQLStatement =  N' DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR'      
         + ' SELECT LOT.Storerkey, LOT.Sku, LOT.Lot,'      
         + ' QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED)'    
         +              ' - MAX(LOT.QTYPREALLOCATED) )'      
         + @c_FromTableJoin    
         + ' JOIN LOT         WITH (NOLOCK) ON (LOTATTRIBUTE.Lot = LOT.Lot) AND (LOT.STATUS = ''OK'')'    
         + ' JOIN LOTxLOCxID  WITH (NOLOCK) ON (LOT.LOT = LOTxLOCxID.Lot)'    
         + ' JOIN LOC         WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc) AND (LOC.STATUS = ''OK'')'    
         +                                 'AND(LOC.LocationFlag = ''NONE'')'    
         + ' JOIN ID          WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.Id)'    
         +                                 'AND(ID.STATUS = ''OK'')'    
         + @c_Where     
         + ' AND   LOTATTRIBUTE.Sku = N''' + RTRIM(@c_Sku) + ''''     
         + ' AND   LOC.Facility = N''' + RTRIM(@c_Facility) + ''''     
         + @c_Condition     
         + ' GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04,LOTATTRIBUTE.Lottable02'    
         + ' HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED)'    
         +      ' - MAX(LOT.QTYPREALLOCATED) > 0 '     
        -- + ' ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot'            --CS01    
   + CHAR(13) + @c_SortBy     
    
      EXEC(@c_SQLStatement)               
    
       
    
   -- print @c_SQLStatement    
   --CS01 End    
   END    
END 

GO