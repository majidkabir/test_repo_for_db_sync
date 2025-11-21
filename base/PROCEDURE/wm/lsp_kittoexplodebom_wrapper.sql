SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: WM.lsp_KitToExplodeBOM_Wrapper                      */  
/* Creation Date: 16-OCT-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-1281 - Stored Procedures for Kitting functionalities    */
/*        :                                                              */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */                                                                                  
/*                                                                       */                                                                                  
/* Version: 8.0                                                          */                                                                                  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2020-11-16  Wan01    1.1   LFWM-2329 - UAT - TW  Detail list in Kitting*/
/*                            does not refresh and generated records not */
/*                            able to display from front end after Explode*/
/*                            BOM                                        */
/* 2020-12-18  Wan02    1.1   Add Big Outer Begin Try..End Try to enable */
/*                            Revert when SP Raise error                 */
/* 2021-01-15  Wan03    1.2   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2023-04-20  BeeTin   1.3   JSM-131854 - Extended @c_id length         */    
/*                            to NVARCHAR(36)                            */   
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_KitToExplodeBOM_Wrapper]  
   @c_KITKey               NVARCHAR(10)
,  @b_Success              INT          = 1  OUTPUT   
,  @n_Err                  INT          = 0  OUTPUT
,  @c_Errmsg               NVARCHAR(255)= '' OUTPUT
,  @n_WarningNo            INT          = 0  OUTPUT
,  @c_ProceedWithWarning   CHAR(1)      = 'N' 
,  @c_UserName             NVARCHAR(128)= ''
,  @n_ErrGroupKey          INT          = 0  OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT

   DECLARE @c_TableName          NVARCHAR(50)   = 'KITDETAIL'
         , @c_SourceType         NVARCHAR(50)   = 'lsp_KitToExplodeBOM_Wrapper'
         , @c_KitType            NVARCHAR(10)   = 'T' 
         , @c_KitToType          NVARCHAR(10)   = 'F' 
              
         , @c_Facility           NVARCHAR(5)    = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_kitLineNumber      NVARCHAR(20)   = ''
         , @c_Sku                NVARCHAR(20)   = ''
         , @c_Lot                NVARCHAR(10)   = ''
         , @c_Loc                NVARCHAR(10)   = ''
         --, @c_ID                 NVARCHAR(10)   = ''    
         , @c_ID                 NVARCHAR(36)   = ''  --JSM-131854   
         , @c_Lottable01         NVARCHAR(18)   = ''         
         , @c_Lottable02         NVARCHAR(18)   = ''         
         , @c_Lottable03         NVARCHAR(18)   = ''         
         , @dt_Lottable04        DATETIME                  
         , @dt_Lottable05        DATETIME            
         , @c_Lottable06         NVARCHAR(30)   = ''         
         , @c_Lottable07         NVARCHAR(30)   = ''         
         , @c_Lottable08         NVARCHAR(30)   = ''         
         , @c_Lottable09         NVARCHAR(30)   = ''         
         , @c_Lottable10         NVARCHAR(30)   = ''         
         , @c_Lottable11         NVARCHAR(30)   = ''         
         , @c_Lottable12         NVARCHAR(30)   = ''         
         , @dt_Lottable13        DATETIME              
         , @dt_Lottable14        DATETIME          
         , @dt_Lottable15        DATETIME        
         , @n_ExpectedQty        INT            = 0

         , @c_Packkey            NVARCHAR(10)   = ''
         , @c_UOM                NVARCHAR(10)   = ''

         , @c_KitToLineNo        NVARCHAR(5)    = ''
         , @n_KitToQty           INT            = 0


         , @c_ComponentSku       NVARCHAR(20)   = ''
         , @n_ComponentQty       INT            = 0
         , @n_ParentQty          INT            = 0

         , @n_QtyAvailable       INT            = 0
         , @n_RemainQty          INT            = 0

         , @n_LineCnt            INT            = 0
         , @n_Count              INT            = 0
         , @n_EmptyComponentSku  INT            = 0
         , @n_InvalidKitQty      INT            = 0

         , @CUR_KITTO            CURSOR
         , @CUR_BOM              CURSOR
         , @CUR_INV              CURSOR

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_ErrGroupKey = 0

   SET @n_Err = 0 
   
   IF SUSER_SNAME() <> @c_UserName       --(Wan03) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                   --(Wan03) - END
   
   BEGIN TRY   --(Wan01) --2020-12-18
  	
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo  < 1
      BEGIN
         -------------------
         -- Validation Start
         -------------------
         SET @c_Facility = ''
         SELECT @c_Facility = K.Facility
         FROM KIT  K WITH (NOLOCK) 
         WHERE K.KitKey = @c_KitKey 

         IF @c_Facility = ''
         BEGIN
            SET @n_continue = 3   
            SET @n_err = 554651
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                           + ': Facility Cannot Be BLANK. (lsp_KitToExplodeBOM_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_Kitkey
               ,  @c_Refkey2     = @c_Sku
               ,  @c_Refkey3     = @c_KitType
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT
         END

         SET @n_Count = 0
         SET @n_ExpectedQty = 0
         SET @c_Sku = ''
         SELECT @n_Count = COUNT(1)
               ,@c_Storerkey = KD.Storerkey
               ,@c_Sku = ISNULL(MIN(KD.Sku),'')
               ,@n_ExpectedQty = ISNULL(MIN(KD.ExpectedQty),0)
         FROM KITDETAIL KD WITH (NOLOCK)
         WHERE KD.KitKey = @c_KitKey
         AND KD.[Type] = @c_KitType
         GROUP BY KD.Storerkey

         IF @n_Count > 1
         BEGIN
            SET @n_continue = 3   
            SET @n_err = 554652
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                          + ': Only One to Many Explode is Allowed!. (lsp_KitToExplodeBOM_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_Kitkey
               ,  @c_Refkey2     = @c_Sku
               ,  @c_Refkey3     = @c_KitType
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT
         END

         IF @n_Count = 1 
         BEGIN
            IF @c_Sku = ''
            BEGIN
               SET @n_continue = 3   
               SET @n_err = 554653
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                              + ': Sku is required. (lsp_KitToExplodeBOM_Wrapper)'

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Kitkey
                  ,  @c_Refkey2     = @c_Sku
                  ,  @c_Refkey3     = @c_KitType
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT
            END
            ELSE 
            BEGIN
               SET @n_Count = 0
               SET @n_EmptyComponentSku = 0
               SET @n_InvalidKitQty = 0
               SELECT @n_Count = COUNT(1)
                     ,@n_EmptyComponentSku = ISNULL(SUM(CASE WHEN BOM.ComponentSku IS NULL OR BOM.ComponentSku = '' THEN 1 ELSE 0 END),0)
                     ,@n_InvalidKitQty = ISNULL(SUM(CASE WHEN (BOM.Qty * @n_ExpectedQty / BOM.ParentQty) <= 0 THEN 1 ELSE 0 END),0)
               FROM BILLOFMATERIAL BOM WITH (NOLOCK)
               WHERE BOM.Storerkey = @c_Storerkey
               AND   BOM.Sku = @c_Sku
       
               IF @n_Count = 0
               BEGIN
                  SET @n_continue = 3   
                  SET @n_err = 554654
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                 + ': Sku Not Found in BOM. Enter Detail lines Manually. (lsp_KitToExplodeBOM_Wrapper)'

                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_Kitkey
                     ,  @c_Refkey2     = @c_Sku
                     ,  @c_Refkey3     = @c_KitType
                     ,  @n_err2        = @n_err
                     ,  @c_errmsg2     = @c_errmsg
                     ,  @b_Success     = @b_Success   OUTPUT
                     ,  @n_err         = @n_err       OUTPUT
                     ,  @c_errmsg      = @c_errmsg    OUTPUT
               END
               ELSE
               BEGIN
                  IF @n_EmptyComponentSku > 0
                  BEGIN
                     SET @n_continue = 3   
                     SET @n_err = 554655
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                    + ': Component Sku is Blank. Please check the setup in BOM. (lsp_KitToExplodeBOM_Wrapper)'

                     EXEC [WM].[lsp_WriteError_List] 
                           @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                        ,  @c_TableName   = @c_TableName
                        ,  @c_SourceType  = @c_SourceType
                        ,  @c_Refkey1     = @c_Kitkey
                        ,  @c_Refkey2     = @c_Sku
                        ,  @c_Refkey3     = @c_KitType
                        ,  @n_err2        = @n_err
                        ,  @c_errmsg2     = @c_errmsg
                        ,  @b_Success     = @b_Success   OUTPUT
                        ,  @n_err         = @n_err       OUTPUT
                        ,  @c_errmsg      = @c_errmsg    OUTPUT
                  END
                  ELSE
                  BEGIN
                     IF @n_InvalidKitQty = 0 
                     BEGIN
                        SET @n_Count = 0
                        SELECT @n_Count = 1
                        FROM BILLOFMATERIAL BOM WITH (NOLOCK)
                        JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (BOM.Storerkey = LLI.Storerkey)
                                                          AND(BOM.ComponentSku = LLI.Sku)
                        JOIN LOT        LOT WITH (NOLOCK) ON (LLI.Lot = LOT.Lot) AND (LOT.[Status] <> 'HOLD')
                        JOIN LOC        L   WITH (NOLOCK) ON (LLI.Loc = L.Loc AND L.Facility = @c_Facility 
                                                          AND L.[Status] <> 'HOLD' AND L.LocationFlag NOT IN ('DAMAGE', 'HOLD'))
                        JOIN ID         ID  WITH (NOLOCK) ON (LLI.ID = ID.ID) AND (ID.[Status] <> 'HOLD')
                        WHERE BOM.Storerkey = @c_Storerkey
                        AND   BOM.Sku = @c_Sku
                        AND   LLI.Qty > LLI.QtyAllocated + LLI.QtyPicked
                        GROUP BY BOM.Storerkey    
                              ,  BOM.ComponentSku
                              ,  BOM.ParentQty
                              ,  BOM.Qty
                        HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) < (BOM.Qty * @n_ExpectedQty) / BOM.ParentQty

                        IF @n_Count > 0
                        BEGIN
                           SET @n_continue = 3   
                           SET @n_err = 554656
                           SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                          + ': Insufficient ComponentSku Qty. Enter Kit From detail Line manually. (lsp_KitToExplodeBOM_Wrapper)'

                           EXEC [WM].[lsp_WriteError_List] 
                                 @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                              ,  @c_TableName   = @c_TableName
                              ,  @c_SourceType  = @c_SourceType
                              ,  @c_Refkey1     = @c_Kitkey
                              ,  @c_Refkey2     = @c_Sku
                              ,  @c_Refkey3     = @c_KitType
                              ,  @n_err2        = @n_err
                              ,  @c_errmsg2     = @c_errmsg
                              ,  @b_Success     = @b_Success   OUTPUT
                              ,  @n_err         = @n_err       OUTPUT
                              ,  @c_errmsg      = @c_errmsg    OUTPUT
                        END 
                     END
                  END
               END
            END

            IF @n_ExpectedQty <= 0
            BEGIN
               SET @n_continue = 3   
               SET @n_err = 554657
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                              + ': Invalid Kit To Expected Qty. (lsp_KitToExplodeBOM_Wrapper)'

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Kitkey
                  ,  @c_Refkey2     = @c_Sku
                  ,  @c_Refkey3     = @c_KitType
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT

            END
            ELSE
            BEGIN
               IF @n_InvalidKitQty > 0 
               BEGIN
                  SET @n_continue = 3   
                  SET @n_err = 554658
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                 + ': Invalid Kit To Expected Qty to form Component Qty. (lsp_KitToExplodeBOM_Wrapper)'

                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_Kitkey
                     ,  @c_Refkey2     = @c_Sku
                     ,  @c_Refkey3     = @c_KitType
                     ,  @n_err2        = @n_err
                     ,  @c_errmsg2     = @c_errmsg
                     ,  @b_Success     = @b_Success   OUTPUT
                     ,  @n_err         = @n_err       OUTPUT
                     ,  @c_errmsg      = @c_errmsg    OUTPUT
               END
            END

         END

         IF @n_continue = 3   
         BEGIN
            GOTO EXIT_SP
         END
      END
      -------------------
      -- Validation End
      -------------------

      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Do You Want To Continue Explode BOM?'

         GOTO EXIT_SP
      END

      IF @c_ProceedWithWarning = 'Y' AND @n_WarningNo < 2
      BEGIN
         SET @n_Count = 0
         SELECT @n_Count = COUNT(1)
         FROM KITDETAIL KD WITH (NOLOCK)
         WHERE KD.KitKey = @c_KitKey
         AND KD.[Type] = @c_KitToType

         IF @n_Count > 0
         BEGIN
            SET @n_WarningNo = 2
            SET @c_ErrMsg = 'Delete Record(s) from ''TO'' Detail?'

            GOTO EXIT_SP
         END
      END

      -------------------
      -- Explode STart
      -------------------
      SET @c_Facility = ''
      SELECT @c_Facility = K.Facility
      FROM KIT  K WITH (NOLOCK) 
      WHERE K.KitKey = @c_KitKey 

      SET @CUR_KITTO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT KD.KITLineNumber
            ,Sku = RTRIM(KD.Sku)
      FROM KITDETAIL KD WITH (NOLOCK)
      WHERE KD.KitKey = @c_KitKey
      AND KD.[Type] = @c_KitToType
      ORDER BY KD.KITLineNumber

      OPEN @CUR_KITTO
   
      FETCH NEXT FROM @CUR_KITTO INTO  @c_KITLineNumber   
                                    ,  @c_Sku 
                                    
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRY
            DELETE FROM KITDETAIL
            WHERE KitKey = @c_KitKey
            AND KitLineNumber = @c_kitLineNumber
            AND [Type] = @c_KitToType
         END TRY

         BEGIN CATCH
            SET @n_continue = 3
            SET @n_err = 554659
            SET @c_ErrMsg   = ERROR_MESSAGE() 
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                           + ': Delete KITDETAIL Table fail. (lsp_KitToExplodeBOM_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
            GOTO EXIT_SP
         END CATCH
 
         FETCH NEXT FROM @CUR_KITTO INTO  @c_KITLineNumber   
                                       ,  @c_Sku 
      END
      CLOSE @CUR_KITTO
      DEALLOCATE @CUR_KITTO

      SET @CUR_BOM = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT BOM.Storerkey
            ,ComponentSku= BOM.componentSku
            ,ComponentQty= BOM.Qty
            ,ParentQty   = BOM.ParentQty
            ,ExpectedQty = KD.ExpectedQty
      FROM KITDETAIL KD WITH (NOLOCK)
      JOIN BILLOFMATERIAL BOM WITH (NOLOCK) ON  (KD.Storerkey = BOM.Storerkey)
                                             AND (KD.Sku = BOM.Sku)
      WHERE KD.KitKey = @c_KitKey
      AND KD.[Type] = @c_KitType
      ORDER BY KD.KITLineNumber

      OPEN @CUR_BOM
      FETCH NEXT FROM @CUR_BOM INTO @c_Storerkey
                                 ,  @c_ComponentSku 
                                 ,  @n_ComponentQty
                                 ,  @n_ParentQty
                                 ,  @n_ExpectedQty
   
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_KitToQty = 0
         SET @n_RemainQty = (@n_ComponentQty * @n_ExpectedQty) / @n_ParentQty

         SET @c_Packkey = ''
         SET @c_UOM = ''
         SELECT @c_Packkey = P.Packkey
               ,@c_UOM     = P.PackUOM3
         FROM SKU S WITH (NOLOCK)
         JOIN PACK P WITH (NOLOCK) ON (S.Packkey = P.Packkey)
         WHERE S.Storerkey = @c_Storerkey
         AND S.Sku = @c_ComponentSku 

         SET @CUR_INV = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT 
               Lot = LLI.Lot
            ,  Loc = LLI.Loc
            ,  ID = LLI.ID
            ,  QtyAvailable = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked
            ,  Lottable01   = Lottable01  
            ,  Lottable02   = Lottable02  
            ,  Lottable03   = Lottable03  
            ,  Lottable04   = Lottable04  
            ,  Lottable05   = Lottable05  
            ,  Lottable06   = Lottable06  
            ,  Lottable07   = Lottable07  
            ,  Lottable08   = Lottable08  
            ,  Lottable09   = Lottable09  
            ,  Lottable10   = Lottable10  
            ,  Lottable11   = Lottable11  
            ,  Lottable12   = Lottable12 
            ,  Lottable13   = Lottable13  
            ,  Lottable14   = Lottable14 
            ,  Lottable15   = Lottable15 
         FROM LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN LOT        LOT WITH (NOLOCK) ON (LLI.Lot = LOT.Lot) AND (LOT.[Status] <> 'HOLD')
         JOIN LOC        L   WITH (NOLOCK) ON (LLI.Loc = L.Loc AND L.Facility = @c_Facility 
                                           AND L.[Status] <> 'HOLD' AND L.LocationFlag NOT IN ('DAMAGE', 'HOLD'))
         JOIN ID         ID  WITH (NOLOCK) ON (LLI.ID = ID.ID) AND (ID.[Status] <> 'HOLD')
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
         WHERE LLI.Storerkey = @c_Storerkey
         AND   LLI.Sku = @c_ComponentSku
         AND   LLI.Qty > LLI.QtyAllocated + LLI.QtyPicked
         ORDER BY LA.Lottable04
               ,  LA.Lottable05


         OPEN @CUR_INV
         FETCH NEXT FROM @CUR_INV INTO @c_Lot 
                                    ,  @c_Loc 
                                    ,  @c_ID  
                                    ,  @n_QtyAvailable 
                                    ,  @c_Lottable01      
                                    ,  @c_Lottable02    
                                    ,  @c_Lottable03    
                                    ,  @dt_Lottable04   
                                    ,  @dt_Lottable05  
                                    ,  @c_Lottable06    
                                    ,  @c_Lottable07    
                                    ,  @c_Lottable08     
                                    ,  @c_Lottable09      
                                    ,  @c_Lottable10     
                                    ,  @c_Lottable11   
                                    ,  @c_Lottable12    
                                    ,  @dt_Lottable13  
                                    ,  @dt_Lottable14   
                                    ,  @dt_Lottable15  
   
         WHILE @@FETCH_STATUS <> -1 AND @n_RemainQty > 0
         BEGIN
            IF @n_RemainQty < @n_QtyAvailable
            BEGIN
               SET @n_KitToQty = @n_RemainQty
            END
            ELSE
            BEGIN
               SET @n_KitToQty = @n_QtyAvailable
            END

            SET @n_RemainQty = @n_RemainQty - @n_KitToQty

            IF @n_KitToQty > 0
            BEGIN
               SET @n_LineCnt = @n_LineCnt + 1
     
               SET @c_KitToLineNo = RIGHT( '00000' + CONVERT(VARCHAR(5), @n_LineCnt) ,5)

               BEGIN TRY
                  INSERT INTO KITDETAIL
                     (  KitKey
                     ,  KitLineNumber
                     ,  [Type] 
                     ,  Storerkey
                     ,  Sku
                     ,  Packkey
                     ,  UOM
                     ,  ExpectedQty
                     ,  Lot
                     ,  Loc
                     ,  ID
                     ,  Lottable01     
                     ,  Lottable02     
                     ,  Lottable03     
                     ,  Lottable04     
                     ,  Lottable05     
                     ,  Lottable06     
                     ,  Lottable07     
                     ,  Lottable08     
                     ,  Lottable09     
                     ,  Lottable10     
                     ,  Lottable11     
                     ,  Lottable12     
                     ,  Lottable13     
                     ,  Lottable14     
                     ,  Lottable15  
                     )
                  VALUES
                     (  @c_KitKey
                     ,  @c_KitToLineNo
                     ,  @c_KitToType
                     ,  @c_Storerkey
                     ,  @c_ComponentSku            --(Wan01)
                     ,  @c_Packkey
                     ,  @c_UOM
                     ,  @n_KitToQty
                     ,  @c_Lot
                     ,  @c_Loc
                     ,  @c_ID
                     ,  @c_Lottable01     
                     ,  @c_Lottable02     
                     ,  @c_Lottable03     
                     ,  @dt_Lottable04     
                     ,  @dt_Lottable05     
                     ,  @c_Lottable06     
                     ,  @c_Lottable07     
                     ,  @c_Lottable08     
                     ,  @c_Lottable09     
                     ,  @c_Lottable10     
                     ,  @c_Lottable11     
                     ,  @c_Lottable12     
                     ,  @dt_Lottable13     
                     ,  @dt_Lottable14     
                     ,  @dt_Lottable15 
                     ) 
               END TRY

               BEGIN CATCH
                  SET @n_continue = 3
                  SET @n_err = 554660
                  SET @c_ErrMsg   = ERROR_MESSAGE()    
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                 + ': Insert KITDETAIL Fail. (lsp_KitToExplodeBOM_Wrapper)'
                                 + ' (' + @c_ErrMsg + ')'
                  GOTO EXIT_SP
               END CATCH
            END

            FETCH NEXT FROM @CUR_INV INTO @c_Lot 
                                       ,  @c_Loc 
                                       ,  @c_ID  
                                       ,  @n_QtyAvailable 
                                       ,  @c_Lottable01      
                                       ,  @c_Lottable02    
                                       ,  @c_Lottable03    
                                       ,  @dt_Lottable04   
                                       ,  @dt_Lottable05  
                                       ,  @c_Lottable06    
                                       ,  @c_Lottable07    
                                       ,  @c_Lottable08     
                                       ,  @c_Lottable09      
                                       ,  @c_Lottable10     
                                       ,  @c_Lottable11   
                                       ,  @c_Lottable12    
                                       ,  @dt_Lottable13  
                                       ,  @dt_Lottable14   
                                       ,  @dt_Lottable15  
         END
         CLOSE @CUR_INV
         DEALLOCATE @CUR_INV

         IF @n_RemainQty > 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err = 554661
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                           + ': Insufficient ComponentSku Qty. Explode BOM fail. (lsp_KitToExplodeBOM_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_Kitkey
               ,  @c_Refkey2     = @c_ComponentSku
               ,  @c_Refkey3     = @c_KitToType
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT
         END

         FETCH NEXT FROM @CUR_BOM INTO @c_Storerkey
                                    ,  @c_ComponentSku 
                                    ,  @n_ComponentQty
                                    ,  @n_ParentQty
                                    ,  @n_ExpectedQty
  
      END
      CLOSE @CUR_BOM
      DEALLOCATE @CUR_BOM 

      -------------------
      -- Explode End
      -------------------
   END TRY
   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Explode BOM for Kitto fail. (lsp_KitToExplodeBOM_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH   --(Wan01) - 2020-12-18
               --   
   EXIT_SP:
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_KitToExplodeBOM_Wrapper'
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