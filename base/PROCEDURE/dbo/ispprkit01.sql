SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispPRKIT01                                            */  
/* Creation Date: 18-APR-2016                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: SOS#367627 - Finalize Kit generate SSCC to lottable09          */                                 
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date       Ver  Author   Purposes                                       */  
/***************************************************************************/    
CREATE PROC [dbo].[ispPRKIT01]    
(     @c_Kitkey      NVARCHAR(10)     
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Debug              INT  
         , @n_Continue           INT   
         , @n_StartTCount        INT   
  
   DECLARE @c_ID                 NVARCHAR(18)   
         , @c_Storerkey          NVARCHAR(15)
         , @c_SSCCNo             NVARCHAR(20)
 
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
 
   SET @b_Debug  = 1
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT    

   IF EXISTS (SELECT 1 FROM KITDETAIL(NOLOCK)
              WHERE ISNULL(ID,'') = ''
              AND Kitkey = @c_Kitkey
              AND Type = 'T')
   BEGIN
      SET @n_Continue = 3
      SET @n_err      = 83005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Empty Plt ID is Not allowed. (ispPRKIT01)'
      GOTO QUIT_SP
   END
        
   DECLARE CUR_KITPLT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT ID, Storerkey
      FROM KITDETAIL(NOLOCK) 
      WHERE Kitkey = @c_Kitkey
      AND Type = 'T'
      AND ISNULL(ID,'') <> ''
      ORDER BY Id
      
   OPEN CUR_KITPLT  
  
   FETCH NEXT FROM CUR_KITPLT INTO  @c_Id, @c_Storerkey
   WHILE @@FETCH_STATUS <> -1  
   BEGIN     	  
      EXEC [rdt].[rdt_GenUCCLabelNo_02] 
           @nMobile = 0,
           @nFunc = 0,
           @cLangCode = '',
           @nStep = 0,
           @nInputKey = 0,
           @cStorerkey = @c_Storerkey, 
           @cOrderKey = '',
           @cPickSlipNo = '',
           @cTrackNo = '',
           @cSKU = '',
           @nCartonNo = 0,
           @cLabelNo = @c_SSCCNo OUTPUT,
           @nErrNo = @n_Err OUTPUT,
           @cErrMsg = @c_ErrMsg OUTPUT
       
      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END
   
      UPDATE KITDETAIL WITH (ROWLOCK)
      SET Lottable09 = @c_SSCCNo,
          Lottable10 = 'VAS',
          TrafficCop = NULL
      WHERE KitKey = @c_Kitkey
      AND Storerkey = @c_Storerkey
      AND ID = @c_ID
      AND Type = 'T'
     
      SET @n_err = @@ERROR     

      IF @n_err <> 0      
      BEGIN    
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 83010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update KITDETAIL Failed. (ispPRKIT01)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
         GOTO QUIT_SP    
      END              
 
      FETCH NEXT FROM CUR_KITPLT INTO  @c_Id, @c_Storerkey
   END
   CLOSE CUR_KITPLT  
   DEALLOCATE CUR_KITPLT  
     
   QUIT_SP:  
  
   IF CURSOR_STATUS('LOCAL', 'CUR_KITPLT') in (0 , 1)  
   BEGIN  
      CLOSE CUR_KITPLT  
      DEALLOCATE CUR_KITPLT  
   END 

   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPRKIT01'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END 

GO