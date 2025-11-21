SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: ispPAKCF13                                            */  
/* Creation Date: 23-SEP-2020                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-15217 PH_Novateur_AutoUpdateOrdersDeliveryNote_CR          */  
/*                                                                         */  
/* Called By: PostPackConfirmSP                                            */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/* 06-NOV-2020  CSCHONG 1.1   WMS-15217 bug fix deliverynote not update(CS01)*/
/***************************************************************************/    
CREATE PROC [dbo].[ispPAKCF13]    
(     @c_PickSlipNo  NVARCHAR(10)     
  ,   @c_Storerkey   NVARCHAR(15)  
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
    
   DECLARE @b_Debug           INT  
         , @n_Continue        INT   
         , @n_StartTCnt       INT   
   
   DECLARE @c_Orderkey        NVARCHAR(10)  
         , @c_Country         NVARCHAR(30)  
         , @c_TrackingNo      NVARCHAR(30)  
         , @c_OH_DELNote      NVARCHAR(20) 
         , @c_getdnccikey     NVARCHAR(10)
              
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
   SET @b_Debug  = 0   
   SET @n_Continue = 1    
   SET @n_StartTCnt = @@TRANCOUNT    
    
   IF @@TRANCOUNT = 0  
      BEGIN TRAN  
  
   SELECT  
          @c_Storerkey = O.Storerkey,  
          @c_Orderkey = O.Orderkey,
          @c_OH_DELNote = CASE WHEN ISNULL(C.UDF02,'N') = 'Y' THEN ISNULL(O.deliveryNote,'') ELSE '0000000000' END
   FROM PICKHEADER PH (NOLOCK)  
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey  
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ORDERTYPE' AND C.code = O.type AND C.storerkey = O.Storerkey  --CS01
   WHERE PH.Pickheaderkey = @c_Pickslipno  
    
   IF @n_continue IN(1,2)  
   BEGIN  
       IF ISNULL(@c_OH_DELNote,'') = '' AND @c_OH_DELNote <> '0000000000'
       BEGIN

          EXECUTE nspg_getkey  
               'DN_NCCI'  
               , 10  
               , @c_getdnccikey   OUTPUT  
               , @b_Success       OUTPUT  
               , @n_Err           OUTPUT  
               , @c_ErrMsg        OUTPUT 

               IF @b_Success <> 1                
               BEGIN
                   SELECT @n_Continue = 3   
                   SELECT @n_Err = 38010  
                   SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Getkey(DN_NCCI) Failed. (ispPAKCF13)'           
                   GOTO QUIT_SP
               END

       

      UPDATE ORDERS WITH (ROWLOCK)  
      SET Deliverynote = REPLACE(LTRIM(REPLACE(@c_getdnccikey,'0',' ')),' ','0') 
      WHERE Orderkey = @c_Orderkey  
        
      SET @n_Err = @@ERROR  
                            
      IF @n_Err <> 0  
      BEGIN  
          SELECT @n_Continue = 3   
          SELECT @n_Err = 38010  
          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update ORDERS Table Failed. (ispPAKCF13)'  
          GOTO QUIT_SP 

      END  
    END       
   END       
    
                                                                                                                                  
   QUIT_SP:  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF13'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
        COMMIT TRAN  
      END   
      RETURN  
   END   
END  

GO