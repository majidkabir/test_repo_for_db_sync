SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_MBOL_UPDATE_RULES_100001_10     */
/* Creation Date: 21-Feb-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21811 - Data Loader - MBOL Update                       */
/*                                                                      */
/* Usage: MBOLDETUPDATE  @c_InParm1 =  '0' Reject Update                */
/*                       @c_InParm1 =  '1' Allow Update                 */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 21-Feb-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_MBOL_UPDATE_RULES_100001_10] (
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

   DECLARE @c_Mbolkey            NVARCHAR(10)  
         , @c_ExternMbolKey      NVARCHAR(30)  
         , @c_VoyageNumber       NVARCHAR(60)  
         , @c_BookingReference   NVARCHAR(60)  
         , @c_OtherReference     NVARCHAR(60)  
         , @c_UserDefine01       NVARCHAR(60)  
         , @c_UserDefine02       NVARCHAR(60)  
         , @c_UserDefine03       NVARCHAR(60)  
         , @c_Orderkey           NVARCHAR(10)  
         , @c_Loadkey            NVARCHAR(10)  
         , @c_ttlMsg             NVARCHAR(250)
         , @c_Status             NVARCHAR(10)
         
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

   DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TRIM(ISNULL(MbolKey,''))
        , TRIM(ISNULL(ExternMbolKey,''))
        , TRIM(ISNULL(VoyageNumber,''))
        , TRIM(ISNULL(BookingReference,''))
        , TRIM(ISNULL(OtherReference,''))
        , TRIM(ISNULL(UserDefine01,''))
        , TRIM(ISNULL(UserDefine02,''))
        , TRIM(ISNULL(UserDefine03,''))
        , TRIM(ISNULL(Orderkey,''))
        , TRIM(ISNULL(Loadkey,''))
        , TRIM(ISNULL([Status],''))
   FROM dbo.SCE_DL_MBOL_STG WITH (NOLOCK)
   WHERE STG_BatchNo    = @n_BatchNo
   AND   STG_Status     = '1'
   GROUP BY TRIM(ISNULL(MbolKey,''))
          , TRIM(ISNULL(ExternMbolKey,''))
          , TRIM(ISNULL(VoyageNumber,''))
          , TRIM(ISNULL(BookingReference,''))
          , TRIM(ISNULL(OtherReference,''))
          , TRIM(ISNULL(UserDefine01,''))
          , TRIM(ISNULL(UserDefine02,''))
          , TRIM(ISNULL(UserDefine03,''))
          , TRIM(ISNULL(Orderkey,''))
          , TRIM(ISNULL(Loadkey,''))
          , TRIM(ISNULL([Status],''))

   OPEN C_CHK

   FETCH NEXT FROM C_CHK
   INTO @c_Mbolkey          
      , @c_ExternMbolKey    
      , @c_VoyageNumber     
      , @c_BookingReference 
      , @c_OtherReference   
      , @c_UserDefine01     
      , @c_UserDefine02     
      , @c_UserDefine03     
      , @c_Orderkey         
      , @c_Loadkey  
      , @c_Status

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      IF ISNULL(@c_Mbolkey,'') = ''
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                       + N'/MbolKey is Null '
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1
                        FROM MBOL (NOLOCK)
                        WHERE MBOLKey = @c_Mbolkey)
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/MbolKey ' + @c_Mbolkey + ' not exists '
         END
      END

      IF @c_InParm1 <> '1'
      BEGIN
         IF @c_Status <> '0'
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/Status is not 0. Cannot Update MBOL '
         END

         IF ISNULL(@c_ExternMbolKey, '') = ''
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/ExternMbolKey is Null '
         END


         IF ISNULL(@c_VoyageNumber, '') = ''
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/VoyageNumber is Null '
         END

         IF ISNULL(@c_BookingReference, '') = ''
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/BookingReference is Null '
         END

         IF ISNULL(@c_OtherReference, '') = ''
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/OtherReference is Null '
         END

         IF ISNULL(@c_UserDefine01, '') = ''
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/UserDefine01 is Null '
         END

         IF ISNULL(@c_UserDefine02, '') = ''
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/UserDefine02 is Null '
         END

         IF ISNULL(@c_UserDefine03, '') = ''
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/UserDefine03 is Null '
         END
      END
      ELSE   --@c_InParm1 = '1'
      BEGIN
         IF @c_Status = '9'
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/Status 9. Cannot Update MBOLDETAIL '
         END

         IF NOT EXISTS (SELECT 1
                        FROM MBOLDETAIL (NOLOCK)
                        WHERE MBOLKey = @c_Mbolkey)
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/MbolKey ' + @c_Mbolkey + ' not exists in MBOLDETAIL table '
         END

         IF ISNULL(@c_Orderkey, '') = ''
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/Orderkey is Null '
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM ORDERS (NOLOCK)
                           WHERE Orderkey = @c_Orderkey)
            BEGIN
               SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                             + N'/Orderkey ' + @c_Orderkey + ' not exists in ORDERS table '
            END
         END

         IF ISNULL(@c_Loadkey, '') = ''
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                          + N'/Loadkey is Null '
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM LOADPLANDETAIL (NOLOCK)
                           WHERE Loadkey = @c_Loadkey
                           AND Orderkey = @c_Orderkey)
            BEGIN
               SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                             + N'/Loadkey ' + @c_Loadkey + ' OR Orderkey ' + @c_Orderkey + ' not exists '
                             + N'or match in LOADPLANDETAIL table '
            END
         END
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.SCE_DL_MBOL_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo       = @n_BatchNo
         AND   STG_Status        = '1'     

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_MBOL_UPDATE_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END

         COMMIT
      END

      FETCH NEXT FROM C_CHK
      INTO @c_Mbolkey          
         , @c_ExternMbolKey    
         , @c_VoyageNumber     
         , @c_BookingReference 
         , @c_OtherReference   
         , @c_UserDefine01     
         , @c_UserDefine02     
         , @c_UserDefine03     
         , @c_Orderkey         
         , @c_Loadkey  
         , @c_Status
   END
   CLOSE C_CHK
   DEALLOCATE C_CHK

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK') IN (0 , 1)
   BEGIN
      CLOSE C_CHK
      DEALLOCATE C_CHK   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_MBOL_UPDATE_RULES_100001_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '')
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