SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_EO_RULES_200001_10              */
/* Creation Date: 15-Dec-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Insert into ExternOrder and ExternOrderDetails     */
/*           table.                                                     */
/*                                                                      */
/* Usage: @c_InParm1 = '1' Turn on the ExternorderKey checking          */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 15-Dec-2021  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_EO_RULES_200001_10] (
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

   DECLARE @n_RowRefNo       INT
         , @c_ExternOrderKey NVARCHAR(50);


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
      DECLARE C_CHK_CONF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
      FROM dbo.SCE_DL_EO_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_CHK_CONF;
      FETCH NEXT FROM C_CHK_CONF
      INTO @n_RowRefNo;

      WHILE @@FETCH_STATUS = 0
      BEGIN

         IF NOT EXISTS (
         SELECT 1
         FROM dbo.SCE_DL_EO_STG      STG WITH (NOLOCK)
         INNER JOIN dbo.ExternOrders EO WITH (NOLOCK)
         ON EO.ExternOrderKey = STG.ExternOrderKey
         WHERE STG.RowRefNo = @n_RowRefNo
         )
         BEGIN
            INSERT INTO dbo.ExternOrders
            (
               ExternOrderKey
             , OrderKey
             , Storerkey
             , Source
             , BindingDate
             , ShippedDate
             , Status
             , PlatformName
             , PlatformOrderNo
             , Userdefine01
             , Userdefine02
             , Userdefine03
             , Userdefine04
             , Userdefine05
             , Userdefine06
             , Userdefine07
             , Userdefine08
             , Userdefine09
             , Userdefine10
             , Notes
             , Addwho
             , Adddate
             , Editwho
             , Editdate
            )
            SELECT ExternOrderKey
                 , OrderKey
                 , Storerkey
                 , [Source]
                 , BindingDate
                 , ShippedDate
                 , Hdr_Status
                 , PlatformName
                 , PlatformOrderNo
                 , Hdr_Userdefine01
                 , Hdr_Userdefine02
                 , Hdr_Userdefine03
                 , Hdr_Userdefine04
                 , Hdr_Userdefine05
                 , Hdr_Userdefine06
                 , Hdr_Userdefine07
                 , Hdr_Userdefine08
                 , Hdr_Userdefine09
                 , Hdr_Userdefine10
                 , Hdr_Notes
                 , Addwho
                 , Adddate
                 , Editwho
                 , Editdate
            FROM dbo.SCE_DL_EO_STG WITH (NOLOCK)
            WHERE RowRefNo = @n_RowRefNo;
         END;

         INSERT INTO dbo.ExternOrdersDetail
         (
            ExternOrderKey
          , ExternLineNo
          , OrderKey
          , OrderLineNumber
          , Storerkey
          , SKU
          , QRCode
          , RFIDNo
          , TIDNo
          , [Status]
          , Userdefine01
          , Userdefine02
          , Userdefine03
          , Userdefine04
          , Userdefine05
          , Userdefine06
          , Userdefine07
          , Userdefine08
          , Userdefine09
          , Userdefine10
          , Notes
          , Addwho
          , Adddate
          , Editwho
          , Editdate
         )
         SELECT ExternOrderKey
              , ExternLineNo
              , OrderKey
              , OrderLineNumber
              , Storerkey
              , SKU
              , QRCode
              , RFIDNo
              , TIDNo
              , Det_Status
              , Det_Userdefine01
              , Det_Userdefine02
              , Det_Userdefine03
              , Det_Userdefine04
              , Det_Userdefine05
              , Det_Userdefine06
              , Det_Userdefine07
              , Det_Userdefine08
              , Det_Userdefine09
              , Det_Userdefine10
              , Det_Notes
              , Addwho
              , Adddate
              , Editwho
              , Editdate
         FROM dbo.SCE_DL_EO_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         UPDATE dbo.SCE_DL_EO_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         FETCH NEXT FROM C_CHK_CONF
         INTO @n_RowRefNo;
      END;

      CLOSE C_CHK_CONF;
      DEALLOCATE C_CHK_CONF;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_EO_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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