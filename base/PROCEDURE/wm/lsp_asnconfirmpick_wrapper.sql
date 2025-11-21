SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_ASNConfirmPick_Wrapper                         */  
/* Creation Date: 29-Jan-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Crossdock confirm pick                                      */  
/*                                                                      */  
/* Called By: XDock Confirm Pick                                        */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                    */
/* 15-Jan-2021 Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 26-Feb-2024 NJOW01   1.2   UWP-14044 ASN support confirm pick by     */
/*                            multiple externpokey per ASN              */
/************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_ASNConfirmPick_Wrapper]
  @c_StorerKey    NVARCHAR(15) ,
  @c_ExternPOKey  NVARCHAR(20), 
  @b_Success      INT OUTPUT, 
  @n_err          INT OUTPUT,
  @c_ErrMsg       NVARCHAR(215) OUTPUT,
  @c_UserName     NVARCHAR(128) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   --NJOW01
   DECLARE @c_Receiptkey    NVARCHAR(10), 
           @CUR_CPICK       CURSOR,       
           @n_continue      INT = 1 

   SET @b_Success = 0
   
   --EXECUTE AS LOGIN=@c_UserName
      
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName     --(Wan01) - START
   BEGIN    
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END 
      
      EXECUTE AS LOGIN = @c_UserName
   END                                 --(Wan01) - END
   
   --NJOW01
   SELECT TOP 1 @c_Receiptkey = RD.receiptkey
   FROM RECEIPTDETAIL RD (NOLOCK)
   JOIN PO (NOLOCK) ON RD.Pokey = PO.Pokey
   WHERE RD.ExternPOKey = @c_ExternPOKey
   AND RD.Storerkey = @c_Storerkey
   AND RD.QtyReceived > 0
   ORDER BY RD.Editdate DESC
   
   IF ISNULL(@c_Receiptkey,'') <> ''  --NJOW01
   BEGIN
      SET @CUR_CPICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR               
         SELECT RD.ExternPOKey
         FROM RECEIPTDETAIL RD WITH (NOLOCK) 
         JOIN PO p WITH (NOLOCK) ON rd.pokey = p.pokey
         WHERE RD.ReceiptKey = @c_ReceiptKey 
         GROUP BY RD.ExternPOKey
         ORDER BY RD.ExternPOKey               
         
         OPEN @CUR_CPICK
         
         FETCH NEXT FROM @CUR_CPICK INTO @c_externpokey
         
         WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
         BEGIN            	
            BEGIN TRY              
                  EXEC dbo.ispASNConfirmPick
                       @cStorerKey = @c_Storerkey,
                       @cExternPOKey = @c_ExternPOkey, -- For one storer, pass in the Storerkey; For All Storer, pass in '%'
                       @b_Success    = @b_Success OUTPUT, 
                       @n_err        = @n_err OUTPUT,
                       @c_ErrMsg     = @c_ErrMsg OUTPUT 
            END TRY
            BEGIN CATCH                  	      
            	 SET @n_continue = 3                           	
               SET @b_Success = 0               
               SET @c_ErrMsg  = ERROR_MESSAGE() 
            END CATCH
      
            FETCH NEXT FROM @CUR_CPICK INTO @c_externpokey
         END   
         CLOSE @CUR_CPICK     
         DEALLOCATE @CUR_CPICK   	   	 
   END
   ELSE
   BEGIN    
      BEGIN TRY -- SWT01 - Begin Outer Begin Try      
         IF NOT EXISTS (SELECT 1 FROM ORDERDETAIL AS o WITH(NOLOCK)
                      WHERE o.StorerKey = @c_StorerKey
                      AND o.ExternPOKey = @c_ExternPOKey)
         BEGIN
            SET @n_err = 554001
            SET @c_ErrMsg = 'Error: ' + CAST(@n_err AS VARCHAR(6)) + ': Invalid Extern PO Key.'
            SET @b_Success = 0
            GOTO EXIT_SP        
         END
         
         EXEC dbo.ispASNConfirmPick
              @cStorerKey = @c_Storerkey,
              @cExternPOKey = @c_ExternPOkey, -- For one storer, pass in the Storerkey; For All Storer, pass in '%'
              @b_Success    = @b_Success OUTPUT, 
              @n_err        = @n_err OUTPUT,
              @c_ErrMsg     = @c_ErrMsg OUTPUT 
               
      END TRY  
      
      BEGIN CATCH  
         SET @b_Success = 0               --(Wan01) 
         SET @c_ErrMsg  = ERROR_MESSAGE() --(Wan01)
         GOTO EXIT_SP  
      END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch         
   END
   
   EXIT_SP:
   REVERT     
END  

GO