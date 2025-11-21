SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_CHANNELTRANSFER_RULES_200001_10 */
/* Creation Date: 10-May-2024                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  Perform insert or update into CHANNELTRANSFER target table */
/*                                                                      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2024  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CHANNELTRANSFER_RULES_200001_10] (
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
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60)
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @c_FromStorerKey               NVARCHAR(15)
         , @c_ExternChannelTransferKey    NVARCHAR(15)
         , @c_FromFacility                NVARCHAR(15)
         , @c_TransferKey                 NVARCHAR(10)
         , @n_RowRefNo                    INT
         , @c_LineNum                     NVARCHAR(5)  
         , @n_iNo                         INT = 0
         , @c_ttlMsg                      NVARCHAR(250)

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
   WHERE SPName = OBJECT_NAME(@@PROCID)

   DECLARE @T_TRANSFER AS TABLE ( 
      Transferkey                NVARCHAR(10)
    , FromStorerkey              NVARCHAR(15)
    , ExternChannelTransferKey   NVARCHAR(20)
    , Facility                   NVARCHAR(5)
   )

   BEGIN TRANSACTION

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT FromStorerKey
                 , ISNULL(ExternChannelTransferKey, '')
                 , ISNULL(Facility, '')
                 , RowRefNo
   FROM dbo.SCE_DL_CHANNELTRANSFER_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'

   OPEN C_HDR
   FETCH NEXT FROM C_HDR
   INTO @c_FromStorerKey
      , @c_ExternChannelTransferKey
      , @c_FromFacility
      , @n_RowRefNo

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_TransferKey = N''

      SELECT @c_TransferKey = Transferkey
      FROM @T_TRANSFER
      WHERE FromStorerkey = @c_FromStorerKey
      AND ExternChannelTransferKey = @c_ExternChannelTransferKey
      AND Facility = @c_FromFacility

      IF ISNULL(@c_TransferKey, '') = ''
      BEGIN
         SELECT @c_TransferKey = NEXT VALUE FOR dbo.ChannelTransferKey

         IF ISNULL(@c_TransferKey, '') <> ''
         BEGIN
            SET @c_TransferKey = RIGHT('0000000000' + @c_TransferKey, 10)
         END
         ELSE
         BEGIN
            SET @c_TransferKey = N''
         END

         IF ISNULL(@c_TransferKey, '') <> ''
         BEGIN
            INSERT INTO dbo.ChannelTransfer ([ChannelTransferKey], [FromStorerKey], [ToStorerKey], [Type], [OpenQty], [Status]
                                  , [ReasonCode], [ExternChannelTransferKey], [CustomerRefNo], [Remarks], [Facility]
                                  , [ToFacility], [UserDefine01], [UserDefine02], [UserDefine03], [UserDefine04]
                                  , [UserDefine05], AddWho, EditWho)
            SELECT @c_TransferKey
                 , STG.FromStorerKey
                 , STG.ToStorerKey
                 , ISNULL(STG.[Type], '')
                 , ISNULL(STG.OpenQty, 0)
                 , '0'
                 , ISNULL(STG.ReasonCode, '')
                 , ExternChannelTransferKey
                 , ISNULL(STG.CustomerRefNo, '')
                 , ISNULL(STG.Remarks, '')
                 , STG.Facility
                 , STG.ToFacility
                 , ISNULL(STG.HUdef01, '')
                 , ISNULL(STG.HUdef02, '')
                 , ISNULL(STG.HUdef03, '')
                 , ISNULL(STG.HUdef04, '')
                 , ISNULL(STG.HUdef05, '')
                 , @c_Username
                 , @c_Username
            FROM dbo.SCE_DL_CHANNELTRANSFER_STG STG WITH (NOLOCK)
            WHERE RowRefNo = @n_RowRefNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
         END

         INSERT INTO @T_TRANSFER (Transferkey, FromStorerkey, ExternChannelTransferKey, Facility)
         SELECT @c_TransferKey, @c_FromStorerkey, @c_ExternChannelTransferKey, @c_FromFacility
      END
      
      IF ISNULL(@c_TransferKey, '') <> ''
      BEGIN
         SET @n_iNo = @n_iNo + 1
         SET @c_LineNum = RIGHT('00000' + CAST(@n_iNo AS NVARCHAR(5)), 5)

         INSERT INTO dbo.ChannelTransferDetail ([ChannelTransferKey], [ExternChannelTransferKey], [ChannelTransferLineNumber]
                                              , [FromStorerKey], [FromSku], [FromQty], [FromPackKey], [FromUOM], [FromChannel]
                                              , [ToStorerKey], [ToSku], [ToQty], [ToPackKey], [ToUOM], [Status], [ToChannel]
                                              , [FromChannel_ID], [ToChannel_ID], [FromC_Attribute01], [FromC_Attribute02]
                                              , [FromC_Attribute03], [FromC_Attribute04], [FromC_Attribute05], [ToC_Attribute01]
                                              , [ToC_Attribute02], [ToC_Attribute03], [ToC_Attribute04], [ToC_Attribute05]
                                              , [UserDefine01], [UserDefine02], [UserDefine03], [UserDefine04], [UserDefine05]
                                              , [ExternChannelTransferLineNo], AddWho, EditWho)
         SELECT @c_TransferKey
              , ExternChannelTransferKey
              , @c_LineNum
              , FromStorerKey
              , FromSku
              , FromQty
              , ISNULL(FromPackKey, '')
              , ISNULL(FromUOM, '')
              , ISNULL(FromChannel, '')
              , ToStorerKey
              , ToSku
              , ToQty
              , ISNULL(ToPackKey, '')
              , ISNULL(ToUOM, '')
              , '0'
              , ISNULL(ToChannel, '')
              , ISNULL(FromChannel_ID, '')
              , ISNULL(ToChannel_ID, '')
              , ISNULL(FromC_Attribute01, '')
              , ISNULL(FromC_Attribute02, '')
              , ISNULL(FromC_Attribute03, '')
              , ISNULL(FromC_Attribute04, '')
              , ISNULL(FromC_Attribute05, '')
              , ISNULL(ToC_Attribute01, '')
              , ISNULL(ToC_Attribute02, '')
              , ISNULL(ToC_Attribute03, '')
              , ISNULL(ToC_Attribute04, '')
              , ISNULL(ToC_Attribute05, '')
              , ISNULL(DUdef01, '')
              , ISNULL(DUdef02, '')
              , ISNULL(DUdef03, '')
              , ISNULL(DUdef04, '')
              , ISNULL(DUdef05, '')
              , ExternChannelTransferLineNo
              , @c_Username
              , @c_Username
         FROM dbo.SCE_DL_CHANNELTRANSFER_STG STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END

      UPDATE dbo.SCE_DL_CHANNELTRANSFER_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         ROLLBACK TRAN
         GOTO QUIT
      END

      FETCH NEXT FROM C_HDR
      INTO @c_FromStorerKey
         , @c_ExternChannelTransferKey
         , @c_FromFacility
         , @n_RowRefNo
   END
   CLOSE C_HDR
   DEALLOCATE C_HDR

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CHANNELTRANSFER_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
   END

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1
   END
   ELSE
   BEGIN
      SET @b_Success = 0
   END
END
GO