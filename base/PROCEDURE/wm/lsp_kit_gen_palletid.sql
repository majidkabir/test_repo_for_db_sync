SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Kit_Gen_PalletID                                */  
/* Creation Date: 28-FEB-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                     */
/* 15-Jan-2021 Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Kit_Gen_PalletID]  (
   @c_StorerKey      NVARCHAR(15), 
   @c_KitKey         NVARCHAR(10),
   @c_KitLineNumber  NVARCHAR(5),
   @c_Type           NVARCHAR(5), 
   @c_DeletePrevious CHAR(1) = 'Y',
   @b_Success        int = 1 OUTPUT,
   @n_Err            int = 0 OUTPUT,
   @c_Errmsg         NVARCHAR(250) = '' OUTPUT,
   @c_UserName       NVARCHAR(50)  = '' )
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
         , @c_MUID_Enable  NVARCHAR(10) = '0'
         , @c_ID           NVARCHAR(18) = ''
         
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
   
      SELECT @c_StorerKey = k.StorerKey
      FROM KIT AS k WITH(NOLOCK)
      WHERE k.KITKey = @c_KitKey
   
       SET @b_success = 0
       SET @c_MUID_Enable = '0'
       Execute nspGetRight null,  -- Facility
       @c_StorerKey,              -- Storerkey
       '',                        -- Sku
       'MUID_Enable', -- Configkey
       @b_success                  OUTPUT,
       @c_MUID_Enable              OUTPUT,
       @n_err                      OUTPUT,
       @c_errmsg                   OUTPUT   
   
      IF @c_MUID_Enable <> '1'
         GOTO EXIT_SP
      
      DECLARE CUR_KITDETAIL_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT KD.KITLineNumber 
      FROM KITDETAIL AS KD WITH (NOLOCK)
      WHERE KD.KITKey = @c_KitKey 
      AND   KD.KITLineNumber = CASE WHEN ISNULL(RTRIM(@c_KitLineNumber), '') = '' THEN KD.KITLineNumber ELSE @c_KitLineNumber END 
      AND   KD.[Type] = 'T' 
      AND   KD.Qty > 0 
      AND  (KD.Id = '' OR KD.ID IS NULL) 
   
      OPEN CUR_KITDETAIL_LINES
   
      FETCH FROM CUR_KITDETAIL_LINES INTO @c_KITLineNumber
                                                  
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_ID = ''
      
         EXEC nspg_GetKey
            @KeyName = 'ID',
            @fieldlength = 10,
            @keystring = @c_ID OUTPUT,
            @b_Success = @b_Success OUTPUT,
            @n_err = @n_err OUTPUT,
            @c_errmsg = @c_errmsg OUTPUT,
            @b_resultset = 1,
            @n_batch = 1
      
         IF ISNULL(RTRIM(@c_ID), '') <> ''
         BEGIN
            UPDATE KITDETAIL WITH (ROWLOCK)
               SET Id = @c_ID, TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME()
            WHERE KITKey = @c_KitKey 
            AND   KITLineNumber = @c_KitLineNumber 
            AND   [Type] = 'T'
            IF @@ERROR <> 0 
            BEGIN
               SET @n_continue = 3  
               SET @n_Err = 554101 
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                     ': Update KitDetail ID Fail (lsp_Kit_Gen_PalletID)'               
               GOTO EXIT_SP            
            END
         END
         FETCH FROM CUR_KITDETAIL_LINES INTO @c_KITLineNumber
      END
   
      CLOSE CUR_KITDETAIL_LINES
      DEALLOCATE CUR_KITDETAIL_LINES
   
   END TRY  
  
   BEGIN CATCH  
      SET @n_Continue = 3                 --(Wan01)
      SET @c_Errmsg = ERROR_MESSAGE()     --(Wan01)    
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