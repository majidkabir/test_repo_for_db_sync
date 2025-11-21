SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_UCC_RULES_200001_10             */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into UCC target table             */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 = '0' Ignore update             */
/*                           @c_InParm1 = '1' Update is allow           */
/* Usage:  Check Status      @c_InParm2 = '0' Turn off                  */
/*                           @c_InParm2 = '1' Check Status with 6       */
/* Usage:  Delete UCC        @c_InParm3 = '0' Turn off                  */
/*                           @c_InParm3 = '1' Delete UCC with UCCNo     */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_UCC_RULES_200001_10] (
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

   DECLARE @c_StorerKey        NVARCHAR(15)
         , @c_Sku              NVARCHAR(20)
         , @c_UCCNo            NVARCHAR(20)
         , @c_PreSku           NVARCHAR(20)
         , @c_PreUCCNo         NVARCHAR(20)
         , @c_Status           NVARCHAR(1)
         , @n_RowRefNo         INT
         , @n_FoundExist       INT
         , @n_ActionFlag       INT
         , @n_UCC_RowRef       INT
         , @c_StorerConfig_UCC NVARCHAR(1)
         , @c_ttlMsg           NVARCHAR(250);

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
      SELECT RowRefNo
           , UCCNo
           , Storerkey
           , SKU
           , UCC_RowRef
      FROM dbo.SCE_DL_UCC_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_UCCNo
         , @c_StorerKey
         , @c_Sku
         , @n_UCC_RowRef;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_Status = N'';
         SET @n_FoundExist = 0;
         SET @n_ActionFlag = 0;

         SELECT @n_FoundExist = 1
              , @c_Status     = ISNULL(RTRIM([Status]), '')
         FROM dbo.V_UCC WITH (NOLOCK)
         WHERE Storerkey = @c_StorerKey
         AND   UCCNo       = @c_UCCNo
         AND   SKU         = @c_Sku;

         SELECT @c_StorerConfig_UCC = SValue
         FROM dbo.V_StorerConfig WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
         AND   ConfigKey   = 'UCC';

         IF @c_InParm1 = '1'
         BEGIN
            IF @n_FoundExist = 1
            BEGIN
               IF @c_InParm2 = '1'
               BEGIN
                  IF @c_Status = '6'
                  BEGIN
                     UPDATE dbo.SCE_DL_UCC_STG WITH (ROWLOCK)
                     SET STG_Status = '5'
                       , STG_ErrMsg = '/UCC with UCCNo ' + @c_UCCNo + N' Storerkey : ' + @c_StorerKey + N' And SKU : ' + @c_Sku
                                      + N' AND UCC_RowRef ' + CONVERT(NVARCHAR(10), @n_UCC_RowRef)
                                      + N' with Status = 6 .Update not allow'
                     WHERE RowRefNo = @n_RowRefNo;

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
                  IF @c_Status > '0'
                  BEGIN
                     UPDATE dbo.SCE_DL_UCC_STG WITH (ROWLOCK)
                     SET STG_Status = '5'
                       , STG_ErrMsg = '/UCC with UCCNo ' + @c_UCCNo + N' Storerkey : ' + @c_StorerKey + N' And SKU : ' + @c_Sku
                                      + N' AND UCC_RowRef ' + CONVERT(NVARCHAR(10), @n_UCC_RowRef)
                                      + N' with Status > 0.Update not allow'
                     WHERE RowRefNo = @n_RowRefNo;

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
            END;
            ELSE
            BEGIN
               SET @n_ActionFlag = 0; -- INSERT
            END;
         END;
         ELSE IF @c_InParm1 = '0'
         BEGIN
            IF @n_FoundExist = 1
            BEGIN
               UPDATE dbo.SCE_DL_UCC_STG WITH (ROWLOCK)
               SET STG_Status = '5'
                 , STG_ErrMsg = '/UCC with UCCNo ' + @c_UCCNo + N'Storerkey : ' + @c_StorerKey + N' And SKU : ' + @c_Sku
                                + N' AND UCC_RowRef ' + CONVERT(NVARCHAR(10), @n_UCC_RowRef) + N' Not exist.Update not allow'
               WHERE RowRefNo = @n_RowRefNo;

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
            IF @c_InParm3 = '1'
            BEGIN
               IF @c_Status > 1
               BEGIN
                  UPDATE dbo.SCE_DL_UCC_STG WITH (ROWLOCK)
                  SET STG_Status = '5'
                    , STG_ErrMsg = '/UCC with UCCNo ' + @c_UCCNo + N' Storerkey : ' + @c_StorerKey + N' And SKU : ' + @c_Sku
                                   + N' with Status > 1 .Delete update not allow'
                  WHERE RowRefNo = @n_RowRefNo;

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
                  SET @n_ActionFlag = 2; -- DELETE
               END;
            END;
            ELSE
            BEGIN
               SET @c_StorerConfig_UCC = N'';

               SELECT @c_StorerConfig_UCC = ISNULL(RTRIM(SValue), '')
               FROM dbo.V_StorerConfig WITH (NOLOCK)
               WHERE StorerKey = @c_StorerKey
               AND   ConfigKey   = 'UCC';


               UPDATE TGT WITH (ROWLOCK)
               SET TGT.Userdefined01 = ISNULL(STG.Userdefined01, '')
                 , TGT.Userdefined02 = ISNULL(STG.Userdefined02, '')
                 , TGT.Userdefined03 = ISNULL(STG.Userdefined03, '')
                 , TGT.Userdefined04 = ISNULL(STG.Userdefined04, '')
                 , TGT.Userdefined05 = ISNULL(STG.Userdefined05, '')
                 , TGT.Userdefined06 = ISNULL(STG.Userdefined06, '')
                 , TGT.Userdefined07 = ISNULL(STG.Userdefined07, '')
                 , TGT.Userdefined08 = ISNULL(STG.Userdefined08, '')
                 , TGT.Userdefined09 = ISNULL(STG.Userdefined09, '')
                 , TGT.Userdefined10 = ISNULL(STG.Userdefined10, '')
                 , qty = CASE WHEN @c_StorerConfig_UCC <> '1' THEN STG.qty
                              ELSE TGT.qty
                         END
                 , EditWho = @c_Username
                 , EditDate = GETDATE()
               FROM dbo.UCC                  TGT
               INNER JOIN dbo.SCE_DL_UCC_STG STG WITH (NOLOCK)
               ON (
                   TGT.UCC_RowRef    = STG.UCC_RowRef
               AND TGT.Storerkey = STG.Storerkey
               AND TGT.UCCNo     = STG.UCCNo
               AND TGT.SKU       = STG.SKU
               )
               WHERE STG.RowRefNo = @n_RowRefNo;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;
            END;
         END;

         IF @n_ActionFlag = 2
         BEGIN
            IF @c_PreUCCNo <> @c_UCCNo
            OR @c_Sku <> @c_PreSku
            BEGIN
               DELETE FROM dbo.UCC
               WHERE UCCNo = @c_UCCNo
               AND   Status  = '1'
               AND   SKU     = @c_Sku;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;
            END;

            SET @n_ActionFlag = 0;
         END;

         IF @n_ActionFlag = 0
         BEGIN
            INSERT INTO dbo.UCC
            (
               UCCNo
             , Storerkey
             , ExternKey
             , SKU
             , qty
             , Sourcekey
             , Sourcetype
             , Userdefined01
             , Userdefined02
             , Userdefined03
             , Status
             , AddWho
             , EditWho
             , Lot
             , Loc
             , Id
             , Receiptkey
             , ReceiptLineNumber
             , Orderkey
             , OrderLineNumber
             , WaveKey
             , PickDetailKey
             , Userdefined04
             , Userdefined05
             , Userdefined06
             , Userdefined07
             , Userdefined08
             , Userdefined09
             , Userdefined10
            )
            SELECT UCCNo
                 , Storerkey
                 , ExternKey
                 , SKU
                 , qty
                 , ISNULL(Sourcekey, '')
                 , ISNULL(Sourcetype, 'PO')
                 , ISNULL(Userdefined01, '')
                 , ISNULL(Userdefined02, '')
                 , ISNULL(Userdefined03, '')
                 , ISNULL(Status, '1')
                 , @c_Username
                 , @c_Username
                 , Lot
                 , Loc
                 , Id
                 , Receiptkey
                 , ReceiptLineNumber
                 , Orderkey
                 , OrderLineNumber
                 , WaveKey
                 , PickDetailKey
                 , ISNULL(Userdefined04, '')
                 , ISNULL(Userdefined05, '')
                 , ISNULL(Userdefined06, '')
                 , ISNULL(Userdefined07, '')
                 , ISNULL(Userdefined08, '')
                 , ISNULL(Userdefined09, '')
                 , ISNULL(Userdefined10, '')
            FROM dbo.SCE_DL_UCC_STG WITH (NOLOCK)
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
         END;

         UPDATE dbo.SCE_DL_UCC_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         NEXTITEM:

         SET @c_PreSku = @c_Sku; --CS08
         SET @c_PreUCCNo = @c_UCCNo; --IN00276016

         FETCH NEXT FROM C_HDR
         INTO @n_RowRefNo
            , @c_UCCNo
            , @c_StorerKey
            , @c_Sku
            , @n_UCC_RowRef;
      END;

      CLOSE C_HDR;
      DEALLOCATE C_HDR;

      WHILE @@TRANCOUNT > 0
      COMMIT TRAN;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_UCC_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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