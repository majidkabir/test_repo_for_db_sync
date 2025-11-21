SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200001_10      */
/* Creation Date: 17-Oct-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19372 - Perform Column Checking                         */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '0' - Reject Update                             */
/*         @c_InParm1 = '1' - Allow Update                              */
/*         @c_InParm1 = '2' - Ignore & Insert New                       */
/*         @c_InParm2 = '0' - Reject Update Lottables                   */
/*         @c_InParm2 = '1' - Allow Update Lottables                    */
/*         @c_InParm3 = '0' - Reject Update Receiptdetail               */
/*         @c_InParm3 = '1' - Allow Update Receiptdetail                */
/*         @c_InParm4 = '0' - Reject Update ReceiptHEADER               */
/*         @c_InParm4 = '1' - Allow Update ReceiptHEADER                */
/*         @c_InParm5 = '0' - Reject Update All Lottables               */
/*         @c_InParm5 = '1' - Allow Update All Lottables                */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 17-Oct-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200001_10] (
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

   DECLARE @c_StorerKey             NVARCHAR(15)
         , @c_ttlMsg                NVARCHAR(250)
         , @c_ExternReceiptkey      NVARCHAR(50)
         , @c_Receiptkey            NVARCHAR(10)
         , @c_ReceiptLineNumber     NVARCHAR(5)
         , @c_ToLoc                 NVARCHAR(20)
         , @n_BeforeReceivedQty     INT
         , @n_RowRefNo              BIGINT
         , @c_Receiptkey_Out        NVARCHAR(10)
         , @c_Storerkey_Get         NVARCHAR(15)     
         , @c_ExternReceiptkey_Get  NVARCHAR(50)  
         , @c_ReceiptGroup_Out      NVARCHAR(50) 
         , @c_GetReceiptkey_Out     NVARCHAR(10)

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

   --Validation--
   DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ISNULL(TRIM(ExternReceiptkey), '')
                 , ISNULL(TRIM(StorerKey), '')
                 , ISNULL(TRIM(Receiptkey),'')
                 , ISNULL(TRIM(ReceiptLineNumber),'')
                 , ISNULL(TRIM(ToLoc),'')
                 , ISNULL(BeforeReceivedQty,0)
                 , RowRefNo
   FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   
   OPEN C_CHK
   
   FETCH NEXT FROM C_CHK
   INTO @c_ExternReceiptkey 
      , @c_StorerKey
      , @c_Receiptkey       
      , @c_ReceiptLineNumber
      , @c_ToLoc            
      , @n_BeforeReceivedQty
      , @n_RowRefNo

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''
      
      IF @c_InParm1 = '1'
      BEGIN
         IF ISNULL(@c_ExternReceiptkey, '') = ''
         BEGIN
            SET @c_ttlMsg += N'/ExternReceiptkey is Null'
         END
      END
      ELSE
      BEGIN
         IF ISNULL(@c_Receiptkey, '') = ''
         BEGIN
            SET @c_ttlMsg += N'/Receiptkey is Null'
         END
      END

      IF @c_InParm4 = '1'
      BEGIN
         IF ISNULL(@c_ExternReceiptkey, '') <> ''
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM dbo.RECEIPT R (NOLOCK)
                           WHERE R.ExternReceiptKey = @c_ExternReceiptkey)
            BEGIN
               SET @c_ttlMsg += N'/ExternReceiptkey not exists'
            END
         END
         ELSE 
         BEGIN
            IF EXISTS (SELECT 1
                       FROM dbo.RECEIPT R (NOLOCK)
                       WHERE R.ReceiptKey = @c_Receiptkey
                       AND ISNULL(R.ExternReceiptKey,'') = '')
            BEGIN
               SET @c_ttlMsg += N'/ExternReceiptkey not exists'
            END
         END
      END

      IF ISNULL(@c_Storerkey, '') = ''
      BEGIN
         SET @c_ttlMsg += N'/Storerkey is Null'
      END

      IF NOT EXISTS (SELECT 1
                     FROM dbo.STORER S (NOLOCK)
                     WHERE S.StorerKey = @c_StorerKey
                     AND S.[type] = '1')
      BEGIN
         SET @c_ttlMsg += N'/Storerkey not exists'
      END

      IF @c_InParm2 = '1' OR @c_InParm3 = '1'
         OR @c_InParm5 = '1' --OR @c_UpdateRecDetUDF = '1'
      BEGIN
         IF ISNULL(@c_Receiptkey, '') = '' OR ISNULL(@c_ReceiptLineNumber, '') = ''
         BEGIN
            SET @c_ttlMsg += N'/Update receiptdetail :Receiptkey or receiptlinenumber cannot NULL'
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM dbo.RECEIPTDETAIL RD (NOLOCK)
                           WHERE RD.ReceiptKey = @c_Receiptkey
                           AND RD.ReceiptLineNumber = @c_ReceiptLineNumber)
            BEGIN
               SET @c_ttlMsg += N'/Receiptkey : ' + @c_Receiptkey
                              + N'Or ReceiptlineNumber : ' + @c_ReceiptLineNumber + N' not exists'
            END
         END
      END

      IF EXISTS (SELECT 1
                 FROM dbo.RECEIPT R (NOLOCK)
                 WHERE R.ExternReceiptKey = @c_ExternReceiptkey
                 AND R.ReceiptKey = @c_Receiptkey
                 AND R.ASNStatus = '9') AND @c_InParm3 = '1' --OR @c_UpdateRecDetUDF = '1'
      BEGIN
         SET @c_ttlMsg += N'/RECEIPT already Finalized, update failed'
      END

      IF @c_InParm4 = '1'
      BEGIN
         IF ISNULL(@c_ExternReceiptkey, '') <> ''
         BEGIN
            IF EXISTS (SELECT 1
                       FROM dbo.RECEIPT R (NOLOCK)
                       WHERE R.ExternReceiptKey = @c_ExternReceiptkey
                       AND R.ASNStatus = '9')
            BEGIN
               SET @c_ttlMsg += N'/RECEIPT already Finalized, update failed'
            END
         END
         ELSE
         BEGIN
            IF EXISTS (SELECT 1
                       FROM dbo.RECEIPT R (NOLOCK)
                       WHERE R.ReceiptKey = @c_Receiptkey
                       AND R.ASNStatus = '9')
            BEGIN
               SET @c_ttlMsg += N'/RECEIPT already Finalized, update failed'
            END
         END
      END

      IF @c_InParm3 = '1'
      BEGIN
         IF ISNULL(@c_ToLoc, '') = ''
         BEGIN
            SET @c_ttlMsg += N'/Toloc cannot be null'
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM dbo.LOC L (NOLOCK)
                           WHERE L.Loc = @c_ToLoc)
            BEGIN
               SET @c_ttlMsg += N'/Toloc not exists'
            END
         END

         IF @c_InParm5 <> '1'
         BEGIN
            IF ISNULL(@n_BeforeReceivedQty, 0) < 1
            BEGIN
               SET @c_ttlMsg += N'/BeforeRecqty cannot be 0'
            END
         END
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION
   
         UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   RowRefNo    = @n_RowRefNo
   
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200001_10)'
            ROLLBACK TRANSACTION
            GOTO STEP_999_EXIT_SP
         END
   
         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END

   
      FETCH NEXT FROM C_CHK
      INTO @c_ExternReceiptkey 
         , @c_StorerKey
         , @c_Receiptkey       
         , @c_ReceiptLineNumber
         , @c_ToLoc            
         , @n_BeforeReceivedQty
         , @n_RowRefNo
   END
   CLOSE C_CHK
   DEALLOCATE C_CHK

   --Update--
   DECLARE C_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ISNULL(TRIM(ExternReceiptkey), '')
                 , ISNULL(TRIM(StorerKey), '')
                 , ISNULL(TRIM(Receiptkey),'')
                 , ISNULL(TRIM(ReceiptLineNumber),'')
                 , RowRefNo
   FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   
   OPEN C_UPD
   
   FETCH NEXT FROM C_UPD
   INTO @c_ExternReceiptkey 
      , @c_StorerKey
      , @c_Receiptkey       
      , @c_ReceiptLineNumber
      , @n_RowRefNo

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      SELECT @c_Receiptkey_Out = R.Receiptkey
      FROM RECEIPT R (NOLOCK)
      WHERE R.StorerKey = @c_StorerKey
      AND R.ExternReceiptKey = @c_ExternReceiptkey

      IF @c_InParm1 = '1'
      BEGIN
         IF ISNULL(TRIM(@c_Receiptkey_Out), '') <> ''
         BEGIN
            SELECT TOP 1 @c_Storerkey_Get          = ISNULL(TRIM(STG.Storerkey), '')
                       , @c_ExternReceiptkey_Get   = ISNULL(TRIM(STG.ExternReceiptkey), '')
                       , @c_ReceiptGroup_Out       = ISNULL(TRIM(STG.ReceiptGroup), '')
            FROM SCE_DL_ASN_STG STG WITH (NOLOCK)
            WHERE STG_BatchNo = @n_BatchNo
            AND   STG_Status  = '1'
            AND   Storerkey = @c_Storerkey
            AND   ExternReceiptkey = @c_ExternReceiptkey
            ORDER BY RowRefNo

            SET @c_Receiptkey = @c_Receiptkey_Out
         END
      END
      ELSE
      BEGIN
         SELECT TOP 1 @c_Storerkey_Get    = ISNULL(TRIM(STG.Storerkey), '')
                    , @c_ReceiptGroup_Out = ISNULL(TRIM(STG.ReceiptGroup), '')
         FROM SCE_DL_ASN_STG STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   Storerkey = @c_Storerkey
         AND   ExternReceiptkey = @c_ExternReceiptkey
         ORDER BY RowRefNo

         BEGIN TRANSACTION

         UPDATE dbo.RECEIPT WITH (ROWLOCK)
         SET ReceiptGroup     = @c_ReceiptGroup_Out
           , Appointment_No   = ISNULL(STG.Appointment_No, RECH.Appointment_No)
           , Userdefine01     = ISNULL(STG.HUSR01, RECH.Userdefine01)
           , VehicleDate      = ISNULL(STG.VehicleDate,'')
           , EditWho          = SUSER_SNAME()
           , Editdate         = GETDATE()
         FROM SCE_DL_ASN_STG STG WITH (NOLOCK)
         JOIN RECEIPT RECH ON (STG.ReceiptKey = RECH.ReceiptKey)
         WHERE STG.Receiptkey = @c_Receiptkey
         AND   STG.StorerKey = @c_Storerkey_Get
         AND   STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status  = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END

      IF @c_InParm2 = '1'
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.ReceiptDetail WITH (ROWLOCK)
         SET Lottable01 = ISNULL(STG.Lottable01, '')
           , Lottable02 = ISNULL(STG.Lottable02, '')
           , Lottable03 = ISNULL(STG.Lottable03, '')
           , EditWho = SUSER_SNAME()
           , Editdate = GETDATE()
         FROM SCE_DL_ASN_STG STG WITH (NOLOCK)
         JOIN ReceiptDetail RecDet ON (STG.ReceiptKey = RecDet.ReceiptKey 
                                   AND STG.ReceiptLineNumber = RecDet.ReceiptLineNumber)
         WHERE RecDet.Receiptkey = @c_Receiptkey
         AND   RecDet.ReceiptLineNumber = @c_ReceiptLineNumber
         AND   STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status  = '1'
         AND   STG.RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END

      IF @c_InParm5 = '1'
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)
         SET Lottable01 = CASE WHEN ISNULL(STG.Lottable01, '') = '' THEN RecDet.Lottable01
                               WHEN STG.Lottable01 = '$$' THEN ''
                               ELSE STG.Lottable01 END
           , Lottable02 = CASE WHEN ISNULL(STG.Lottable02, '') = '' THEN RecDet.Lottable02
                               WHEN STG.Lottable02 = '$$' THEN ''
                               ELSE STG.Lottable02 END
           , Lottable03 = CASE WHEN ISNULL(STG.Lottable03, '') = '' THEN RecDet.Lottable03
                               WHEN STG.Lottable03 = '$$' THEN ''
                               ELSE STG.Lottable03 END
           , Lottable04 = CASE WHEN STG.Lottable04 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable04 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable04 > '1900-01-01 00:00:00.000' THEN STG.Lottable04 END
                               ELSE RecDet.Lottable04 END
           , Lottable05 = CASE WHEN STG.Lottable05 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable05 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable05 > '1900-01-01 00:00:00.000' THEN STG.Lottable05 END
                               ELSE RecDet.Lottable05 END
           , Lottable06 = CASE WHEN ISNULL(STG.Lottable06, '') = '' THEN RecDet.Lottable06
                               WHEN STG.Lottable06 = '$$' THEN ''
                               ELSE STG.Lottable06 END
           , Lottable07 = CASE WHEN ISNULL(STG.Lottable07, '') = '' THEN RecDet.Lottable07
                               WHEN STG.Lottable07 = '$$' THEN ''
                               ELSE STG.Lottable07 END
           , Lottable08 = CASE WHEN ISNULL(STG.Lottable08, '') = '' THEN RecDet.Lottable08
                               WHEN STG.Lottable08 = '$$' THEN ''
                               ELSE STG.Lottable08 END
           , Lottable09 = CASE WHEN ISNULL(STG.Lottable09, '') = '' THEN RecDet.Lottable09
                               WHEN STG.Lottable09 = '$$' THEN ''
                               ELSE STG.Lottable09 END
           , Lottable10 = CASE WHEN ISNULL(STG.Lottable10, '') = '' THEN RecDet.Lottable10
                               WHEN STG.Lottable10 = '$$' THEN ''
                               ELSE STG.Lottable10 END
           , Lottable11 = CASE WHEN ISNULL(STG.Lottable11, '') = '' THEN RecDet.Lottable11
                               WHEN STG.Lottable11 = '$$' THEN ''
                               ELSE STG.Lottable11 END
           , Lottable12 = CASE WHEN ISNULL(STG.Lottable12, '') = '' THEN RecDet.Lottable12
                               WHEN STG.Lottable12 = '$$' THEN ''
                               ELSE STG.Lottable12 END
           , Lottable13 = CASE WHEN STG.Lottable13 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable13 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable13 > '1900-01-01 00:00:00.000' THEN STG.Lottable13 END
                               ELSE RecDet.Lottable13 END
           , Lottable14 = CASE WHEN STG.Lottable14 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable14 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable14 > '1900-01-01 00:00:00.000' THEN STG.Lottable14 END
                               ELSE RecDet.Lottable14 END
           , Lottable15 = CASE WHEN STG.Lottable15 IS NOT NULL THEN
                                  CASE WHEN STG.Lottable15 = '1900-01-01 00:00:00.000' THEN NULL
                                       WHEN STG.Lottable15 > '1900-01-01 00:00:00.000' THEN STG.Lottable15 END
                               ELSE RecDet.Lottable15 END
           , EditWho = SUSER_SNAME()
           , EditDate = GETDATE()
         FROM SCE_DL_ASN_STG STG WITH (NOLOCK)
         JOIN RECEIPTDETAIL RecDet ON (STG.ReceiptKey = RecDet.ReceiptKey
                                       AND STG.ReceiptLineNumber = RecDet.ReceiptLineNumber)
         WHERE RecDet.ReceiptKey = @c_Receiptkey
         AND   RecDet.ReceiptLineNumber = @c_ReceiptLineNumber
         AND   STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status  = '1'
         AND   STG.RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END

      IF @c_InParm3 = '1'
      BEGIN
         BEGIN TRANSACTION

         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
         SET BeforeReceivedQty = ISNULL(STG.BeforeReceivedQty, 0)
           , ToLoc = STG.ToLoc
           , XdockKey = ISNULL(STG.XdockKey, RecDet.XdockKey)
           , EditWho = SUSER_SNAME()
           , EditDate = GETDATE()
         FROM SCE_DL_ASN_STG STG WITH (NOLOCK)
         JOIN RECEIPTDETAIL RecDet ON (  STG.ReceiptKey = RecDet.ReceiptKey
                                   AND   STG.ReceiptLineNumber = RecDet.ReceiptLineNumber)
         WHERE RecDet.ReceiptKey = @c_Receiptkey
         AND   RecDet.ReceiptLineNumber = @c_ReceiptLineNumber
         AND   RecDet.FinalizeFlag = 'N'
         AND   STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status = '1'
         AND   STG.RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END

      IF @c_InParm4 = '1'
      BEGIN
         BEGIN TRANSACTION

         SELECT @c_GetReceiptkey_Out = R.Receiptkey
         FROM RECEIPT R (NOLOCK)
         WHERE R.StorerKey = @c_StorerKey
         AND R.ExternReceiptKey = @c_ExternReceiptkey

         UPDATE dbo.RECEIPT WITH (ROWLOCK)
         SET WarehouseReference = ISNULL(STG.WarehouseReference, Rec.WarehouseReference)
           , TermsNote = ISNULL(STG.TermsNote, Rec.TermsNote)
           , ContainerKey = ISNULL(STG.ContainerKey, Rec.ContainerKey)
           , Appointment_No = ISNULL(STG.Appointment_No, Rec.Appointment_No)
           , UserDefine01 = ISNULL(STG.husr01, Rec.UserDefine01)
           , UserDefine02 = ISNULL(STG.husr02, Rec.UserDefine02)
           , UserDefine03 = ISNULL(STG.husr03, Rec.UserDefine03)
           , UserDefine04 = ISNULL(STG.husr04, Rec.UserDefine04)
           , UserDefine05 = ISNULL(STG.husr05, Rec.UserDefine05)
           , UserDefine06 = ISNULL(STG.husr06, Rec.UserDefine06)
           , UserDefine07 = ISNULL(STG.husr07, Rec.UserDefine07)
           , UserDefine08 = ISNULL(STG.husr08, Rec.UserDefine08)
           , UserDefine09 = ISNULL(STG.husr09, Rec.UserDefine09)
           , UserDefine10 = ISNULL(STG.husr10, Rec.UserDefine10)
           , ReceiptDate = ISNULL(STG.ReceiptDate, Rec.ReceiptDate)
           , BilledContainerQty = ISNULL(STG.BilledContainerQty, Rec.BilledContainerQty)
           , ReceiptGroup = ISNULL(STG.ReceiptGroup, Rec.ReceiptGroup)
           , ContainerType = ISNULL(STG.ContainerType, Rec.ContainerType)
           , ContainerQty = ISNULL(STG.ContainerQty, Rec.ContainerQty)
           , Notes = ISNULL(STG.Notes, Rec.Notes)
           , Signatory = ISNULL(STG.Signatory, Rec.Signatory)
           , TrackingNo = ISNULL(STG.TrackingNo, Rec.TrackingNo)
           , SellerName = ISNULL(STG.SellerName, Rec.SellerName)
           , EditWho = SUSER_SNAME()
           , EditDate = GETDATE()
         FROM SCE_DL_ASN_STG STG WITH (NOLOCK)
         JOIN RECEIPT Rec ON (STG.ExternReceiptKey = Rec.ExternReceiptKey)
         WHERE Rec.ReceiptKey = @c_GetReceiptkey_Out
         AND   STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status = '1'
         AND   STG.RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION
   
         UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   RowRefNo    = @n_RowRefNo
   
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200001_10)'
            ROLLBACK TRANSACTION
            GOTO STEP_999_EXIT_SP
         END
   
         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END

      FETCH NEXT FROM C_UPD
      INTO @c_ExternReceiptkey 
         , @c_StorerKey
         , @c_Receiptkey       
         , @c_ReceiptLineNumber
         , @n_RowRefNo
   END
   CLOSE C_UPD
   DEALLOCATE C_UPD

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK') IN (0 , 1)
   BEGIN
      CLOSE C_CHK
      DEALLOCATE C_CHK   
   END

   IF CURSOR_STATUS('LOCAL', 'C_UPD') IN (0 , 1)
   BEGIN
      CLOSE C_UPD
      DEALLOCATE C_UPD   
   END
   
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_ASN_UPDATE_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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