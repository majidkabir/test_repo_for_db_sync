SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PackAutoCloseCarton_Wrapper                    */  
/* Creation Date: 08-Aug-2018                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-5729 CN Puma auto close carton                          */  
/*                                                                      */  
/* Called By: Packing (Call ispPKCLOSECTN01)                            */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */ 
/* 27-Jan-2021 Wan01    1.1   WMS-16079 - RG - LEGO - EXCEED Packing    */ 
/************************************************************************/  
 
CREATE PROCEDURE [dbo].[isp_PackAutoCloseCarton_Wrapper]
   @c_PickSlipNo  NVARCHAR(10),
   @c_Storerkey   NVARCHAR(15),  
   @c_ScanSkuCode NVARCHAR(50),
   @c_Sku         NVARCHAR(20),  
   @c_CloseCarton NVARCHAR(10) OUTPUT,
   @b_Success     INT      OUTPUT,
   @n_Err         INT      OUTPUT, 
   @c_ErrMsg      NVARCHAR(250) OUTPUT,
   @n_CartonNo    INT          = 0,          -- Add default @n_CartonNo to SP
   @c_ScanColumn  NVARCHAR(50) = '',         -- Add default @c_ScanColumn to SP
   @n_Qty         INT          = 0           -- Add default @n_Qty to SP  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SPCode        NVARCHAR(30),
           @c_SQL           NVARCHAR(MAX)
           
         , @c_SQLParms     NVARCHAR(4000) = ''  --(Wan01)
                                                      
   SELECT @c_SPCode = '', @n_err=0, @b_success=1, @c_errmsg=''
      
   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'PackAutoCloseCarton_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') =''
   BEGIN
       SELECT @n_continue = 4  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Please Setup Stored Procedure Name into Storer Configuration for '+RTRIM(@c_StorerKey)+' (isp_PackAutoCloseCarton_Wrapper )'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Storerconfig PackAutoCloseCarton_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_PackAutoCloseCarton_Wrapper )'  
       GOTO QUIT_SP
   END
   
   --(Wan01) - Add @n_CartonNo,  @c_ScanColumn,  @n_Qty
   SET @c_SQL = 'EXEC ' + @c_SPCode 
              + '  @c_Pickslipno  = @c_Pickslipno'
              + ', @c_Storerkey   = @c_Storerkey'
              + ', @c_ScanSkuCode = @c_ScanSkuCode'
              + ', @c_Sku         = @c_Sku'
              + ', @c_CloseCarton = @c_CloseCarton OUTPUT'
              + ', @b_Success     = @b_Success OUTPUT'
              + ', @n_Err         = @n_Err     OUTPUT'
              + ', @c_ErrMsg      = @c_ErrMsg  OUTPUT'
              + ', @n_CartonNo    = @n_CartonNo'           
              + ', @c_ScanColumn  = @c_ScanColumn'  
              + ', @n_Qty         = @n_Qty'
                        
   SET @c_SQLParms = N'@c_Pickslipno    NVARCHAR(10)'
                   + ', @c_Storerkey      NVARCHAR(15)'
                   + ', @c_ScanSkuCode    NVARCHAR(50)'
                   + ', @c_Sku            NVARCHAR(20)'
                   + ', @c_CloseCarton    NVARCHAR(10) OUTPUT'
                   + ', @b_Success        int OUTPUT'
                   + ', @n_Err            int OUTPUT'
                   + ', @c_ErrMsg         NVARCHAR(250) OUTPUT'
                   + ', @n_CartonNo       INT' 
                   + ', @c_ScanColumn     NVARCHAR(50)'  
                   + ', @n_Qty            INT'                          
             
   EXEC sp_executesql @c_SQL, 
        @c_SQLParms,
        @c_Pickslipno,
        @c_Storerkey,
        @c_ScanSkuCode,
        @c_Sku,
        @c_CloseCarton OUTPUT,
        @b_Success OUTPUT,                      
        @n_Err OUTPUT, 
        @c_ErrMsg OUTPUT,
        @n_CartonNo,  
        @c_ScanColumn, 
        @n_Qty
                         
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PackAutoCloseCarton_Wrapper '  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO