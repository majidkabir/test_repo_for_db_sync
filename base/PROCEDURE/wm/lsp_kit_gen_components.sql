SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Kit_Gen_Components                              */  
/* Creation Date: 28-FEB-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.3                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */
/* 2020-10-09  Wan01    1.1   LFWM-2136 - UAT  MY SCE Kitting Get Component*/
/*                            Error                                      */
/* 28-Dec-2020 SWT01    1.2   Adding Begin Try/Catch                     */
/* 15-Jan-2021 Wan02    1.3   Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Kit_Gen_Components]  (
   @c_StorerKey      NVARCHAR(15), 
   @c_KitKey         NVARCHAR(10),
   @c_KitLineNumber  NVARCHAR(5),
   @c_Type           NVARCHAR(5), 
   @c_DeletePrevious CHAR(1) = 'Y',
   @b_Success        int = 1 OUTPUT,
   @n_Err            int = 0 OUTPUT,
   @c_Errmsg         NVARCHAR(250) = '' OUTPUT,
   @c_UserName       NVARCHAR(128)  = '' )
AS  
BEGIN  
   SET ANSI_NULLS ON
   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON
   SET QUOTED_IDENTIFIER ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON

   DECLARE @n_Continue     INT = '1'         
         , @n_Count        INT = 0 
         , @c_ComponentSku NVARCHAR(20) = '' 
         , @n_ComponentQty INT = 0 
         , @n_ParentQty    INT = 0 
         , @n_Remainder    INT = 0
         , @n_BOMQty       INT = 0  
         , @c_NewKitLineNo NVARCHAR(5)  = ''
         , @c_PackKey      NVARCHAR(10) = ''
         , @c_UOM          NVARCHAR(10) = ''
         
   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName       --(Wan02) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
   
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName 
   END                                   --(Wan02) - END

   BEGIN TRY -- SWT01 - Begin Outer Begin Try
   
      DECLARE @c_FromSKU         NVARCHAR(20) = '', 
              @n_FromExpectedQty INT = 0 
   
      SELECT @c_StorerKey = KD.StorerKey, 
             @c_FromSKU   = KD.Sku,
             @n_FromExpectedQty = KD.ExpectedQty
      FROM KITDETAIL AS KD WITH (NOLOCK)
      WHERE KD.KITKey = @c_KitKey 
      AND   KD.KITLineNumber = @c_KitLineNumber 
      AND   KD.[Type] = @c_Type
   
      IF ISNULL(RTRIM(@c_FromSKU),'') = ''
      BEGIN
         SET @n_continue =0
         SET @n_err = 552551
         SET @c_ErrMsg = 'SKU Cannot be BLANK'     
      END
   
      IF @n_FromExpectedQty <= 0 
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 552552 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
              ': Expected Qty must greater than ZERO (lsp_Kit_Gen_Components)'               
         GOTO EXIT_SP      
      END
   
      IF @c_DeletePrevious='Y'
      BEGIN
         DELETE FROM KITDETAIL 
         WHERE KITKey = @c_KitKey 
         AND   [Type] = CASE WHEN @c_Type = 'T' THEN 'F' ELSE 'T' END 
         AND   [Status] NOT IN ('9')
         IF @@ERROR <> 0 
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 552553 
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                  ': Delete Kit Detail Failed (lsp_Kit_Gen_Components)'                
            GOTO EXIT_SP         
         END
      END
   
      DECLARE CUR_COMPONENTS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ComponentSku, Qty, ParentQty
      FROM BillOfMaterial WITH (NOLOCK)
      WHERE Storerkey = @c_StorerKey 
      AND   Sku = @c_FromSKU
   
      OPEN CUR_COMPONENTS
   
      FETCH FROM CUR_COMPONENTS INTO @c_ComponentSku, @n_ComponentQty, @n_ParentQty
                                                  
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_Remainder = 0 
         IF @n_ComponentQty > @n_ParentQty  
            SET @n_Remainder = @n_ComponentQty % @n_ParentQty
         ELSE 
         IF @n_ComponentQty < @n_ParentQty  
            SET @n_Remainder = @n_ParentQty % @n_ComponentQty        
 
      
         IF @n_Remainder > 0 
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 552554 
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                  ': Remaining Qty found while dividing Parent Qty and Component Qty for Components. Please check Bill Of Material Setting. (lsp_Kit_Gen_Components)'               
            GOTO EXIT_SP         
         END

         SELECT @c_PackKey = PACK.Packkey, 
                @c_UOM = PACKUOM3 
         FROM SKU (NOLOCK) 
         JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE SKU.SKU = @c_ComponentSku
         AND   SKU.Storerkey = @c_StorerKey  

         SET @n_BOMQty = (@n_FromExpectedQty * @n_ComponentQty) / @n_ParentQty--@n_FromExpectedQty / (@n_ParentQty/@n_ComponentQty) -- Wna01:Fix
      
         SET @c_NewKitLineNo = '00001'                                                                   --(Wan01)
         SELECT TOP 1                                                                                    --(Wan01)
                @c_NewKitLineNo = RIGHT('0000' + CAST(CAST(k.KITLineNumber AS INT) + 1 AS VARCHAR(5))    --(Wan01)
                                        ,5)
         FROM KITDETAIL AS k WITH(NOLOCK)
         WHERE k.KITKey = @c_KitKey 
         --AND k.[Type] = CASE WHEN @c_Type = 'T' THEN 'F' ELSE 'T' END                                  --(Wan01)
         ORDER BY k.KITLineNumber DESC                                                                   --(Wan01)
           
         INSERT INTO KITDETAIL
         (
            KITKey,     KITLineNumber, [Type],
            StorerKey,  Sku,           Lot,
            Loc,        Id,            ExpectedQty,
            Qty,        PackKey,       UOM, 
            [Status]
         )
         VALUES
         (
            @c_KitKey,        @c_NewKitLineNo,
            CASE WHEN @c_Type = 'T' THEN 'F' ELSE 'T' END,
            @c_StorerKey,     @c_ComponentSku,        '',
            '',               '',                     @n_BOMQty,
            0,                @c_PackKey,             @c_UOM,
            '0'
         )
      
         FETCH FROM CUR_COMPONENTS INTO @c_ComponentSku, @n_ComponentQty, @n_ParentQty
      END
   
      CLOSE CUR_COMPONENTS
      DEALLOCATE CUR_COMPONENTS
   
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