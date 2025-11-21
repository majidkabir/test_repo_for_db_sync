SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_KIT_RULES_200001_10             */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into KIT target table             */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore Update           */
/*                           @c_InParm1 =  '1'  Update is allow         */
/* Usage:  SKU Uppercase     @c_InParm2 =  '1'  Turn on                 */
/* Usage:  ByPass Checking   @c_InParm3 =  '1'  Turn on                 */
/* Usage:  KIT Strategy      @c_InParm4 =  '1'  Remy                    */
/*                           @c_InParm4 =  '2'  Max                     */
/* Usage:  GenerateIQC       @c_InParm5 =  '1'  Turn on                 */
/* Usage:  GenerateSO        @c_InParm5 =  '2'  Turn on                 */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2022  GHChan    1.1   Initial                                 */
/* 02-Jan-2023  WLChooi   1.2   WMS-24466 - Add Lot, Loc, ID & Qty and  */
/*                              Bug Fix (WL01)                          */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_KIT_RULES_200001_10] (
   @b_Debug       INT            = 0
 , @n_BatchNo     INT            = 0
 , @n_Flag        INT            = 0
 , @c_SubRuleJson NVARCHAR(MAX)
 , @c_STGTBL      NVARCHAR(250)  = ''
 , @c_POSTTBL     NVARCHAR(250)  = ''
 , @c_UniqKeyCol  NVARCHAR(1000) = ''
 , @c_Username    NVARCHAR(128)  = ''
 , @b_Success     INT            = 0 OUTPUT
 , @n_ErrNo       INT            = 0 OUTPUT
 , @c_ErrMsg      NVARCHAR(250)  = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_WARNINGS OFF;

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT;

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60);
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @c_Storerkey       NVARCHAR(15)
         , @c_ExternKitKey    NVARCHAR(20)
         , @c_KITKey          NVARCHAR(10)
         , @c_Status          NVARCHAR(10)
         , @n_ActionFlag      INT
         , @c_Facility        NVARCHAR(5)
         , @c_AdjustmentType  NVARCHAR(5)
         , @n_RowRefNo        INT
         , @c_AdjustmentKey   NVARCHAR(10)
         , @n_GetQty          INT
         , @c_UOM             NVARCHAR(10)
         , @c_Packkey         NVARCHAR(10)
         , @c_Sku             NVARCHAR(20)
         , @n_Qty             INT
         , @n_iNo             INT
         , @n_iFNo            INT
         , @n_iTNo            INT
         , @c_KitLineNo       NVARCHAR(10)
         , @c_ExternLineNo    NVARCHAR(10)
         , @c_GetKitLineNo    NVARCHAR(10)
         , @c_GetExternLineNo NVARCHAR(10)
         , @c_ttlMsg          NVARCHAR(250);

   DECLARE @c_DType       NVARCHAR(5)
         , @c_Lottable01  NVARCHAR(18)
         , @c_Lottable02  NVARCHAR(18)
         , @c_Lottable03  NVARCHAR(18)
         , @d_Lottable04  DATETIME
         , @d_Lottable05  DATETIME
         , @c_Lottable06  NVARCHAR(30)
         , @c_Lottable07  NVARCHAR(30)
         , @c_Lottable08  NVARCHAR(30)
         , @c_Lottable09  NVARCHAR(30)
         , @c_Lottable10  NVARCHAR(30)
         , @c_Lottable11  NVARCHAR(30)
         , @c_Lottable12  NVARCHAR(30)
         , @d_Lottable13  DATETIME
         , @d_Lottable14  DATETIME
         , @d_Lottable15  DATETIME
         , @n_ExpectedQty INT
         , @n_CaseCnt     INT;

   DECLARE @iID       INT
         , @n_CalcQty INT
         , @n_SumQty  INT
         , @n_UsedQty INT   --WL01
         , @c_Lot     NVARCHAR(10)   --WL01
         , @c_Loc     NVARCHAR(10)   --WL01
         , @c_ID      NVARCHAR(18)   --WL01

   DECLARE @KitDetail TABLE (
      iID          INT          IDENTITY
    , KitKey       NVARCHAR(10) NULL
    , Type         NVARCHAR(5)  NULL
    , SKU          NVARCHAR(20) NULL
    , Lot          NVARCHAR(10) NULL
    , Loc          NVARCHAR(10) NULL
    , Id           NVARCHAR(18) NULL
    , ExpectedQty  INT          NULL
    , Packkey      NVARCHAR(10) NULL
    , UOM          NVARCHAR(10) NULL
    , Lottable01   NVARCHAR(18) NULL
    , Lottable02   NVARCHAR(18) NULL
    , Lottable03   NVARCHAR(18) NULL
    , Lottable04   DATETIME     NULL
    , Lottable05   DATETIME     NULL
    , Lottable06   NVARCHAR(30) NULL
    , Lottable07   NVARCHAR(30) NULL
    , Lottable08   NVARCHAR(30) NULL
    , Lottable09   NVARCHAR(30) NULL
    , Lottable10   NVARCHAR(30) NULL
    , Lottable11   NVARCHAR(30) NULL
    , Lottable12   NVARCHAR(30) NULL
    , Lottable13   DATETIME     NULL
    , Lottable14   DATETIME     NULL
    , Lottable15   DATETIME     NULL
    , ExternKitkey NVARCHAR(20) NULL
    , KITLineNo    NVARCHAR(10) NULL
    , ExternLineNo NVARCHAR(10) NULL
    , Qty          INT NULL   --WL01
   );

   DECLARE @IQCDetail TABLE (
      iID           INT          IDENTITY(1, 1)
    , Storerkey     NVARCHAR(15) NULL
    , from_Facility NVARCHAR(5)  NULL
    , to_facility   NVARCHAR(5)  NULL
    , HReason       NVARCHAR(20) NULL
    , refno         NVARCHAR(10) NULL
    , SKU           NVARCHAR(20) NULL
    , OriginalQty   INT          NULL
    , Qty           INT          NULL
    , FromLoc       NVARCHAR(10) NULL
    , FromLot       NVARCHAR(10) NULL
    , FromID        NVARCHAR(18) NULL
    , ToLoc         NVARCHAR(10) NULL
    , DReason       NVARCHAR(20) NULL
   );

   DECLARE @LotxLocxID TABLE (
      iID       INT          IDENTITY(1, 1)
    , Storerkey NVARCHAR(15) NULL
    , SKU       NVARCHAR(20) NULL
    , Lot       NVARCHAR(10) NULL
    , Loc       NVARCHAR(10) NULL
    , ID        NVARCHAR(18) NULL
    , Qty       INT          NULL
   );

   DECLARE @Results TABLE (
      Storerkey NVARCHAR(15) NULL
    , SKU       NVARCHAR(20) NULL
    , Lot       NVARCHAR(10) NULL
    , Loc       NVARCHAR(10) NULL
    , ID        NVARCHAR(18) NULL
    , Qty       INT          NULL
   );

   DECLARE @KItINV TABLE (
      Storerkey NVARCHAR(15) NULL
    , SKU       NVARCHAR(20) NULL
    , Lot       NVARCHAR(10) NULL
    , Loc       NVARCHAR(10) NULL
    , ID        NVARCHAR(18) NULL
    , Qty       INT          NULL
   );

   CREATE TABLE #PopulateSO (
      Storerkey NVARCHAR(15) NULL
    , KITKey    NVARCHAR(10) NULL
   );

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (
      SPName NVARCHAR(300) '$.SubRuleSP'
    , InParm1 NVARCHAR(60) '$.InParm1'
    , InParm2 NVARCHAR(60) '$.InParm2'
    , InParm3 NVARCHAR(60) '$.InParm3'
    , InParm4 NVARCHAR(60) '$.InParm4'
    , InParm5 NVARCHAR(60) '$.InParm5'
      )
   WHERE SPName = OBJECT_NAME(@@PROCID);

   BEGIN TRANSACTION;

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT RTRIM(StorerKey)
                 , RTRIM(ExternKitkey)
                 , RTRIM(Facility)
   FROM dbo.SCE_DL_KIT_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1';

   OPEN C_HDR;
   FETCH NEXT FROM C_HDR
   INTO @c_Storerkey
      , @c_ExternKitKey
      , @c_Facility;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_KITKey = N'';
      SET @c_Status = N'';
      SELECT TOP (1) @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_KIT_STG WITH (NOLOCK)
      WHERE STG_BatchNo       = @n_BatchNo
      AND   STG_Status          = '1'
      AND   RTRIM(StorerKey)    = @c_Storerkey
      AND   RTRIM(ExternKitkey) = @c_ExternKitKey
      ORDER BY STG_SeqNo ASC;

      SELECT @c_KITKey = ISNULL(RTRIM(KITKey), '')
           , @c_Status = [Status]
      FROM dbo.V_KIT WITH (NOLOCK)
      WHERE StorerKey  = @c_Storerkey
      AND   ExternKitKey = @c_ExternKitKey
      AND   Facility     = @c_Facility;

      IF @c_InParm1 = '1'
      BEGIN
         IF @c_KITKey <> ''
         BEGIN
            IF @c_Status = '9'
            BEGIN
               UPDATE dbo.SCE_DL_KIT_STG WITH (ROWLOCK)
               SET STG_Status = '5'
                 , STG_ErrMsg = 'Error:Kit(' + @c_KITKey + ') already Finalized,UPDATE failed.'
               WHERE STG_BatchNo = @n_BatchNo
               AND   STG_Status    = '1'
               AND   Storerkey     = @c_Storerkey
               AND   ExternKitKey  = @c_ExternKitKey;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;
               GOTO NEXTITEM;
            END;
            ELSE
            BEGIN
               SET @n_ActionFlag = 1; -- UPDATE
            END;

         END;
         ELSE
         BEGIN
            SET @n_ActionFlag = 0; -- INSERT
         END;
      END;
      ELSE IF @c_InParm1 = '0'
      BEGIN
         IF @c_KITKey <> ''
         BEGIN
            UPDATE dbo.SCE_DL_KIT_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error:KIT(' + @c_KITKey + ') already exists'
            WHERE STG_BatchNo = @n_BatchNo
            AND   STG_Status    = '1'
            AND   Storerkey     = @c_Storerkey
            AND   ExternKitKey  = @c_ExternKitKey;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
            GOTO NEXTITEM;
         END;
         ELSE
         BEGIN
            SET @n_ActionFlag = 0; -- INSERT
         END;
      END;

      IF @n_ActionFlag = 1
      BEGIN
         UPDATE K WITH (ROWLOCK)
         SET K.StorerKey = STG.StorerKey
           , K.ToStorerKey = ISNULL(STG.ToStorerKey, STG.StorerKey)
           , K.Type = ISNULL(STG.HType, 'RC1')
           , K.EffectiveDate = STG.EffectiveDate
           , K.ReasonCode = ISNULL(STG.ReasonCode, 'A01')
           , K.CustomerRefNo = STG.CustomerRefNo
           , K.Remarks = STG.Remarks
           , K.Facility = STG.Facility
           , K.USRDEF1 = STG.HUdef01
           , K.USRDEF2 = STG.HUdef02
           , K.USRDEF3 = STG.HUdef03
           , K.ExternKitKey = STG.ExternKitKey
           , K.EditWho = @c_Username
         FROM dbo.KIT                  K
         INNER JOIN dbo.SCE_DL_KIT_STG STG WITH (NOLOCK)
         ON  K.StorerKey     = STG.StorerKey
         AND K.ExternKitKey = STG.ExternKitKey
         WHERE STG.RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         DELETE FROM dbo.KITDETAIL
         WHERE KITKey = @c_KITKey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;
      ELSE IF @n_ActionFlag = 0
      BEGIN
         SELECT @b_Success = 0;
         EXEC dbo.nspg_GetKey @KeyName = 'Kitting'
                            , @fieldlength = 10
                            , @keystring = @c_KITKey OUTPUT
                            , @b_Success = @b_Success OUTPUT
                            , @n_err = @n_ErrNo OUTPUT
                            , @c_errmsg = @c_ErrMsg OUTPUT;

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3;
            SET @c_ErrMsg = N'Unable to get a new KITKey from nspg_getkey.';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         INSERT INTO dbo.KIT
         (
            KITKey
          , StorerKey
          , ToStorerKey
          , Type
          , EffectiveDate
          , ReasonCode
          , CustomerRefNo
          , Remarks
          , Facility
          , USRDEF1
          , USRDEF2
          , USRDEF3
          , ExternKitKey
          , AddWho
          , EditWho
         )
         SELECT @c_KITKey
              , @c_Storerkey
              , ISNULL(STG.ToStorerkey, @c_Storerkey)
              , ISNULL(STG.HType, 'RC1')
              , STG.EffectiveDate
              , ISNULL(STG.ReasonCode, 'A01')
              , STG.CustomerRefNo
              , STG.Remarks
              , STG.Facility
              , STG.HUdef01
              , STG.HUdef02
              , STG.HUdef03
              , @c_ExternKitKey
              , @c_Username
              , @c_Username
         FROM dbo.SCE_DL_KIT_STG STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;

      SET @n_iNo = 0; --(CS05)  
      SET @n_iFNo = 0; --(CS05)  
      SET @n_iTNo = 0; --(CS05)  

      DECLARE C_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , CASE WHEN @c_InParm2 = '1' THEN UPPER(SKU)
                  ELSE SKU
             END
           , DType
           , LOTTABLE01
           , LOTTABLE02
           , LOTTABLE03
           , LOTTABLE04
           , LOTTABLE05
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
           , ExpectedQty
           , ISNULL(Qty, 0)   --WL01
           , ISNULL(TRIM(Lot), '')   --WL01
           , ISNULL(TRIM(Loc), '')   --WL01
           , ISNULL(TRIM(ID ), '')   --WL01
      FROM dbo.SCE_DL_KIT_STG WITH (NOLOCK)
      WHERE STG_BatchNo       = @n_BatchNo
      AND   STG_Status          = '1'
      AND   RTRIM(Storerkey)    = @c_Storerkey
      AND   RTRIM(ExternKitKey) = @c_ExternKitKey
      AND   RTRIM(Facility)     = @c_Facility;

      OPEN C_DET;

      FETCH NEXT FROM C_DET
      INTO @n_RowRefNo
         , @c_Sku
         , @c_DType
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
         , @n_ExpectedQty
         , @n_UsedQty   --WL01
         , @c_Lot       --WL01
         , @c_Loc       --WL01
         , @c_ID        --WL01

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SELECT @c_Packkey = P.PackKey
              , @c_UOM     = P.PackUOM3
              , @n_CaseCnt = CAST(P.CaseCnt AS INT)
         FROM dbo.V_SKU        S WITH (NOLOCK)
         INNER JOIN dbo.V_PACK P WITH (NOLOCK)
         ON P.PackKey = S.PACKKey
         WHERE S.Sku = @c_Sku;

         IF @c_InParm3 = '0'   --WL01
         BEGIN
            IF @c_DType = 'T'
            BEGIN
               INSERT INTO @KitDetail
               (
                  KitKey
                , Type
                , SKU
                , ExpectedQty
                , Packkey
                , UOM
                , ExternKitkey
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
                , Qty   --WL01
               )
               VALUES
               (
                  @c_KITKey
                , @c_DType
                , @c_Sku
                , @n_ExpectedQty
                , @c_Packkey
                , @c_UOM
                , @c_ExternKitKey
                , ISNULL(@c_Lottable01, '')
                , ISNULL(@c_Lottable02, '')
                , ISNULL(@c_Lottable03, '')
                , ISNULL(@d_Lottable04, '')
                , ISNULL(@d_Lottable05, '')
                , ISNULL(@c_Lottable06, '')
                , ISNULL(@c_Lottable07, '')
                , ISNULL(@c_Lottable08, '')
                , ISNULL(@c_Lottable09, '')
                , ISNULL(@c_Lottable10, '')
                , ISNULL(@c_Lottable11, '')
                , ISNULL(@c_Lottable12, '')
                , ISNULL(@d_Lottable13, '')
                , ISNULL(@d_Lottable14, '')
                , ISNULL(@d_Lottable15, '')
                , @n_UsedQty   --WL01
               );

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;
            END;
            ELSE
            BEGIN
               SET @n_CalcQty = 0;

               IF @c_InParm4 = '1'
               BEGIN

                  INSERT INTO @LotxLocxID (Storerkey, SKU, Lot, Loc, ID, Qty)
                  SELECT @c_Storerkey
                       , @c_Sku
                       , t1.Lot
                       , t1.Loc
                       , t1.Id
                       , (t1.Qty - t1.QtyAllocated - t1.QtyPicked)
                  FROM dbo.V_LOTxLOCxID        AS t1 WITH (NOLOCK)
                  LEFT JOIN dbo.V_LOTATTRIBUTE AS t2 WITH (NOLOCK)
                  ON  t1.StorerKey = t2.StorerKey
                  AND t1.Sku      = t2.Sku
                  AND t1.Lot      = t2.Lot
                  INNER JOIN dbo.V_LOC         AS t3 WITH (NOLOCK)
                  ON t1.Loc       = t3.Loc
                  WHERE t1.StorerKey                                           = @c_Storerkey
                  AND   t1.Sku                                                   = @c_Sku
                  AND   t3.Facility                                              = @c_Facility
                  AND   t1.Qty - t1.QtyAllocated - t1.QtyPicked                  > 0
                  AND   ((t1.Qty - t1.QtyAllocated - t1.QtyPicked) % @n_CaseCnt) = 0
                  AND   (CASE WHEN ISNULL(@c_Lottable02, '') = '' THEN 1
                              WHEN ISNULL(@c_Lottable02, '') <> ''
                              AND  t2.Lottable02 = @c_Lottable02 THEN 1
                              ELSE 0
                         END
                        )                                                        = 1
                  ORDER BY t2.Lottable05
                         , t1.Loc;

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     ROLLBACK TRAN;
                     GOTO QUIT;
                  END;
               END;
               ELSE IF @c_InParm4 = '2'
               BEGIN
                  INSERT INTO @LotxLocxID (Storerkey, SKU, Lot, Loc, ID, Qty)
                  SELECT @c_Storerkey
                       , @c_Sku
                       , t1.Lot
                       , t1.Loc
                       , t1.Id
                       , (t1.Qty - t1.QtyAllocated - t1.QtyPicked - ISNULL(t6.Qty, 0))
                  FROM dbo.V_LOTxLOCxID        AS t1 WITH (NOLOCK)
                  LEFT JOIN dbo.V_LOTATTRIBUTE AS t2 WITH (NOLOCK)
                  ON  t1.StorerKey = t2.StorerKey
                  AND t1.Sku      = t2.Sku
                  AND t1.Lot      = t2.Lot
                  INNER JOIN dbo.V_LOC         AS t3 WITH (NOLOCK)
                  ON t1.Loc       = t3.Loc
                  INNER JOIN dbo.V_LOT         AS t4 WITH (NOLOCK)
                  ON t1.Lot       = t4.Lot
                  INNER JOIN dbo.V_ID          AS t5 WITH (NOLOCK)
                  ON t1.Id        = t5.Id
                  LEFT JOIN (
                  SELECT Storerkey
                       , SKU
                       , Lot
                       , Loc
                       , ID
                       , SUM(Qty) AS Qty
                  FROM @KItINV
                  WHERE Storerkey = @c_Storerkey
                  GROUP BY Storerkey
                         , SKU
                         , Lot
                         , Loc
                         , ID
                  )                            AS t6
                  ON  t1.StorerKey = t6.Storerkey
                  AND t1.Sku      = t6.SKU
                  AND t1.Lot      = t6.Lot
                  AND t1.Loc      = t6.Loc
                  WHERE t1.StorerKey                                              = @c_Storerkey
                  AND   t1.Sku                                                      = @c_Sku
                  AND   t3.Facility                                                 = @c_Facility
                  AND   t3.LocationFlag                                             = 'NONE'
                  AND   t4.Status                                                   <> 'HOLD'
                  AND   t5.Status                                                   <> 'HOLD'
                  AND   t1.Qty - t1.QtyAllocated - t1.QtyPicked - ISNULL(t6.Qty, 0) > 0
                  AND   (CASE WHEN ISNULL(@c_Lottable02, '') = '' THEN 1
                              WHEN ISNULL(@c_Lottable02, '') <> ''
                              AND  t2.Lottable02 = @c_Lottable02 THEN 1
                              ELSE 0
                         END
                        )                                                           = 1
                  AND   (CASE WHEN ISNULL(@d_Lottable04, '1900-1-1') = '1900-1-1' THEN 1
                              WHEN ISNULL(@d_Lottable04, '1900-1-1') <> '1900-1-1'
                              AND  t2.Lottable04 = @d_Lottable04 THEN 1
                              ELSE 0
                         END
                        )                                                           = 1
                  ORDER BY t2.Lottable05
                         , ((t1.Qty - t1.QtyAllocated - t1.QtyPicked - ISNULL(t6.Qty, 0)) % @n_CaseCnt) DESC
                         , (t1.Qty - t1.QtyAllocated - t1.QtyPicked - ISNULL(t6.Qty, 0))
                         , t1.Loc;


                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     ROLLBACK TRAN;
                     GOTO QUIT;
                  END;
               END;

               SELECT @n_SumQty = SUM(Qty)
               FROM @LotxLocxID;

               IF ISNULL(@n_SumQty, 0) < @n_Qty
                  SET @n_Qty = @n_SumQty;

               WHILE @n_Qty > 0
               BEGIN

                  SELECT TOP (1) @iID       = iID
                               , @n_CalcQty = Qty
                  FROM @LotxLocxID
                  ORDER BY iID;

                  IF @n_CalcQty >= @n_Qty
                  BEGIN
                     INSERT INTO @Results (Storerkey, SKU, Lot, Loc, ID, Qty)
                     SELECT Storerkey
                          , SKU
                          , Lot
                          , Loc
                          , ID
                          , @n_Qty
                     FROM @LotxLocxID
                     WHERE iID = @iID;

                     SET @n_Qty = 0;
                  END;
                  ELSE
                  BEGIN
                     INSERT INTO @Results (Storerkey, SKU, Lot, Loc, ID, Qty)
                     SELECT Storerkey
                          , SKU
                          , Lot
                          , Loc
                          , ID
                          , Qty
                     FROM @LotxLocxID
                     WHERE iID = @iID;

                     DELETE @LotxLocxID
                     WHERE iID = @iID;

                     SET @n_Qty = @n_Qty - @n_CalcQty;
                  END;
               END;

               INSERT INTO @KitDetail
               (
                  KitKey
                , Type
                , SKU
                , Lot
                , Loc
                , Id
                , ExpectedQty
                , Packkey
                , UOM
                , Lottable01
                , Lottable02
                , Lottable03
                , Lottable04
                , Lottable05
                , ExternKitkey
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
                , Qty
               )
               SELECT @c_KITKey
                    , @c_DType
                    , @c_Sku
                    , t1.Lot
                    , t1.Loc
                    , t1.ID
                    , t1.Qty
                    , @c_Packkey
                    , @c_UOM
                    , ISNULL(t2.Lottable01, '')
                    , ISNULL(t2.Lottable02, '')
                    , ISNULL(t2.Lottable03, '')
                    , t2.Lottable04
                    , t2.Lottable05
                    , @c_ExternKitKey
                    , ISNULL(t2.Lottable06, '')
                    , ISNULL(t2.Lottable07, '')
                    , ISNULL(t2.Lottable08, '')
                    , ISNULL(t2.Lottable09, '')
                    , ISNULL(t2.Lottable10, '')
                    , ISNULL(t2.Lottable11, '')
                    , ISNULL(t2.Lottable12, '')
                    , t2.Lottable13
                    , t2.Lottable14
                    , t2.Lottable15
                    , @n_UsedQty   --WL01
               FROM @Results                 t1
               INNER JOIN dbo.V_LOTATTRIBUTE t2 WITH (NOLOCK)
               ON  t2.Sku        = t1.SKU
               AND t2.StorerKey = t1.Storerkey
               AND t2.Lot       = t1.Lot
               WHERE t1.Storerkey = @c_Storerkey
               AND   t1.SKU         = @c_Sku;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;

               IF @c_InParm5 = '1'
               BEGIN -- @c_GenerateIQC='1'

                  INSERT INTO @IQCDetail
                  (
                     Storerkey
                   , from_Facility
                   , to_facility
                   , HReason
                   , refno
                   , SKU
                   , OriginalQty
                   , Qty
                   , FromLoc
                   , FromLot
                   , FromID
                   , ToLoc
                   , DReason
                  )
                  SELECT t1.Storerkey
                       , @c_Facility
                       , 'CKT01'
                       , 'RC_KD1'
                       , ''
                       , t1.SKU
                       , SUM(t2.Qty)
                       , SUM(t1.Qty)
                       , t1.Loc
                       , t1.Lot
                       , t1.ID
                       , 'RCKIT-D'
                       , 'OK'
                  FROM @Results               AS t1
                  INNER JOIN dbo.V_LOTxLOCxID AS t2 WITH (NOLOCK)
                  ON  t1.Storerkey = t2.StorerKey
                  AND t1.SKU      = t2.Sku
                  AND t1.Lot      = t2.Lot
                  WHERE t1.Storerkey = @c_Storerkey
                  AND   t1.SKU         = @c_Sku
                  GROUP BY t1.Storerkey
                         , t1.SKU
                         , t1.Loc
                         , t1.Lot
                         , t1.ID;

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     ROLLBACK TRAN;
                     GOTO QUIT;
                  END;

                  INSERT INTO dbo.SCE_DL_IQC_STG
                  (
                     STG_BatchNo
                   , STG_SeqNo
                   , STG_Status
                   , Storerkey
                   , from_facility
                   , to_facility
                   , HReason
                   , Refno
                   , SKU
                   , Originalqty
                   , Qty
                   , FromLoc
                   , FromLot
                   , FromID
                   , ToLoc
                   , ToQty
                   , DReason
                   , addwho
                  )
                  SELECT @n_BatchNo
                       , iID
                       , '1'
                       , Storerkey
                       , from_Facility
                       , to_facility
                       , HReason
                       , refno
                       , SKU
                       , OriginalQty
                       , Qty
                       , FromLoc
                       , FromLot
                       , FromID
                       , ToLoc
                       , Qty
                       , DReason
                       , @c_Username
                  FROM @IQCDetail;


                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3;
                     ROLLBACK TRAN;
                     GOTO QUIT;
                  END;

                  SET @c_SubRuleJson = N'[{"SubRuleSP":"isp_SCE_DL_GENERIC_IQC_RULES_200001_10","InParm1":"1","InParm2":"'
                                       + @c_InParm2 + ' ","InParm3":"","InParm4":"","InParm5":""}]';

                  EXEC dbo.isp_SCE_DL_GENERIC_IQC_RULES_200001_10 @b_Debug = @b_Debug
                                                                , @n_BatchNo = @n_BatchNo
                                                                , @n_Flag = @n_Flag
                                                                , @c_SubRuleJson = @c_SubRuleJson
                                                                , @c_STGTBL = @c_STGTBL
                                                                , @c_POSTTBL = @c_POSTTBL
                                                                , @c_UniqKeyCol = @c_UniqKeyCol
                                                                , @c_Username = @c_Username
                                                                , @b_Success = @b_Success OUTPUT
                                                                , @n_ErrNo = @n_ErrNo OUTPUT
                                                                , @c_ErrMsg = @c_ErrMsg OUTPUT;

                  IF @n_ErrNo <> 0
                  OR @c_ErrMsg <> ''
                  BEGIN
                     SET @n_Continue = 3;
                     IF @@TRANCOUNT > 0
                     BEGIN
                        ROLLBACK TRAN;
                     END
                     
                     GOTO QUIT;
                  END;

               END; --@c_GenerateIQC='1'
            END; --@c_DType <>'T'
         END;
         ELSE
         BEGIN
            IF @c_DType = 'T'
            BEGIN
               SET @n_iTNo += 1;
               SET @c_KitLineNo = CAST(FORMAT(@n_iTNo, 'D5') AS NVARCHAR(10));
               SET @c_ExternLineNo = @c_KitLineNo;
            END;
            ELSE
            BEGIN
               SET @n_iFNo += 1;
               SET @c_KitLineNo = CAST(FORMAT(@n_iFNo, 'D5') AS NVARCHAR(10));
               SET @c_ExternLineNo = @c_KitLineNo;
            END;

            INSERT INTO @KitDetail
            (
               KitKey
             , Type
             , SKU
             , ExpectedQty
             , Packkey
             , UOM
             , ExternKitkey
             , Lottable01
             , Lottable02
             , Lottable03
             , Lottable04
             , Lottable05
             , KITLineNo
             , ExternLineNo
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
             , Qty   --WL01
             , Lot   --WL01
             , Loc   --WL01
             , ID    --WL01
            )
            VALUES
            (
               @c_KITKey
             , @c_DType
             , @c_Sku
             , @n_ExpectedQty   --WL01
             , @c_Packkey
             , @c_UOM
             , @c_ExternKitKey
             , ISNULL(@c_Lottable01, '')
             , ISNULL(@c_Lottable02, '')
             , ISNULL(@c_Lottable03, '')
             , ISNULL(@d_Lottable04, '')
             , ISNULL(@d_Lottable05, '')
             , @c_KitLineNo
             , @c_ExternLineNo
             , ISNULL(@c_Lottable06, '')
             , ISNULL(@c_Lottable07, '')
             , ISNULL(@c_Lottable08, '')
             , ISNULL(@c_Lottable09, '')
             , ISNULL(@c_Lottable10, '')
             , ISNULL(@c_Lottable11, '')
             , ISNULL(@c_Lottable12, '')
             , ISNULL(@d_Lottable13, '')
             , ISNULL(@d_Lottable14, '')
             , ISNULL(@d_Lottable15, '')
             , @n_UsedQty   --WL01
             , @c_Lot   --WL01
             , @c_Loc   --WL01
             , @c_ID    --WL01
            );

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
         END;

         UPDATE dbo.SCE_DL_KIT_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         FETCH NEXT FROM C_DET
         INTO @n_RowRefNo
            , @c_Sku
            , @c_DType
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
            , @n_ExpectedQty
            , @n_UsedQty   --WL01
            , @c_Lot       --WL01
            , @c_Loc       --WL01
            , @c_ID        --WL01
      END;
      CLOSE C_DET;
      DEALLOCATE C_DET;

      SELECT @c_GetKitLineNo = ISNULL(RTRIM(KITLineNo), '')
           , @c_ExternLineNo = ISNULL(RTRIM(ExternLineNo), '')
      FROM @KitDetail;

      INSERT INTO dbo.KITDETAIL
      (
         KITKey
       , KITLineNumber
       , Type
       , StorerKey
       , Sku
       , Lot
       , Loc
       , Id
       , ExpectedQty
       , PackKey
       , UOM
       , LOTTABLE01
       , LOTTABLE02
       , LOTTABLE03
       , LOTTABLE04
       , LOTTABLE05
       , ExternKitKey
       , ExternLineNo
       , AddWho
       , EditWho
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
       , Qty   --WL01
      )
      SELECT KitKey
           , CASE WHEN @c_GetKitLineNo = ''
                  AND  @c_ExternLineNo = '' THEN CAST(FORMAT(iID, 'D5') AS NVARCHAR(5))
                  ELSE KITLineNo
             END
           , Type
           , @c_Storerkey
           , SKU
           , ISNULL(Lot, '')
           , ISNULL(Loc, '')
           , ISNULL(Id, '')
           , ExpectedQty
           , Packkey
           , UOM
           , Lottable01
           , Lottable02
           , Lottable03
           , Lottable04
           , Lottable05
           , ExternKitkey
           , CASE WHEN @c_GetKitLineNo = ''
                  AND  @c_ExternLineNo = '' THEN CAST(FORMAT(iID, 'D5') AS NVARCHAR(5))
                  ELSE ExternLineNo
             END
           , @c_Username
           , @c_Username
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
           , Qty   --WL01
      FROM @KitDetail;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      INSERT INTO @KItINV (Storerkey, SKU, Lot, Loc, ID, Qty)
      SELECT @c_Storerkey
           , SKU
           , Lot
           , Loc
           , Id
           , ExpectedQty
      FROM @KitDetail;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      SELECT @n_SumQty = SUM(ISNULL(ExpectedQty, 0))
      FROM @KitDetail;

      IF @c_InParm3 = '1'
      BEGIN
         SELECT @n_SumQty = SUM(ISNULL(ExpectedQty, 0))
         FROM @KitDetail
         WHERE [Type] = CASE WHEN @c_DType = 'T' THEN 'T'
                             ELSE [Type]
                        END;
      END;

      UPDATE dbo.KIT WITH (ROWLOCK)
      SET OpenQty = ISNULL(@n_SumQty,0)
      WHERE KITKey = @c_KITKey;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      IF @c_InParm5 = '2'
      BEGIN

         INSERT INTO #PopulateSO (Storerkey, KITKey)
         VALUES
         (@c_Storerkey, @c_KITKey);

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         BEGIN TRAN;

         EXEC [dbo].ispGenerateSOfromKit_Wrapper @c_StorerKey = @c_Storerkey
                                               , @c_KitKey = @c_KITKey
                                               , @b_Success = @b_Success OUTPUT
                                               , @n_Err = @n_ErrNo OUTPUT
                                               , @c_Errmsg = @c_ErrMsg OUTPUT;

         IF @b_Debug = '1'
         BEGIN
            PRINT 'Error Msg Return : ' + @c_ErrMsg;
         END;

         IF @@ERROR = 0
         BEGIN
            WHILE @@TRANCOUNT > 0
            COMMIT TRAN;
         END;
         ELSE
         BEGIN
            ROLLBACK TRAN;
            BREAK;
            GOTO QUIT;
         END;
      END;

      DELETE @KitDetail;

      NEXTITEM:
      FETCH NEXT FROM C_HDR
      INTO @c_Storerkey
         , @c_ExternKitKey
         , @c_Facility;
   END;

   CLOSE C_HDR;
   DEALLOCATE C_HDR;

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_KIT_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
   END;

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1;
   END;
   ELSE
   BEGIN
      SET @b_Success = 0;
   END;
END;
GO