SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_SKUDecode_Wrapper                               */  
/* Creation Date: 14-Mar-2011                                            */  
/* Copyright: IDS                                                        */  
/* Written by: NJOW                                                      */  
/*                                                                       */  
/* Purpose: SOS#208211  - barcode rule in Packing module                 */  
/*                                                                       */  
/* Called By: Packing (Call ispSKUDC01)                                  */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 22-Mar-2011  NJOW     1.0  Fix new sku no value problem if not setup  */
/* 07-Sep-2020  WLChooi  1.1  WMS-14786 - Add new optional parameters    */
/*                            for decoding (WL01)                        */
/* 01-Oct-2021  NJOW02   1.2  WMS-18189 add pickslipno parameter         */
/* 01-Oct-2021  NJOW02   1.2  DEVOPS combine script                      */
/* 29-Mar-2023	NJOW03   1.3  WMS-21989 add cartonno & UCC parameters    */
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[isp_SKUDecode_Wrapper]
   @c_Storerkey  NVARCHAR(15),  
   @c_Sku        NVARCHAR(60),
   @c_NewSku     NVARCHAR(60) OUTPUT,   
   @b_Success    INT      OUTPUT,
   @n_Err        INT      OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT,
   @c_Code01     NVARCHAR(60) = '' OUTPUT,   --WL01
   @c_Code02     NVARCHAR(60) = '' OUTPUT,   --WL01
   @c_Code03     NVARCHAR(60) = '' OUTPUT,    --WL01
   @c_PickslipNo NVARCHAR(10) = '', --NJOW02                                          
   @n_CartonNo   INT = 0, --NJOW03   
   @c_UCCNo      NVARCHAR(20) = ''  --Pack by UCC when UCCtoDropID = '1' --NJOW03
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SPCode        NVARCHAR(10),
           @c_SQL           NVARCHAR(MAX),
           @c_SPParam       NVARCHAR(2000) = '', --NJOW02
           @c_IsErrNoParm   NVARCHAR(10) = 'N' --NJOW02
                                                      
   SELECT @c_SPCode = '', @n_err=0, @b_success=1, @c_errmsg=''
   SELECT @c_NewSku = @c_Sku --NJOW01
      
   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'SKUDECODE'  

   IF ISNULL(RTRIM(@c_SPCode),'') =''
   BEGIN
       SELECT @n_continue = 4  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Please Setup Stored Procedure Name into Storer Configuration for '+RTRIM(@c_StorerKey)+' (isp_SKUDecode_Wrapper)'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Storerconfig SKUDECODE - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_SKUDecode_Wrapper)'  
       GOTO QUIT_SP
   END
   
   --NJOW02 S
   IF EXISTS( SELECT 1
              FROM sys.parameters AS p
              JOIN sys.types AS t ON t.user_type_id = p.user_type_id
              WHERE object_id = OBJECT_ID(RTRIM(@c_SPCode))
              AND   P.name = N'@n_ErrNo')
   BEGIN
      SET @c_IsErrNoParm = 'Y'
   END           
   
   IF EXISTS (SELECT 1
              FROM sys.parameters AS p
              JOIN sys.types AS t ON t.user_type_id = p.user_type_id
              WHERE object_id = OBJECT_ID(RTRIM(@c_SPCode))
              AND   P.name = N'@c_Code01')
   BEGIN
   	   SET @c_SPParam = ' @c_StorerKey=@c_StorerKey, @c_sku=@c_Sku, @c_NewSku=@c_NewSku OUTPUT, @c_Code01=@c_Code01 OUTPUT, @c_Code02=@c_Code02 OUTPUT, @c_Code03=@c_Code03 OUTPUT, 
                        @b_Success=@b_Success OUTPUT, ' + CASE WHEN @c_IsErrNoParm = 'Y' THEN '@n_ErrNo=@n_Err OUTPUT' ELSE '@n_Err=@n_Err OUTPUT' END + ', @c_ErrMsg=@c_ErrMsg OUTPUT '
   END 
   ELSE
   BEGIN
       SET @c_SPParam = ' @c_StorerKey=@c_StorerKey, @c_sku=@c_sku, @c_NewSku=@c_NewSku OUTPUT, @b_Success=@b_Success OUTPUT, ' + CASE WHEN @c_IsErrNoParm = 'Y' THEN '@n_ErrNo=@n_Err OUTPUT' ELSE '@n_Err=@n_Err OUTPUT' END + 
                        ', @c_ErrMsg=@c_ErrMsg OUTPUT '	
   END
   
   IF EXISTS (SELECT 1
              FROM sys.parameters AS p
              JOIN sys.types AS t ON t.user_type_id = p.user_type_id
              WHERE object_id = OBJECT_ID(RTRIM(@c_SPCode))
              AND   P.name = N'@c_Pickslipno')
   BEGIN
   	  SET @c_SPParam = @c_SPParam + ', @c_PickslipNo=@c_Pickslipno '
   END

   --NJOW03
   IF EXISTS (SELECT 1
              FROM sys.parameters AS p
              JOIN sys.types AS t ON t.user_type_id = p.user_type_id
              WHERE object_id = OBJECT_ID(RTRIM(@c_SPCode))
              AND   P.name = N'@n_CartonNo')
   BEGIN
   	  SET @c_SPParam = @c_SPParam + ', @n_CartonNo=@n_CartonNo, @c_UCCNo=@c_UCCNo '
   END

   SET @c_SQL = 'EXEC ' + @c_SPCode + @c_SPParam
      
   EXEC sp_executesql @c_SQL, 
        N'@c_StorerKey NVARCHAR(15), @c_Sku NVARCHAR(60), @c_NewSku NVARCHAR(60) OUTPUT, @c_Code01 NVARCHAR(60) OUTPUT, @c_Code02 NVARCHAR(60) OUTPUT, @c_Code03 NVARCHAR(60) OUTPUT, 
          @b_Success int OUTPUT, @n_Err int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @c_Pickslipno NVARCHAR(10), @n_CartonNo INT, @c_UCCNo NVARCHAR(20)', 
        @c_StorerKey,
        @c_Sku,
        @c_NewSku OUTPUT,
        @c_Code01 OUTPUT,   
        @c_Code02 OUTPUT,  
        @c_Code03 OUTPUT,
        @b_Success OUTPUT,                      
        @n_Err OUTPUT, 
        @c_ErrMsg OUTPUT,
        @c_PickslipNo,
        @n_CartonNo,  --NJOW03
        @c_UCCNo --NJOW03
   --NJOW02 E        

   --WL01 START
   /*
   IF EXISTS (SELECT 1
              FROM sys.parameters AS p
              JOIN sys.types AS t ON t.user_type_id = p.user_type_id
              WHERE object_id = OBJECT_ID(RTRIM(@c_SPCode))
              AND   P.name = N'@c_Code01')
   BEGIN
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_StorerKey=@c_StorerKey, @c_sku=@c_Sku, @c_NewSku=@c_NewSku OUTPUT, @c_Code01=@c_Code01 OUTPUT, @c_Code02=@c_Code02 OUTPUT, @c_Code03=@c_Code03 OUTPUT, '
                 + '@b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT '
                 
      EXEC sp_executesql @c_SQL, 
        N'@c_StorerKey NVARCHAR(15), @c_Sku NVARCHAR(60), @c_NewSku NVARCHAR(60) OUTPUT, @c_Code01 NVARCHAR(60) OUTPUT, @c_Code02 NVARCHAR(60) OUTPUT, @c_Code03 NVARCHAR(60) OUTPUT, 
          @b_Success int OUTPUT, @n_Err int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
        @c_StorerKey,
        @c_Sku,
        @c_NewSku OUTPUT,
        @c_Code01 OUTPUT,   
        @c_Code02 OUTPUT,  
        @c_Code03 OUTPUT,
        @b_Success OUTPUT,                      
        @n_Err OUTPUT, 
        @c_ErrMsg OUTPUT
   END
   ELSE
   BEGIN   --WL01 END
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_StorerKey=@c_StorerKey, @c_sku=@c_sku, @c_NewSku=@c_NewSku OUTPUT, @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT,' +
                   ' @c_ErrMsg=@c_ErrMsg OUTPUT '
        
      EXEC sp_executesql @c_SQL, 
           N'@c_StorerKey NVARCHAR(15), @c_Sku NVARCHAR(60), @c_NewSku NVARCHAR(60) OUTPUT, @b_Success int OUTPUT, @n_Err int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
           @c_StorerKey,
           @c_Sku,
           @c_NewSku OUTPUT,
           @b_Success OUTPUT,                      
           @n_Err OUTPUT, 
           @c_ErrMsg OUTPUT
   END   --WL01
   */
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_SKUDecode_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO