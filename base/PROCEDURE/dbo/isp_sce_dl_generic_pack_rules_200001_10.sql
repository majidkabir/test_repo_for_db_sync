SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_PACK_RULES_200001_10            */
/* Creation Date: 11-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into PACK target table            */
/*                                                                      */
/*                                                                      */
/* Usage:  Insert or Ignore    @c_InParm1 =  '0'  Ignore Add            */
/*                             @c_InParm1 =  '1'  Add/Update is allow   */
/* Update All Field or Ignore  @c_InParm2 =  '0'  Ignore                */
/*                             @c_InParm2 =  '1'  Allow update all      */
/*                             @c_InParm3 =  '1'  ByPass Checking       */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 11-May-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_PACK_RULES_200001_10] (
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

   DECLARE @n_ActionFlag INT
         , @n_FoundExist INT
         , @n_RowRefNo   INT
         , @c_Packkey    NVARCHAR(10)
         , @c_ttlMsg     NVARCHAR(250);

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
   SELECT RowRefNo
        , RTRIM(PackKey)
   FROM dbo.SCE_DL_PACK_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1';

   OPEN C_HDR;
   FETCH NEXT FROM C_HDR
   INTO @n_RowRefNo
      , @c_Packkey;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_FoundExist = 0;

      SELECT @n_FoundExist = 1
      FROM dbo.V_PACK WITH (NOLOCK)
      WHERE PackKey = @c_Packkey;


      IF @c_InParm1 = '1'
      BEGIN
         IF @n_FoundExist = 1
         BEGIN
            SET @n_ActionFlag = 1; -- UPDATE
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
            SET @n_ActionFlag = 1; --UPDATE
         END;
         ELSE
         BEGIN
            UPDATE dbo.SCE_DL_PACK_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error:PackKey not exists.User not allow to add this PackKey(' + @c_Packkey + ')'
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
            GOTO NEXTITEM;
         END;
      END;

      IF @n_ActionFlag = 0
      BEGIN
         INSERT INTO dbo.PACK
         (
            PackKey
          , PackDescr
          , PackUOM1
          , CaseCnt
          , PackUOM2
          , InnerPack
          , PackUOM3
          , Qty
          , PackUOM4
          , Pallet
          , PackUOM5
          , [Cube]
          , PackUOM6
          , GrossWgt
          , PackUOM7
          , NetWgt
          , PackUOM8
          , OtherUnit1
          , PackUOM9
          , OtherUnit2
          , PalletTI
          , PalletHI
          , AddWho
          , EditWho
          , LengthUOM1
          , WidthUOM1
          , HeightUOM1
          , CubeUOM1
          , LengthUOM2
          , WidthUOM2
          , HeightUOM2
          , CubeUOM2
          , LengthUOM3
          , WidthUOM3
          , HeightUOM3
          , CubeUOM3
          , LengthUOM4
          , WidthUOM4
          , HeightUOM4
          , CubeUOM4
         )
         SELECT @c_Packkey
              , PackDescr
              , ISNULL(PackUOM1, '')
              , ISNULL(CaseCnt, 0)
              , ISNULL(PackUOM2, '')
              , ISNULL(InnerPack, 0)
              , PackUOM3
              , Qty
              , ISNULL(PackUOM4, '')
              , ISNULL(Pallet, 0)
              , ISNULL(PackUOM5, '')
              , ISNULL([Cube], 0)
              , ISNULL(PackUOM6, '')
              , ISNULL(GrossWgt, 0)
              , ISNULL(PackUOM7, '')
              , ISNULL(NetWgt, 0)
              , ISNULL(PackUOM8, '')
              , ISNULL(OtherUnit1, 0)
              , ISNULL(PackUOM9, '')
              , ISNULL(OtherUnit2, 0)
              , ISNULL(PalletTI, 0)
              , ISNULL(PalletHI, 0)
              , @c_Username
              , @c_Username
              , ISNULL(LengthUOM1, 0.0)
              , ISNULL(WidthUOM1, 0.0)
              , ISNULL(HeightUOM1, 0.0)
              , ISNULL(CubeUOM1, 0.0)
              , ISNULL(LengthUOM2, 0.0)
              , ISNULL(WidthUOM2, 0.0)
              , ISNULL(HeightUOM2, 0.0)
              , ISNULL(CubeUOM2, 0.0)
              , ISNULL(LengthUOM3, 0.0)
              , ISNULL(WidthUOM3, 0.0)
              , ISNULL(HeightUOM3, 0.0)
              , ISNULL(CubeUOM3, 0.0)
              , ISNULL(LengthUOM4, 0.0)
              , ISNULL(WidthUOM4, 0.0)
              , ISNULL(HeightUOM4, 0.0)
              , ISNULL(CubeUOM4, 0.0)
         FROM dbo.SCE_DL_PACK_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;
      ELSE IF @n_ActionFlag = '1'
      BEGIN
         UPDATE P WITH (ROWLOCK)
         SET P.PackUOM1 = IIF(@c_InParm2 = '1'
                              , IIF(STG.PackUOM1 = 'NULL', '', ISNULL(STG.PackUOM1, P.PACKUOM1))
                              , ISNULL(STG.PackUOM1, ''))
           , P.CaseCnt = IIF(@c_InParm2 = '1', ISNULL(STG.CaseCnt, P.CaseCnt), ISNULL(STG.CaseCnt, 0))
           , P.PackUOM2 = IIF(@c_InParm2 = '1'
                              , IIF(STG.PackUOM2 = 'NULL', '', ISNULL(STG.PackUOM2, P.PackUOM2))
                              , ISNULL(STG.PackUOM2, ''))
           , P.InnerPack = IIF(@c_InParm2 = '1', ISNULL(STG.InnerPack, P.InnerPack), ISNULL(STG.InnerPack, 0))
           , P.PackUOM3 = IIF(@c_InParm2 = '1'
                              , IIF(STG.PackUOM3 = 'NULL', '', ISNULL(STG.PackUOM3, P.PackUOM3))
                              , ISNULL(STG.PackUOM3, ''))
           , P.Qty = IIF(@c_InParm2 = '1', ISNULL(STG.Qty, P.Qty), ISNULL(STG.Qty, 0))
           , P.PackUOM4 = IIF(@c_InParm2 = '1'
                              , IIF(STG.PackUOM4 = 'NULL', '', ISNULL(STG.PackUOM4, P.PackUOM4))
                              , ISNULL(STG.PackUOM4, ''))
           , P.Pallet = IIF(@c_InParm2 = '1', ISNULL(STG.Pallet, P.Pallet), ISNULL(STG.Pallet, 0))
           , P.PackUOM5 = IIF(@c_InParm2 = '1'
                              , IIF(STG.PackUOM5 = 'NULL', '', ISNULL(STG.PackUOM5, P.PackUOM5))
                              , ISNULL(STG.PackUOM5, ''))
           , P.[Cube] = IIF(@c_InParm2 = '1', ISNULL(STG.[Cube], P.[Cube]), ISNULL(STG.[Cube], 0))
           , P.PackUOM6 = IIF(@c_InParm2 = '1'
                              , IIF(STG.PackUOM6 = 'NULL', '', ISNULL(STG.PackUOM6, P.PackUOM6))
                              , ISNULL(STG.PackUOM6, ''))
           , P.GrossWgt = IIF(@c_InParm2 = '1', ISNULL(STG.GrossWgt, P.GrossWgt), ISNULL(STG.GrossWgt, 0))
           , P.PackUOM7 = IIF(@c_InParm2 = '1'
                              , IIF(STG.PackUOM7 = 'NULL', '', ISNULL(STG.PackUOM7, P.PackUOM7))
                              , ISNULL(STG.PackUOM7, ''))
           , P.NetWgt = IIF(@c_InParm2 = '1', ISNULL(STG.NetWgt, P.NetWgt), ISNULL(STG.NetWgt, 0))
           , P.PackUOM8 = IIF(@c_InParm2 = '1'
                              , IIF(STG.PackUOM8 = 'NULL', '', ISNULL(STG.PackUOM8, P.PackUOM8))
                              , ISNULL(STG.PackUOM8, ''))
           , P.OtherUnit1 = IIF(@c_InParm2 = '1', ISNULL(STG.OtherUnit1, P.OtherUnit1), ISNULL(STG.OtherUnit1, 0))
           , P.PackUOM9 = IIF(@c_InParm2 = '1'
                              , IIF(STG.PackUOM9 = 'NULL', '', ISNULL(STG.PackUOM9, P.PackUOM9))
                              , ISNULL(STG.PackUOM9, ''))
           , P.OtherUnit2 = IIF(@c_InParm2 = '1', ISNULL(STG.OtherUnit2, P.OtherUnit2), ISNULL(STG.OtherUnit2, 0))
           , P.PalletTI = IIF(@c_InParm2 = '1', ISNULL(STG.PalletTI, P.PalletTI), ISNULL(STG.PalletTI, 0))
           , P.PalletHI = IIF(@c_InParm2 = '1', ISNULL(STG.PalletHI, P.PalletHI), ISNULL(STG.PalletHI, 0))
           , P.EditWho = @c_Username
           , P.EditDate = GETDATE()
           , P.LengthUOM1 = ISNULL(STG.LengthUOM1, P.LengthUOM1)
           , P.WidthUOM1 = ISNULL(STG.WidthUOM1, P.WidthUOM1)
           , P.HeightUOM1 = ISNULL(STG.HeightUOM1, P.HeightUOM1)
           , P.CubeUOM1 = ISNULL(STG.CubeUOM1, P.CubeUOM1)
           , P.LengthUOM2 = ISNULL(STG.LengthUOM2, P.LengthUOM2)
           , P.WidthUOM2 = ISNULL(STG.WidthUOM2, P.WidthUOM2)
           , P.HeightUOM2 = ISNULL(STG.HeightUOM2, P.HeightUOM2)
           , P.CubeUOM2 = ISNULL(STG.CubeUOM2, P.CubeUOM2)
           , P.LengthUOM3 = ISNULL(STG.LengthUOM3, P.LengthUOM3)
           , P.WidthUOM3 = ISNULL(STG.WidthUOM3, P.WidthUOM3)
           , P.HeightUOM3 = ISNULL(STG.HeightUOM3, P.HeightUOM3)
           , P.CubeUOM3 = ISNULL(STG.CubeUOM3, P.CubeUOM3)
           , P.LengthUOM4 = ISNULL(STG.LengthUOM4, P.LengthUOM4)
           , P.WidthUOM4 = ISNULL(STG.WidthUOM4, P.WidthUOM4)
           , P.HeightUOM4 = ISNULL(STG.HeightUOM4, P.HeightUOM4)
           , P.CubeUOM4 = ISNULL(STG.CubeUOM4, P.CubeUOM4)
         FROM dbo.PACK            P
         JOIN dbo.SCE_DL_PACK_STG STG WITH (NOLOCK)
         ON P.PackKey = STG.PackKey
         WHERE STG.RowRefNo = @n_RowRefNo
         AND   P.CaseCnt      = CASE WHEN @c_InParm3 = '0' THEN 0
                                     ELSE P.CaseCnt
                                END;
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;
      UPDATE dbo.SCE_DL_PACK_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      NEXTITEM:
      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_Packkey;
   END;

   CLOSE C_HDR;
   DEALLOCATE C_HDR;

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_PACK_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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