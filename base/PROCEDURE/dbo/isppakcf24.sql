SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF24                                            */
/* Creation Date: 07-Aug-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-23311 - CN Chargeurs Pack confirm re-send transmitlog3 for */
/*          Repack                                                         */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 07-AUG-2023  NJOW    1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE   PROC [dbo].[ispPAKCF24]  
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
         , @c_Orderkey        NVARCHAR(10) = ''
         , @c_TransmitlogKey  NVARCHAR(10)
         , @c_TableName       NVARCHAR(30)
         , @c_Storererkey     NVARCHAR(15)
         , @c_Facility        NVARCHAR(5)
         , @c_Option5         NVARCHAR(1000)         
         , @c_TransmitlogNo   NVARCHAR(5)         
    
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT   

   IF @@TRANCOUNT = 0
      BEGIN TRAN 
   
   IF @n_Continue IN(1,2)
   BEGIN
      SELECT @c_Orderkey = PH.Orderkey, 
             @c_Storerkey = O.Storerkey,
             @c_Facility = O.Facility
   	  FROM PACKHEADER PH (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   	  WHERE PH.Pickslipno = @c_Pickslipno
   	  AND PH.PackStatus = 'REPACK'   	
   	     	     	     	  
   	  IF ISNULL(@c_Orderkey,'') <> ''
   	  BEGIN         
         SELECT @c_Option5 = SC.Option5
         FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'PostPackConfirmSP') AS SC   	  
         
         SET @c_Tablename = 'PICKCFMLOG'            
         SET @c_TransmitlogNo = '3'
         
         SELECT @c_TableName = dbo.fnc_GetParamValueFromString('@c_TransmitLogTableName', @c_Option5, @c_TableName)
         SELECT @c_TransmitlogNo = dbo.fnc_GetParamValueFromString('@c_TransmitLogNo', @c_Option5, @c_TransmitlogNo)
         
         IF @c_TransmitlogNo = '2'
         BEGIN
            SELECT @c_TransmitlogKey = Transmitlogkey 
            FROM TRANSMITLOG2 (NOLOCK)
            WHERE tablename = @c_Tablename
            AND Key1 = @c_Orderkey
            AND Key2 = ''
            AND Key3 = @c_Storerkey
         END
         ELSE
         BEGIN
            SELECT @c_TransmitlogKey = Transmitlogkey 
            FROM TRANSMITLOG3 (NOLOCK)
            WHERE tablename = @c_Tablename
            AND Key1 = @c_Orderkey
            AND Key2 = ''
            AND Key3 = @c_Storerkey
         END
         
         IF ISNULL(@c_Transmitlogkey,'') <> ''
         BEGIN
         	  IF @c_TransmitlogNo = '2'
         	  BEGIN
               UPDATE TRANSMITLOG2 WITH (ROWLOCK)
               SET transmitflag = '0',
                   TrafficCop  = NULL
               WHERE Transmitlogkey = @c_Transmitlogkey
            END                                   
            ELSE
            BEGIN
               UPDATE TRANSMITLOG3 WITH (ROWLOCK)
               SET transmitflag = '0',
                   TrafficCop  = NULL
               WHERE Transmitlogkey = @c_Transmitlogkey
            END
         
            IF @@ERROR <> 0          
            BEGIN          
               SET @n_continue = 3  
               SET @c_errmsg = ERROR_MESSAGE()        
               SET @n_err = 64310          
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                             + ': Update TRANSMITLOG' + @c_TransmitlogNo + ' Failed. (ispPAKCF24) '
                             + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '          
               GOTO QUIT_SP          
            END                                        
         END
         ELSE
         BEGIN                         
         	  IF @c_TransmitlogNo = '2'                
         	  BEGIN
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
                  SET @n_Err = 64320   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                                    + ': Unable to Obtain transmitlogkey. (ispPAKCF24) ( SQLSvr MESSAGE='   
                                      + @c_errmsg + ' ) ' 
                  GOTO QUIT_SP                     
               END     	     
               
               INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)  
               VALUES (@c_TransmitlogKey, @c_TableName, @c_Orderkey, '', @c_StorerKey, '0', '')              
            END   
            ELSE
            BEGIN
               EXECUTE nspg_getkey  
                 'TransmitlogKey3'  
                 , 10  
                 , @c_TransmitlogKey   OUTPUT  
                 , @b_success          OUTPUT  
                 , @n_err              OUTPUT  
                 , @c_errmsg           OUTPUT  
               
               IF NOT @b_success = 1  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_Err = 64320   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                                    + ': Unable to Obtain transmitlogkey. (ispPAKCF24) ( SQLSvr MESSAGE='   
                                      + @c_errmsg + ' ) ' 
                  GOTO QUIT_SP                     
               END     	     
               
               INSERT INTO TRANSMITLOG3 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)  
               VALUES (@c_TransmitlogKey, @c_TableName, @c_Orderkey, '', @c_StorerKey, '0', '')              
            END
         END
         
         IF @@ERROR <> 0          
         BEGIN          
            SET @n_continue = 3  
            SET @c_errmsg = ERROR_MESSAGE()        
            SET @n_err = 64330          
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                          + ': Insert into TRANSMITLOG' + @c_TransmitlogNo + ' Failed. (ispPAKCF24) '
                          + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '          
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF24'
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