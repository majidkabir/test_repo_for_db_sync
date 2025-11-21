SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SKUINFO_RULES_200001_10         */
/* Creation Date: 06-Mar-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-21909 Perform insert or update into SKUINFO table      */
/*                                                                      */
/* Usage:  @c_InParm1 = 'SP Name' Update before Insert                  */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data MoSIfications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 06-Mar-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SKUINFO_RULES_200001_10]
(
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

   DECLARE @c_SKU        NVARCHAR(20)
         , @c_StorerKey  NVARCHAR(15)
         , @n_RowRefNo   INT
         , @n_FoundExist INT
         , @n_ActionFlag INT
         , @c_ttlMsg     NVARCHAR(250)

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (SPName NVARCHAR(300) '$.SubRuleSP'
          , InParm1 NVARCHAR(60) '$.InParm1'
          , InParm2 NVARCHAR(60) '$.InParm2'
          , InParm3 NVARCHAR(60) '$.InParm3'
          , InParm4 NVARCHAR(60) '$.InParm4'
          , InParm5 NVARCHAR(60) '$.InParm5')
   WHERE SPName = OBJECT_NAME(@@PROCID)

   IF ISNULL(@c_InParm1, '') <> ''
   BEGIN
      IF NOT EXISTS (  SELECT *
                       FROM dbo.sysobjects
                       WHERE id = OBJECT_ID(@c_InParm1) AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
      BEGIN
         UPDATE dbo.SCE_DL_SKUINFO_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = 'Error:SP ' + TRIM(@c_InParm1) + N' is not found'
         WHERE STG_BatchNo = @n_BatchNo AND STG_Status = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END

      SET @c_ExecStatements = N''
      SET @c_ExecArguments = N''

      SET @c_ExecStatements = N' EXEC ' + TRIM(@c_InParm1)
                            + N'   @b_Debug       = @b_Debug '              + CHAR(13)
                            + N' , @n_BatchNo     = @n_BatchNo '            + CHAR(13)   
                            + N' , @n_Flag        = @n_Flag '               + CHAR(13)      
                            + N' , @c_SubRuleJson = @c_SubRuleJson '        + CHAR(13) 
                            + N' , @c_STGTBL      = @c_STGTBL '             + CHAR(13) 
                            + N' , @c_POSTTBL     = @c_POSTTBL '            + CHAR(13)     
                            + N' , @c_UniqKeyCol  = @c_UniqKeyCol '         + CHAR(13)  
                            + N' , @c_Username    = @c_Username '           + CHAR(13)    
                            + N' , @b_Success     = @b_Success     OUTPUT ' + CHAR(13) 
                            + N' , @n_ErrNo       = @n_ErrNo       OUTPUT ' + CHAR(13) 
                            + N' , @c_ErrMsg      = @c_ErrMsg      OUTPUT '

      SET @c_ExecArguments = N'   @b_Debug       INT                   ' + CHAR(13) 
                           + N' , @n_BatchNo     INT                   ' + CHAR(13) 
                           + N' , @n_Flag        INT                   ' + CHAR(13) 
                           + N' , @c_SubRuleJson NVARCHAR(MAX)         ' + CHAR(13) 
                           + N' , @c_STGTBL      NVARCHAR(250)         ' + CHAR(13) 
                           + N' , @c_POSTTBL     NVARCHAR(250)         ' + CHAR(13) 
                           + N' , @c_UniqKeyCol  NVARCHAR(1000)        ' + CHAR(13) 
                           + N' , @c_Username    NVARCHAR(128)         ' + CHAR(13) 
                           + N' , @b_Success     INT            OUTPUT ' + CHAR(13) 
                           + N' , @n_ErrNo       INT            OUTPUT ' + CHAR(13) 
                           + N' , @c_ErrMsg      NVARCHAR(250)  OUTPUT '

      EXEC sp_executesql @c_ExecStatements
                       , @c_ExecArguments
                       , @b_Debug      
                       , @n_BatchNo    
                       , @n_Flag       
                       , @c_SubRuleJson
                       , @c_STGTBL     
                       , @c_POSTTBL    
                       , @c_UniqKeyCol 
                       , @c_Username   
                       , @b_Success      OUTPUT  
                       , @n_ErrNo        OUTPUT  
                       , @c_ErrMsg       OUTPUT  

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT
      END
   END

   QUIT:

   STEP_999_EXIT_SP:

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SKUINFO_RULES_200001_10] EXIT... ErrMsg : '
             + ISNULL(TRIM(@c_ErrMsg), '')
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