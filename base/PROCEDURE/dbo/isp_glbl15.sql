SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: isp_GLBL15                                          */  
/* Creation Date: 09-Apr-2019                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-4538 - CN UA SCAN AND PACK LABEL NO                     */   
/*                                                                      */  
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Usage: Call from isp_GenLabelNo_Wrapper                              */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GLBL15] (   
         @c_StorerKey   NVARCHAR(15)   
      ,  @n_TotalLabel  INT  
       )  
AS  
BEGIN  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
        
   DECLARE @n_StartTCnt          INT  
         , @n_Continue           INT  
         , @b_Success            INT   
         , @n_Err                INT    
         , @c_ErrMsg             NVARCHAR(255)  
         , @c_LabelNo            NVARCHAR(20) 
         , @nCounter             INT
        -- , @c_Storerkey          NVARCHAR(15)  
     
   SET @n_StartTCnt        = @@TRANCOUNT  
   SET @n_Continue         = 1  
   SET @b_Success          = 0  
   SET @n_Err              = 0  
   SET @c_ErrMsg           = ''  
     
--   SELECT @c_Storerkey = Storerkey  
--   FROM PACKHEADER (NOLOCK)  
--   WHERE Pickslipno = @c_Pickslipno  

  DECLARE @tLabelNo TABLE (LabelNo NVARCHAR(20) )   
  
  SELECT @b_success = 1, @c_errmsg='', @n_err=0   
  SET @nCounter = 0 
  
  WHILE @nCounter <   @n_TotalLabel    
  BEGIN
      
      EXEC isp_GenUCCLabelNo  
          @c_Storerkey,  
          @c_LabelNo OUTPUT,   
          @b_success OUTPUT,  
          @n_err     OUTPUT,  
          @c_errmsg  OUTPUT  
     
      IF @b_Success <> 1  
         SELECT @n_Continue = 3  
         
      INSERT INTO @tLabelNo VALUES ( @c_LabelNo)
        
        SET @nCounter = @nCounter + 1  
  END

   SELECT * FROM @tLabelNo
     
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0       
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt   
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE   
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt   
         BEGIN  
            COMMIT TRAN  
         END            
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL15"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE   
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt   
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END  


GO