SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_CHANNELTRANSFER_RULES_100002_10 */
/* Creation Date: 10-May-2024                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-25319 - CHANNELTRANSFER - Perform Column Checking       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2024  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CHANNELTRANSFER_RULES_100002_10] (
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
         , @n_RowRefNo       BIGINT = 0

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

   DECLARE @c_ttlMsg                   NVARCHAR(250)
         , @c_ExternCTKey_Out          NVARCHAR(20) = N''
         , @n_FromQty_Out              INT = 0
         , @c_Packkey_Out              NVARCHAR(10) = N''
         , @c_Packkey                  NVARCHAR(10)
         , @c_FromStorerkey            NVARCHAR(15)
         , @c_ToStorerkey              NVARCHAR(15)
         , @c_FromFacility             NVARCHAR(5)
         , @c_ToFacility               NVARCHAR(5)
         , @c_ExternCTKey              NVARCHAR(20)
         , @c_FromSKU                  NVARCHAR(20)
         , @c_ToSKU                    NVARCHAR(20)
         , @n_FromQty                  INT
         , @n_ToQty                    INT
         , @c_FromPackkey              NVARCHAR(10)
         , @c_ToPackkey                NVARCHAR(10)
         , @c_FromUOM                  NVARCHAR(10)
         , @c_ToUOM                    NVARCHAR(10)
         , @c_FromChannel              NVARCHAR(20)
         , @c_ToChannel                NVARCHAR(20)

   DECLARE @c_PackUOM1                 NVARCHAR(10)
         , @n_CaseCnt                  FLOAT
         , @c_PackUOM2                 NVARCHAR(10)
         , @n_InnerPack                FLOAT
         , @c_PackUOM3                 NVARCHAR(10)
         , @n_uom3Qty                  FLOAT
         , @c_PackUOM4                 NVARCHAR(10)
         , @n_Pallet                   FLOAT
         , @c_PACKUOM5                 NVARCHAR(10)
         , @n_Cube                     FLOAT
         , @c_PACKUOM6                 NVARCHAR(10)
         , @n_GrossWgt                 FLOAT
         , @c_PACKUOM7                 NVARCHAR(10)
         , @n_NetWgt                   FLOAT
         , @c_PACKUOM8                 NVARCHAR(10)
         , @n_OtherUnit1               FLOAT
         , @c_PACKUOM9                 NVARCHAR(10)
         , @n_OtherUnit2               FLOAT
         , @n_Qty                      INT
         , @n_GetQty                   INT

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

   DECLARE C_CHK_COLUMN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , FromStorerKey
        , ToStorerKey
        , Facility
        , ToFacility
        , ExternChannelTransferKey
        , TRIM(FromSku)
        , TRIM(ToSku)
        , FromQty
        , ToQty
        , FromPackKey
        , ToPackKey
        , FromUOM
        , ToUOM
        , FromChannel
        , ToChannel
   FROM dbo.SCE_DL_CHANNELTRANSFER_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'

   OPEN C_CHK_COLUMN
   FETCH NEXT FROM C_CHK_COLUMN
   INTO @n_RowRefNo
      , @c_FromStorerkey
      , @c_ToStorerkey  
      , @c_FromFacility 
      , @c_ToFacility   
      , @c_ExternCTKey  
      , @c_FromSKU      
      , @c_ToSKU        
      , @n_FromQty      
      , @n_ToQty        
      , @c_FromPackkey  
      , @c_ToPackkey    
      , @c_FromUOM      
      , @c_ToUOM        
      , @c_FromChannel  
      , @c_ToChannel    

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''
      SET @c_ExternCTKey_Out = N''

      SELECT @c_ExternCTKey_Out = ExternChannelTransferKey
      FROM dbo.ChannelTransfer WITH (NOLOCK)
      WHERE ExternChannelTransferKey = @c_ExternCTKey

      IF ISNULL(@c_ExternCTKey_Out, '') <> ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ExternChannelTransferKey already exists'
      END

      IF ISNULL(@c_FromFacility, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromFacility is Null'
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                         FROM Facility WITH (NOLOCK)
                         WHERE Facility = @c_FromFacility )
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromFacility not exists'
         END
      END

      IF ISNULL(@c_ToFacility, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ToFacility is Null'
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                         FROM Facility WITH (NOLOCK)
                         WHERE Facility = @c_ToFacility )
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ToFacility not exists'
         END
      END

      IF ISNULL(@c_FromSKU, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromSKU is Null'
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                         FROM SKU WITH (NOLOCK)
                         WHERE Storerkey = @c_FromStorerkey
                         AND SKU = @c_FromSKU )
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromSKU not exists'
         END

         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.ChannelInv WITH (NOLOCK)
                         WHERE Storerkey = @c_FromStorerkey
                         AND Channel = @c_FromChannel
                         AND SKU = @c_FromSKU )
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromSKU not exists in ChannelInv table'
         END
      END

      IF ISNULL(@c_ToSKU, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ToSKU is Null'
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                         FROM SKU WITH (NOLOCK)
                         WHERE Storerkey = @c_ToStorerkey
                         AND SKU = @c_ToSKU )
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ToSKU not exists'
         END

         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.ChannelInv WITH (NOLOCK)
                         WHERE Storerkey = @c_ToStorerkey
                         AND Channel = @c_ToChannel
                         AND SKU = @c_ToSKU )
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ToSKU not exists in ChannelInv table'
         END
      END

      IF @c_FromSKU <> @c_ToSKU
      BEGIN 
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromSKU and ToSKU must be the same'
      END

      IF ISNULL(@c_FromChannel, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromChannel is Null'
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                         FROM CODELKUP WITH (NOLOCK)
                         WHERE Storerkey = @c_FromStorerkey
                         AND Listname = 'CHANNEL'
                         AND Code = @c_FromChannel)
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromChannel not exists in CODELKUP table'
         END
      END

      IF ISNULL(@c_ToChannel, '') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ToChannel is Null'
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                         FROM CODELKUP WITH (NOLOCK)
                         WHERE Storerkey = @c_ToStorerkey
                         AND Listname = 'CHANNEL'
                         AND Code = @c_ToChannel)
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ToChannel not exists in CODELKUP table'
         END
      END

      IF ISNULL(@n_FromQty, 0) = 0
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromQty must > 0'
      END
      ELSE
      BEGIN
         SET @n_FromQty_Out = 0

         SELECT @n_FromQty_Out = SUM(Qty)
         FROM dbo.ChannelInv WITH (NOLOCK)
         WHERE Storerkey = @c_FromStorerkey
         AND SKU = @c_FromSKU
         AND Channel = @c_FromChannel

         IF @n_FromQty > @n_FromQty_Out
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromQty not match with ChannelInv Qty'
         END
      END

      IF @n_FromQty <> @n_ToQty
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromQty must same as ToQty'
      END

      IF ISNULL(@c_FromPackkey, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1
                         FROM PACK WITH (NOLOCK)
                         WHERE PackKey = @c_FromPackkey )
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromPackkey not exists in PACK table'
         END
      END

      IF ISNULL(@c_ToPackkey, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1
                         FROM PACK WITH (NOLOCK)
                         WHERE PackKey = @c_ToPackkey )
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ToPackkey not exists in PACK table'
         END
      END

      IF ISNULL(@c_FromUOM, '') <> ''
      BEGIN
         SET @c_Packkey_Out = N''

         SELECT @c_Packkey_Out = Packkey
         FROM SKU WITH (NOLOCK)
         WHERE Storerkey = @c_FromStorerkey
         AND SKU = @c_FromSKU

         IF ISNULL(@c_FromPackkey, '') = ''
         BEGIN
            SET @c_Packkey = @c_Packkey_Out
         END
         ELSE
         BEGIN
            SET @c_Packkey = @c_FromPackkey
         END

         SET @c_PackUOM1 = N''
         SET @c_PackUOM2 = N''
         SET @c_PackUOM3 = N''
         SET @c_PackUOM4 = N''

         SELECT @c_PackUOM1 = PACKUOM1
              , @c_PackUOM2 = PACKUOM2
              , @c_PackUOM3 = PACKUOM3
              , @c_PackUOM4 = PACKUOM4
         FROM PACK WITH (NOLOCK)
         WHERE PackKey = @c_Packkey

         IF  @c_FromUOM <> @c_PackUOM1
         AND @c_FromUOM <> @c_PackUOM2
         AND @c_FromUOM <> @c_PackUOM3
         AND @c_FromUOM <> @c_PackUOM4
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/FromUOM not exists'
         END
      END

      IF ISNULL(@c_ToUOM, '') <> ''
      BEGIN
         SET @c_Packkey_Out = N''

         SELECT @c_Packkey_Out = Packkey
         FROM SKU WITH (NOLOCK)
         WHERE Storerkey = @c_ToStorerkey
         AND SKU = @c_ToSKU

         IF ISNULL(@c_ToPackkey, '') = ''
         BEGIN
            SET @c_Packkey = @c_Packkey_Out
         END
         ELSE
         BEGIN
            SET @c_Packkey = @c_ToPackkey
         END

         SET @c_PackUOM1 = N''
         SET @c_PackUOM2 = N''
         SET @c_PackUOM3 = N''
         SET @c_PackUOM4 = N''

         SELECT @c_PackUOM1 = PACKUOM1
              , @c_PackUOM2 = PACKUOM2
              , @c_PackUOM3 = PACKUOM3
              , @c_PackUOM4 = PACKUOM4
         FROM PACK WITH (NOLOCK)
         WHERE PackKey = @c_Packkey

         IF  @c_ToUOM <> @c_PackUOM1
         AND @c_ToUOM <> @c_PackUOM2
         AND @c_ToUOM <> @c_PackUOM3
         AND @c_ToUOM <> @c_PackUOM4
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/ToUOM not exists'
         END
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.SCE_DL_CHANNELTRANSFER_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status = '1'
         AND   RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_CHANNELTRANSFER_RULES_100002_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END

         COMMIT
      END

      FETCH NEXT FROM C_CHK_COLUMN
      INTO @n_RowRefNo
         , @c_FromStorerkey
         , @c_ToStorerkey  
         , @c_FromFacility 
         , @c_ToFacility   
         , @c_ExternCTKey  
         , @c_FromSKU      
         , @c_ToSKU        
         , @n_FromQty      
         , @n_ToQty        
         , @c_FromPackkey  
         , @c_ToPackkey    
         , @c_FromUOM      
         , @c_ToUOM        
         , @c_FromChannel  
         , @c_ToChannel   
   END
   CLOSE C_CHK_COLUMN
   DEALLOCATE C_CHK_COLUMN

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK_COLUMN') IN (0 , 1)
   BEGIN
      CLOSE C_CHK_COLUMN
      DEALLOCATE C_CHK_COLUMN   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CHANNELTRANSFER_RULES_100002_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '')
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