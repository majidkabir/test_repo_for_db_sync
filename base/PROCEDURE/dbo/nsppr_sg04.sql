SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPR_SG04                                         */
/* Creation Date: 05-OCT-2017                                           */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3044 - PMS Allocation Logic Based on consignee          */
/*                                                                      */
/* Called By: nspPReallocateOrderProcessing                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/

CREATE PROC  [dbo].[nspPR_SG04]   
   @c_storerkey         NVARCHAR(15)  
,  @c_sku               NVARCHAR(20)    
,  @c_lot               NVARCHAR(10)    
,  @c_lottable01        NVARCHAR(18)  
,  @c_lottable02        NVARCHAR(18)  
,  @c_lottable03        NVARCHAR(18)  
,  @d_lottable04        DATETIME      
,  @d_lottable05        DATETIME      
,  @c_lottable06        NVARCHAR(30)   
,  @c_lottable07        NVARCHAR(30)   
,  @c_lottable08        NVARCHAR(30)   
,  @c_lottable09        NVARCHAR(30)   
,  @c_lottable10        NVARCHAR(30)   
,  @c_lottable11        NVARCHAR(30)   
,  @c_lottable12        NVARCHAR(30)   
,  @d_lottable13        DATETIME       
,  @d_lottable14        DATETIME       
,  @d_lottable15        DATETIME       
,  @c_uom               NVARCHAR(10)         
,  @c_facility          NVARCHAR(10)     
,  @n_uombase           INT  
,  @n_qtylefttofulfill  INT 
,  @c_OtherParms        NVARCHAR(200) = ''  --Orderinfo4PreAllocation   
AS
BEGIN
   DECLARE @c_Condition          NVARCHAR(4000)    
         , @c_SQLStatement       NVARCHAR(4000) 
         , @c_SQLArgument        NVARCHAR(4000)

         , @c_Orderkey           NVARCHAR(10)

   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN 
      SET @c_Orderkey = LEFT(@c_OtherParms,10)
   END 
   
   IF EXISTS ( SELECT 1 
               FROM ORDERS OH WITH (NOLOCK)
               WHERE OH.Orderkey = @c_Orderkey     
               AND   OH.ConsigneeKey <> 'PMS1'
             )
   BEGIN
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT TOP 1 LOT.Storerkey,LOT.Sku,LOT.Lot  
            ,QtyAvailable = 0
      FROM LOT WITH (NOLOCK)  
      WHERE 1=2

      GOTO QUIT_SP
   END
         
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.Storerkey,LOT.Sku,LOT.Lot  
            ,QtyAvailable = SUM(LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyOnHold - LOT.QtyPreallocated)
      FROM LOTxLOCxID WITH (NOLOCK)  
      JOIN LOT WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
                             AND(LOT.Status = 'OK')
      JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc) 
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)
      LEFT JOIN ( SELECT P.Lot, O.Facility, PreAllocatedQty = SUM(P.Qty) 
                  FROM ORDERS O WITH (NOLOCK)
                  JOIN PREALLOCATEPICKDETAIL P WITH (NOLOCK) ON (O.Orderkey = P.Orderkey)
                  WHERE O.Facility = @c_Facility
                  AND   O.Storerkey= @c_Storerkey
                  AND   O.Status < '9'
                  GROUP BY P.Lot, O.Facility) PR
                  ON (LOTxLOCxID.Lot = PR.Lot)
                  AND(LOC.Facility = PR.Facility) 
      WHERE LOT.LOT = @c_lot
      AND   LOC.Facility = @c_Facility
      AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOT.QtyOnHold - ISNULL(PR.PreAllocatedQty,0) > 0
      GROUP BY LOT.Storerkey, LOT.Sku, LOT.Lot 
      ORDER BY LOT.LOT

      GOTO QUIT_SP
   END

   SET @c_Condition = ''
      
   IF RTRIM(@c_Lottable01) <> '' AND @c_Lottable01 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01' 
   END   
      
   IF RTRIM(@c_Lottable02) <> '' AND @c_Lottable02 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02' 
   END   
      
   IF RTRIM(@c_Lottable03) <> '' AND @c_Lottable03 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03' 
   END   
      
   IF CONVERT(CHAR(8), @d_Lottable04, 112) <> '19000101'
   BEGIN
      SET @d_Lottable04 = CONVERT(DATETIME, CONVERT(CHAR(8), @d_Lottable04, 112))
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable04 = @d_Lottable04'
   END
      
   IF CONVERT(CHAR(8), @d_Lottable05, 112) <> '19000101'
   BEGIN
      SET @d_Lottable05 = CONVERT(DATETIME, CONVERT(CHAR(8), @d_Lottable05, 112))
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable05 = @d_Lottable05'
   END
      
   IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06' 
   END   
      
   IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07' 
   END   
      
   IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08' 
   END   
      
   IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09' 
   END   
      
   IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10' 
   END   
      
   IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11' 
   END   
      
   IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12' 
   END  
      
   IF CONVERT(CHAR(8), @d_Lottable13, 112) <> '19000101'
   BEGIN
      SET @d_Lottable13 = CONVERT(DATETIME, CONVERT(CHAR(8), @d_Lottable13, 112))
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable13 = @c_Lottable13'
   END
      
   IF CONVERT(CHAR(8), @d_Lottable14, 112) <> '19000101'
   BEGIN
      SET @d_Lottable14 = CONVERT(DATETIME, CONVERT(CHAR(8), @d_Lottable14, 112))
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable14 = @d_Lottable14'
   END
      
   IF CONVERT(CHAR(8), @d_Lottable15, 112) <> '19000101'
   BEGIN
      SET @d_Lottable15 = CONVERT(DATETIME, CONVERT(CHAR(8), @d_Lottable15, 112))
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable15 = @d_Lottable15'
   END   

   SET @c_SQLStatement = N'DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR'
                        + ' SELECT LOT.Storerkey, LOT.Sku, LOT.Lot  ,'
                        + ' QtyAvailable = SUM(LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyOnHold -  LOT.QtyPreallocated)'
                        + ' FROM LOTxLOCxID WITH (NOLOCK)'
                        + ' JOIN LOT WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)'
                        +                        ' AND(LOT.Status = ''OK'')'
                        + ' JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)'
                        +                        ' AND(LOC.Status = ''OK'')'
                        + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)'
                        + ' LEFT JOIN ( SELECT P.Lot, O.Facility, PreAllocatedQty = SUM(P.Qty)' 
                        +             ' FROM ORDERS O WITH (NOLOCK)'
                        +             ' JOIN PREALLOCATEPICKDETAIL P WITH (NOLOCK) ON (O.Orderkey = P.Orderkey)'
                        +             ' WHERE O.Facility = @c_Facility'
                        +             ' AND   O.Storerkey= @c_Storerkey'
                        +             ' AND   O.Status < ''9'''
                        +             ' GROUP BY P.Lot, O.Facility) PR'
                        +             ' ON (LOTxLOCxID.Lot = PR.Lot)'
                        +             ' AND(LOC.Facility = PR.Facility)' 
                        + ' WHERE LOTxLOCxID.Storerkey = @c_Storerkey'
                        + ' AND   LOTxLOCxID.Sku       = @c_Sku'
                        + ' AND   LOC.Facility         = @c_Facility'
                        + ' AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOT.QtyOnHold -  ISNULL(PR.PreAllocatedQty,0) > 0'
                        + @c_Condition
                        + ' GROUP BY LOT.Storerkey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable15'
                        + ' ORDER BY LOTATTRIBUTE.Lottable15, LOT.Lot'

   SET @c_SQLArgument = N'@c_Facility     NVARCHAR(5)'
                      + ',@c_Storerkey    NVARCHAR(10)'
                      + ',@c_Sku          NVARCHAR(20)'
                      + ',@c_lottable01   NVARCHAR(18)'  
                      + ',@c_lottable02   NVARCHAR(18)'  
                      + ',@c_lottable03   NVARCHAR(18)'  
                      + ',@d_lottable04   DATETIME'      
                      + ',@d_lottable05   DATETIME'      
                      + ',@c_lottable06   NVARCHAR(30)'   
                      + ',@c_lottable07   NVARCHAR(30)'   
                      + ',@c_lottable08   NVARCHAR(30)'   
                      + ',@c_lottable09   NVARCHAR(30)'   
                      + ',@c_lottable10   NVARCHAR(30)'   
                      + ',@c_lottable11   NVARCHAR(30)'   
                      + ',@c_lottable12   NVARCHAR(30)'   
                      + ',@d_lottable13   DATETIME'       
                      + ',@d_lottable14   DATETIME'       
                      + ',@d_lottable15   DATETIME'   
  
   EXEC sp_executesql @c_SQLStatement
         ,  @c_SQLArgument
         ,  @c_Facility
         ,  @c_Storerkey 
         ,  @c_Sku
         ,  @c_lottable01 
         ,  @c_lottable02 
         ,  @c_lottable03 
         ,  @d_lottable04 
         ,  @d_lottable05 
         ,  @c_lottable06 
         ,  @c_lottable07 
         ,  @c_lottable08 
         ,  @c_lottable09 
         ,  @c_lottable10 
         ,  @c_lottable11 
         ,  @c_lottable12 
         ,  @d_lottable13 
         ,  @d_lottable14 
         ,  @d_lottable15                                 
              
   QUIT_SP:
END     

GO