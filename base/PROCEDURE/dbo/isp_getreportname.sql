SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: isp_GetReportName                                   */  
/* Creation Date: 19-Nov-2018                                           */  
/* Copyright: LF                                                        */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-6808 - [CN] - D1M - Packing list                        */   
/*                                                                      */  
/* Input Parameters:  @c_storerkey-storerkey, @c_Datawindow - Datawindow*/
/*                    Param01 - Pickslipno,Parm02- CartonNo             */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Usage: Call from isp_PrintToRDTSpooler_Wrapper                       */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */    
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GetReportName] (   
         @c_Storerkey          NVARCHAR(10)  
	  ,  @c_Datawindow         NVARCHAR(40)
	  ,  @c_Param01            NVARCHAR(20)    	  
      ,  @c_Param02            NVARCHAR(20) 
      ,  @c_GetDatawindow      NVARCHAR(40)   OUTPUT )  
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
           
   DECLARE @c_Label_SeqNo NVARCHAR(10)  
          ,@c_vat         NVARCHAR(18)  
           
         , @n_RecCnt       INT       
		 , @c_orderkey     NVARCHAR(20)
		 , @c_Brand        NVARCHAR(40)
		 , @c_long         NVARCHAR(40)
  
   SET @n_StartTCnt        = @@TRANCOUNT  
   SET @n_Continue         = 1  
   SET @b_Success          = 0  
   SET @n_Err              = 0  
   SET @c_ErrMsg           = ''  
   SET @c_long             = ''
  
   SET @n_RecCnt  = 0  
     
   SELECT @c_long = C.long                                         
   FROM PACKHEADER PH (NOLOCK)                                             
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey       
   JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'D1MBrand' AND C.Code = O.UserDefine03
                                  AND C.Storerkey = O.StorerKey                  
   WHERE PH.Pickslipno = @c_Param01  
  

   IF ISNULL(@c_long,'') <> ''
   BEGIN   
      SET @c_GetDatawindow = @c_long      
   END
   ELSE
   BEGIN
    SET @c_GetDatawindow = @c_Datawindow 
   END
   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GetReportName"  
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