SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/     
/* Copyright: IDS                                                             */     
/* Purpose: BondDPC Integration SP                                            */     
/*                                                                            */     
/* Modifications log:                                                         */     
/*                                                                            */     
/* Date       Rev  Author     Purposes                                        */     
/* 2013-02-15 1.0  Shong      Created                                         */    
/* 2013-12-13 1.1  ChewKP     Allow to Display Alphabet (ChewKP01)            */    
/* 2014-05-19 1.2  Shong      Set LightUp = 1                                 */      
/* 2014-07-14 1.3  ChewKP     Change Message Number                           */    
/* 2014-06-10 1.3  Chee       Add DeviceID when exec isp_DPC_SendMsg (Chee01) */    
/* 2017-02-27 1.4  TLTING     Variable Nvarchar                               */
/******************************************************************************/            
          
CREATE PROC [dbo].[isp_DPC_LightUpLoc]           
(          
   @c_StorerKey NVARCHAR(15)          
  ,@n_PTLKey    BIGINT           
  ,@c_DeviceID  NVARCHAR(20)          
  ,@c_DevicePos NVARCHAR(10)          
  ,@n_LModMode  INT           
  ,@n_Qty       NVARCHAR(5) -- (ChewKP01)    
  ,@b_Success   INT OUTPUT            
  ,@n_Err       INT OUTPUT          
  ,@c_ErrMsg    NVARCHAR(215) OUTPUT          
)          
AS          
BEGIN          
   SET NOCOUNT ON          
             
   DECLARE @c_DeviceIP   CHAR(40),           
           @c_DSPMessage VARCHAR(2000),          
           @n_IsRDT      INT,          
           @n_StartTCnt  INT,          
           @n_Continue   INT,    
           @c_DeviceType NVARCHAR(20)        
                     
                     
   SET @n_StartTCnt = @@TRANCOUNT          
   SET @n_Continue = 1           
         
   BEGIN TRANSACTION       
   SAVE TRAN isp_DPC_LightUpLoc  
  
  
         
             
   IF ISNULL(@n_PTLKey,0) = 0           
   BEGIN          
      SET @n_Err = 90951          
      SET @c_ErrMsg = '90951 - PTLKey Requied'          
      SET @n_Continue=3            
      GOTO EXIT_SP                     
   END          
             
   IF NOT EXISTS(SELECT 1 FROM PTLTran p WITH (NOLOCK)          
                 WHERE p.PTLKey = @n_PTLKey           
                   AND p.[Status]='0')          
   BEGIN          
      SET @n_Err = 90952          
      SET @c_ErrMsg = '90952 - No Record Found in PTLTRAN, PTLKey=' + CAST(@n_PTLKey AS VARCHAR(10))          
      SET @n_Continue=3            
      GOTO EXIT_SP                           
   END          
             
         
       
       
   IF @c_DeviceID <> ''    
   BEGIN        
      SET @c_DeviceIP = ''    
      SELECT   @c_DeviceIP = ISNULL(ll.IPAddress,'')      
             , @c_DeviceType = ll.DeviceType           
      FROM DeviceProfile ll WITH (NOLOCK)    
      WHERE ll.DeviceID = @c_DeviceID     
   END    
          
          
   IF ISNULL(RTRIM(@c_DeviceIP), '') = ''          
   BEGIN          
      SET @n_Err = 90953          
      SET @c_ErrMsg = '90953 - Device Location Not Found in DeviceProfile'          
      SET @n_Continue=3            
      GOTO EXIT_SP               
   END          
   
     
             
   --EXEC dbo.isp_DPC_SendMsg 'LOR', 'LM_LIGHT_UP<TAB>172.26.204.205<TAB>0201<TAB>3<TAB>00005', @b_success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT          
             
   SET @c_DSPMessage = 'LM_LIGHT_UP<TAB>' + RTRIM(@c_DeviceIP) +             
                       '<TAB>' + RTRIM(@c_DevicePos) +             
                       '<TAB>' + CAST(@n_LModMode AS VARCHAR(10)) +             
                       '<TAB>' + RIGHT('     ' + CAST(@n_Qty AS VARCHAR(5)), 5) -- (ChewKP01)      
   EXEC isp_DPC_SendMsg @c_StorerKey, @c_DSPMessage, @b_success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @c_DeviceType    
                        ,@c_DeviceID   -- (Chee01)        
    
  
  
  
   IF @n_Err <> 0     
   BEGIN    
      
      SET @n_Continue=3            
      GOTO EXIT_SP     
   END    
       
          
   UPDATE PTLTran WITH (ROWLOCK)            SET IPAddress = @c_DeviceIP,           
       [Status] = '1',    
       LightUp='1'        
   WHERE PTLKey = @n_PTLKey            
           
   IF @@ERROR <> 0 OR @@ROWCOUNT=0          
   BEGIN          
      SET @n_Err = 90954          
      SET @c_ErrMsg = '71004 - Update PTLTran Failed'          
      SET @n_Continue=3            
      GOTO EXIT_SP                   
   END          
           
           
          
EXIT_SP:          
   IF @n_Continue=3  -- Error Occured - Process And Return            
   BEGIN            
       --DECLARE @n_IsRDT INT            
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT            
                  
      IF @n_IsRDT = 1 -- (ChewKP01)            
      BEGIN            
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here            
          -- Instead we commit and raise an error back to parent, let the parent decide            
                  
          -- Commit until the level we begin with            
          WHILE @@TRANCOUNT > @n_StartTCnt            
             COMMIT TRAN isp_DPC_LightUpLoc            
                  
          -- Raise error with severity = 10, instead of the default severity 16.             
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger            
          RAISERROR (@n_err, 10, 1) WITH SETERROR             
                  
          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten            
      END               
      ELSE            
      BEGIN            
         ROLLBACK TRAN isp_DPC_LightUpLoc         
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_DPC_LightUpLoc'            
                     
         WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started              
         COMMIT TRAN isp_DPC_LightUpLoc       
                     
         RETURN            
      END            
                  
   END            
   ELSE            
   BEGIN            
      WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started              
         COMMIT TRAN isp_DPC_LightUpLoc            
               
      RETURN            
   END                  
END

GO