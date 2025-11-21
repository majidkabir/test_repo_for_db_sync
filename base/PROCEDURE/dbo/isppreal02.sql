SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Proc: ispPreAL02                                               */
/* Creation Date: 05-NOV-2017                                            */
/* Copyright: LF Logistics                                               */
/* Written by: YTWan                                                     */
/*                                                                       */
/* Purpose:                                                              */
/*        :                                                              */
/* Called By:                                                            */
/*          :                                                            */
/* PVCS Version: 1.5                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */
/* 07-NOV-2017 Wan01    1.1   WMS-3044 - PMS Allocation Logic Based on   */
/*                            consignee                                  */
/* 05-OCT-2020 NJOW01   1.2   WMS-15367 allocation based on consignee PMS*/
/* 04-APR-2021 NJOW02   1.3   WMS-16523 change sorting                   */
/* 04-OCT-2021 WLChooi  1.4   DevOps Combine Script                      */
/* 04-OCT-2021 WLChooi  1.5   WMS-18082 - Change sorting (WL01)          */
/* 29-MAR-2023 NJOW03   1.6   WMS-22107 - Change sorting                 */
/*************************************************************************/
CREATE   PROC [dbo].[ispPreAL02]                      
           @c_OrderKey NVARCHAR(10) 
         , @c_LoadKey  NVARCHAR(10)    
         , @b_Success  INT    OUTPUT  
         , @n_Err      INT    OUTPUT
         , @c_ErrMsg   NVARCHAR(255) OUTPUT  
         , @b_debug    INT = 0   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT

         , @n_Qty                INT
         , @n_OpenQty            INT
         , @n_QtyLeftToFulfill   INT
         , @n_QtyAvailable       INT

         , @c_Facility           NVARCHAR(5)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_AltSku             NVARCHAR(20)
         , @c_AltSku_Prev        NVARCHAR(20)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_Lot                NVARCHAR(10)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @dt_Lottable04        DATETIME    
         , @dt_Lottable05        DATETIME    
         , @c_Lottable06         NVARCHAR(30)
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable09         NVARCHAR(30)
         , @c_Lottable10         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_Lottable12         NVARCHAR(30)
         , @dt_Lottable13        DATETIME    
         , @dt_Lottable14        DATETIME    
         , @dt_Lottable15        DATETIME  

         , @c_Lottable01_Prev    NVARCHAR(18)
         , @c_Lottable02_Prev    NVARCHAR(18)
         , @c_Lottable03_Prev    NVARCHAR(18)
         , @dt_Lottable04_Prev   DATETIME    
         , @dt_Lottable05_Prev   DATETIME    
         , @c_Lottable06_Prev    NVARCHAR(30)
         , @c_Lottable07_Prev    NVARCHAR(30)
         , @c_Lottable08_Prev    NVARCHAR(30)
         , @c_Lottable09_Prev    NVARCHAR(30)
         , @c_Lottable10_Prev    NVARCHAR(30)
         , @c_Lottable11_Prev    NVARCHAR(30)
         , @c_Lottable12_Prev    NVARCHAR(30)
         , @dt_Lottable13_Prev   DATETIME    
         , @dt_Lottable14_Prev   DATETIME    
         , @dt_Lottable15_Prev   DATETIME  
         , @c_InvLottable02      NVARCHAR(18)  --NJOW01
         , @n_BatchCnt           INT           --NJOW01

         , @c_PreAllocatePickDetailKey NVARCHAR(10)

         , @c_SQL                NVARCHAR(MAX)
         , @c_SQLParms           NVARCHAR(MAX)           --(Wan01)
         , @c_AddWhereSQL        NVARCHAR(MAX)       

         , @n_UOMQty             INT                     --(Wan01)
         , @n_PackQty            INT                     --(Wan01)
         , @n_CaseCnt            FLOAT                   --(Wan01)
         , @n_Pallet             FLOAT                   --(Wan01)
         , @c_Consigneekey       NVARCHAR(15)            --(Wan01)

   CREATE TABLE #TMP_PREALLOC
      (  RowRef            INT            IDENTITY(1,1)
      ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT ('')
      --,  OrderLineNumber   NVARCHAR(5)    NOT NULL DEFAULT ('')
      ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT ('')
      ,  Lot               NVARCHAR(10)   NOT NULL DEFAULT ('')
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT ('')
      ,  AltSku            NVARCHAR(20)   NOT NULL DEFAULT ('')
      ,  UOM               NVARCHAR(10)   NOT NULL DEFAULT ('')                                    --(Wan01)
      ,  UOMQty            INT            NOT NULL DEFAULT (0)                                     --(Wan01)
      ,  Lottable01        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable02        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable03        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable04        DATETIME       NULL  
      ,  Lottable05        DATETIME       NULL  
      ,  Lottable06        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable07        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable08        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable09        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable10        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable11        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable12        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable13        DATETIME       NULL  
      ,  Lottable14        DATETIME       NULL  
      ,  Lottable15        DATETIME       NULL  
      ,  Qty               INT            NOT NULL DEFAULT (0)
      ,  QtyLeftToFulfill  INT            NOT NULL DEFAULT (0)
      )

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @b_Success = 1
   SET @c_ErrMsg  = ''
   SET @b_debug = 0   --WL01 Set @b_debug = 0
   
   DECLARE CUR_OD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OH.Facility
         ,OD.Storerkey
         ,OD.AltSku
         ,Lottable01 = ISNULL(RTRIM(OD.Lottable01),'')      
         ,Lottable02 = ISNULL(RTRIM(OD.Lottable02),'')      
         ,Lottable03 = ISNULL(RTRIM(OD.Lottable03),'')      
         ,Lottable04 = ISNULL(OD.Lottable04,'19000101')   
         ,Lottable05 = ISNULL(OD.Lottable05,'19000101')   
         ,Lottable06 = ISNULL(RTRIM(OD.Lottable06),'')      
         ,Lottable07 = ISNULL(RTRIM(OD.Lottable07),'')      
         ,Lottable08 = ISNULL(RTRIM(OD.Lottable08),'')      
         ,Lottable09 = ISNULL(RTRIM(OD.Lottable09),'')      
         ,Lottable10 = ISNULL(RTRIM(OD.Lottable10),'')      
         ,Lottable11 = ISNULL(RTRIM(OD.Lottable11),'')      
         ,Lottable12 = ISNULL(RTRIM(OD.Lottable12),'')      
         ,Lottable13 = ISNULL(OD.Lottable13,'19000101')   
         ,Lottable14 = ISNULL(OD.Lottable14,'19000101')   
         ,Lottable15 = ISNULL(OD.Lottable15,'19000101') 
         ,QtyLeftToFulfill = SUM(OD.OpenQty - OD.QtyAllocated - OD.QtyPicked - OD.QtyPreAllocated)
         ,Consigneekey = ISNULL(RTRIM(OH.Consigneekey),'')                                         --(Wan01)
   FROM ORDERS      OH WITH (NOLOCK) 
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Orderkey = @c_Orderkey                                                                  
   AND OD.OpenQty - OD.QtyAllocated - OD.QtyPicked - OD.QtyPreAllocated > 0
   AND OD.AltSku <> ''
   GROUP BY OH.Facility
         ,  OD.Storerkey
         ,  OD.AltSku
         ,  ISNULL(RTRIM(OD.Lottable01),'')   
         ,  ISNULL(RTRIM(OD.Lottable02),'')   
         ,  ISNULL(RTRIM(OD.Lottable03),'')   
         ,  ISNULL(OD.Lottable04,'19000101')
         ,  ISNULL(OD.Lottable05,'19000101')
         ,  ISNULL(RTRIM(OD.Lottable06),'')   
         ,  ISNULL(RTRIM(OD.Lottable07),'')   
         ,  ISNULL(RTRIM(OD.Lottable08),'')   
         ,  ISNULL(RTRIM(OD.Lottable09),'')   
         ,  ISNULL(RTRIM(OD.Lottable10),'')   
         ,  ISNULL(RTRIM(OD.Lottable11),'')   
         ,  ISNULL(RTRIM(OD.Lottable12),'')   
         ,  ISNULL(OD.Lottable13,'19000101')
         ,  ISNULL(OD.Lottable14,'19000101')
         ,  ISNULL(OD.Lottable15,'19000101')
         ,  ISNULL(RTRIM(OH.Consigneekey),'')                                                      --(Wan01)

   OPEN CUR_OD
   
   FETCH NEXT FROM CUR_OD INTO  @c_Facility
                              , @c_Storerkey
                              , @c_AltSku
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
                              , @n_QtyLeftToFulfill     
                              , @c_ConsigneeKey                                                    --(Wan01)                               

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @b_debug = 1
      BEGIN
         SELECT @c_AltSku 'AltSku', @n_QtyLeftToFulfill 'QtyLeftToFulfill' 
         SELECT @c_Consigneekey 'Consigneekey'
      END

      SET @c_AddWhereSQL = ''

      IF @c_Lottable01 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01'
      END

      IF @c_Lottable02 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02'
      END

      IF @c_Lottable03 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable04, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable04 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_Lottable04, 112))'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable05, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable05 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_Lottable05, 112))'
      END

      IF @c_Lottable06 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06'
      END

      IF @c_Lottable07 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07'
      END
      
      IF @c_Lottable08 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08'
      END

      IF @c_Lottable09 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09'
      END

      IF @c_Lottable10 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10'
      END

      IF @c_Lottable11 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11'
      END

      IF @c_Lottable12 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable13, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable13 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @@dt_Lottable13, 112))' 
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable14, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable14 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @@dt_Lottable14, 112))'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable15, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable15 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @@dt_Lottable15, 112))'
      END

      SET @c_SQL = 
               N'DECLARE CUR_LLI CURSOR FAST_FORWARD READ_ONLY FOR'
               + ' SELECT LOTxLOCxID.Lot'
               + ',LOTxLOCxID.Sku'
               + ',QtyAvail=SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0))'
               + ',PACK.CaseCnt'                                                                   --(Wan01) 
               + ',PACK.Pallet'                                                                    --(Wan01) 
               + ',LOTATTRIBUTE.Lottable02'                                                        --NJOW01
               + ' FROM   SKU  WITH (NOLOCK)'
               + ' JOIN   PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)'
               + ' JOIN   LOTxLOCxID WITH (NOLOCK) ON (SKU.Storerkey = LOTxLOCxID.Storerkey)'
               +                                 ' AND(SKU.Sku = LOTxLOCxID.Sku)'
               + ' JOIN   LOT WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)'
               +                          ' AND(LOT.Status = ''OK'')'
               + ' JOIN   LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)' 
               +                          ' AND(LOC.LocationFlag NOT IN (''DAMAGE'', ''HOLD''))'  
               +                          ' AND(LOC.Status = ''OK'')'
               + ' JOIN   ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)'
               +                          ' AND(ID.Status = ''OK'')'   
               + ' JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)'
               + ' LEFT JOIN ( SELECT P.Lot, O.Facility, PreAllocatedQty = SUM(P.Qty)' 
               +             ' FROM ORDERS O WITH (NOLOCK)'
               +             ' JOIN PREALLOCATEPICKDETAIL P WITH (NOLOCK) ON (O.Orderkey = P.Orderkey)'
               +             ' WHERE O.Facility = @c_Facility '
               +             ' AND   O.Storerkey= @c_Storerkey'
               +             ' AND   O.Status < ''9'''
               +             ' GROUP BY P.Lot, O.Facility) PR'
               +             ' ON (LOTxLOCxID.Lot = PR.Lot)'
               +             ' AND(LOC.Facility = PR.Facility)'                  
               + ' WHERE SKU.Storerkey = @c_Storerkey'
               + ' AND   SKU.AltSku    = @c_AltSku'
               + ' AND   LOC.Facility  = @c_Facility'
               + @c_AddWhereSQL
               + ' AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0) > 0'
               + CASE WHEN @c_Consigneekey IN('PMS1') THEN
               	   ' AND 0 < CASE WHEN PACK.CaseCnt > 0 THEN FLOOR((LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) / PACK.CaseCnt) ELSE 1 END ' END --NJOW02      	                  
               + ' GROUP BY LOTxLOCxID.Lot'
               +        ',  LOTxLOCxID.Sku'
               +        ',  LOTATTRIBUTE.Lottable06'  
               +        ',  ISNULL(SKU.BUSR5,'''')'   
               +        ',  LOTATTRIBUTE.Lottable15'
               +        ',  PACK.CaseCnt'                                                          --(Wan01) 
               +        ',  PACK.Pallet'                                                           --(Wan01) 
               +        ',  LOTATTRIBUTE.Lottable02'                                               --NJOW01
               +        ',  LOTATTRIBUTE.Lottable05'                                               --NJOW01               
               +   CASE WHEN @c_Consigneekey NOT IN('PMS1') THEN ', LOTXLOCXID.Loc, LOTXLOCXID.ID ' ELSE ' ' END --NJOW02
               + CASE WHEN @c_Consigneekey = 'PMS' THEN  --NJOW01 
               --+ ' ORDER BY LOTATTRIBUTE.Lottable06 DESC, ISNULL(SKU.BUSR5,''''), LOTATTRIBUTE.Lottable15, LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable02, LOTxLOCxID.Lot ' ELSE 
               --' ORDER BY LOTATTRIBUTE.Lottable06 DESC, ISNULL(SKU.BUSR5,''''), LOTATTRIBUTE.Lottable15, LOTATTRIBUTE.Lottable05,  ' --NJOW02  --NJOW03 Remove
                 ' ORDER BY ISNULL(SKU.BUSR5,''''), LOTATTRIBUTE.Lottable15, LOTATTRIBUTE.Lottable06 DESC, LOTATTRIBUTE.Lottable05,  ' --NJOW03
               +         '  LOTATTRIBUTE.Lottable02, '  --WL01
               +         '  CASE WHEN PACK.Casecnt > 0 THEN CASE WHEN SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) % CAST(PACK.Casecnt AS INT) = 0 THEN 1 ELSE 2 END ELSE 3 END,' --NJOW02
               +         '  MIN(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), ' + --NJOW02
               --+         '  LOTATTRIBUTE.Lottable02, LOTxLOCxID.Lot '  --NJOW02  --WL01
               +         '  LOTxLOCxID.Lot '   --WL01
                       -- ' MIN(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked), LOTATTRIBUTE.Lottable02, LOTxLOCxID.Lot '  --NJOW02
                      WHEN @c_Consigneekey = 'PMS1' THEN  --NJOW02
               --  ' ORDER BY LOTATTRIBUTE.Lottable06 DESC' --NJOW03 Remove
               +        ' ORDER BY ISNULL(SKU.BUSR5,'''')'  
               +        ',  LOTATTRIBUTE.Lottable15'  
               +        ',  LOTATTRIBUTE.Lottable06 DESC'  --NJOW03
               +        ',  LOTATTRIBUTE.Lottable05'  --NJOW02
               +        ',  LOTATTRIBUTE.Lottable02'  --WL01
               +        ',  MIN(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) ' --NJOW02           
                 ELSE                
               --  ' ORDER BY LOTATTRIBUTE.Lottable06 DESC' --NJOW03 Remove
               + ' ORDER BY ISNULL(SKU.BUSR5,'''')'  
               +        ',  LOTATTRIBUTE.Lottable15'  
               +        ',  LOTATTRIBUTE.Lottable06 DESC'  --NJOW03
               +        ',  LOTATTRIBUTE.Lottable05'  --NJOW02
               +        ',  LOTATTRIBUTE.Lottable02'  --WL01
               +        ',  CASE WHEN PACK.CaseCnt > 0 THEN '
               +        '      CASE WHEN SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) % CAST(PACK.CaseCnt AS INT) > 0 THEN 1 ELSE 2 END ELSE 3 END ' --NJOW02           
               +        ',  MIN(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) ' --NJOW02           
                 END                                                                                 
               --(Wan01) - START
               + CASE WHEN @c_Consigneekey = 'PMS1'  
                      THEN ' '  
                      ELSE ', CASE WHEN PACK.Pallet > 0 AND FLOOR(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0)) / PACK.Pallet) > 0 '
                               + ' THEN 1'
                               + ' WHEN PACK.CaseCnt> 0 AND FLOOR(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0)) / PACK.CaseCnt)> 0 '
                               + ' THEN 2'
                               + ' ELSE 9'  
                               + ' END'                                 
                      END
               --(Wan01) - END
               +        ',  LOTxLOCxID.Sku'

              --print @c_SQL
              --WL01 Remark
              --select @c_Facility    
              --    ,@c_StorerKey   
              --    ,@c_AltSku      
              --    ,@c_Lottable01  
              --    ,@c_Lottable02  
              --    ,@c_Lottable03  
              --    ,@dt_Lottable04 
              --    ,@dt_Lottable05 
              --    ,@c_Lottable06  
              --    ,@c_Lottable07  
              --    ,@c_Lottable08  
              --    ,@c_Lottable09  
              --    ,@c_Lottable10  
              --    ,@c_Lottable11  
              --    ,@c_Lottable12  
              --    ,@dt_Lottable13 
              --    ,@dt_Lottable14 
              --    ,@dt_Lottable15 
                  
      --EXEC (@c_SQL)
      SEt @c_SQLParms = N'@c_Facility     NVARCHAR(5)'  
                      + ',@c_StorerKey    NVARCHAR(15)'
                      + ',@c_AltSku       NVARCHAR(20)'
                      + ',@c_Lottable01   NVARCHAR(18)'
                      + ',@c_Lottable02   NVARCHAR(18)'
                      + ',@c_Lottable03   NVARCHAR(18)'
                      + ',@dt_Lottable04  DATETIME'
                      + ',@dt_Lottable05  DATETIME'
                      + ',@c_Lottable06   NVARCHAR(30)'
                      + ',@c_Lottable07   NVARCHAR(30)'
                      + ',@c_Lottable08   NVARCHAR(30)'
                      + ',@c_Lottable09   NVARCHAR(30)'
                      + ',@c_Lottable10   NVARCHAR(30)'
                      + ',@c_Lottable11   NVARCHAR(30)'
                      + ',@c_Lottable12   NVARCHAR(30)'
                      + ',@dt_Lottable13  DATETIME'
                      + ',@dt_Lottable14  DATETIME'
                      + ',@dt_Lottable15  DATETIME'

      EXEC sp_executesql @c_SQL                                                                                   
         ,@c_SQLParms     
         ,@c_Facility                                                                                                  
         ,@c_StorerKey   
         ,@c_AltSku   
         ,@c_Lottable01                                                                                          
     	   ,@c_Lottable02
         ,@c_Lottable03
         ,@dt_Lottable04  
         ,@dt_Lottable05 
         ,@c_Lottable06                                                                                         
     	   ,@c_Lottable07
         ,@c_Lottable08
         ,@c_Lottable09  
         ,@c_Lottable10  
         ,@c_Lottable11                                                                                          
     	   ,@c_Lottable12
         ,@dt_Lottable13
         ,@dt_Lottable14  
         ,@dt_Lottable15                                                                                            

      OPEN CUR_LLI
     
      FETCH NEXT FROM CUR_LLI INTO @c_Lot, @c_Sku, @n_QtyAvailable, @n_CaseCnt, @n_Pallet, @c_InvLottable02  --(Wan01)  NJOW01
      
      WHILE @@FETCH_STATUS <> -1 AND @n_QtyLeftToFulfill > 0 
      BEGIN      	    
         IF @b_debug = 1
         BEGIN
            SELECT @c_Lot 'Lot', @c_Sku 'Sku', @n_QtyAvailable 'QtyAvailable' 
            SELECT @n_CaseCnt 'CaseCnt',@n_Pallet 'Pallet' 
            SELECT @c_Consigneekey 'Consigneekey'
         END

         --(Wan01) - START
         SET @c_UOM = '6'
         SEt @n_Packqty = 1
         IF @c_Consigneekey = 'PMS1'
         BEGIN 
            IF @n_Pallet > 0 AND FLOOR(@n_QtyAvailable/@n_Pallet) > 0 
            BEGIN 
               SET @c_UOM = '1'
               SET @n_Packqty = @n_Pallet
               SET @n_QtyAvailable = FLOOR(@n_QtyAvailable/@n_Pallet) * @n_Pallet
               --SET @n_QtyLeftToFulfill = FLOOR(@n_QtyLeftToFulfill/@n_Pallet) * @n_Pallet
            END
            ELSE IF @n_CaseCnt > 0 AND FLOOR(@n_QtyAvailable/@n_CaseCnt) > 0 
            BEGIN
               SET @c_UOM = '2'
               SET @n_Packqty = @n_CaseCnt
               SET @n_QtyAvailable = FLOOR(@n_QtyAvailable/@n_CaseCnt) * @n_CaseCnt
               --SET @n_QtyLeftToFulfill = FLOOR(@n_QtyLeftToFulfill/@n_CaseCnt) * @n_CaseCnt
            END

            IF @c_UOM = '6'
            BEGIN
               GOTO NEXT_INV
            END
         END
         --(Wan01) - END
         
         --NJOW01
         IF @c_Consigneekey = 'PMS'
         BEGIN
         	  IF @n_QtyAvailable >= @n_QtyLeftToFulfill  --last batch
         	  BEGIN
               SET @n_BatchCnt = 0  
         	  	
         	  	 SELECT @n_Batchcnt = COUNT(DISTINCT LA.Lottable02) + 1  --total batch
         	  	 FROM #TMP_PREALLOC P
         	  	 JOIN LOTATTRIBUTE LA (NOLOCK) ON P.Lot = LA.Lot 
         	  	 WHERE LA.Lottable02 <> @c_InvLottable02
         	  	 AND P.AltSku = @c_AltSku
         	  	 
         	  	 IF @n_Batchcnt > 1  --more than one batch
         	  	 BEGIN
         	  	 	  IF @n_QtyLeftToFulfill % CAST(@n_CaseCnt AS INT) > 0 --Not full case
         	  	 	  BEGIN
         	  	 	  	 IF @n_QtyAvailable >= CEILING(@n_QtyLeftToFulfill / @n_CaseCnt) * @n_Casecnt --sufficient stock to fulfill as full case
         	  	 	  	    SET @n_QtyLeftToFulfill = CEILING(@n_QtyLeftToFulfill / @n_CaseCnt) * @n_Casecnt
         	  	 	  END
         	  	 END
         	  END
         END

         IF @n_QtyLeftToFulfill > @n_QtyAvailable
         BEGIN
            SET @n_OpenQty = @n_QtyAvailable
         END
         ELSE
         BEGIN
            SET @n_OpenQty = @n_QtyLeftToFulfill 
         END

         SET @n_UOMQty = @n_OpenQty / @n_Packqty                                                   --(Wan01)

         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_OpenQty

         IF @b_debug = 1
         BEGIN
            SELECT @n_QtyLeftToFulfill 'QtyLeftToFulfill',@n_QtyAvailable 'QtyAvailable' 
            SELECT @c_UOM 'UOM', @n_Packqty 'Packqty' 
            SELECT @n_UOMQty 'UOMQty', @n_OpenQty 'OpenQty' 
         END

         IF @n_OpenQty > 0                                                                         --(Wan01)
         BEGIN
            INSERT INTO #TMP_PREALLOC
                     (  Orderkey
                     ,  Lot
                     ,  Storerkey 
                     ,  Sku   
                     ,  AltSku
                     ,  UOM                                                                        --(Wan01)
                     ,  UOMQty                                                                     --(Wan01)
                     ,  Lottable01     
                     ,  Lottable02     
                     ,  Lottable03     
                     ,  Lottable04    
                     ,  Lottable05    
                     ,  Lottable06     
                     ,  Lottable07     
                     ,  Lottable08     
                     ,  Lottable09     
                     ,  Lottable10     
                     ,  Lottable11     
                     ,  Lottable12     
                     ,  Lottable13    
                     ,  Lottable14    
                     ,  Lottable15 
                     ,  Qty
                     )
            VALUES   (  @c_Orderkey
                     ,  @c_Lot
                     ,  @c_Storerkey 
                     ,  @c_Sku
                     ,  @c_AltSku
                     ,  @c_UOM                                                                     --(Wan01)
                     ,  @n_UOMQty                                                                  --(Wan01)
                     ,  @c_Lottable01     
                     ,  @c_Lottable02     
                     ,  @c_Lottable03     
                     ,  @dt_Lottable04    
                     ,  @dt_Lottable05    
                     ,  @c_Lottable06     
                     ,  @c_Lottable07     
                     ,  @c_Lottable08     
                     ,  @c_Lottable09     
                     ,  @c_Lottable10     
                     ,  @c_Lottable11     
                     ,  @c_Lottable12     
                     ,  @dt_Lottable13    
                     ,  @dt_Lottable14    
                     ,  @dt_Lottable15 
                     ,  @n_OpenQty
                     )

            IF @@ERROR <> 0 
            BEGIN
               SET @n_Continue = 3    
               SET @n_Err = 63500    
               SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Failed Into Table #TMP_PREALLOC. (ispPreAL02)'
               GOTO QUIT_SP  
            END
         END
                  
         NEXT_INV:                                                                                 --(Wan01) 
         
         FETCH NEXT FROM CUR_LLI INTO @c_Lot, @c_Sku, @n_QtyAvailable, @n_CaseCnt, @n_Pallet, @c_InvLottable02       --(Wan01)    NJOW01         
      END
      CLOSE CUR_LLI
      DEALLOCATE CUR_LLI

      IF @b_debug = 1
      BEGIN
         SELECT 'ORDERDETAIL Loop'
         SELECT @n_QtyLeftToFulfill 'QtyLeftToFulfill',@c_AltSku 'AltSku' 
      END

      UPDATE #TMP_PREALLOC
         SET QtyLeftToFulfill = @n_QtyLeftToFulfill
      WHERE ALTSKU = @c_AltSku

      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3    
         SET @n_Err = 63510    
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Failed On Table #TMP_PREALLOC. (ispPreAL02)'
         GOTO QUIT_SP  
      END

      FETCH NEXT FROM CUR_OD INTO  @c_Facility
                                 , @c_Storerkey
                                 , @c_AltSku
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
                                 , @n_QtyLeftToFulfill  
                                 , @c_ConsigneeKey                                                 --(Wan01)                                 

   END
   CLOSE CUR_OD
   DEALLOCATE CUR_OD  


   BEGIN TRAN         
   SET @c_AltSku_Prev = ''
   DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  Sku
         , AltSku
         , Lottable01     
         , Lottable02     
         , Lottable03     
         , Lottable04    
         , Lottable05    
         , Lottable06     
         , Lottable07     
         , Lottable08     
         , Lottable09     
         , Lottable10     
         , Lottable11     
         , Lottable12     
         , Lottable13    
         , Lottable14    
         , Lottable15 
         , Qty = Sum(Qty)
         , QtyLeftToFulfill
   FROM #TMP_PREALLOC 
   GROUP BY Sku
          , AltSku
          , Lottable01     
          , Lottable02     
          , Lottable03     
          , Lottable04    
          , Lottable05    
          , Lottable06     
          , Lottable07     
          , Lottable08     
          , Lottable09     
          , Lottable10     
          , Lottable11     
          , Lottable12     
          , Lottable13    
          , Lottable14    
          , Lottable15 
          , QtyLeftToFulfill
   ORDER BY --, MIN(RowRef)                                                                        --(Wan01)
            AltSku
          , Lottable01     
          , Lottable02     
          , Lottable03     
          , Lottable04    
          , Lottable05    
          , Lottable06     
          , Lottable07     
          , Lottable08     
          , Lottable09     
          , Lottable10     
          , Lottable11     
          , Lottable12     
          , Lottable13    
          , Lottable14    
          , Lottable15
               
   OPEN CUR_SPLIT
   
   FETCH NEXT FROM CUR_SPLIT INTO  @c_Sku
                                 , @c_AltSku
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
                                 , @n_OpenQty
                                 , @n_QtyLeftToFulfill
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_AltSku_Prev <> @c_AltSku 
      OR @c_Lottable01_Prev  <> @c_Lottable01    
      OR @c_Lottable02_Prev  <> @c_Lottable02    
      OR @c_Lottable03_Prev  <> @c_Lottable03    
      OR @dt_Lottable04_Prev <> @dt_Lottable04   
      OR @dt_Lottable05_Prev <> @dt_Lottable05   
      OR @c_Lottable06_Prev  <> @c_Lottable06    
      OR @c_Lottable07_Prev  <> @c_Lottable07    
      OR @c_Lottable08_Prev  <> @c_Lottable08    
      OR @c_Lottable09_Prev  <> @c_Lottable09    
      OR @c_Lottable10_Prev  <> @c_Lottable10    
      OR @c_Lottable11_Prev  <> @c_Lottable11    
      OR @c_Lottable12_Prev  <> @c_Lottable12    
      OR @dt_Lottable13_Prev <> @dt_Lottable13   
      OR @dt_Lottable14_Prev <> @dt_Lottable14   
      OR @dt_Lottable15_Prev <> @dt_Lottable15   
      BEGIN
         SET @n_OpenQty = @n_OpenQty + @n_QtyLeftToFulfill
      END

      IF @b_debug = 1
      BEGIN
         SELECT @n_QtyLeftToFulfill 'QtyLeftToFulfill',@n_OpenQty 'OpenQty' 
      END

      SET @c_Packkey = ''
      SET @c_UOM = ''

      SELECT @c_Packkey = SKU.Packkey
            ,@c_UOM     = PACK.PackUOM3
      FROM SKU  WITH (NOLOCK) 
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE Storerkey = @c_Storerkey
      AND   Sku = @c_Sku

      -- Same AltSku and Sku OrderlineNumber
      SET @c_OrderLineNumber = ''
      SELECT @c_OrderLineNumber = OrderLineNumber
      FROM ORDERDETAIL WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND   Storerkey= @c_Storerkey
      AND   Sku      = @c_Sku
      AND   AltSku   = @c_AltSku
      AND   Lottable01 = @c_Lottable01
      AND   Lottable02 = @c_Lottable02
      AND   Lottable03 = @c_Lottable03
      AND   ISNULL(Lottable04,'19000101') = @dt_Lottable04
      AND   ISNULL(Lottable05,'19000101') = @dt_Lottable05
      AND   Lottable06 = @c_Lottable06
      AND   Lottable07 = @c_Lottable07
      AND   Lottable08 = @c_Lottable08
      AND   Lottable09 = @c_Lottable09
      AND   Lottable10 = @c_Lottable10
      AND   Lottable11 = @c_Lottable11
      AND   Lottable12 = @c_Lottable12
      AND   ISNULL(Lottable13,'19000101') = @dt_Lottable13
      AND   ISNULL(Lottable14,'19000101') = @dt_Lottable14
      AND   ISNULL(Lottable15,'19000101') = @dt_Lottable15

      IF @c_OrderLineNumber = ''
      BEGIN
         -- Find Open OrderlineNumber with Same AltSku 
         SELECT TOP 1 @c_OrderLineNumber = OrderLineNumber
         FROM ORDERDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
         AND   Storerkey= @c_Storerkey
         AND   AltSku   = @c_AltSku
         AND   Lottable01 = @c_Lottable01
         AND   Lottable02 = @c_Lottable02
         AND   Lottable03 = @c_Lottable03
         AND   ISNULL(Lottable04,'19000101') = @dt_Lottable04
         AND   ISNULL(Lottable05,'19000101') = @dt_Lottable05
         AND   Lottable06 = @c_Lottable06
         AND   Lottable07 = @c_Lottable07
         AND   Lottable08 = @c_Lottable08
         AND   Lottable09 = @c_Lottable09
         AND   Lottable10 = @c_Lottable10
         AND   Lottable11 = @c_Lottable11
         AND   Lottable12 = @c_Lottable12
         AND   ISNULL(Lottable13,'19000101') = @dt_Lottable13
         AND   ISNULL(Lottable14,'19000101') = @dt_Lottable14
         AND   ISNULL(Lottable15,'19000101') = @dt_Lottable15
         AND   Sku      <> @c_Sku
         AND   QtyAllocated + QtyPicked + QtyPreAllocated = 0
      END

      IF @c_OrderLineNumber <> ''
      BEGIN
         UPDATE ORDERDETAIL WITH (ROWLOCK)
            SET Sku     = @c_Sku
               ,PackKey = @c_Packkey
               ,UOM     = @c_UOM 
               ,OpenQty = QtyAllocated + QtyPicked + QtyPreAllocated + @n_OpenQty
               ,EditDate= GETDATE()
               ,EditWho = SUSER_NAME()
         WHERE Orderkey = @c_Orderkey
         AND OrderLineNumber = @c_OrderLineNumber 

         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3    
            SET @n_Err = 63530    
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Failed On Table ORDERDETAIL. (ispPreAL02)'
            GOTO QUIT_SP  
         END
      END
      ELSE
      BEGIN
         SELECT @c_OrderLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5), MAX(OrderLineNumber) + 1),5)
         FROM ORDERDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey

         INSERT INTO ORDERDETAIL  
            (
               Orderkey
            ,  OrderLineNumber
            ,  Storerkey
            ,  Sku
            ,  ManufacturerSku
            ,  RetailSku
            ,  AltSku
            ,  OriginalQty
            ,  OpenQty
            ,  Packkey
            ,  UOM 
            ,  PickCode
            ,  CartonGroup
            ,  Facility
            ,  UnitPrice
            ,  Tax01
            ,  Tax02
            ,  ExtendedPrice
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
            ,  Lottable05
            ,  Lottable06
            ,  Lottable07
            ,  Lottable08
            ,  Lottable09
            ,  Lottable10
            ,  Lottable11
            ,  Lottable12
            ,  Lottable13
            ,  Lottable14
            ,  Lottable15
            ,  FreeGoodQty
            ,  UserDefine01
            ,  UserDefine02
            ,  UserDefine03
            ,  UserDefine04
            ,  UserDefine05
            ,  UserDefine06
            ,  UserDefine07
            ,  UserDefine08
            ,  UserDefine09
            ,  UserDefine10
            ,  Loadkey
            )
         SELECT TOP 1
               Orderkey
            ,  @c_OrderLineNumber
            ,  @c_Storerkey
            ,  @c_Sku
            ,  ManufacturerSku
            ,  RetailSku
            ,  AltSku
            ,  @n_OpenQty
            ,  @n_OpenQty
            ,  @c_Packkey
            ,  @c_UOM 
            ,  PickCode
            ,  CartonGroup
            ,  Facility
            ,  UnitPrice
            ,  Tax01
            ,  Tax02
            ,  ExtendedPrice
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
            ,  Lottable05
            ,  Lottable06
            ,  Lottable07
            ,  Lottable08
            ,  Lottable09
            ,  Lottable10
            ,  Lottable11
            ,  Lottable12
            ,  Lottable13
            ,  Lottable14
            ,  Lottable15
            ,  FreeGoodQty
            ,  UserDefine01
            ,  UserDefine02
            ,  UserDefine03
            ,  UserDefine04
            ,  UserDefine05
            ,  UserDefine06
            ,  UserDefine07
            ,  UserDefine08
            ,  UserDefine09
            ,  UserDefine10
            ,  Loadkey
         FROM ORDERDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
         AND   AltSku = @c_AltSku
         AND   Lottable01 = @c_Lottable01
         AND   Lottable02 = @c_Lottable02
         AND   Lottable03 = @c_Lottable03
         AND   ISNULL(Lottable04,'19000101') = @dt_Lottable04
         AND   ISNULL(Lottable05,'19000101') = @dt_Lottable05
         AND   Lottable06 = @c_Lottable06
         AND   Lottable07 = @c_Lottable07
         AND   Lottable08 = @c_Lottable08
         AND   Lottable09 = @c_Lottable09
         AND   Lottable10 = @c_Lottable10
         AND   Lottable11 = @c_Lottable11
         AND   Lottable12 = @c_Lottable12
         AND   ISNULL(Lottable13,'19000101') = @dt_Lottable13
         AND   ISNULL(Lottable14,'19000101') = @dt_Lottable14
         AND   ISNULL(Lottable15,'19000101') = @dt_Lottable15

         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3    
            SET @n_Err = 63540    
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Failed INTO Table ORDERDETAIL. (ispPreAL02)'
            GOTO QUIT_SP  
         END
      END
      
      DECLARE CUR_PREALLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Lot
            ,Qty 
            ,UOM                                                                                   --(Wan01)
            ,UOMQty                                                                                --(Wan01)
      FROM  #TMP_PREALLOC WITH (NOLOCK) 
      WHERE ORderkey = @c_Orderkey
      AND   ALTSku   = @c_AltSku
      AND   Sku      = @c_Sku 
      AND   Lottable01 = @c_Lottable01
      AND   Lottable02 = @c_Lottable02
      AND   Lottable03 = @c_Lottable03
      AND   Lottable04 = @dt_Lottable04
      AND   Lottable05 = @dt_Lottable05
      AND   Lottable06 = @c_Lottable06
      AND   Lottable07 = @c_Lottable07
      AND   Lottable08 = @c_Lottable08
      AND   Lottable09 = @c_Lottable09
      AND   Lottable10 = @c_Lottable10
      AND   Lottable11 = @c_Lottable11
      AND   Lottable12 = @c_Lottable12
      AND   Lottable13 = @dt_Lottable13
      AND   Lottable14 = @dt_Lottable14
      AND   Lottable15 = @dt_Lottable15
       
      OPEN CUR_PREALLOC
   
      FETCH NEXT FROM CUR_PREALLOC INTO @c_Lot
                                       ,@n_Qty
                                       ,@c_UOM                                                     --(Wan01)  
                                       ,@n_UOMQty                                                  --(Wan01)         
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @b_success = 0
         EXECUTE nspg_getkey 
                 'PreAllocatePickDetailKey'
               , 10
               , @c_PreAllocatePickDetailKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @n_Continue = 3    
            SET @n_Err = 63550    
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Getting PreAllocatePickDetailKey. (ispPreAL02)'
            GOTO QUIT_SP 
         END 

         INSERT INTO PREALLOCATEPICKDETAIL
               (  PreAllocatePickDetailKey
               ,  Orderkey
               ,  OrderLineNumber
               ,  Storerkey
               ,  Sku
               ,  Lot
               ,  UOM 
               ,  UOMQty
               ,  Packkey
               ,  Qty
               ,  PreAllocateStrategyKey   
               ,  PreAllocatePickCode
               )
         VALUES ( @c_PreAllocatePickDetailKey
               ,  @c_Orderkey
               ,  @c_OrderLineNumber
               ,  @c_Storerkey
               ,  @c_Sku
               ,  @c_Lot
               ,  @c_UOM                                                                           --(Wan01)  
               ,  @n_UOMQty                                                                        --(Wan01)     
               ,  @c_Packkey
               ,  @n_Qty
               , 'SplitOrdLn'
               , 'ispPreAL02'
               )

         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3    
            SET @n_Err = 63560    
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Failed Into Table ORDERDETAIL. (ispPreAL02)'
            GOTO QUIT_SP  
         END 
      
         FETCH NEXT FROM CUR_PREALLOC INTO @c_Lot
                                         , @n_Qty
                                         , @c_UOM                                                  --(Wan01) 
                                         , @n_UOMQty                                               --(Wan01) 
      END 
      CLOSE CUR_PREALLOC
      DEALLOCATE CUR_PREALLOC

      SET @c_AltSku_Prev      = @c_AltSku
      SET @c_Lottable01_Prev  = @c_Lottable01       
      SET @c_Lottable02_Prev  = @c_Lottable02       
      SET @c_Lottable03_Prev  = @c_Lottable03       
      SET @dt_Lottable04_Prev = @dt_Lottable04      
      SET @dt_Lottable05_Prev = @dt_Lottable05      
      SET @c_Lottable06_Prev  = @c_Lottable06       
      SET @c_Lottable07_Prev  = @c_Lottable07       
      SET @c_Lottable08_Prev  = @c_Lottable08       
      SET @c_Lottable09_Prev  = @c_Lottable09       
      SET @c_Lottable10_Prev  = @c_Lottable10       
      SET @c_Lottable11_Prev  = @c_Lottable11       
      SET @c_Lottable12_Prev  = @c_Lottable12       
      SET @dt_Lottable13_Prev = @dt_Lottable13      
      SET @dt_Lottable14_Prev = @dt_Lottable14      
      SET @dt_Lottable15_Prev = @dt_Lottable15      
      FETCH NEXT FROM CUR_SPLIT INTO  @c_Sku, @c_AltSku
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
                                    , @n_OpenQty
                                    , @n_QtyLeftToFulfill
   END 
   CLOSE CUR_SPLIT
   DEALLOCATE CUR_SPLIT

   -- Remove ALTSKu Residual orderdetail line
   DECLARE CUR_OD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OD.Orderkey
         ,OD.OrderLineNumber
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN #TMP_PREALLOC  PR ON  (OD.AltSku = PR.AltSku AND OD.Orderkey = PR.Orderkey)
                          AND (OD.Lottable01 = PR.Lottable01)
                          AND (OD.Lottable02 = PR.Lottable02)
                          AND (OD.Lottable03 = PR.Lottable03)
                          AND (ISNULL(OD.Lottable04,'19000101') = PR.Lottable04)
                          AND (ISNULL(OD.Lottable05,'19000101') = PR.Lottable05)
                          AND (OD.Lottable06 = PR.Lottable06)
                          AND (OD.Lottable07 = PR.Lottable07)
                          AND (OD.Lottable08 = PR.Lottable08)
                          AND (OD.Lottable09 = PR.Lottable09)
                          AND (OD.Lottable10 = PR.Lottable10)
                          AND (OD.Lottable11 = PR.Lottable11)
                          AND (OD.Lottable12 = PR.Lottable12)
                          AND (ISNULL(OD.Lottable13,'19000101') = PR.Lottable13)
                          AND (ISNULL(OD.Lottable14,'19000101') = PR.Lottable14)
                          AND (ISNULL(OD.Lottable15,'19000101') = PR.Lottable15)                          
   WHERE OD.Orderkey = @c_Orderkey
   AND   OD.QtyAllocated + OD.QtyPicked + OD.QtyPreAllocated = 0
   AND OD.AltSku <> ''
   OPEN CUR_OD
  
   FETCH NEXT FROM CUR_OD INTO @c_Orderkey
                             , @c_OrderLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE FROM ORDERDETAIL WITH (ROWLOCK)
      WHERE Orderkey = @c_Orderkey
      AND   OrderLineNumber = @c_OrderLineNumber  

      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3    
         SET @n_Err = 63560    
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Delete Failed From Table ORDERDETAIL. (ispPreAL02)'
         GOTO QUIT_SP  
      END                  
      FETCH NEXT FROM CUR_OD INTO @c_Orderkey
                                , @c_OrderLineNumber
   END
   CLOSE CUR_OD
   DEALLOCATE CUR_OD
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_OD') in (0 , 1)  
   BEGIN
      CLOSE CUR_OD
      DEALLOCATE CUR_OD
   END

   IF CURSOR_STATUS( 'GLOBAL', 'CUR_LLI') in (0 , 1)  
   BEGIN
      CLOSE CUR_LLI
      DEALLOCATE CUR_LLI
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_SPLIT') in (0 , 1)  
   BEGIN
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PREALLOC') in (0 , 1)  
   BEGIN
      CLOSE CUR_PREALLOC
      DEALLOCATE CUR_PREALLOC
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPreAL02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO