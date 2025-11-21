SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_IQC_RULES_200001_10             */
/* Creation Date: 09-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert into IQC target table     	               */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Active Flag                                 */
/*         @c_InParm2 = '1' Convert SKU to Uppercase                    */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-May-2022  GHChan    1.1   Initial                                 */
/* 27-Feb-2023  WLChooi   1.1   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_IQC_RULES_200001_10] (
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

   DECLARE @c_Storerkey      NVARCHAR(15)
         , @c_HReason        NVARCHAR(10)
         , @c_FROMFacility   NVARCHAR(5)
         , @c_ToFacility     NVARCHAR(5)
         , @c_TradeReturnkey NVARCHAR(10)
         , @c_RefNo          NVARCHAR(10)
         , @n_RowRefNo       INT
         , @c_IQCKey         NVARCHAR(10)
         , @n_GetQty         INT
         , @c_UOM            NVARCHAR(10)
         , @c_Packkey        NVARCHAR(10)
         , @c_Sku            NVARCHAR(20)
         , @n_ToQty          INT
         , @n_iNo            INT
         , @c_ttlMsg         NVARCHAR(250);

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

   IF @c_InParm1 = '1'
   BEGIN

      BEGIN TRANSACTION;

      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Storerkey
                    , ISNULL(HReason, '')
                    , ISNULL(TradeReturnkey, '')
                    , ISNULL(RefNo, '')
                    , FROM_facility
                    , to_facility
      FROM dbo.SCE_DL_IQC_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @c_Storerkey
         , @c_HReason
         , @c_TradeReturnkey
         , @c_RefNo
         , @c_FROMFacility
         , @c_ToFacility;

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SELECT TOP (1) @n_RowRefNo = RowRefNo
         FROM dbo.SCE_DL_IQC_STG WITH (NOLOCK)
         WHERE STG_BatchNo              = @n_BatchNo
         AND   STG_Status                 = '1'
         AND   Storerkey                  = @c_Storerkey
         AND   ISNULL(HReason, '')        = ISNULL(@c_HReason, '')
         AND   ISNULL(TradeReturnkey, '') = ISNULL(@c_TradeReturnkey, '')
         AND   ISNULL(RefNo, '')          = ISNULL(@c_RefNo, '')
         AND   FROM_facility              = @c_FROMFacility
         AND   To_Facility                = @c_ToFacility
         ORDER BY STG_SeqNo ASC;

         SELECT @b_Success = 0;
         EXEC dbo.nspg_getkey @keyname = 'invqc'
                            , @fieldlength = 10
                            , @keystring = @c_IQCKey OUTPUT
                            , @b_Success = @b_Success OUTPUT
                            , @n_err = @n_ErrNo OUTPUT
                            , @c_errmsg = @c_ErrMsg OUTPUT;

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3;
            SET @c_ErrMsg = 'Unable to get a new IQC Key from nspg_getkey.';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         INSERT INTO dbo.InventoryQC
         (
            QC_key
          , Storerkey
          , Reason
          , TradeReturnkey
          , RefNo
          , FROM_facility
          , to_facility
          , userdefine01
          , userdefine02
          , userdefine03
          , userdefine04
          , userdefine05
          , userdefine06
          , userdefine07
          , userdefine08
          , userdefine09
          , userdefine10
          , Notes
          , Addwho
          , Editwho
         )
         SELECT @c_IQCKey
              , @c_Storerkey
              , ISNULL(@c_HReason, '')
              , ISNULL(@c_TradeReturnkey, '')
              , @c_RefNo
              , @c_FROMFacility
              , @c_ToFacility
              , ISNULL(STG.HUdef01, '')
              , ISNULL(STG.HUdef02, '')
              , ISNULL(STG.HUdef03, '')
              , ISNULL(STG.HUdef04, '')
              , ISNULL(STG.HUdef05, '')
              , ISNULL(STG.HUdef06, '')
              , ISNULL(STG.HUdef07, '')
              , ISNULL(STG.HUdef08, '')
              , ISNULL(STG.HUdef09, '')
              , ISNULL(STG.HUdef10, '')
              , STG.Notes
              , @c_Username
              , @c_Username
         FROM dbo.SCE_DL_IQC_STG STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         SET @n_iNo = 0;

         DECLARE C_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRefNo
              , ISNULL(TRIM(CASE WHEN @c_InParm2 = '1' THEN UPPER(Sku)
                                  ELSE Sku
                             END
                       ), ''
                )
              , ISNULL(toqty, 0)
              , ISNULL(TRIM(PackKey), '')
              , ISNULL(TRIM(UOM), '')
         FROM dbo.SCE_DL_IQC_STG WITH (NOLOCK)
         WHERE STG_BatchNo              = @n_BatchNo
         AND   STG_Status                 = '1'
         AND   Storerkey                  = @c_Storerkey
         AND   ISNULL(HReason, '')        = ISNULL(@c_HReason, '')
         AND   ISNULL(TradeReturnkey, '') = ISNULL(@c_TradeReturnkey, '')
         AND   ISNULL(RefNo, '')          = ISNULL(@c_RefNo, '')
         AND   FROM_facility              = @c_FROMFacility
         AND   To_Facility                = @c_ToFacility;

         OPEN C_DET;

         FETCH NEXT FROM C_DET
         INTO @n_RowRefNo
            , @c_Sku
            , @n_ToQty
            , @c_Packkey
            , @c_UOM;

         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @n_iNo += 1;

            SELECT @n_GetQty = CASE @c_UOM WHEN LTRIM(TRIM(PackUOM1)) THEN CaseCnt * @n_ToQty
                                           WHEN LTRIM(TRIM(PackUOM2)) THEN InnerPack * @n_ToQty
                                           WHEN LTRIM(TRIM(PackUOM3)) THEN Qty * @n_ToQty
                                           WHEN LTRIM(TRIM(PackUOM4)) THEN Pallet * @n_ToQty
                                           WHEN LTRIM(TRIM(PackUOM8)) THEN OtherUnit1 * @n_ToQty
                                           WHEN LTRIM(TRIM(PackUOM9)) THEN OtherUnit2 * @n_ToQty
                                           ELSE 0
                               END
            FROM dbo.V_PACK (NOLOCK)
            WHERE PackKey = @c_Packkey
            AND   (
                   PackUOM1      = @c_UOM
                OR PackUOM2 = @c_UOM
                OR PackUOM3 = @c_UOM
                OR PackUOM4 = @c_UOM
                OR PackUOM5 = @c_UOM
                OR PackUOM6 = @c_UOM
                OR PackUOM7 = @c_UOM
                OR PackUOM8 = @c_UOM
                OR PackUOM9 = @c_UOM
            );

            INSERT INTO dbo.InventoryQCDetail
            (
               QC_Key
             , QCLineNo
             , StorerKey
             , SKU
             , PackKey
             , UOM
             , OriginalQty
             , Qty
             , FromLoc
             , FromLot
             , FromID
             , ToQty
             , ToID
             , ToLoc
             , Reason
             , UserDefine01
             , UserDefine02
             , UserDefine03
             , UserDefine04
             , UserDefine05
             , UserDefine06
             , UserDefine07
             , UserDefine08
             , UserDefine09
             , UserDefine10
             , AddWho
             , EditWho
            )
            SELECT @c_IQCKey
                 , CAST(FORMAT(@n_iNo, 'D5') AS NVARCHAR(5))
                 , @c_Storerkey
                 , @c_Sku
                 , @c_Packkey
                 , @c_UOM
                 , @n_GetQty
                 , ISNULL(Qty, 0)
                 , FromLoc
                 , FromLot
                 , ISNULL(FromID, '')
                 , @n_GetQty
                 , ISNULL(ToID, '')
                 , ToLoc
                 , ISNULL(DReason, 'OK')
                 , ISNULL(DUdef01, '')
                 , ISNULL(DUdef02, '')
                 , ISNULL(DUdef03, '')
                 , ISNULL(DUdef04, '')
                 , ISNULL(DUdef05, '')
                 , ISNULL(DUdef06, '')
                 , ISNULL(DUdef07, '')
                 , ISNULL(DUdef08, '')
                 , ISNULL(DUdef09, '')
                 , ISNULL(DUdef10, '')
                 , @c_Username
                 , @c_Username
            FROM dbo.SCE_DL_IQC_STG WITH (NOLOCK)
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;

            UPDATE dbo.SCE_DL_IQC_STG WITH (ROWLOCK)
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
               , @n_ToQty
               , @c_Packkey
               , @c_UOM;
         END;
         CLOSE C_DET;
         DEALLOCATE C_DET;

         FETCH NEXT FROM C_HDR
         INTO @c_Storerkey
            , @c_HReason
            , @c_TradeReturnkey
            , @c_RefNo
            , @c_FROMFacility
            , @c_ToFacility;
      END;

      CLOSE C_HDR;
      DEALLOCATE C_HDR;

      IF @@TRANCOUNT > 0
      COMMIT TRAN;
   END;

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_HDR') IN ( 0, 1 )
   BEGIN
      CLOSE C_HDR
      DEALLOCATE C_HDR
   END

   IF CURSOR_STATUS('LOCAL', 'C_DET') IN ( 0, 1 )
   BEGIN
      CLOSE C_DET
      DEALLOCATE C_DET
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_IQC_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '');
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