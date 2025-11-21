SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_RULES_300001_10              */
/* Creation Date: 13-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Create XDOCK ASN                                           */
/*                                                                      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 13-Jan-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_RULES_300001_10] (
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

   DECLARE @c_XExternOrderkey NVARCHAR(50)
         , @c_Orderkey        NVARCHAR(10)
         , @c_XStorerKey      NVARCHAR(15)
         , @c_XDUdef01        NVARCHAR(18)
         , @c_Addwho          NVARCHAR(50)
         , @c_XFacility       NVARCHAR(5)
         , @c_TargetDBName    NVARCHAR(10)
         , @c_Receiptkey      NVARCHAR(25)
         , @c_OrdDETUdef01    NVARCHAR(18)
         , @c_XExternlineno   NVARCHAR(10)
         , @c_XSKU            NVARCHAR(20)
         , @n_XQty            INT
         , @c_XOutQty         INT
         , @c_XUOM            NVARCHAR(10)
         , @c_Xlottable03     NVARCHAR(18)
         , @c_Facility        NVARCHAR(5)
         , @c_XPackkey_out    NVARCHAR(10)
         , @c_FACUDEF04       NVARCHAR(30)
         , @c_LineNum         NVARCHAR(5)
         , @i                 INT;


   SET @c_TargetDBName = DB_NAME();

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

   DECLARE C_XDOCK_Header CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ExternOrderkey
        , OrderKey
        , Storerkey
        , DUdef01
        , AddWho
   FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '9'
   AND   DUdef01       <> ''
   GROUP BY ExternOrderkey
          , OrderKey
          , Storerkey
          , DUdef01
          , AddWho
   ORDER BY ExternOrderkey;

   OPEN C_XDOCK_Header;
   FETCH NEXT FROM C_XDOCK_Header
   INTO @c_XExternOrderkey
      , @c_Orderkey
      , @c_XStorerKey
      , @c_XDUdef01
      , @c_Addwho;

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN --while            

      IF @b_Debug = '2'
      BEGIN
         SELECT 'Start ASN';
      END;

      SELECT @c_OrdDETUdef01 = DUdef01
      FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
      WHERE STG_BatchNo  = @n_BatchNo
      AND   STG_Status     = '9'
      AND   ExternOrderkey = @c_XExternOrderkey
      AND   DUdef01        = @c_XDUdef01
      GROUP BY DUdef01;

      IF @b_Debug = '2'
      BEGIN
         SELECT 'Order detail Userdefine 01 : ' + @c_XDUdef01 + ' with externorederkey : ' + @c_XExternOrderkey;
      END;

      IF ISNULL(@c_OrdDETUdef01, '') <> ''
      BEGIN --Ord Det Udef01  

         SELECT @c_XFacility = Facility
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey     = @c_Orderkey
         AND   ExternOrderKey = @c_XExternOrderkey;

         IF @b_Debug = '2'
         BEGIN
            SELECT 'Order Facility : ' + @c_XFacility;
         END;

         SELECT @b_Success = 0;
         EXEC ispDBGetKey @c_DBName = @c_TargetDBName
                        , @c_KeyName = 'Receipt'
                        , @n_FieldLength = 10
                        , @c_KeyString = @c_Receiptkey OUTPUT
                        , @b_Success = @b_Success OUTPUT;

         IF @b_Success <> 1
         BEGIN
            SET @n_Continue = 3;
            SET @c_ErrMsg = 'Unable to get a new ReceiptKey from ispDBGetKey SP. (isp_SCE_DL_GENERIC_SO_RULES_300001_10)';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         -- Get Receipt key  
         IF @b_Debug = '2'
         BEGIN
            SELECT 'New Receiptkey : ' + @c_Receiptkey;
         END;

         INSERT INTO dbo.RECEIPT
         (
            ReceiptKey
          , ExternReceiptKey
          , StorerKey
          , ReceiptDate
          , CarrierKey
          , CarrierName
          , CarrierAddress1
          , CarrierAddress2
          , CarrierZip
          , WarehouseReference
          , RECType
          , Facility
          , DOCTYPE
          , AddWho
          , EditWho
         )
         SELECT @c_Receiptkey
              , @c_XExternOrderkey
              , @c_XStorerKey
              , GETDATE()
              , @c_OrdDETUdef01
              , S.Company
              , S.Address1
              , S.Address2
              , S.Zip
              , @c_Orderkey
              , 'XDOCK'
              , @c_XFacility
              , 'A'
              , @c_Addwho
              , @c_Addwho
         FROM dbo.STORER S WITH (NOLOCK)
         WHERE S.StorerKey = @c_OrdDETUdef01
         AND   type          = '2';

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END; -- Ord Det Udef01  

      --SET @n_iNo = 0  
      DECLARE C_XDOCK_Detail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ExternLineNo
           , SKU
           , OpenQty
           , UOM
           , Lottable03
           , Facility
      FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
      WHERE STG_BatchNo  = @n_BatchNo
      AND   STG_Status     = '9'
      AND   ExternOrderkey = @c_XExternOrderkey
      AND   DUdef01        = @c_XDUdef01
      AND   DUdef01        <> ''
      GROUP BY ExternLineNo
             , SKU
             , OpenQty
             , UOM
             , Lottable03
             , Facility;

      OPEN C_XDOCK_Detail;
      FETCH NEXT FROM C_XDOCK_Detail
      INTO @c_XExternlineno
         , @c_XSKU
         , @n_XQty
         , @c_XUOM
         , @c_Xlottable03
         , @c_Facility;

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN --while C_XDOCK_Detail  

         --  IF ISNULL(@c_XDUdef01,'') <> ''  
         --   BEGIN  
         --SET @n_iNo = @n_iNo + 1      
         SET @i = 0;
         WHILE @i < (5 - LEN(@c_XExternlineno))
         BEGIN
            SET @c_LineNum += N'0';
            SET @i += 1;
         END;


         SELECT @c_FACUDEF04 = UserDefine04
         FROM dbo.V_FACILITY WITH (NOLOCK)
         WHERE Facility = @c_Facility;

         SET @c_XOutQty = 0;

         SELECT @c_XOutQty = OpenQty
         FROM dbo.V_ORDERDETAIL WITH (NOLOCK)
         WHERE ExternOrderKey = @c_XExternOrderkey
         AND   OrderLineNumber  = @c_LineNum;

         SET @c_XPackkey_out = N'';
         SELECT @c_XPackkey_out = PackKey
         FROM dbo.V_ORDERDETAIL WITH (NOLOCK)
         WHERE ExternOrderKey = @c_XExternOrderkey
         AND   OrderLineNumber  = @c_LineNum;

         IF @b_Debug = '2'
         BEGIN
            PRINT 'Select Facility Userdefine04 : ' + @c_FACUDEF04 + 'with qty : ' + CONVERT(NVARCHAR(10), @c_XOutQty)
                  + ' with packkey : ' + @c_XPackkey_out;
         END;

         INSERT INTO dbo.RECEIPTDETAIL
         (
            ReceiptKey
          , ReceiptLineNumber
          , ExternReceiptKey
          , ExternLineNo
          , StorerKey
          , Sku
          , PackKey
          , QtyExpected
          , UOM
          , Lottable03
          , ToLoc
          , AddWho
          , EditWho
         )
         VALUES
         (
            @c_Receiptkey
          , @c_LineNum
          , @c_XExternOrderkey
          , @c_XExternlineno
          , @c_XStorerKey
          , @c_XSKU
          , @c_XPackkey_out
          , ISNULL(@c_XOutQty, '0')
          , @c_XUOM
          , ISNULL(@c_Xlottable03, '')
          , ISNULL(@c_FACUDEF04, '')
          , @c_Addwho
          , @c_Addwho
         );

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
         --   END  
         FETCH NEXT FROM C_XDOCK_Detail
         INTO @c_XExternlineno
            , @c_XSKU
            , @n_XQty
            , @c_XUOM
            , @c_Xlottable03
            , @c_Facility;
      END; --while C_XDOCK_Detail     

      CLOSE C_XDOCK_Detail;
      DEALLOCATE C_XDOCK_Detail;

      FETCH NEXT FROM C_XDOCK_Header
      INTO @c_XExternOrderkey
         , @c_Orderkey
         , @c_XStorerKey
         , @c_XDUdef01
         , @c_Addwho;
   END; --while  

   CLOSE C_XDOCK_Header;
   DEALLOCATE C_XDOCK_Header;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_RULES_300001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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