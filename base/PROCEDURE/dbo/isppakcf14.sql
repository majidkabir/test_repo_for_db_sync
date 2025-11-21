SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: ispPAKCF14                                            */  
/* Creation Date: 12-NOV-2020                                              */  
/* Copyright: LFL                                                          */  
/* Written by: Wan                                                         */  
/*                                                                         */  
/* Purpose: ADIDAS MALAYSIA-Create to Solve Production Issue Without JIRA  */  
/*                                                                         */  
/* Called By: PostPackConfirmSP                                            */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.3                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author   Ver   Purposes                                     */ 
/* 2020-11-12  Wan      1.0   Creation                                     */ 
/* 2021-08-17  WLChooi  1.1   WMS-17206 - Trigger Interface (WL01)         */
/* 2021-08-17  WLChooi  1.2   DevOps Combine Script                        */  
/* 2021-10-06  WLChooi  1.3   Fix - Immediate trigger label extract web    */
/*                            service (WL02)                               */
/***************************************************************************/    
CREATE PROC [dbo].[ispPAKCF14]    
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
   
   DECLARE @c_Orderkey        NVARCHAR(10) = ''
         , @c_Key2            NVARCHAR(11) = ''
         , @c_OrderGroup      NVARCHAR(50) = ''   --WL01
         , @n_MaxCarton       INT = 0   --WL01
         , @c_trmlogkey       NVARCHAR(10) = ''   --WL02
              
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
   SET @b_Debug  = 0   
   SET @n_Continue = 1    
   SET @n_StartTCnt = @@TRANCOUNT    
    
   IF @@TRANCOUNT = 0  
      BEGIN TRAN  

   SELECT @c_Orderkey = PH.Orderkey
   FROM PACKHEADER PH WITH (NOLOCK)
   WHERE PH.PickSlipNo = @c_PickSlipNo

   SET @c_Key2 = 'O' + @c_Orderkey 
   EXEC ispGenTransmitLog2 'WOLSHPLABLELOG', @c_PickSlipNo, @c_Key2, @c_StorerKey, ''    
         , @b_success OUTPUT    
         , @n_err OUTPUT    
         , @c_errmsg OUTPUT    
                         
   IF @b_success <> 1    
   BEGIN    
      SET @n_continue = 3    
      SET @n_err = 68010    
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +     
                        ': Insert into TRANSMITLOG2 Failed. (ispPAKCF14) ( SQLSvr MESSAGE = ' +     
                        ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '    
      GOTO QUIT_SP  
   END 
   
   --WL01 S
   SELECT @c_OrderGroup = OH.OrderGroup
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PH.Orderkey
   WHERE PH.PickSlipNo = @c_PickSlipNo

   IF @c_OrderGroup = 'aCommerce' AND @c_Storerkey = 'ADIDAS'
   BEGIN
      --WL02 S
      --SELECT @n_MaxCarton = MAX(CartonNo)
      --FROM PACKDETAIL WITH (NOLOCK)
      --WHERE Pickslipno = @c_PickSlipNo

      --EXEC ispGenTransmitLog2 'WSPACFMLOGAC', @c_PickSlipNo, 1, @c_StorerKey, ''    
      --      , @b_success OUTPUT    
      --      , @n_err OUTPUT    
      --      , @c_errmsg OUTPUT    
                            
      --IF @b_success <> 1    
      --BEGIN    
      --   SET @n_continue = 3    
      --   SET @n_err = 68015    
      --   SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +     
      --                     ': Insert into TRANSMITLOG2 Failed. (ispPAKCF14) ( SQLSvr MESSAGE = ' +     
      --                     ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '    
      --   GOTO QUIT_SP  
      --END
      
      SELECT @b_success = 1
      EXECUTE nspg_getkey
         'TransmitlogKey2'
         , 10
         , @c_trmlogkey OUTPUT
         , @b_success   OUTPUT
         , @n_err       OUTPUT
         , @c_errmsg    OUTPUT
           
      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3    
         SET @n_err = 68015    
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +     
                           ': Insert into TRANSMITLOG2 Failed. (ispPAKCF14) ( SQLSvr MESSAGE = ' +     
                           ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '    
         GOTO QUIT_SP
      END
      ELSE
      BEGIN
         INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
         VALUES (@c_trmlogkey, 'WSPACFMLOGAC', @c_Pickslipno, '1', @c_Storerkey, '0', '')

         --For immediate trigger label extract web service 
         IF EXISTS(SELECT 1 FROM QCmd_TransmitlogConfig AS qtc WITH(NOLOCK)
                   WHERE qtc.PhysicalTableName='TRANSMITLOG2' 
                   AND qtc.TableName = 'WSPACFMLOGAC' 
                   AND qtc.StorerKey = @c_Storerkey
                   AND qtc.QCmdClass = 'FRONTEND')
         BEGIN
            SET @n_err = 0 
            EXEC  [dbo].[isp_QCmd_WSTransmitLogInsertAlert] 
                 @c_QCmdClass            = 'FRONTEND'      
               , @c_FrmTransmitlogKey    = @c_trmlogkey 
               , @c_ToTransmitlogKey     = @c_trmlogkey                
               , @b_Debug                = 0            
               , @b_Success              = @b_success OUTPUT                
               , @n_Err                  = @n_err     OUTPUT
               , @c_ErrMsg               = @c_errmsg  OUTPUT
                      
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3    
               SET @n_err = 68020   
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +     
                                 ': EXEC isp_QCmd_WSTransmitLogInsertAlert Failed. (ispPAKCF14) ( SQLSvr MESSAGE = ' +     
                                 ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '    
               GOTO QUIT_SP  
            END                    
         END
      END 
      --WL02 E        
   END
   --WL01 E    
                                                                                                                                
   QUIT_SP:  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF14'  
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