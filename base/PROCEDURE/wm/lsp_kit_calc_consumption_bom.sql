SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: lsp_Kit_Calc_Consumption_BOM                        */  
/* Creation Date: 28-FEB-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.2                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                     */
/* 15-Jan-2021 Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 31-Jan-2023 Wan02    1.2   LFWM-3911 - CN-SCE-Kitting-CalculateConsumptionbyBOM*/
/*                            DevOps Combine Script                      */
/* 21-Jul-2023 NJOW01   1.3   WMS-23149 - allow update consumption by    */
/*                            matching kitlineno to externlineno         */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_Kit_Calc_Consumption_BOM]  (
   @c_StorerKey      NVARCHAR(15), 
   @c_KitKey         NVARCHAR(10),
   @c_KitLineNumber  NVARCHAR(5),
   @c_Type           NVARCHAR(5), 
   --@c_DeletePrevious CHAR(1) = 'Y',                                                              --(Wan02) - Not need
   @b_Success        int = 1 OUTPUT,
   @n_Err            int = 0 OUTPUT,
   @c_Errmsg         NVARCHAR(250) = '' OUTPUT,
   @c_UserName       NVARCHAR(128)  = '' )
AS  
BEGIN  
   --SET ANSI_NULLS ON                                                                             --(Wan02) - START
   --SET ANSI_PADDING ON
   --SET ANSI_WARNINGS ON
   --SET QUOTED_IDENTIFIER ON
   --SET CONCAT_NULL_YIELDS_NULL ON
   --SET ARITHABORT ON
   SET NOCOUNT ON                                                                                                                                                          
   SET ANSI_NULLS OFF                                                                                                                                                      
   SET QUOTED_IDENTIFIER OFF                                                                                                                                               
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                 --(Wan02) - END

   DECLARE @n_Continue                   INT = '1'         
         , @n_Count                      INT = 0 
         , @c_ComponentSku               NVARCHAR(20) = '' 
         , @n_ComponentQty               INT = 0 
         , @n_ParentQty                  INT = 0 
         , @n_Remainder                  INT = 0
         , @n_BOMQty                     INT = 0  
         , @c_NewKitLineNo               NVARCHAR(5)  = ''
         , @c_PackKey                    NVARCHAR(10) = ''
         , @c_UOM                        NVARCHAR(10) = ''         
         , @c_ToType                     NVARCHAR(10) = ''                                        --(Wan02) - START 
         , @c_ToKitLineNumber            NVARCHAR(5)   --NJOW01    
         , @c_Facility                   NVARCHAR(5)   --NJOW01  
         , @c_KitCalConsumBOMByLineMatch NVARCHAR(30)=''  --NJOW01
         
   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName       --(Wan01) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
   
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName 
   END                                   --(Wan01) - END
   
   BEGIN TRY -- SWT01 - Begin Outer Begin Try
   
      DECLARE @c_FromSKU         NVARCHAR(20) = '',
              @c_ToSKU           NVARCHAR(20) = '',  
              @n_FromExpectedQty INT = 0,
              @n_FromCompleteQty INT = 0,
              @n_ToExpectedQty   INT = 0,
              @n_ToCompleteQty   INT = 0,
              @n_RemainingQty    INT = 0
              --@n_ShortQty        INT = 0 
              
      SET @c_ToType = IIF(@c_Type = 'T', 'F', 'T')                                                 --(Wan02)                           
              
      SELECT @c_StorerKey = KD.StorerKey, 
             @c_FromSKU   = KD.Sku,
             @n_FromExpectedQty = KD.ExpectedQty,
             @n_FromCompleteQty = KD.Qty,
             @c_Facility = K.Facility --NJOW01
      FROM KIT AS K WITH (NOLOCK)
      JOIN KITDETAIL AS KD WITH (NOLOCK) ON K.Kitkey = KD.Kitkey
      WHERE KD.KITKey = @c_KitKey 
      AND   KD.KITLineNumber = @c_KitLineNumber 
      AND   KD.[Type] = @c_Type                                                                    --(Wan02)
   
      IF ISNULL(RTRIM(@c_FromSKU),'') = ''
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 552451 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
               ': SKU Cannot be BLANK (lsp_Kit_Calc_Consumption_BOM)'               
         GOTO EXIT_SP   
      END
   
      IF @n_FromCompleteQty <= 0 
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 552452 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
               ': Completed Qty Cannot Be Blank (lsp_Kit_Calc_Consumption_BOM)'                 
         GOTO EXIT_SP      
      END
   
      IF NOT EXISTS (SELECT 1 FROM KITDETAIL AS k WITH(NOLOCK)
                     WHERE k.KITKey = @c_KitKey 
                     AND   k.[Type] = @c_ToType                                                    --(Wan02)
                     AND   k.[Status] <> '9' )
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 552453 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
               ': To Components record not found (lsp_Kit_Calc_Consumption_BOM)'                
         GOTO EXIT_SP      
      END
   
      IF OBJECT_ID('tempdb..#KIT_BOM_DETAIL') IS NOT NULL 
      BEGIN
         DROP TABLE #KIT_BOM_DETAIL
      END
   
      CREATE TABLE #KIT_BOM_DETAIL (
         KitKey        NVARCHAR(10),
         KitLineNumber NVARCHAR(5), 
         [Type]        NVARCHAR(5), 
         Qty           INT )
         
      SELECT @c_KitCalConsumBOMByLineMatch = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'KitCalConsumBOMByLineMatch')    --NJOW01
         
      DECLARE CUR_COMPONENTS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ComponentSku, Qty 
      FROM BillOfMaterial WITH (NOLOCK)
      WHERE Storerkey = @c_StorerKey 
      AND   Sku = @c_FromSKU                                                                       --(Wan02)
   
      OPEN CUR_COMPONENTS
   
      FETCH FROM CUR_COMPONENTS INTO @c_ComponentSku, @n_ComponentQty 
      
      IF @@FETCH_STATUS = -1                                                                       --(Wan02) - START
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 552455 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
               ': BOM Sku not found (lsp_Kit_Calc_Consumption_BOM)'                
         GOTO EXIT_SP         
      END                                             
      --(Wan02) - END
                                                        
      WHILE @@FETCH_STATUS = 0
      BEGIN   
         SET @n_RemainingQty = @n_ComponentQty * @n_FromCompleteQty
         --SET @n_ShortQty = 0 
                                 
         DECLARE CUR_SOURCE_KITDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT KITLineNumber, ExpectedQty
            FROM KITDETAIL WITH (NOLOCK)
            WHERE KITKey = @c_KitKey 
            AND   [Type] = @c_ToType                                                                  --(Wan02)
            AND   [Status] <> '9' 
            AND   Sku = @c_ComponentSku       
            AND   ExternLineNo = CASE WHEN @c_KitCalConsumBOMByLineMatch = '1' THEN 
                                        @c_KitLineNumber
                                 ELSE ExternLineNo END  
            ORDER BY KITLineNumber   
   
         OPEN CUR_SOURCE_KITDETAIL
   
         FETCH FROM CUR_SOURCE_KITDETAIL INTO @c_ToKitLineNumber, @n_ToExpectedQty
   
         WHILE @@FETCH_STATUS = 0 
         BEGIN         
            IF @n_RemainingQty = 0
               SET @n_ToCompleteQty = 0 --= @n_RemainingQty - @n_ToExpectedQty                           --(Wan02)  --NJOW01
            ELSE 
            --IF (@n_RemainingQty < 0) AND (@n_ToExpectedQty > @n_RemainingQty)   --NJOW01 Removed
            --BEGIN
                --SET @n_ShortQty = @n_ToExpectedQty + @n_RemainingQty  
                --SET @n_ToCompleteQty = @n_ShortQty
            --END
            --ELSE 
            IF @n_RemainingQty > 0
            BEGIN
                IF @n_RemainingQty >= @n_ToExpectedQty
                   SET @n_ToCompleteQty = @n_ToExpectedQty
                ELSE 
                IF @n_RemainingQty < @n_ToExpectedQty
                BEGIN
                   SET @n_ToCompleteQty = @n_RemainingQty
                END
            END
 
            SET @n_RemainingQty = @n_RemainingQty - @n_ToCompleteQty
           
            INSERT INTO #KIT_BOM_DETAIL
            (  KitKey, KitLineNumber, [Type], Qty )
            VALUES
            (
               @c_KitKey,
               @c_ToKitLineNumber,
               @c_ToType,                                                                          --(Wan02)
               @n_ToCompleteQty
            )
            
            FETCH FROM CUR_SOURCE_KITDETAIL INTO @c_ToKitLineNumber, @n_ToExpectedQty 
         END   
         CLOSE CUR_SOURCE_KITDETAIL
         DEALLOCATE CUR_SOURCE_KITDETAIL                              
         
         --IF EXISTS(SELECT 1 FROM #KIT_BOM_DETAIL AS kbd WITH(NOLOCK)
         --          WHERE kbd.Qty < 0 )  --NJOW01 Removed
         IF @n_RemainingQty > 0  --NJOW01
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 552454 
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                  ': Insufficient Qty for Component SKU (lsp_Kit_Calc_Consumption_BOM)'               
            GOTO EXIT_SP         
         END
         --ELSE                                                                                    --(Wan02) - START Move Down
         --BEGIN
         --   UPDATE KITDETAIL WITH (ROWLOCK)
         --      SET Qty = kbd.Qty, EditDate = GETDATE(), EditWho = SUSER_SNAME() 
         --   FROM KITDETAIL 
         --   JOIN #KIT_BOM_DETAIL AS kbd WITH(NOLOCK) ON kbd.KITKey = KITDETAIL.KITKey 
         --         AND kbd.KITLineNumber = KITDETAIL.KITLineNumber 
         --         AND kbd.[Type] = KITDETAIL.[Type]
               
         --END                                                                                     --(Wan02) - END Move Down
      
         FETCH FROM CUR_COMPONENTS INTO @c_ComponentSku, @n_ComponentQty 
      END
   
      CLOSE CUR_COMPONENTS
      DEALLOCATE CUR_COMPONENTS
      
      IF EXISTS (SELECT 1 FROM #KIT_BOM_DETAIL)                                                    --(Wan02) - START
      BEGIN
         UPDATE KITDETAIL WITH (ROWLOCK)
            SET Qty = kbd.Qty, EditDate = GETDATE(), EditWho = SUSER_SNAME() 
         FROM KITDETAIL 
         JOIN #KIT_BOM_DETAIL AS kbd WITH(NOLOCK) ON kbd.KITKey = KITDETAIL.KITKey 
               AND kbd.KITLineNumber = KITDETAIL.KITLineNumber 
               AND kbd.[Type] = KITDETAIL.[Type]
      END                                                                                          --(Wan02) - END
   
   END TRY  
  
   BEGIN CATCH 
      SET @n_Continue = 3 
      SET @c_Errmsg = ERROR_MESSAGE()     
      GOTO EXIT_SP  
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch 
   
   EXIT_SP:
   
   IF @n_Continue = 3   
   BEGIN
      SET @b_Success = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
   END
   REVERT      
END  

GO