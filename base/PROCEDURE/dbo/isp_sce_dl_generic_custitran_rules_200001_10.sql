SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_CUSTITRAN_RULES_200001_10       */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert into WMSCUSTITRAN target table              */
/*                                                                      */
/*                                                                      */
/* Usage:   @c_InParm1 =  '1'  Active Flag                              */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CUSTITRAN_RULES_200001_10] (
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

   DECLARE @n_RowRefNo           INT
         , @c_fileKey            NVARCHAR(10)
         , @dt_ExternPostingDate DATETIME
         , @c_StorerKey          NVARCHAR(15)
         , @c_ExternType         NVARCHAR(10)
         , @c_ExternRefKey       NVARCHAR(30)
         , @c_ExternTranIDKey    NVARCHAR(15)
         , @c_SKU                NVARCHAR(20)
         , @c_lottable01         NVARCHAR(20)
         , @c_lottable02         NVARCHAR(20)
         , @c_lottable03         NVARCHAR(20)
         , @d_lottable04         DATETIME
         , @d_lottable05         DATETIME
         , @c_HostWhCode         NVARCHAR(10)
         , @c_UserDefine01       NVARCHAR(30)
         , @c_UserDefine02       NVARCHAR(30)
         , @c_UserDefine03       NVARCHAR(30)
         , @c_UserDefine04       NVARCHAR(30)
         , @c_UserDefine05       NVARCHAR(30)
         , @c_ttlMsg             NVARCHAR(250);

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

      EXECUTE dbo.nspg_getkey @keyname = 'FileKey'
                            , @fieldlength = 10
                            , @keystring = @c_fileKey OUTPUT
                            , @b_Success = @b_Success OUTPUT
                            , @n_err = @n_ErrNo OUTPUT
                            , @c_errmsg = @c_ErrMsg OUTPUT;


      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ExternPostingDate
                    , Storerkey
                    , ExternType
                    , ExternRefKey
                    , ExternTranIDKey
                    , SKU
                    , ISNULL(Lottable01, '')
                    , ISNULL(Lottable02, '')
                    , ISNULL(Lottable03, '')
                    , ISNULL(Lottable04, '1900-01-01')
                    , ISNULL(Lottable05, '1900-01-01')
                    , ISNULL(HostWhCode, '')
                    , ISNULL(UserDefine01, '')
                    , ISNULL(UserDefine02, '')
                    , ISNULL(UserDefine03, '')
                    , ISNULL(UserDefine04, '')
                    , ISNULL(UserDefine05, '')
                    , MIN(RowRefNo)
      FROM dbo.SCE_DL_CUSTITRAN_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'
      GROUP BY ExternPostingDate
             , Storerkey
             , ExternType
             , ExternRefKey
             , ExternTranIDKey
             , SKU
             , ISNULL(Lottable01, '')
             , ISNULL(Lottable02, '')
             , ISNULL(Lottable03, '')
             , ISNULL(Lottable04, '1900-01-01')
             , ISNULL(Lottable05, '1900-01-01')
             , ISNULL(HostWhCode, '')
             , ISNULL(UserDefine01, '')
             , ISNULL(UserDefine02, '')
             , ISNULL(UserDefine03, '')
             , ISNULL(UserDefine04, '')
             , ISNULL(UserDefine05, '')
      ORDER BY MIN(RowRefNo);

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @dt_ExternPostingDate
         , @c_StorerKey
         , @c_ExternType
         , @c_ExternRefKey
         , @c_ExternTranIDKey
         , @c_SKU
         , @c_lottable01
         , @c_lottable02
         , @c_lottable03
         , @d_lottable04
         , @d_lottable05
         , @c_HostWhCode
         , @c_UserDefine01
         , @c_UserDefine02
         , @c_UserDefine03
         , @c_UserDefine04
         , @c_UserDefine05
         , @n_RowRefNo;

      WHILE @@FETCH_STATUS = 0
      BEGIN

         INSERT INTO dbo.WMSCustITRAN
         (
            DataStream
          , File_key
          , ExternPostingDate
          , Storerkey
          , Facility
          , ExternType
          , ExternRefKey
          , ExternTranIDKey
          , HostWhCode
          , SKU
          , ALTSKU
          , Lottable01
          , Lottable02
          , Lottable03
          , Lottable04
          , Lottable05
          , Qty
          , UOM
          , UserDefine01
          , UserDefine02
          , UserDefine03
          , UserDefine04
          , UserDefine05
          , AddWho
         )
         SELECT '2481'
              , CONVERT(INT, @c_fileKey)
              , ExternPostingDate
              , Storerkey
              , ISNULL(Facility, '')
              , ISNULL(ExternType, '')
              , ISNULL(ExternRefKey, '')
              , ISNULL(ExternTranIDKey, '')
              , ISNULL(HostWhCode, '')
              , SKU
              , ISNULL(ALTSKU, '')
              , ISNULL(Lottable01, '')
              , ISNULL(Lottable02, '')
              , ISNULL(Lottable03, '')
              , Lottable04
              , Lottable05
              , ISNULL(Qty, 0)
              , ISNULL(UOM, '')
              , ISNULL(UserDefine01, '')
              , ISNULL(UserDefine02, '')
              , ISNULL(UserDefine03, '')
              , ISNULL(UserDefine04, '')
              , ISNULL(UserDefine05, '')
              , @c_Username
         FROM dbo.SCE_DL_CUSTITRAN_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         UPDATE dbo.SCE_DL_CUSTITRAN_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE STG_BatchNo                    = @n_BatchNo
         AND   STG_Status                       = '1'
         AND   ExternPostingDate                = @dt_ExternPostingDate
         AND   Storerkey                        = @c_StorerKey
         AND   ExternType                       = @c_ExternType
         AND   ExternRefKey                     = @c_ExternRefKey
         AND   ExternTranIDKey                  = @c_ExternTranIDKey
         AND   SKU                              = @c_SKU
         AND   ISNULL(Lottable01, '')           = @c_lottable01
         AND   ISNULL(Lottable02, '')           = @c_lottable02
         AND   ISNULL(Lottable03, '')           = @c_lottable03
         AND   ISNULL(Lottable04, '1900-01-01') = @d_lottable04
         AND   ISNULL(Lottable05, '1900-01-01') = @d_lottable05
         AND   ISNULL(HostWhCode, '')           = @c_HostWhCode
         AND   ISNULL(UserDefine01, '')         = @c_UserDefine01
         AND   ISNULL(UserDefine02, '')         = @c_UserDefine02
         AND   ISNULL(UserDefine03, '')         = @c_UserDefine03
         AND   ISNULL(UserDefine04, '')         = @c_UserDefine04
         AND   ISNULL(UserDefine05, '')         = @c_UserDefine05;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         NEXTITEM:

         FETCH NEXT FROM C_HDR
         INTO @dt_ExternPostingDate
            , @c_StorerKey
            , @c_ExternType
            , @c_ExternRefKey
            , @c_ExternTranIDKey
            , @c_SKU
            , @c_lottable01
            , @c_lottable02
            , @c_lottable03
            , @d_lottable04
            , @d_lottable05
            , @c_HostWhCode
            , @c_UserDefine01
            , @c_UserDefine02
            , @c_UserDefine03
            , @c_UserDefine04
            , @c_UserDefine05
            , @n_RowRefNo;
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CUSTITRAN_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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