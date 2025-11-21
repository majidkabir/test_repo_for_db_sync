SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF20                                            */
/* Creation Date: 20-Apr-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-19427 - [CN] Nike_PHC_Ecom Packing_Pack Confirm Trigger    */
/*          Refund(S22)                                                    */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 20-Apr-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE PROC [dbo].[ispPAKCF20]  
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
  
   DECLARE @b_Debug           INT = 0
         , @n_Continue        INT 
         , @n_StartTCnt       INT 
 
   DECLARE @c_DeliveryNote    NVARCHAR(50)
         , @c_Status          NVARCHAR(10)
         , @c_SOStatus        NVARCHAR(20)
         , @c_ECPlatform      NVARCHAR(50)
         , @c_Orderkey        NVARCHAR(10)
         , @c_InsertTL2       NVARCHAR(1) = 'N'
         , @c_Tablename       NVARCHAR(20)
         , @c_ECPresale       NVARCHAR(20)   = ''

   DECLARE @c_Command         NVARCHAR(1000) = ''
         , @c_TransmitlogKey  NVARCHAR(10)   = ''
         , @c_IP              VARCHAR(20)    = ''
         , @c_Port            VARCHAR(10)    = ''
         , @n_ThreadPerAcct   INT            = 0
         , @n_MilisecondDelay INT            = 0
         , @c_APP_DB_Name     VARCHAR(30)    = ''
         , @n_ThreadPerStream INT            = 0
         , @c_IniFilePath     NVARCHAR(200)  = ''
         , @c_DataStream      VARCHAR(10)    = '6158'
   
   IF @n_Err > 0
   BEGIN
      SET @b_Debug  = @n_Err
   END

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   IF @@TRANCOUNT = 0
      BEGIN TRAN 
   
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT @c_DeliveryNote  = MAX(ISNULL(OH.DeliveryNote,''))
           , @c_Status        = MAX(OH.[Status]) 
           , @c_SOStatus      = MAX(OH.SOStatus)
           , @c_ECPlatform    = MAX(ISNULL(OH.ECOM_Platform,''))
           , @c_Orderkey      = MAX(OH.OrderKey)
           , @c_Storerkey     = MAX(OH.StorerKey)
           , @c_ECPresale     = MAX(ISNULL(OH.ECOM_PRESALE_FLAG,''))
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.Orderkey
      WHERE PH.PickSlipNo = @c_Pickslipno

      IF @c_Status = '5' AND @c_SOStatus = 'PENDPACK'
      BEGIN
         IF ISNULL(@c_DeliveryNote,'') = '' AND ISNULL(@c_ECPlatform,'') = 'TM'
         BEGIN
            SET @c_InsertTL2 = 'Y'
         END
         ELSE IF ISNULL(@c_DeliveryNote,'') = '30' AND ISNULL(@c_ECPresale,'') = 'PR'
         BEGIN
            SET @c_InsertTL2 = 'Y'
         END
         ELSE
         BEGIN
            SET @c_InsertTL2 = 'N'
         END
      END

      IF @c_InsertTL2 = 'Y'
      BEGIN
         SET @c_Tablename = 'WSPICKCFMBZ'
         SET @c_TransmitlogKey = ''
   
         EXECUTE nspg_getkey  
           'TransmitlogKey2'  
           , 10  
           , @c_TransmitlogKey   OUTPUT  
           , @b_success          OUTPUT  
           , @n_err              OUTPUT  
           , @c_errmsg           OUTPUT  
        
         IF NOT @b_success = 1  
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 64300   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                              + ': Unable to Obtain transmitlogkey. (ispPAKCF20) ( SQLSvr MESSAGE='   
                                + @c_errmsg + ' ) ' 
            GOTO QUIT_SP                     
         END  
      
         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)  
         VALUES (@c_TransmitlogKey, @c_TableName, @c_OrderKey, '5', @c_StorerKey, '0', '') 
         
         IF @@ERROR <> 0          
         BEGIN          
            SET @n_continue = 3  
            SET @c_errmsg = ERROR_MESSAGE()        
            SET @n_err = 64305          
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                          + ': Insert into TRANSMITLOG2 Failed. (ispPAKCF20) '
                          + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '          
            GOTO QUIT_SP          
         END 
   
         SELECT @c_Command = StoredProcName + ',@c_TransmitlogKey=''' + @c_TransmitlogKey + ''' ' 
              , @c_IP = [IP]
              , @c_Port = [Port]
              , @n_ThreadPerAcct = ThreadPerAcct
              , @n_MilisecondDelay = MilisecondDelay 
              , @c_APP_DB_Name = App_DB_Name    --TargetDB      
              , @c_IniFilePath = IniFilePath                
              , @n_ThreadPerStream = ThreadPerStream        
         FROM QCmd_TransmitlogConfig WITH (NOLOCK)  
         WHERE DataStream = @c_DataStream 
            AND TableName = @c_TableName  
            AND StorerKey = @c_StorerKey

         SET @c_Command = REPLACE(@c_Command, 'EXEC ', '')
         SET @c_Command = 'EXEC ' + TRIM(@c_APP_DB_Name) + '.dbo.' + @c_Command
         
         BEGIN TRY    
            EXEC isp_QCmd_SubmitTaskToQCommander     
                  @cTaskType        = 'T'-- D=By Datastream, T=Transmitlog, O=Others           
               ,  @cStorerKey       = @c_StorerKey                                                
               ,  @cDataStream      = @c_DataStream                                                         
               ,  @cCmdType         = 'SQL'                                                      
               ,  @cCommand         = @c_Command                                                  
               ,  @cTransmitlogKey  = @c_TransmitlogKey                                             
               ,  @nThreadPerAcct   = @n_ThreadPerAcct                                                    
               ,  @nThreadPerStream = @n_ThreadPerStream                                                          
               ,  @nMilisecondDelay = @n_MilisecondDelay                                                          
               ,  @nSeq             = 1                           
               ,  @cIP              = @c_IP                                             
               ,  @cPORT            = @c_PORT                                                    
               ,  @cIniFilePath     = @c_IniFilePath           
               ,  @cAPPDBName       = @c_APP_DB_Name                                                   
               ,  @bSuccess         = @b_Success      OUTPUT                                     
               ,  @nErr             = @n_Err          OUTPUT      
               ,  @cErrMsg          = @c_ErrMsg       OUTPUT 
               ,  @nPriority        = 2                                                    
         END TRY    
         BEGIN CATCH  
            SET @n_Continue = 3 
            SET @n_err = 64310   
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                       + ': Error Executing isp_QCmd_SubmitTaskToQCommander. (ispPAKCF20) '
                       + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '    
            GOTO QUIT_SP 
         END CATCH 
      
         IF @n_Err <> 0 AND ISNULL(@c_ErrMsg,'') <> ''    
         BEGIN
            SET @n_Continue = 3 
            SET @n_err = 64315   
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                       + ': ' + @c_errmsg + '. (ispPAKCF20) '
            GOTO QUIT_SP     
         END       
      END   --@c_InsertTL2 = 'Y'        
   END

QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF20'
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