SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPOALKIT02                                          */
/* Creation Date: 15-Dec-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-21261 - [CN] RITUALS_Kit_Allocation NEW                    */
/*                                                                         */
/* Called By: isp_PostKitAllocation_Wrapper: PostKitAllocation_SP          */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 15-Dec-2022  WLChooi 1.0   DevOps Combine Script                        */
/* 15-Jun-2023  NJOW01  1.1   WMS-22851 create transmitlog2 after allocate */
/***************************************************************************/
CREATE   PROC [dbo].[ispPOALKIT02]
(
   @c_Kitkey  NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_Err     INT           OUTPUT
 , @c_ErrMsg  NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug              INT
         , @n_Continue           INT
         , @n_StartTCnt          INT
         , @c_Storerkey          NVARCHAR(15)
         , @c_ParentSku          NVARCHAR(20)
         , @c_ParentPackkey      NVARCHAR(10)
         , @c_ParentUOM          NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
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
         , @c_KitLineNumber      NVARCHAR(5)
         , @n_LineCnt            INT
         , @n_Qty                INT
         , @n_ExpectedQty        INT
         , @c_Sku                NVARCHAR(20)
         , @c_ExternLineNo       NVARCHAR(10)
         , @n_BOMQty             INT
         , @n_BOMParentQty       INT
         , @n_ActualQty          INT
         , @n_packqty            INT
         , @n_cnt                INT
         , @n_pickqty            INT
         , @n_splitqty           INT
         , @c_NewLineNumber      NVARCHAR(5)
         , @n_RowID              INT
         , @n_CurrentExpQty      INT
         , @n_RemainQty          INT
         , @n_SKUGrp             INT = 0
         , @dt_MinLott04         DATETIME

   IF @n_Err > 0
      SET @b_Debug = @n_Err

   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @n_Continue = 1
   SET @n_StartTCnt = @@TRANCOUNT

   DECLARE @T_KIT TABLE (
      RowID             INT NOT NULL IDENTITY(1,1) PRIMARY KEY
    , KITKey            NVARCHAR(10)
    , KitLineNumber     NVARCHAR(5)
    , SKU               NVARCHAR(20)
    , ExpectedQty       INT
    , Lottable02        NVARCHAR(50)
    , Lottable04        DATETIME
    , KITType           NVARCHAR(1)
    , PartitionIndex    INT
    , BOMQty            INT
    , BOMParentQty      INT
    , SKUGrp            INT
    , ExternLineNo      NVARCHAR(10) NULL
   )

   DECLARE @T_KIT_TEMP TABLE (
      RowID             INT NOT NULL IDENTITY(1,1) PRIMARY KEY
    , KITKey            NVARCHAR(10)
    , KitLineNumber     NVARCHAR(5)
    , SKU               NVARCHAR(20)
    , ExpectedQty       INT
    , Lottable02        NVARCHAR(50)
    , Lottable04        DATETIME
    , KITType           NVARCHAR(1)
    , PartitionIndex    INT
    , BOMQty            INT
    , BOMParentQty      INT
    , SKUGrp            INT NULL
   )

   DECLARE @T_KIT_DRAFT TABLE (
      RowID             INT NOT NULL IDENTITY(1,1) PRIMARY KEY
    , KITKey            NVARCHAR(10)
    , KitLineNumber     NVARCHAR(5)
    , SKU               NVARCHAR(20)
    , ExpectedQty       INT
    , Lottable02        NVARCHAR(50)
    , Lottable04        DATETIME
    , KITType           NVARCHAR(1)
    , PartitionIndex    INT
    , BOMQty            INT
    , BOMParentQty      INT
    , SKUGrp            INT NULL
   )

   DECLARE @T_KIT_F TABLE (
      KITKey            NVARCHAR(10)
    , SKU               NVARCHAR(20)
    , ExpectedQty       INT
    , Lottable04        DATETIME
    , KITType           NVARCHAR(1)
    , BOMQty            INT
    , BOMParentQty      INT
    , ExternLineNo      NVARCHAR(10) NULL
   )

   --NJOW01
   IF @n_Continue IN(1,2)
   BEGIN   	  
      IF EXISTS(SELECT 1
                FROM KIT (NOLOCK)
                WHERE Kitkey = @c_Kitkey
                AND Status IN('1','2'))
      OR EXISTS(SELECT 1 
   	            FROM KITDETAIL (NOLOCK)
   	            WHERE Kitkey = @c_Kitkey
   	            AND Type = 'F'
   	            AND Lot <> '' 
   	            AND Lot IS NOT NULL)   	              
      BEGIN
      	 SELECT @c_Storerkey = Storerkey
      	 FROM KIT (NOLOCK)
      	 WHERE Kitkey = @c_KitKey
      	 
         EXEC ispGenTransmitLog2
               @c_TableName      = 'WSKALLOCLOG'  
              ,@c_Key1           = @C_Kitkey
              ,@c_Key2           = ''  
              ,@c_Key3           = @c_Storerkey  
              ,@c_TransmitBatch  = ''
              ,@b_Success        = @b_Success  OUTPUT
              ,@n_err            = @n_Err      OUTPUT
              ,@c_errmsg         = @c_ErrMsg   OUTPUT      	
          
          IF @b_Success = 0
             SELECT @n_Continue  = 3          	  
      END                                
   END

   IF @n_Continue IN ( 1, 2 )
   BEGIN
      SELECT TOP 1 @c_ParentSku = KT.Sku
                 , @c_ParentPackkey = KT.PackKey
                 , @c_Storerkey = KT.StorerKey
      FROM KITDETAIL KT (NOLOCK)
      JOIN BillOfMaterial BOM (NOLOCK) ON KT.StorerKey = BOM.Storerkey AND KT.Sku = BOM.Sku
      WHERE KT.KITKey = @c_Kitkey AND KT.Type = 'T'
      ORDER BY KT.KITLineNumber

      IF ISNULL(@c_ParentSku, '') = ''
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 65330
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5), @n_Err) + ': BOM Sku not found for the kit. (ispPOALKIT02)'
      END
   END
   
   IF @n_Continue IN ( 1, 2 )
   BEGIN
      INSERT INTO @T_KIT (KITKey, KitLineNumber, SKU, ExpectedQty, Lottable02, Lottable04, KITType, PartitionIndex, BOMQty, BOMParentQty)
      SELECT KF.KITKey
           , KF.KITLineNumber
           , KF.Sku
           , (SUM(KF.ExpectedQty) / MAX(BOM.Qty)) * MAX(BOM.ParentQty) AS ExpectedQty
           , LA.LOTTABLE02
           , LA.LOTTABLE04
           , KF.[Type]
           , (ROW_NUMBER() OVER (PARTITION BY KF.SKU ORDER BY KF.SKU, LA.LOTTABLE04 ) )  AS PartitionIndex
           , MAX(BOM.Qty)
           , MAX(BOM.ParentQty)
      FROM KIT (NOLOCK)
      JOIN KITDETAIL KF (NOLOCK) ON KIT.KITKey = KF.KITKey
      JOIN SKU (NOLOCK) ON KF.StorerKey = SKU.StorerKey AND KF.Sku = SKU.Sku
      LEFT JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = KF.Lot
      JOIN BillOfMaterial BOM (NOLOCK) ON  KF.StorerKey = BOM.Storerkey
                                       AND KF.Sku = BOM.ComponentSku
                                       AND BOM.SKU = @c_ParentSku
      WHERE KF.KITKey = @c_Kitkey
      AND KF.Type = 'F'
      GROUP BY KF.KITKey
           , KF.Sku
           , KF.[Type]
           , LA.LOTTABLE02
           , LA.LOTTABLE04
           , KF.KITLineNumber
      ORDER BY KF.SKU, LA.LOTTABLE04

      IF @b_Debug = 1
         SELECT * FROM @T_KIT ORDER BY PartitionIndex, Lottable04
   END

   IF (@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      WHILE EXISTS (SELECT 1 FROM @T_KIT TK WHERE TK.KITType = 'F')
      BEGIN
         DELETE FROM @T_KIT_TEMP

         INSERT INTO @T_KIT_TEMP (KITKey, SKU, ExpectedQty, Lottable02, Lottable04, KITType, PartitionIndex, BOMQty
                                , BOMParentQty, KitLineNumber)
         SELECT KITKey
              , SKU
              , ExpectedQty
              , Lottable02
              , Lottable04
              , KITType
              , (ROW_NUMBER() OVER (PARTITION BY SKU
                                    ORDER BY CASE WHEN Lottable04 IS NULL THEN 2 ELSE 1 END))
              , BOMQty
              , BOMParentQty
              , KitLineNumber
         FROM @T_KIT
         WHERE KITType = 'F'
         ORDER BY CASE WHEN Lottable04 IS NULL THEN 2 ELSE 1 END

         SET @n_ExpectedQty = NULL
         SET @n_SKUGrp = @n_SKUGrp + 1

         DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TKT.RowID, TKT.SKU, TKT.BOMQty, TKT.BOMParentQty FROM @T_KIT_TEMP TKT 
         WHERE TKT.PartitionIndex = 1
         ORDER BY TKT.PartitionIndex, TKT.Lottable04

         OPEN CUR_LOOP

         FETCH NEXT FROM CUR_LOOP INTO @n_RowID, @c_SKU, @n_BOMQty, @n_BOMParentQty

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @n_ExpectedQty IS NULL
               SELECT TOP 1 @n_ExpectedQty = ExpectedQty FROM @T_KIT_TEMP WHERE PartitionIndex = 1 AND RowID = @n_RowID ORDER BY Lottable04

            --SELECT @n_ExpectedQty = @n_ExpectedQty / @n_BOMQty * @n_BOMParentQty

            SELECT @n_CurrentExpQty = ExpectedQty
            FROM @T_KIT_TEMP TKT
            WHERE RowID = @n_RowID

            --SELECT @n_RowID, @c_SKU, @n_CurrentExpQty, @n_ExpectedQty

            IF @n_CurrentExpQty < @n_ExpectedQty
            BEGIN
               INSERT INTO @T_KIT_DRAFT (KITKey, KitLineNumber, SKU, ExpectedQty, Lottable02, Lottable04, KITType, PartitionIndex
                                       , BOMQty, BOMParentQty, SKUGrp)
               SELECT KITKey, KitLineNumber, SKU, ExpectedQty, Lottable02, Lottable04, KITType, PartitionIndex
                    , BOMQty, BOMParentQty, @n_SKUGrp
               FROM @T_KIT_TEMP TKT
               WHERE RowID = @n_RowID

               UPDATE @T_KIT_TEMP
               SET ExpectedQty = 0
               WHERE RowID = @n_RowID

               SET @n_RemainQty = @n_ExpectedQty - @n_CurrentExpQty

               WHILE (@n_RemainQty > 0)
               BEGIN
                  SELECT @n_CurrentExpQty = ExpectedQty, @n_RowID = RowID
                  FROM @T_KIT_TEMP
                  WHERE SKU = @c_SKU AND ExpectedQty >= @n_RemainQty ORDER BY PartitionIndex
                  
                  INSERT INTO @T_KIT_DRAFT (KITKey, KitLineNumber, SKU, ExpectedQty, Lottable02, Lottable04, KITType, PartitionIndex
                                          , BOMQty, BOMParentQty, SKUGrp)
                  SELECT KITKey, KitLineNumber, SKU, CASE WHEN @n_RemainQty < @n_CurrentExpQty THEN @n_RemainQty ELSE @n_CurrentExpQty END, Lottable02, Lottable04, KITType, PartitionIndex
                       , BOMQty, BOMParentQty, @n_SKUGrp
                  FROM @T_KIT_TEMP TKT
                  WHERE RowID = @n_RowID

                  UPDATE @T_KIT_TEMP
                  SET ExpectedQty = ExpectedQty - CASE WHEN @n_RemainQty < @n_CurrentExpQty THEN @n_RemainQty ELSE @n_CurrentExpQty END
                  WHERE RowID = @n_RowID

                  IF @n_RemainQty < @n_CurrentExpQty
                     SET @n_RemainQty = 0
                  ELSE
                     SET @n_RemainQty = @n_RemainQty - @n_CurrentExpQty
               END
            END
            ELSE
            BEGIN
               INSERT INTO @T_KIT_DRAFT (KITKey, KitLineNumber, SKU, ExpectedQty, Lottable02, Lottable04, KITType, PartitionIndex
                                       , BOMQty, BOMParentQty, SKUGrp)
               SELECT KITKey, KitLineNumber, SKU, @n_ExpectedQty, Lottable02, Lottable04, KITType, PartitionIndex
                    , BOMQty, BOMParentQty, @n_SKUGrp
               FROM @T_KIT_TEMP TKT
               WHERE RowID = @n_RowID

               UPDATE @T_KIT_TEMP
               SET ExpectedQty = ExpectedQty - @n_ExpectedQty
               WHERE RowID = @n_RowID
            END

            FETCH NEXT FROM CUR_LOOP INTO @n_RowID, @c_SKU, @n_BOMQty, @n_BOMParentQty
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP

         DELETE FROM @T_KIT_TEMP WHERE ExpectedQty <=0

         DELETE FROM @T_KIT
         INSERT @T_KIT (KITKey, KitLineNumber, SKU, ExpectedQty, Lottable02, Lottable04, KITType, PartitionIndex, BOMQty
                           , BOMParentQty, SKUGrp)
         SELECT KITKey, KitLineNumber, SKU, ExpectedQty, Lottable02, Lottable04, KITType, (ROW_NUMBER() OVER (PARTITION BY SKU
                                    ORDER BY Lottable04)), BOMQty
                           , BOMParentQty, SKUGrp
         FROM @T_KIT_TEMP TKT
      END
   END

   IF @b_Debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
   END

   --Split F Line
   IF (@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      IF @@TRANCOUNT = 0 AND @b_Debug = 0
         BEGIN TRAN

      DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKU, ExpectedQty / BOMParentQty * BOMQty, Lottable02, Lottable04, SKUGrp, KitLineNumber
      FROM @T_KIT_DRAFT
   
      OPEN CUR_UPD
   
      FETCH NEXT FROM CUR_UPD INTO @c_SKU, @n_ExpectedQty, @c_Lottable02, @dt_Lottable04, @n_SKUGrp, @c_ExternLineNo
   
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @c_KitLineNumber = '' 
         SET @n_packqty = @n_ExpectedQty

         WHILE @n_packqty > 0  
         BEGIN
            SET @n_cnt = 0  

            SELECT TOP 1 @n_cnt = 1
                       , @n_pickqty = KD.ExpectedQty
                       , @c_KitLineNumber = KD.KitLineNumber
            FROM KITDETAIL KD (NOLOCK)
            --JOIN LOTxLocxID LLI (NOLOCK) ON LLI.Lot = KD.Lot AND LLI.Loc = KD.Loc AND LLI.ID = KD.ID
            WHERE KD.KITKey = @c_Kitkey
            AND KD.Type = 'F'
            AND KD.Sku = @c_SKU
            AND KD.StorerKey = @c_Storerkey
            --AND KD.KitLineNumber > @c_KitLineNumber
            AND KD.Status <> '9'
            AND ISNULL(KD.LOTTABLE02,'') = ISNULL(@c_Lottable02,'')
            AND KD.LOTTABLE04 = @dt_Lottable04
            AND ISNULL(KD.ExternLineNo, '') = ''
            ORDER BY KD.KitLineNumber
            --SELECT @c_SKU, @n_ExpectedQty, @c_Lottable02, @dt_Lottable04, @n_SKUGrp, @c_ExternLineNo, @n_pickqty,  @n_packqty 
            IF @n_cnt = 0  
               BREAK
            
            IF @n_pickqty <= @n_packqty  
            BEGIN  
               UPDATE KITDETAIL WITH (ROWLOCK)  
               SET ExternLineNo = RIGHT('00000' + CAST(@n_SKUGrp AS NVARCHAR),5)
                 , LOTTABLE04 = @dt_Lottable04
                 , TrafficCop = NULL  
                 , EditWho = SUSER_SNAME()
                 , EditDate = GETDATE()
               WHERE KITLineNumber = @c_KitLineNumber  
               AND KITKey = @c_Kitkey
               AND Type = 'F'

               SELECT @n_err = @@ERROR  

               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65335  
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update KITDETAIL Table Failed. (ispPOALKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  BREAK  
               END  
               SELECT @n_packqty = @n_packqty - @n_pickqty  
            END  
            ELSE  
            BEGIN  -- pickqty > packqty  
               SELECT @n_splitqty = @n_pickqty - @n_packqty  

               SET @c_NewLineNumber = ''

               ;WITH CTE (KitLineNumber) AS (
                  SELECT CAST(MAX(KitLineNumber) AS INT)
                  FROM KITDETAIL (NOLOCK)
                  WHERE Kitkey = @c_Kitkey)
               SELECT @c_NewLineNumber = RIGHT('00000' + CAST((CTE.KitLineNumber + 1) AS NVARCHAR), 5)
               FROM CTE

               IF NOT @b_success = 1  
               BEGIN  
                  SELECT @n_continue = 3  
                  BREAK  
               END  

               INSERT INTO dbo.KITDETAIL (KITKey, KITLineNumber, Type, StorerKey, Sku, Lot, Loc, Id, ExpectedQty, Qty, PackKey, UOM
                                        , LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05, Status, EffectiveDate
                                        , ExternKitKey, ExternLineNo, Lottable06
                                        , Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13
                                        , Lottable14, Lottable15, Channel, Channel_ID)
               SELECT @c_Kitkey, @c_NewLineNumber, 'F', StorerKey, @c_Sku, Lot, Loc, Id, @n_splitqty, Qty, PackKey, UOM
                    , LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05, Status, EffectiveDate
                    , ExternKitKey, '', Lottable06
                    , Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13
                    , Lottable14, Lottable15, Channel, Channel_ID
               FROM KITDETAIL (NOLOCK)  
               WHERE KITKey = @c_Kitkey
               AND KITLineNumber = @c_KitLineNumber
               AND Type = 'F'
         
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65340  
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert KITDETAIL Table Failed. (ispPOALKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  BREAK  
               END  
         
               UPDATE KITDETAIL WITH (ROWLOCK)  
               SET ExpectedQty = @n_packqty  
                 --, LOTTABLE04 = @dt_Lottable04
                 , ExternLineNo = RIGHT('00000' + CAST(@n_SKUGrp AS NVARCHAR),5)
                 , TrafficCop = NULL  
                 , EditWho = SUSER_SNAME()
                 , EditDate = GETDATE()
                WHERE KITKey = @c_Kitkey
                AND KITLineNumber = @c_KitLineNumber
                AND Type = 'F'

                SELECT @n_err = @@ERROR  
   
                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65345  
                   SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update KITDETAIL Table Failed. (ispPOALKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                   BREAK  
                END  
         
               SELECT @n_packqty = 0  
            END  
         END -- While packqty > 0
         NEXT_LOOP_UPD:
         FETCH NEXT FROM CUR_UPD INTO @c_SKU, @n_ExpectedQty, @c_Lottable02, @dt_Lottable04, @n_SKUGrp, @c_ExternLineNo
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END
   
   IF @b_Debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
   END

   --Initialize Temp table again after splitting F line
   IF (@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      DELETE FROM @T_KIT

      INSERT INTO @T_KIT (KITKey, KitLineNumber, SKU, ExpectedQty, Lottable02, Lottable04, KITType, PartitionIndex, BOMQty, BOMParentQty, ExternLineNo)
      SELECT KF.KITKey
           , KF.KITLineNumber
           , KF.Sku
           , (SUM(KF.ExpectedQty) / MAX(BOM.Qty)) * MAX(BOM.ParentQty) AS ExpectedQty
           , KF.LOTTABLE02
           , KF.LOTTABLE04
           , KF.[Type]
           , 1 AS PartitionIndex
           , MAX(BOM.Qty)
           , MAX(BOM.ParentQty)
           , KF.ExternLineNo
      FROM KIT (NOLOCK)
      JOIN KITDETAIL KF (NOLOCK) ON KIT.KITKey = KF.KITKey
      JOIN SKU (NOLOCK) ON KF.StorerKey = SKU.StorerKey AND KF.Sku = SKU.Sku
      JOIN BillOfMaterial BOM (NOLOCK) ON  KF.StorerKey = BOM.Storerkey
                                       AND KF.Sku = BOM.ComponentSku
                                       AND BOM.SKU = @c_ParentSku
      WHERE KF.KITKey = @c_Kitkey
      AND KF.Type = 'F'
      GROUP BY KF.KITKey
           , KF.Sku
           , KF.[Type]
           , KF.LOTTABLE02
           , KF.LOTTABLE04
           , KF.KITLineNumber
           , KF.ExternLineNo
      ORDER BY KF.SKU, KF.LOTTABLE04
   END

   --Insert/Split T Line
   IF (@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      IF @@TRANCOUNT = 0 AND @b_Debug = 0
         BEGIN TRAN

      DECLARE CUR_INS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT K.KITKey, @c_ParentSku, K.ExpectedQty, T.Lottable04, K.ExternLineNo
         FROM @T_KIT K
         CROSS APPLY (SELECT MIN(Lottable04) AS Lottable04
                      FROM @T_KIT TK
                      WHERE TK.KITKey = K.KITKey AND TK.ExternLineNo = K.ExternLineNo) AS T
         WHERE KITType = 'F'
         AND ExternLineNo <> ''
         GROUP BY K.KITKey, K.ExpectedQty, T.Lottable04, K.ExternLineNo
         ORDER BY K.ExternLineNo
      
      OPEN CUR_INS
      
      FETCH NEXT FROM CUR_INS INTO @c_Kitkey, @c_Sku, @n_ExpectedQty, @dt_Lottable04, @c_ExternLineNo
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @b_Debug = 2
            SELECT @c_Kitkey, @c_Sku, @n_ExpectedQty, @dt_Lottable04, @c_ExternLineNo, @c_Lottable02

         SET @c_Lottable02 = @c_Kitkey + RIGHT(@c_ExternLineNo, 2)

         IF EXISTS ( SELECT 1 
                     FROM KITDETAIL KT (NOLOCK)
                     WHERE KT.Kitkey = @c_Kitkey
                     AND KT.Type = 'T'
                     AND KT.KitLineNumber = @c_ExternLineNo )
         BEGIN
            UPDATE KITDETAIL WITH (ROWLOCK)
            SET ExpectedQty = @n_ExpectedQty
              , LOTTABLE02 = @c_Lottable02
              --, LOTTABLE03 = @c_Lottable03
              , LOTTABLE04 = @dt_Lottable04
            WHERE Kitkey = @c_Kitkey
            AND Type = 'T'
            AND KitLineNumber = @c_ExternLineNo

            SELECT @n_Err = @@ERROR

            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65350  
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update KITDETAIL Table Failed. (ispPOALKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
               GOTO QUIT_SP  
            END  
         END
         ELSE
         BEGIN
            IF EXISTS ( SELECT 1 
                        FROM KITDETAIL KT (NOLOCK)
                        WHERE KT.Kitkey = @c_Kitkey
                        AND KT.Type = 'T'
                        AND KT.LOTTABLE04 = @dt_Lottable04)   --Group same Lottable04
            BEGIN
               UPDATE KITDETAIL
               SET ExpectedQty = ExpectedQty + @n_ExpectedQty
                 , LOTTABLE02 = @c_Lottable02
                 --, LOTTABLE03 = @c_Lottable03
                 , LOTTABLE04 = @dt_Lottable04
               WHERE Kitkey = @c_Kitkey
               AND Type = 'T'
               AND LOTTABLE04 = @dt_Lottable04

               SELECT @n_Err = @@ERROR

               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65355  
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update KITDETAIL Table Failed. (ispPOALKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  GOTO QUIT_SP  
               END 
            END
            ELSE
            BEGIN
               INSERT INTO KITDETAIL (Kitkey, KitLineNumber, Type, Storerkey, Sku, Loc, ExpectedQty, Qty, Packkey, UOM, 
                                      Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07,
                                      Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, 
                                      Lottable15, ExternKitKey, ExternLineNo)
               SELECT TOP 1 @c_Kitkey, @c_ExternLineNo, 'T', Storerkey, Sku, Loc, @n_ExpectedQty, 0, Packkey, UOM, 
                            Lottable01, @c_Lottable02, Lottable03, @dt_Lottable04, Lottable05, Lottable06, Lottable07,--@c_Lottable03
                            Lottable08, Lottable09, Lottable10, Lottable11, LOttable12, Lottable13, Lottable14, 
                            Lottable15, ExternKitKey, ExternLineNo
               FROM KITDETAIL (NOLOCK)
               WHERE Kitkey = @c_Kitkey
               AND Type = 'T'

               SELECT @n_Err = @@ERROR

               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65360  
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert KITDETAIL Table Failed. (ispPOALKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  GOTO QUIT_SP  
               END 
            END
         END
          
         FETCH NEXT FROM CUR_INS INTO @c_Kitkey, @c_Sku, @n_ExpectedQty, @dt_Lottable04, @c_ExternLineNo
      END
      CLOSE CUR_INS
      DEALLOCATE CUR_INS
   END

   IF @b_Debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
   END

   QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_INS') IN (0 , 1)
   BEGIN
      CLOSE CUR_INS
      DEALLOCATE CUR_INS   
   END

   IF @n_Continue = 3 -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOALKIT02'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

   IF @b_Debug = 0
   BEGIN
      WHILE @@TRANCOUNT < @n_StartTCnt
         BEGIN TRAN
   END
END

GO