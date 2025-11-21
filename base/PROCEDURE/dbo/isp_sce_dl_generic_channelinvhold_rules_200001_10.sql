SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure: isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_200001_10   */
/* Creation Date: 13-Sep-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23299 - Perform Insert into target table action.        */
/*                                                                      */
/* Usage:                                                               */
/*   @c_InParm1 = '1' Perform Insert into target table action.          */
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

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_200001_10]
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

   DECLARE @n_RowRefNo           BIGINT
         , @c_HoldType           NVARCHAR(10)
         , @c_Sourcekey          NVARCHAR(10)
         , @c_SourceLineNo       NVARCHAR(5)
         , @c_Facility           NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_SKU                NVARCHAR(20)
         , @c_Channel            NVARCHAR(20)
         , @c_C_Attribute01      NVARCHAR(30)
         , @c_C_Attribute02      NVARCHAR(30)
         , @c_C_Attribute03      NVARCHAR(30)
         , @c_C_Attribute04      NVARCHAR(30)
         , @c_C_Attribute05      NVARCHAR(30)
         , @n_Channel_ID         BIGINT
         , @c_Hold               NVARCHAR(1)
         , @c_Remarks            NVARCHAR(255)
         , @n_Qty                INT
         , @c_HoldTRFType        NVARCHAR(10) = N''
         , @n_DelQty             INT          = 0
         , @n_QtyHoldToAdj       INT          = 0

         , @n_ChannelTran_ID_Ref BIGINT = 0           
         , @n_InvHoldKey         BIGINT = 0


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

   SET @n_Continue = 1

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF @c_InParm1 = '1'
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , HoldType
           , Sourcekey
           , SourceLineNo
           , Facility
           , Storerkey
           , SKU
           , Channel
           , C_Attribute01
           , C_Attribute02
           , C_Attribute03
           , C_Attribute04
           , C_Attribute05
           , Channel_ID
           , Hold
           , Remarks
           , Qty
      FROM dbo.SCE_DL_CHANNELINVHOLD_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo 
      AND STG_Status = '1'

      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP
      INTO @n_RowRefNo
         , @c_HoldType
         , @c_Sourcekey
         , @c_SourceLineNo
         , @c_Facility
         , @c_Storerkey
         , @c_SKU
         , @c_Channel
         , @c_C_Attribute01
         , @c_C_Attribute02
         , @c_C_Attribute03
         , @c_C_Attribute04
         , @c_C_Attribute05
         , @n_Channel_ID
         , @c_Hold
         , @c_Remarks
         , @n_Qty

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_HoldTRFType = N''
         SET @n_DelQty = 0
         SET @n_QtyHoldToAdj = 0
         SET @n_InvHoldKey = 0

         IF @c_HoldType = 'TRF'
         BEGIN
            SET @c_HoldTRFType = N'F'
            SET @n_DelQty = @n_Qty
         END

         IF @c_HoldType = 'TRANHOLD'
         BEGIN
            SET @n_QtyHoldToAdj = @n_Qty
         END

         IF @@TRANCOUNT = 0
            BEGIN TRAN

         EXEC dbo.isp_ChannelInvHoldWrapper
              @c_HoldType           = @c_HoldType
            , @c_SourceKey          = @c_SourceKey
            , @c_SourceLineNo       = @c_SourceLineNo
            , @c_Facility           = @c_Facility
            , @c_Storerkey          = @c_Storerkey
            , @c_Sku                = @c_Sku
            , @c_Channel            = @c_Channel
            , @c_C_Attribute01      = @c_C_Attribute01
            , @c_C_Attribute02      = @c_C_Attribute02
            , @c_C_Attribute03      = @c_C_Attribute03
            , @c_C_Attribute04      = @c_C_Attribute04
            , @c_C_Attribute05      = @c_C_Attribute05
            , @n_Channel_ID         = @n_Channel_ID
            , @c_Hold               = @c_Hold
            , @c_Remarks            = @c_Remarks
            , @c_HoldTRFType        = @c_HoldTRFType
            , @n_DelQty             = @n_DelQty
            , @n_QtyHoldToAdj       = @n_QtyHoldToAdj
            , @n_ChannelTran_ID_Ref = @n_ChannelTran_ID_Ref OUTPUT
            , @b_Success            = @b_Success            OUTPUT
            , @n_Err                = @n_ErrNo              OUTPUT
            , @c_ErrMsg             = @c_ErrMsg             OUTPUT
            , @n_InvHoldKey         = @n_InvHoldKey         OUTPUT

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         WHILE @@TRANCOUNT > 0 
         BEGIN
            COMMIT TRAN
         END

         IF @@TRANCOUNT = 0
            BEGIN TRAN

         UPDATE dbo.SCE_DL_CHANNELINVHOLD_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo  
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT 
         END

         WHILE @@TRANCOUNT > 0 
         BEGIN
            COMMIT TRAN
         END

         FETCH NEXT FROM CUR_LOOP
         INTO @n_RowRefNo
            , @c_HoldType
            , @c_Sourcekey
            , @c_SourceLineNo
            , @c_Facility
            , @c_Storerkey
            , @c_SKU
            , @c_Channel
            , @c_C_Attribute01
            , @c_C_Attribute02
            , @c_C_Attribute03
            , @c_C_Attribute04
            , @c_C_Attribute05
            , @n_Channel_ID
            , @c_Hold
            , @c_Remarks
            , @n_Qty
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_200001_10] EXIT... ErrMsg : '
             + ISNULL(TRIM(@c_ErrMsg), '')
   END

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_ErrNo, @c_ErrMsg, 'isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_200001_10'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   REVERT
END
GO