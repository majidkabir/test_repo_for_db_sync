SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_WorkOrderGenerateKitting_Wrapper               */  
/* Creation Date: 15-Jun-2017                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-2133 Work Order generate kitting                        */  
/*          Storerconfig WorkOrderGenerateKitting_SP={SPName}           */
/*          SPName = ispWOKITxx                                         */      
/*                                                                      */  
/* Called By: Work Order RCM Generate Kitting                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_WorkOrderGenerateKitting_Wrapper]  
   @c_WorkOrderKey NVARCHAR(10),    
   @b_Success      INT      OUTPUT,
   @n_Err          INT      OUTPUT, 
   @c_ErrMsg       NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SPCode        NVARCHAR(30),
           @c_StorerKey     NVARCHAR(15),
           @c_Facility      NVARCHAR(5),
           @c_SQL           NVARCHAR(MAX),
           @c_option1      NVARCHAR(50),
           @c_option2      NVARCHAR(50),
           @c_option3      NVARCHAR(50),
           @c_option4      NVARCHAR(50),
           @c_option5      NVARCHAR(4000)
                       
   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_continue   = 1
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_SQL        = ''
   
   SELECT @c_Storerkey = WORKORDER.Storerkey
         ,@c_facility = WORKORDER.Facility
   FROM WORKORDER WITH (NOLOCK)
   WHERE WORKORDER.WorkOrderkey = @c_WorkOrderkey
   
   IF EXISTS (SELECT 1  
              FROM WORKORDER WITH (NOLOCK)
              WHERE WorkOrderKey = @c_WorkOrderkey
              AND Status = '9')
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31213 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': Work Order#: ' + RTRIM(@c_WorkOrderKey) + ' already completed. (isp_WorkOrderGenerateKitting_Wrapper)'  
       GOTO QUIT_SP
   END

   EXECUTE nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      '',  --Sku                    
      'WorkOrderGenerateKitting_SP', -- Configkey
      @b_success    OUTPUT,
      @c_SPCode     OUTPUT,
      @n_err        OUTPUT,
      @c_errmsg     OUTPUT,
      @c_option1 OUTPUT,
      @c_option2 OUTPUT,
      @c_option3 OUTPUT,
      @c_option4 OUTPUT,
      @c_option5 OUTPUT

   IF @b_success <> 1
   BEGIN       
       SET @n_continue = 3  
       SET @n_Err = 31214 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = RTRIM(ISNULL(@c_Errmsg,'')) + ' (isp_WorkOrderGenerateKitting_Wrapper)'  
       GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN       
       SET @n_continue = 3  
       SET @n_Err = 31215 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': Please Setup Stored Procedure Name into Storer Configuration(WorkOrderGenerateKitting_SP) for '
                     + RTRIM(@c_StorerKey)+ '. (isp_WorkOrderGenerateKitting_Wrapper)'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31216
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Storerconfig WorkOrderGenerateKitting_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                     + '). (isp_WorkOrderGenerateKitting_Wrapper)'  
       GOTO QUIT_SP
   END

   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_WorkOrderKey, @b_Success OUTPUT, @n_Err OUTPUT,' +
                ' @c_ErrMsg OUTPUT '

   EXEC sp_executesql @c_SQL 
      , N'@c_WorkOrderKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT' 
      , @c_WorkOrderKey 
      , @b_Success   OUTPUT                       
      , @n_Err       OUTPUT  
      , @c_ErrMsg    OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_WorkOrderGenerateKitting_Wrapper'  
   END   
END  

GO