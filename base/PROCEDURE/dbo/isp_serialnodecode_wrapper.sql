SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_SerialNoDecode_Wrapper                         */  
/* Creation Date: 02-Mar-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-16407 - Serial number decode in Packing module          */  
/*                                                                      */  
/* Called By: Packing (Call ispSNDC01)                                  */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 10-May-2021  NJOW01   1.0  Fix storerconfig                          */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_SerialNoDecode_Wrapper]
   @c_PickslipNo  NVARCHAR(10),
   @c_Storerkey   NVARCHAR(15),  
   @c_Sku         NVARCHAR(20),  
   @c_SerialNo    NVARCHAR(200),
   @c_NewSerialNo NVARCHAR(50) OUTPUT,   
   @c_Code01      NVARCHAR(100) = '' OUTPUT, 
   @c_Code02      NVARCHAR(100) = '' OUTPUT,
   @c_Code03      NVARCHAR(100) = '' OUTPUT,
   @b_Success     INT      OUTPUT,
   @n_Err         INT      OUTPUT, 
   @c_ErrMsg      NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue          INT,
           @c_SPCode            NVARCHAR(30),
           @c_SQL               NVARCHAR(MAX)
                                                      
   SELECT @c_SPCode = '', @n_err=0, @b_success=1, @c_errmsg=''
   SELECT @c_NewSerialNo = @c_Serialno 
      
   --SELECT @c_SPCode = dbo.fnc_GetRight('', @c_Storerkey, '', 'SerialNoDecode_SP')
             
   SELECT TOP 1 @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'SerialNoDecode_SP'    

   IF ISNULL(RTRIM(@c_SPCode),'') IN ('','0')
   BEGIN
       SELECT @n_continue = 4  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Storerconfig SerialNoDecode_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_SerialNoDecode_Wrapper)'  
       GOTO QUIT_SP
   END

   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_PickslipNo=@c_Pickslipno, @c_StorerKey=@c_Storerkey, @c_Sku=@c_Sku, @c_SerialNo=@c_SerialNo, @c_NewSerialNo=@c_NewSerialNo OUTPUT, @c_Code01=@c_Code01 OUTPUT, @c_Code02=@c_Code02 OUTPUT, @c_Code03=@c_Code03 OUTPUT, ' 
              + '@b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT '
              
   EXEC sp_executesql @c_SQL, 
     N'@c_PickslipNo NVARCHAR(10), @c_StorerKey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_SerialNo NVARCHAR(200), @c_NewSerialNo NVARCHAR(50) OUTPUT, @c_Code01 NVARCHAR(100) OUTPUT, @c_Code02 NVARCHAR(100) OUTPUT, @c_Code03 NVARCHAR(100) OUTPUT, 
       @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
     @c_Pickslipno,
     @c_StorerKey,
     @c_Sku,
     @c_SerialNo,
     @c_NewSerialNo OUTPUT,
     @c_Code01 OUTPUT,   
     @c_Code02 OUTPUT,  
     @c_Code03 OUTPUT,
     @b_Success OUTPUT,                      
     @n_Err OUTPUT, 
     @c_ErrMsg OUTPUT
                      
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_SerialNoDecode_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO