SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_INVMOVES_RULES_200001_10        */
/* Creation Date: 05-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20470 - Perform Inventory Moves                         */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Active Flag                                 */
/*         @c_InParm2 = '1' Convert SKU to Uppercase                    */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 05-Sep-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_INVMOVES_RULES_200001_10] (
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

   DECLARE @c_Storerkey    NVARCHAR(15)
         , @c_SKU          NVARCHAR(20)
         , @c_Lot          NVARCHAR(10)
         , @c_FromLoc      NVARCHAR(10)
         , @c_FromID       NVARCHAR(18)
         , @c_ToLoc        NVARCHAR(10)
         , @c_ToID         NVARCHAR(18)
         , @c_Lottable01   NVARCHAR(18)
         , @c_Lottable02   NVARCHAR(18)
         , @c_Lottable03   NVARCHAR(18)
         , @dt_Lottable04  DATETIME
         , @dt_Lottable05  DATETIME
         , @c_Lottable06   NVARCHAR(30)
         , @c_Lottable07   NVARCHAR(30)
         , @c_Lottable08   NVARCHAR(30)
         , @c_Lottable09   NVARCHAR(30)
         , @c_Lottable10   NVARCHAR(30)
         , @c_Lottable11   NVARCHAR(30)
         , @c_Lottable12   NVARCHAR(30)
         , @dt_Lottable13  DATETIME
         , @dt_Lottable14  DATETIME
         , @dt_Lottable15  DATETIME
         , @c_ToPackkey    NVARCHAR(10)
         , @c_ToUOM        NVARCHAR(10)
         , @c_ttlMsg       NVARCHAR(250)
         , @n_RowRefNo     INT
         , @n_ToQty        INT

   DECLARE @c_itrnkey      NVARCHAR(10)
         , @n_Channel_ID   BIGINT

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

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   IF @@TRANCOUNT = 0
      BEGIN TRANSACTION

   IF @c_InParm1 = '1'
   BEGIN
      DECLARE C_MOVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ISNULL(TRIM(Storerkey ), '') 
                    , ISNULL(TRIM(SKU       ), '') 
                    , ISNULL(TRIM(Lot       ), '') 
                    , ISNULL(TRIM(Loc   ), '') 
                    , ISNULL(TRIM(MovableUnit    ), '') 
                    , ISNULL(TRIM(ToLoc     ), '') 
                    , ISNULL(TRIM(ToID      ), '') 
                    , ISNULL(TRIM(Lottable01), '') 
                    , ISNULL(TRIM(Lottable02), '') 
                    , ISNULL(TRIM(Lottable03), '') 
                    , Lottable04
                    , Lottable05
                    , ISNULL(TRIM(Lottable06), '') 
                    , ISNULL(TRIM(Lottable07), '') 
                    , ISNULL(TRIM(Lottable08), '') 
                    , ISNULL(TRIM(Lottable09), '') 
                    , ISNULL(TRIM(Lottable10), '') 
                    , ISNULL(TRIM(Lottable11), '') 
                    , ISNULL(TRIM(Lottable12), '') 
                    , Lottable13
                    , Lottable14 
                    , Lottable15
                    , ISNULL(TRIM(ToPackkey ), '') 
                    , ISNULL(TRIM(ToUOM     ), '') 
                    , ISNULL(ToQty, 0)
      FROM dbo.SCE_DL_INVMOVES_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'

      OPEN C_MOVE

      FETCH NEXT FROM C_MOVE INTO @c_Storerkey, @c_SKU, @c_Lot, @c_FromLoc, @c_FromID, @c_ToLoc, @c_ToID       
                                , @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05
                                , @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10 
                                , @c_Lottable11, @c_Lottable12, @dt_Lottable13, @dt_Lottable14, @dt_Lottable15
                                , @c_ToPackkey, @c_ToUOM, @n_ToQty  

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT TOP (1) @n_RowRefNo = RowRefNo
         FROM dbo.SCE_DL_INVMOVES_STG WITH (NOLOCK)
         WHERE STG_BatchNo                   = @n_BatchNo
         AND   STG_Status                    = '1'
         AND   ISNULL(TRIM(Storerkey  ), '')  = @c_Storerkey   
         AND   ISNULL(TRIM(SKU        ), '')  = @c_SKU         
         AND   ISNULL(TRIM(Lot        ), '')  = @c_Lot         
         AND   ISNULL(TRIM(Loc        ), '')  = @c_FromLoc     
         AND   ISNULL(TRIM(MovableUnit), '')  = @c_FromID      
         AND   ISNULL(TRIM(ToLoc      ), '')  = @c_ToLoc       
         AND   ISNULL(TRIM(ToID       ), '')  = @c_ToID        
         AND   ISNULL(TRIM(Lottable01 ), '')  = @c_Lottable01  
         AND   ISNULL(TRIM(Lottable02 ), '')  = @c_Lottable02  
         AND   ISNULL(TRIM(Lottable03 ), '')  = @c_Lottable03  
         AND   Lottable04  = @dt_Lottable04 
         AND   Lottable05  = @dt_Lottable05 
         AND   ISNULL(TRIM(Lottable06 ), '')  = @c_Lottable06  
         AND   ISNULL(TRIM(Lottable07 ), '')  = @c_Lottable07  
         AND   ISNULL(TRIM(Lottable08 ), '')  = @c_Lottable08  
         AND   ISNULL(TRIM(Lottable09 ), '')  = @c_Lottable09  
         AND   ISNULL(TRIM(Lottable10 ), '')  = @c_Lottable10  
         AND   ISNULL(TRIM(Lottable11 ), '')  = @c_Lottable11  
         AND   ISNULL(TRIM(Lottable12 ), '')  = @c_Lottable12  
         AND   Lottable13  = @dt_Lottable13 
         AND   Lottable14  = @dt_Lottable14 
         AND   Lottable15  = @dt_Lottable15 
         AND   ISNULL(TRIM(ToPackkey  ), '')  = @c_ToPackkey   
         AND   ISNULL(TRIM(ToUOM      ), '')  = @c_ToUOM   
         AND   ToQty                          = @n_ToQty
         ORDER BY STG_SeqNo ASC

         IF @c_InParm2 = '1' 
            SET @c_SKU = UPPER(TRIM(@c_SKU))

         EXEC dbo.nspItrnAddMove 
              @n_ItrnSysId = 0                         
            , @c_StorerKey = @c_Storerkey                       
            , @c_Sku = @c_SKU           
            , @c_Lot = @c_Lot                            
            , @c_FromLoc = @c_FromLoc                        
            , @c_FromID = @c_FromID                         
            , @c_ToLoc = @c_ToLoc                          
            , @c_ToID = @c_ToID                           
            , @c_Status = N'0'                          
            , @c_lottable01 = @c_Lottable01  
            , @c_lottable02 = @c_Lottable02  
            , @c_lottable03 = @c_Lottable03  
            , @d_lottable04 = @dt_Lottable04 
            , @d_lottable05 = @dt_Lottable05 
            , @c_lottable06 = @c_Lottable06  
            , @c_lottable07 = @c_Lottable07  
            , @c_lottable08 = @c_Lottable08  
            , @c_lottable09 = @c_Lottable09  
            , @c_lottable10 = @c_Lottable10  
            , @c_lottable11 = @c_Lottable11  
            , @c_lottable12 = @c_Lottable12  
            , @d_lottable13 = @dt_Lottable13  
            , @d_lottable14 = @dt_Lottable14 
            , @d_lottable15 = @dt_Lottable15 
            , @n_casecnt = 0                           
            , @n_innerpack = 0                         
            , @n_qty = @n_ToQty                              
            , @n_pallet = 0                            
            , @f_cube = 0.0                            
            , @f_grosswgt = 0.0                        
            , @f_netwgt = 0.0                          
            , @f_otherunit1 = 0.0                      
            , @f_otherunit2 = 0.0                      
            , @c_SourceKey = N''                       
            , @c_SourceType = N'SCE_DL_INVMOVES'                      
            , @c_PackKey = @c_ToPackkey                        
            , @c_UOM = @c_ToUOM                 
            , @b_UOMCalc = 0                           
            , @d_EffectiveDate = NULL
            , @c_itrnkey = @c_itrnkey OUTPUT           
            , @b_Success = @b_Success OUTPUT           
            , @n_err = @n_ErrNo OUTPUT                   
            , @c_errmsg = @c_ErrMsg OUTPUT             
            , @c_MoveRefKey = N''                      
            , @c_Channel = N''                         
            , @n_Channel_ID = @n_Channel_ID OUTPUT     

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         UPDATE dbo.SCE_DL_INVMOVES_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         FETCH NEXT FROM C_MOVE INTO @c_Storerkey, @c_SKU, @c_Lot, @c_FromLoc, @c_FromID, @c_ToLoc, @c_ToID       
                                   , @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05
                                   , @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10 
                                   , @c_Lottable11, @c_Lottable12, @dt_Lottable13, @dt_Lottable14, @dt_Lottable15
                                   , @c_ToPackkey, @c_ToUOM, @n_ToQty  
      END

      CLOSE C_MOVE
      DEALLOCATE C_MOVE

      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_INVMOVES_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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