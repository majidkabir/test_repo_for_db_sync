SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure: isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100002_10   */
/* Creation Date: 13-Sep-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23299 - Perform Channel_ID Checking by Storerkey+SKU    */
/*                                                                      */
/* Usage:                                                               */
/*   @c_InParm1 = '1' Perform Channel_ID Checking by Storerkey+SKU      */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 13-Sep-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100002_10] (
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

   DECLARE @n_RowRefNo         BIGINT
         , @c_Storerkey        NVARCHAR(15)
         , @c_SKU              NVARCHAR(20)
         , @n_Channel_ID       BIGINT
         , @b_Flag             INT = 0

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

   IF @c_InParm1 = '1'
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Storerkey
           , SKU
           , Channel_ID
           , RowRefNo
      FROM SCE_DL_CHANNELINVHOLD_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status = '1'
      GROUP BY Storerkey
             , SKU
             , Channel_ID
             , RowRefNo

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_Storerkey, @c_SKU, @n_Channel_ID, @n_RowRefNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @b_Flag = 0

         SELECT TOP 1 @b_Flag = 1
         FROM ChannelInv CI WITH (NOLOCK)
         WHERE CI.Storerkey = @c_Storerkey
         AND CI.SKU = @c_SKU
         AND CI.Channel_ID = @n_Channel_ID

         IF @b_Flag = 0
         BEGIN
            BEGIN TRANSACTION

            UPDATE STG WITH (ROWLOCK)
            SET STG.STG_Status = '3'
              , STG.STG_ErrMsg = 'Channel_ID is not valid for Storerkey: ' + @c_Storerkey
                               + ' and SKU: ' + @c_SKU
            FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
            WHERE STG.STG_BatchNo = @n_BatchNo AND STG.STG_Status = '1' 
            AND STG.RowRefNo = @n_RowRefNo
   
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_ErrNo = 68001
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100002_10)'
               ROLLBACK
               GOTO STEP_999_EXIT_SP
   
            END
   
            COMMIT TRANSACTION
         END

         FETCH NEXT FROM CUR_LOOP INTO @c_Storerkey, @c_SKU, @n_Channel_ID, @n_RowRefNo
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   QUIT:

   STEP_999_EXIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100002_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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