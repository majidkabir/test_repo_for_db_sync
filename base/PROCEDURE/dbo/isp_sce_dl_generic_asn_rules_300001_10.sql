SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_ASN_RULES_300001_10              */
/* Creation Date: 28-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  INSERT Carton info into SEPTWOLVES Carton Table            */
/*                                                                      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.2                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-Jan-2022  GHChan    1.1   Initial                                 */
/* 03-Nov-2022  WLChooi   1.2   Extend ExternReceiptkey to 50 (WL01)    */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_ASN_RULES_300001_10] (
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

   DECLARE @c_ExternReceiptkey NVARCHAR(50)   --WL01
         , @c_Orderkey        NVARCHAR(10);

   DECLARE @c_TargetDBName        NVARCHAR(30)
         , @c_ORDExternReceiptkey NVARCHAR(50)   --WL01
         , @c_ORDStorerkey        NVARCHAR(15)
         , @c_ORDLottable02       NVARCHAR(20)
         , @c_ORDLottable03       NVARCHAR(20)
         , @c_ORDDUSR01           NVARCHAR(30)
         , @c_Company             NVARCHAR(45)
         , @c_address1            NVARCHAR(45)
         , @c_address2            NVARCHAR(45)
         , @c_zip                 NVARCHAR(18)
         , @c_country             NVARCHAR(30)
         , @c_phone1              NVARCHAR(18)
         , @c_ORDExternlineNo     NVARCHAR(20)
         , @c_ORDSKU              NVARCHAR(20)
         , @c_ORDUOM              NVARCHAR(10)
         , @c_ORDPackkey          NVARCHAR(10)
         , @n_ORDOpenQty          INT
         , @c_GetORDPackkey       NVARCHAR(10)
         , @c_ReceiptLineNumber   NVARCHAR(5);

   SET @c_TargetDBName = DB_NAME();
   SET @n_StartTCnt = @@TRANCOUNT;

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

   BEGIN TRAN;

   DECLARE C_ASNORD_Header CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ExternReceiptkey
        , Storerkey
        , Lottable02
        , Lottable03
        , DUSR01
   FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
   WHERE STG_BatchNo          = @n_BatchNo
   AND   STG_Status             = '9'
   AND   RECType                = 'HMVM'
   AND   ISNULL(Lottable02, '') <> ''
   AND   ISNULL(Lottable03, '') <> ''
   AND   Lottable03             = ExternReceiptkey
   GROUP BY ExternReceiptkey
          , Storerkey
          , Lottable02
          , Lottable03
          , DUSR01;

   OPEN C_ASNORD_Header;
   FETCH NEXT FROM C_ASNORD_Header
   INTO @c_ORDExternReceiptkey
      , @c_ORDStorerkey
      , @c_ORDLottable02
      , @c_ORDLottable03
      , @c_ORDDUSR01;

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN --while

      IF @b_Debug = '1'
      BEGIN
         SELECT 'Start Create Order';
      END;

      SET @c_Company = N'';
      SET @c_address1 = N'';
      SET @c_address2 = N'';
      SET @c_zip = N'';
      SET @c_country = N'';
      SET @c_phone1 = N'';

      SELECT @c_Company  = Company
           , @c_address1 = Address1
           , @c_address2 = Address2
           , @c_zip      = Zip
           , @c_country  = Country
           , @c_phone1   = Phone1
      FROM dbo.V_STORER WITH (NOLOCK)
      WHERE StorerKey = @c_ORDLottable02;

      SELECT @b_Success = 0;
      SET @c_Orderkey = N'';
      EXEC dbo.ispDBGetKey @c_DBName = @c_TargetDBName
                         , @c_KeyName = 'Order'
                         , @n_FieldLength = 10
                         , @c_KeyString = @c_Orderkey OUTPUT
                         , @b_Success = @b_Success OUTPUT;

      IF @b_Success = 1
      BEGIN
         SET @n_Continue = 3;
         SET @c_ErrMsg = 'Unable to get a new OrderKey from ispDBGetKey.';
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      -- Get Order key
      IF @b_Debug = '1'
      BEGIN
         SELECT 'New orderkey : ' + @c_Orderkey;
      END;

      INSERT INTO dbo.ORDERS
      (
         OrderKey
       , ExternOrderKey
       , StorerKey
       , OrderDate
       , DeliveryDate
       , ConsigneeKey
       , Type
       , Facility
       , C_Company
       , C_Address1
       , C_Address2
       , C_Zip
       , C_Country
       , C_Phone1
       , AddWho
       , EditWho
      )
      SELECT TOP (1) @c_Orderkey
                   , @c_ORDExternReceiptkey
                   , @c_ORDStorerkey
                   , GETDATE()
                   , @c_ORDDUSR01
                   , @c_ORDLottable02
                   , 'HMVM'
                   , REC.Facility
                   , @c_Company
                   , @c_address1
                   , @c_address2
                   , @c_zip
                   , @c_country
                   , @c_phone1
                   , @c_Username
                   , @c_Username
      FROM dbo.V_RECEIPT REC WITH (NOLOCK)
      WHERE ExternReceiptKey = @c_ORDExternReceiptkey
      ORDER BY REC.ReceiptKey DESC;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;


      --SET @n_iNo = 0
      DECLARE C_ASNORD_Detail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ExternLineNo
           , SKU
           , UOM
           , Packkey
           , ReceiptLineNumber
      FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
      WHERE STG_BatchNo    = @n_BatchNo
      AND   STG_Status       = '9'
      AND   ExternReceiptkey = @c_ORDExternReceiptkey
      AND   Storerkey        = @c_ORDStorerkey
      AND   Lottable02       = @c_ORDLottable02
      AND   Lottable03       = @c_ORDLottable03
      AND   DUSR01           = @c_ORDDUSR01
      GROUP BY ExternLineNo
             , SKU
             , UOM
             , Packkey
             , ReceiptLineNumber;

      OPEN C_ASNORD_Detail;
      FETCH NEXT FROM C_ASNORD_Detail
      INTO @c_ORDExternlineNo
         , @c_ORDSKU
         , @c_ORDUOM
         , @c_ORDPackkey
         , @c_ReceiptLineNumber;

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN --while C_ASNORD_Detail
         SET @n_ORDOpenQty = '';
         SET @c_GetORDPackkey = N'';


         SELECT @n_ORDOpenQty    = QtyExpected
              , @c_ORDPackkey = PackKey
         FROM dbo.V_RECEIPTDETAIL WITH (NOLOCK)
         WHERE ExternReceiptKey = @c_ORDExternReceiptkey
         AND   ReceiptLineNumber  = @c_ReceiptLineNumber;
         --CS27 END

         INSERT INTO dbo.ORDERDETAIL
         (
            OrderKey
          , OrderLineNumber
          , ExternLineNo
          , ExternOrderKey
          , StorerKey
          , Sku
          , PackKey
          , OpenQty
          , OriginalQty
          , UOM
          , Lottable02
          , Lottable03
          , AddWho
          , EditWho
         )
         VALUES
         (
            @c_Orderkey
          , @c_ReceiptLineNumber
          , @c_ORDExternlineNo
          , @c_ORDExternReceiptkey
          , @c_ORDStorerkey
          , @c_ORDSKU
          , @c_ORDPackkey
          , ISNULL(@n_ORDOpenQty, '0')
          , ISNULL(@n_ORDOpenQty, '0')
          , @c_ORDUOM
          , ISNULL(@c_ORDLottable02, '')
          , ISNULL(@c_ORDLottable03, '')
          , @c_Username
          , @c_Username
         );

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
         --   END
         FETCH NEXT FROM C_ASNORD_Detail
         INTO @c_ORDExternlineNo
            , @c_ORDSKU
            , @c_ORDUOM
            , @c_ORDPackkey;
      END; --while C_ASNORD_Detail

      CLOSE C_ASNORD_Detail;
      DEALLOCATE C_ASNORD_Detail;

      FETCH NEXT FROM C_ASNORD_Header
      INTO @c_ORDExternReceiptkey
         , @c_ORDStorerkey
         , @c_ORDLottable02
         , @c_ORDLottable03
         , @c_ORDDUSR01;
   END; --while

   CLOSE C_ASNORD_Header;
   DEALLOCATE C_ASNORD_Header;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_ASN_RULES_300001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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