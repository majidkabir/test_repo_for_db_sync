SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PackWithMultiCodeUpdate_Wrapper                */  
/* Creation Date: 08-Sep-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-14786 - Pack Update using Code1, Code2, Code3           */  
/*          Call Sub SP (ispPMCUXX)                                     */  
/*                                                                      */  
/* Called By: Scan and Pack                                             */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_PackWithMultiCodeUpdate_Wrapper]
   @c_PickSlipNo     NVARCHAR(10),  
   @n_CartonNo       INT,  
   @c_SKU            NVARCHAR(20),  
   @n_Qty            INT,  
   @c_Code01         NVARCHAR(60) = '',
   @c_Code02         NVARCHAR(60) = '',
   @c_Code03         NVARCHAR(60) = '',
   @b_Success        INT           OUTPUT,  
   @n_err            INT           OUTPUT,  
   @c_errmsg         NVARCHAR(255) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SPCode        NVARCHAR(10),
           @c_SQL           NVARCHAR(MAX),
           @c_StorerKey     NVARCHAR(15)
                                                      
   SELECT @c_SPCode = '', @n_err=0, @b_success=1, @c_errmsg=''
    
   SELECT @c_Storerkey = Storerkey
   FROM PACKHEADER (NOLOCK)
   WHERE Pickslipno = @c_PickSlipNo
   
   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'PackWithMultiCodeUpdate'  

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 61012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Storerconfig PackWithMultiCodeUpdate - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_PackWithMultiCodeUpdate_Wrapper)'  
       GOTO QUIT_SP
   END
   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_PickSlipNo, @n_CartonNo, @c_SKU, @n_Qty, @c_Code01, @c_Code02, @c_Code03, ' +
                '@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
        
   EXEC sp_executesql @c_SQL, 
        N'@c_PickSlipNo NVARCHAR(10), @n_CartonNo INT, @c_SKU NVARCHAR(20), @n_Qty INT, @c_Code01 NVARCHAR(60), @c_Code02 NVARCHAR(60), @c_Code03 NVARCHAR(60),
          @b_Success int OUTPUT, @n_Err int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
        @c_PickSlipNo   ,
        @n_CartonNo     ,
        @c_SKU          ,      
        @n_Qty          ,
        @c_Code01       ,         
        @c_Code02       ,         
        @c_Code03       ,         
        @b_Success      OUTPUT,                 
        @n_err          OUTPUT,                 
        @c_errmsg       OUTPUT  
                                   
   IF @b_Success <> 1
   BEGIN
      SELECT @n_continue = 3  
      GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PackWithMultiCodeUpdate_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO