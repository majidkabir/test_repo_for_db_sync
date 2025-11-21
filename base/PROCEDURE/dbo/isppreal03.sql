SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPreAL03                                         */
/* Creation Date: 20-Feb-2018                                           */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4046 - Allocation by Lottable03 Based on Consignee      */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 24/05/2018  NJOW01   1.0   WMS-5158 modify shelflife checking and    */
/*                            sorting based on strategykey              */
/* 06/08/2018  NJOW02   1.1   Fix FIFO Shelflife                        */
/* 09/11/2018  NJOW03   1.2   WMS-6892 change FIFO&FEFO shelflife filter*/
/* 24/07/2019  NJOW04   1.3   WMS-9509 SG Prestige lottable03 filter    */
/* 24/10/2019  NJOW05   1.4   WMS-9509 Filter hold stock for CONSIGTAG  */
/*                            or DMGALLOC at staging                    */
/* 25/03/2020  NJOW06   1.5   WMS-12622 add sku brand and skugroup FEFO */
/*                            shelflife by consignee                    */
/* 28/05/2020  NJOW07   1.6   WMS-13544 Change FIFO to use lottable04   */
/* 14/09/2020  Leong    1.7   INC1283171 - Bug Fix.                     */
/* 15/12/2021  NJOW08   1.8   WMS-18573 Lottable07 filtring condition   */
/* 15/12/2021  NJOW08   1.8   DEVOPS combine script                     */
/* 01/06/2022  CLVN01   1.9   JSM-71556 Add LocationFlag <> HOLD        */
/************************************************************************/

CREATE PROC [dbo].[ispPreAL03]
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

   DECLARE  @n_Continue          INT
          , @n_StartTCnt         INT
          , @c_SQL               NVARCHAR(MAX)
          , @c_SQLParms          NVARCHAR(MAX)
          , @c_AddWhereSQL       NVARCHAR(MAX)

   DECLARE @n_MinShelfLife       INT
         , @c_Lottable04Label    NVARCHAR(30)
         , @c_Strategy           NVARCHAR(10)

   DECLARE @n_SeqNo              INT

         , @n_QtyLeftToFulfill   INT
         , @n_QtyAvailable       INT
         , @n_QtyToTake          INT
         , @n_Pallet             FLOAT
         , @n_cPackQty           FLOAT


         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_PickDetailKey      NVARCHAR(10)
         , @c_Facility           NVARCHAR(5)
         , @c_StorerKey          NVARCHAR(15)
         , @c_SKU                NVARCHAR(20)
         , @c_Packkey            NVARCHAR(10)
         , @c_aUOM               NVARCHAR(10)
         , @n_UOMQty             INT
         , @c_PickMethod         NVARCHAR(1)
         , @c_Lot                NVARCHAR(10)
         , @c_Loc                NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
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

         , @c_uom3pickmethod     NVARCHAR(10)
         , @c_uom4pickmethod     NVARCHAR(10)
         , @c_uom7pickmethod     NVARCHAR(10)

         , @CUR_OD               CURSOR
         , @c_Strategykey        NVARCHAR(10) --NJOW01
         , @n_ConMinShelfLife    INT --NJOW01
         , @n_SkuOGShelflife     INT --NJOW03
         , @n_SkuGroupShelfLife  INT --NJOW06
         , @n_SkuGroupShelfLife2 INT --NJOW06
         , @c_SortMode           NVARCHAR(10)='' --NJOW08
         , @c_AllowHOLDLoc       NVARCHAR(1) ='N' --NJOW08

         --NJOW04
   DECLARE @c_CONSIGTAG          NVARCHAR(1)
         , @c_DMGALLOC           NVARCHAR(1)
         , @c_RTNNOALLOC         NVARCHAR(1)
         , @c_Lottable03Inc      NVARCHAR(50)

   SELECT @c_CONSIGTAG = 'N', @c_DMGALLOC = 'N', @c_RTNNOALLOC = 'N'

   IF EXISTS ( SELECT 1
            FROM ORDERS OH WITH (NOLOCK)
            JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'CONSIGTAG')
                                             AND(CL.Code = OH.Consigneekey)
                                             AND(CL.Storerkey = OH.Storerkey)
            WHERE OH.Orderkey = @c_Orderkey
            )
   BEGIN
        SET @c_CONSIGTAG = 'Y'  --NJOW04
      --GOTO QUIT_SP
   END

   --NJOW04 S
   IF EXISTS ( SELECT 1
            FROM ORDERS OH WITH (NOLOCK)
            JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'DMGALLOC')
                                             AND(CL.Code = OH.Consigneekey)
                                             AND(CL.Storerkey = OH.Storerkey)
            WHERE OH.Orderkey = @c_Orderkey
            )
   BEGIN
        SET @c_DMGALLOC = 'Y'
   END

   IF EXISTS ( SELECT 1
            FROM ORDERS OH WITH (NOLOCK)
            JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'RTNNOALLOC')
                                             AND(CL.Code = OH.Consigneekey)
                                             AND(CL.Storerkey = OH.Storerkey)
            WHERE OH.Orderkey = @c_Orderkey
            )
   BEGIN
        SET @c_RTNNOALLOC = 'Y'
   END

   --IF @c_CONSIGTAG = 'N' AND @c_DMGALLOC = 'N' AND @c_RTNNOALLOC = 'Y'
   --   GOTO QUIT_SP
   --NJOW04 E
                                         
   IF EXISTS ( SELECT 1
               FROM PREALLOCATEPICKDETAIl PR WITH (NOLOCK)
               WHERE PR.Orderkey = @c_Orderkey
              )
   BEGIN
      DELETE FROM PREALLOCATEPICKDETAIl WITH (ROWLOCK)
      WHERE Orderkey = @c_Orderkey

      SET @n_Err = @@ERROR
      IF @@ERROR > 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_err)
         SET @n_Err = 68010
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Delete PREALLOCATEPICKDETAIL Fail. (ispPreAL03)'
                       + ' ( ' + ' SQLSvr MESSAGE=' + @c_errmsg + ' )'
         GOTO QUIT_SP
      END
   END

   SET @CUR_OD = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT OH.Facility
         ,OD.Orderkey
         ,OD.OrderLineNumber
         ,OD.Storerkey
         ,OD.Sku
         ,Lottable01 = ISNULL(RTRIM(OD.Lottable01),'')
         ,Lottable02 = ISNULL(RTRIM(OD.Lottable02),'')
         ,Lottable03 = ISNULL(RTRIM(OD.Lottable03),'')
         ,Lottable04 = ISNULL(OD.Lottable04,'19000101')
         ,Lottable05 = ISNULL(OD.Lottable05,'19000101')
         ,Lottable06 = ISNULL(RTRIM(OD.Lottable06),'')
         ,Lottable07 = CASE WHEN ISNULL(RTRIM(OD.Lottable07),'') <> '' THEN ISNULL(RTRIM(OD.Lottable07),'') 
                            WHEN ISNULL(RTRIM(CL3.Code2),'') <> '' THEN ISNULL(RTRIM(CL3.Code2),'') 
                            ELSE ''
                       END --NJOW08
         ,Lottable08 = ISNULL(RTRIM(OD.Lottable08),'')
         ,Lottable09 = ISNULL(RTRIM(OD.Lottable09),'')
         ,Lottable10 = ISNULL(RTRIM(OD.Lottable10),'')
         ,Lottable11 = ISNULL(RTRIM(OD.Lottable11),'')
         ,Lottable12 = ISNULL(RTRIM(OD.Lottable12),'')
         ,Lottable13 = ISNULL(OD.Lottable13,'19000101')
         ,Lottable14 = ISNULL(OD.Lottable14,'19000101')
         ,Lottable15 = ISNULL(OD.Lottable15,'19000101')
         ,PK.Packkey
         ,QtyLeftToFullFill = OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty )
         ,SKU.Lottable04Label
         ,MinShelfLife = CASE WHEN ISNUMERIC (ISNULL(RTRIM(SKU.Susr2),'0')) = 1
                              THEN ISNULL(RTRIM(SKU.Susr2),'0')
                              ELSE 0
                              END
         ,Pallet = ISNULL(PK.Pallet,0)
         ,Strategykey = SKU.Strategykey --NJOW01
         ,ConMinShelfLife = ISNULL(CONS.MinShelflife,0)  --NJOW01
         ,SkuOGShelflife = CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN CAST(SKU.Susr2 AS INT) ELSE 0 END --NJOW03
         ,SkuGroupShelfLife = CASE WHEN ISNUMERIC(CL3.Short) = 1 THEN CAST(CL3.Short AS INT)  --NJOW08
                                   WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT) ELSE 0 END --NJOW06         
         ,SkuGroupShelfLife2 = CASE WHEN ISNUMERIC(CL2.Short) = 1 THEN CAST(CL2.Short AS INT) ELSE 0 END --NJOW06          
         ,SortMode = ISNULL(CL.Long,'')  --NJOW08
         ,AllowHoldLoc = CASE WHEN CL3.Code IS NOT NULL THEN 'Y' ELSE 'N' END --NJOW08
   FROM ORDERS OH      WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey  = OD.Orderkey)
   JOIN SKU        SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey)
                                       AND(OD.Sku       = SKU.Sku)
   JOIN PACK        PK WITH (NOLOCK) ON (SKU.Packkey  = PK.Packkey)
   LEFT JOIN STORER CONS WITH (NOLOCK) ON (OH.Consigneekey = CONS.Storerkey) --NJOW01
   LEFT JOIN CODELKUP CL (NOLOCK) ON (OH.Storerkey = CL.Storerkey 
                                       AND SKU.Busr6 = CL.Code AND SKU.SkuGroup = CL.Code2 
                                       AND CL.Listname = 'PRESTALLOC'
                                       AND ( (CONS.Secondary = CL.UDF01 
                                              OR CONS.Secondary = CL.UDF02 
                                              OR CONS.Secondary = CL.UDF03 
                                              OR CONS.Secondary = CL.UDF04 
                                              OR CONS.Secondary = CL.UDF05)
                                              AND ISNULL(CONS.Secondary, '') <> '' ) -- INC1283171
                                           ) 
   OUTER APPLY (SELECT TOP 1 CL3.Short FROM CODELKUP CL3 (NOLOCK) 
                  WHERE OH.Storerkey = CL3.Storerkey AND SKU.Busr6 <> CL3.Code 
                  AND SKU.SkuGroup <> CL3.Code2 AND CL3.Listname = 'PRESTALLOC' AND CL3.Code = 'ALLOTHERS'
                  AND ( (CONS.Secondary = CL3.UDF01 
                         OR CONS.Secondary = CL3.UDF02 
                         OR CONS.Secondary = CL3.UDF03 
                         OR CONS.Secondary = CL3.UDF04 
                         OR CONS.Secondary = CL3.UDF05)
                         AND ISNULL(CONS.Secondary, '') <> '' ) -- INC1283171
                         ) CL2
   OUTER APPLY (SELECT TOP 1 CL4.Code2, CL4.Short, CL4.Code FROM CODELKUP CL4 (NOLOCK) WHERE OH.Storerkey = CL4.Storerkey AND SKU.Busr6 = CL4.Code AND CL4.Listname = 'ALLOBYLTBL' 
               AND (CONS.Secondary = CL4.UDF01 OR CONS.Secondary = CL4.UDF02 OR CONS.Secondary = CL4.UDF03 OR CONS.Secondary = CL4.UDF04 OR CONS.Secondary = CL4.UDF05)
               AND ISNULL(CONS.Secondary, '') <> '') CL3   --NJOW08                         
   WHERE OH.Orderkey = @c_Orderkey
   AND   OH.SOStatus <> 'CANC'
   AND   OH.Status < '9'
   AND   OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0
   ORDER BY OD.OrderKey
         ,  OD.OrderLineNumber

   OPEN @CUR_OD

   FETCH NEXT FROM @CUR_OD INTO @c_Facility
                              , @c_Orderkey
                              , @c_OrderLineNumber
                              , @c_Storerkey
                              , @c_Sku
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
                              , @c_Packkey
                              , @n_QtyLeftToFulFill
                              , @c_Lottable04Label
                              , @n_MinShelfLife
                              , @n_Pallet
                              , @c_Strategykey --NJOW01
                              , @n_ConMinShelfLife --NJOW01
                              , @n_skuOGShelflife  --NJOW03
                              , @n_SkuGroupShelfLife  --NJOW06
                              , @n_SkuGroupShelfLife2 --NJOW06
                              , @c_SortMode --NJOW08
                              , @c_AllowHoldLoc --NJOW08
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Sku '@c_Sku', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill'
      END

      SET @c_AddWhereSQL = ''

      --NJOW01
      IF @c_strategykey = 'PPDSTD'
         SET @c_Strategy = 'FIFO'
      ELSE IF @c_strategykey = 'PPDFEFO'
         SET @c_Strategy = 'FEFO'
      ELSE
         SET @c_Strategy = 'FIFO'

      /*
      SET @c_Strategy = 'FEFO'
      IF @c_Lottable04Label = ''
      BEGIN
         SET @c_Strategy = 'FIFO'
      END
      */

      IF @c_Lottable01 <> ''
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable01 = @c_Lottable01'
      END

      IF @c_Lottable02 <> ''
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable02 = @c_Lottable02'
      END

      SET @c_Lottable03Inc = ''

      IF @c_CONSIGTAG = 'Y' --NJOW04
         SET @c_Lottable03Inc = '''PER-TAG'',''TAG'''

      IF  @c_DMGALLOC = 'Y' --NJOW04
          IF @c_Lottable03Inc = ''
             SET @c_Lottable03Inc = '''DMG-OK'''
         ELSE
             SET @c_Lottable03Inc = @c_Lottable03Inc + ',''DMG-OK'''

      IF @c_RTNNOALLOC = 'N' --NJOW04
      BEGIN
          IF @c_Lottable03Inc = ''
             SET @c_Lottable03Inc = '''OK-RTN'''
         ELSE
             SET @c_Lottable03Inc = @c_Lottable03Inc + ',''OK-RTN'''
      END
      ELSE
      BEGIN  -- Y
          IF @c_Lottable03Inc = ''
             SET @c_Lottable03Inc = '''OK-RTN'',''OK'''
         ELSE
             SET @c_Lottable03Inc = @c_Lottable03Inc + ',''OK-RTN'',''OK'''
      END
      
      IF @c_Lottable03Inc <> ''
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable03 IN(' + @c_Lottable03Inc + ') '

      IF @n_SkuGroupShelfLife > 0 AND @c_Strategy = 'FEFO' --NJOW06
      BEGIN
          SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND DateDiff(Day, GETDATE(), LA.Lottable04) >= @n_SkuGroupShelfLife ' --+ CAST(@n_SkuGroupShelfLife AS NVARCHAR)
      END
      ELSE IF @n_SkuGroupShelfLife2 > 0 AND @c_Strategy = 'FEFO' --NJOW06
      BEGIN
          SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND DateDiff(Day, GETDATE(), LA.Lottable04) >= @n_SkuGroupShelfLife2 ' --+ CAST(@n_SkuGroupShelfLife2 AS NVARCHAR)
      END
      ELSE IF @n_ConMinShelfLife > 0 AND @c_Strategy = 'FEFO' --NJOW01
      BEGIN
         --SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable04 > CONVERT(DATETIME, CONVERT(NVARCHAR(8), DATEADD(day, @n_MinShelfLife, GETDATE()), 112))'
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND DateDiff(Day, GETDATE(), LA.Lottable04) >= @n_ConMinShelfLife ' --+ CAST(@n_ConMinShelfLife AS NVARCHAR) --NJOW03
         SET @n_MinShelfLife = @n_ConMinShelfLife
      END
      ELSE IF @n_SkuOGShelfLife > 0 AND @c_Strategy = 'FEFO' --NJOW03
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND DateDiff(Day, GETDATE(), LA.Lottable04) >= @n_SkuOGShelfLife ' --+ CAST(@n_SkuOGShelfLife AS NVARCHAR) --NJOW03
      END
      ELSE IF @c_Lottable04Label <> '' AND @n_MinShelfLife > 0
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable04 > CONVERT(DATETIME, CONVERT(NVARCHAR(8), DATEADD(day, @n_MinShelfLife, GETDATE()), 112))'
      END
      ELSE IF @c_Strategy = 'FEFO'
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND DateDiff(Day, GETDATE(), LA.Lottable04) > 0 '  --NJOW03
      END
      ELSE
      BEGIN
         IF CONVERT(NVARCHAR(8), @dt_Lottable04, 112) <> '19000101'
         BEGIN
            SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable04 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_Lottable04, 112))'
         END
      END

      IF @n_ConMinShelfLife > 0 AND @c_Strategy = 'FIFO' --NJOW01
      BEGIN
         --SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable05 >= CONVERT(DATETIME, CONVERT(NVARCHAR(8), DATEADD(day, @n_MinShelfLife * -1, GETDATE()), 112))'   --NJOW02
         --SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND DateDiff(Day, GETDATE(), LA.Lottable05 + SKU.ShelfLife) >= @n_ConMinShelfLife ' --+ CAST(@n_ConMinShelfLife AS NVARCHAR) --NJOW03
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND DateDiff(Day, GETDATE(), LA.Lottable04) >= @n_ConMinShelfLife ' --+ CAST(@n_ConMinShelfLife AS NVARCHAR) --NJOW07
         SET @n_MinShelfLife = @n_ConMinShelfLife
      END
      ELSE IF @n_SkuOGShelfLife > 0 AND @c_Strategy = 'FIFO' --NJOW03
      BEGIN
         --SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND DateDiff(Day, GETDATE(), LA.Lottable05 + SKU.ShelfLife) >= @n_SkuOGShelfLife ' --+ CAST(@n_SkuOGShelfLife AS NVARCHAR) --NJOW03
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND DateDiff(Day, GETDATE(), LA.Lottable04) >= @n_SkuOGShelfLife ' --+ CAST(@n_SkuOGShelfLife AS NVARCHAR) --NJOW07
         SET @n_MinShelfLife = @n_SkuOGShelfLife
      END
      ELSE IF CONVERT(NVARCHAR(8), @dt_Lottable05, 112) <> '19000101'
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable05 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_Lottable05, 112))'
      END

      IF @c_Lottable06 <> ''
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable06 = @c_Lottable06'
      END
                                     
 	    IF @c_Lottable07 <> ''
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable07 = @c_Lottable07'
      END

      IF @c_Lottable08 <> ''
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable08 = @c_Lottable08'
      END

      IF @c_Lottable09 <> ''
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable09 = @c_Lottable09'
      END

      IF @c_Lottable10 <> ''
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable10 = @c_Lottable10'
      END

      IF @c_Lottable11 <> ''
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable11 = @c_Lottable11'
      END

      IF @c_Lottable12 <> ''
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable12 = @c_Lottable12'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable13, 112) <> '19000101'
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable13 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_Lottable13, 112))'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable14, 112) <> '19000101'
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable14 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_Lottable14, 112))'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable15, 112) <> '19000101'
      BEGIN
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LA.Lottable15 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_Lottable15, 112))'
      END

      SET @c_SQL =
               N'DECLARE CUR_LLI CURSOR FAST_FORWARD READ_ONLY FOR'
               + ' SELECT LLI.LOT'
               +       ', LLI.LOC'
               +       ', LLI.ID '
               +       ', QTYAVAILABLE = (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED)'
               +       ', aUOM = CASE WHEN @c_Strategy = ''FIFO'' AND @n_Pallet > 0 AND (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED) >= @n_Pallet THEN 1'
               +                    ' WHEN @c_Strategy = ''FEFO'' AND SL.LocationType = ''PICK'' THEN 6'
               +                    ' ELSE 7'
               +                    ' END'
               + ' FROM LOTxLOCxID   LLI WITH (NOLOCK)'
               + ' JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.Lot = LA.lot)'
               + ' JOIN LOC          LOC WITH (NOLOCK) ON (LLI.Loc = LOC.Loc)'
               + ' JOIN ID           ID  WITH (NOLOCK) ON (LLI.ID = ID.ID)'
               + ' JOIN SKUxLOC      SL  WITH (NOLOCK) ON (LLI.Storerkey = SL.Storerkey)'
               +                                     ' AND(LLI.Sku = SL.Sku)'
               +                                     ' AND(LLI.Loc = SL.Loc)'
               + ' JOIN SKU              WITH (NOLOCK) ON (LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku)'
               + ' JOIN LOT              WITH (NOLOCK) ON (LLI.Lot = LOT.Lot)'  --NJOW04
               + ' WHERE LLI.Storerkey = @c_Storerkey'
               + ' AND   LLI.Sku = @c_Sku'
              -- + ' AND ID.Status <> ''HOLD'''  --NJOW04 remove
              -- + ' AND (LOC.Locationflag = ''HOLD'''
              -- + ' OR  LOC.Status = ''HOLD'')'
               + CASE WHEN @c_AllowHoldLoc <> 'Y' THEN  --NJOW08
                   ' AND LOC.Locationflag <> ''HOLD'''               
                 ELSE '' END  
			        --+ ' AND LOC.Locationflag <> ''HOLD''' --CLVN01
			        + CASE WHEN @c_AllowHoldLoc = 'Y' THEN  --NJOW08			        
                  ' AND NOT (LA.Lottable03 IN (''OK-RTN'',''OK'') AND (ID.Status <> ''OK'' OR LOC.Status <> ''OK'' OR LOT.Status <> ''OK'')) '  --NJOW04
			          ELSE
                  ' AND NOT (LA.Lottable03 IN (''OK-RTN'',''OK'') AND (ID.Status <> ''OK'' OR LOC.Status <> ''OK'' OR LOT.Status <> ''OK'' OR LOC.LocationFlag <> ''NONE'')) '  --NJOW04
                END                                 
               + ' AND NOT (LA.Lottable03 IN (''PER-TAG'',''TAG'',''DMG-OK'') AND LOC.LocationCategory = ''STAGING'') '  --NJOW05
              -- + ' AND NOT (LA.Lottable03 IN (''PER-TAG'',''TAG'',''DMG-OK'') AND LOC.LocationCategory = ''STAGING'' AND (ID.Status <> ''OK'' OR LOC.Status <> ''OK'' OR LOT.Status <> ''OK'' OR LOC.LocationFlag <> ''NONE'')) '  --NJOW05
               + ' AND LOC.Facility = @c_Facility'
               + ' AND (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED) > 0'
               + ' ' + @c_AddWhereSQL
               + ' ORDER BY CASE WHEN LA.Lottable03 IN(''PER-TAG'',''TAG'') THEN 1 WHEN LA.Lottable03 = ''DMG-OK'' THEN 2 WHEN LA.Lottable03 = ''OK'' THEN 3 WHEN LA.Lottable03 = ''OK-RTN'' THEN 4 ELSE 5 END'  --NJOW04
               +        ',  LA.Lottable04' 
               + CASE WHEN @c_Strategy = 'FEFO' AND @c_SortMode = 'LEFO' THEN ' DESC ' ELSE '' END --NJOW08
               +        ',  LA.Lottable05'
               +        ',  LLI.Lot'
               +        ',  aUOM'
               +        ',  LOC.Loc '

      SET @c_SQLParms = N'@c_Facility     NVARCHAR(5)'
                      + ',@c_StorerKey    NVARCHAR(15)'
                      + ',@c_Sku          NVARCHAR(20)'
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
                      + ',@c_Strategy     NVARCHAR(10)'
                      + ',@n_Pallet       INT'
                      + ',@n_MinShelfLife INT'
                      + ',@n_SkuOGShelfLife INT'
                      + ',@n_ConMinShelfLife INT'
                      + ',@n_SkuGroupShelfLife INT'
                      + ',@n_SkuGroupShelfLife2 INT'

      IF @b_debug = 1
      BEGIN
         PRINT @c_SQL
      END

      EXEC sp_executesql @c_SQL
         ,@c_SQLParms
         ,@c_Facility
         ,@c_StorerKey
         ,@c_Sku
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
         ,@c_Strategy
         ,@n_Pallet
         ,@n_MinShelfLife
         ,@n_SkuOGShelfLife --NJOW03
         ,@n_ConMinShelfLife
         ,@n_SkuGroupShelfLife
         ,@n_SkuGroupShelfLife2

      OPEN CUR_LLI

      FETCH NEXT FROM CUR_LLI INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvailable, @c_aUOM

      WHILE @@FETCH_STATUS <> -1 AND @n_QtyLeftToFulfill > 0
      BEGIN
         SET @n_cPackQty = CASE @c_aUOM  WHEN '1' THEN @n_Pallet
                                         WHEN '6' THEN 1
                                         WHEN '7' THEN 1
                                         ELSE 0
                                         END

         SET @n_QtyAvailable = FLOOR(@n_QtyAvailable / @n_cPackQty) * @n_cPackQty

         SET @n_QtyToTake = 0

         IF @n_QtyLeftToFulfill <= @n_QtyAvailable
         BEGIN
            SET @n_QtyToTake = @n_QtyLeftToFulfill
         END
         ELSE
         BEGIN
            SET @n_QtyToTake = @n_QtyAvailable
         END

         SET @n_UOMQty = FLOOR(@n_QtyToTake / @n_cPackQty)

         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake

         IF @b_debug = 1
         BEGIN
            SELECT @c_Sku '@c_Sku', @n_QtyToTake '@n_QtyToTake'
                  ,@n_QtyAvailable '@n_QtyAvailable', @n_UOMQty '@n_UOMQty', @c_aUOM '@c_aUOM'
                  ,@n_cPackQty '@n_cPackQty'
         END

         IF @n_QtyToTake > 0
         BEGIN
            SELECT
                  @c_uom3pickmethod = uom3pickmethod -- piece
                 ,@c_uom4pickmethod = uom4pickmethod -- pallet
                 ,@c_uom7pickmethod = uom3pickmethod
            FROM LOC WITH (NOLOCK)
            JOIN PUTAWAYZONE WITH(NOLOCK) ON (LOC.Putawayzone = PUtawayzone.Putawayzone)
            WHERE LOC.LOC = @c_loc

            SET @c_PickMethod =
                  CASE @c_aUOM WHEN '1' THEN @c_uom4pickmethod
                               WHEN '6' THEN @c_uom3pickmethod
                               WHEN '7' THEN @c_uom7pickmethod
                               END

            EXECUTE nspg_getkey
               'PickDetailKey'
               , 10
               , @c_PickDetailKey OUTPUT
               , @b_Success       OUTPUT
               , @n_Err           OUTPUT
               , @c_ErrMsg        OUTPUT

            IF @b_Success <> 1
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 68020
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Get PickDetailKey Failed. (ispPRNIK01)'
               GOTO QUIT_SP
            END

            INSERT INTO PICKDETAIL
                        (
                           PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber
                        ,  Lot, StorerKey, Sku, UOM, UOMQty, Qty
                        ,  Loc, Id, PackKey, CartonGroup, DoReplenish
                        ,  replenishzone, doCartonize, Trafficcop, PickMethod
                        )
               VALUES   (
                        @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber
                        , @c_Lot, @c_StorerKey, @c_SKU, @c_aUOM, @n_UOMQty, @n_QtyToTake
                        , @c_Loc, @c_ID, @c_PackKey, '', 'N'
                        , '', NULL, 'U', @c_PickMethod
                        )

               SET @n_Err = @@ERROR
               IF @n_err > 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_err)
                  SET @n_Err = 68020
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert PICKDETAIL Fail. (ispPreAL03)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + @c_errmsg + ' )'
                  GOTO QUIT_SP
               END
         END

         FETCH NEXT FROM CUR_LLI INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvailable, @c_aUOM
      END
      CLOSE CUR_LLI
      DEALLOCATE CUR_LLI

      FETCH NEXT FROM @CUR_OD INTO @c_Facility
                                 , @c_Orderkey
                                 , @c_OrderLineNumber
                                 , @c_Storerkey
                                 , @c_Sku
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
                                 , @c_Packkey
                                 , @n_QtyLeftToFulFill
                                 , @c_Lottable04Label
                                 , @n_MinShelfLife
                                 , @n_Pallet
                                 , @c_Strategykey --NJOW01
                                 , @n_ConMinShelfLife --NJOW01
                                 , @n_skuOGShelflife --NJOW03
                                 , @n_SkuGroupShelfLife --NJOW06
                                 , @n_SkuGroupShelfLife2 --NJOW06
                                 , @c_SortMode --NJOW08
                                 , @c_AllowHoldLoc --NJOW08                              
   END

   QUIT_SP:

   IF CURSOR_STATUS( 'VARIABLE', 'CUR_OD') in (0 , 1)
   BEGIN
      CLOSE CUR_OD
      DEALLOCATE CUR_OD
   END

   IF CURSOR_STATUS( 'GLOBAL', 'CUR_LLI') in (0 , 1)
   BEGIN
      CLOSE CUR_LLI
      DEALLOCATE CUR_LLI
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPreAL03'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- Procedure

GO