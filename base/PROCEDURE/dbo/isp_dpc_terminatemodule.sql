SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/     
/* Copyright: IDS                                                             */     
/* Purpose: BondDPC Integration SP                                            */     
/*          This SP is to Terminate All Light By PutawayZone                  */    
/*                                                                            */     
/* Modifications log:                                                         */     
/*                                                                            */     
/* Date       Rev  Author     Purposes                                        */     
/* 2014-02-07 1.0  ChewKP     Created                                         */    
/* 2014-05-15 1.1  Shong      Add Deveice ID when calling isp_DPC_SendMsg     */    
/* 2015-01-30 1.2  ChewKP     LightUp Update by DevicePosition (CheWKP01)     */  
/* 2015-10-27 1.3  ChewKP     Performance Tuning (ChewKP02)                   */
/******************************************************************************/    
    
CREATE PROC [dbo].[isp_DPC_TerminateModule]     
(    
   @c_StorerKey NVARCHAR(15)    
  ,@c_DeviceID  NVARCHAR(20)    
  ,@c_TerminateType NVARCHAR(1)     
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
           @c_PutawayZone  NVARCHAR(10),    
           @c_ZoneDeviceID NVARCHAR(20),    
           @c_DeviceType   NVARCHAR(20),    
           @c_CurrDeviceID NVARCHAR(20),
           @n_PTLKey       INT
               
               
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue = 1             
       
   SET @c_PutawayZone = ''    
       
   BEGIN TRANSACTION    
       
   IF @c_DeviceID <> ''    
   BEGIN        
      SET @c_DeviceIP = ''    
      SELECT @c_DeviceIP = ISNULL(ll.IPAddress,'')      
      FROM DeviceProfile ll WITH (NOLOCK)    
      WHERE ll.DeviceID = @c_DeviceID     
          
      SELECT @c_PutawayZone = PutawayZone    
      FROM dbo.Loc  WITH (NOLOCK)  
      WHERE Loc = @c_DeviceID    
   END    
       
       
    
   IF ISNULL(RTRIM(@c_DeviceIP), '') = ''    
   BEGIN    
      SET @n_Err = 85701    
      SET @c_ErrMsg = '85701 - Device Not Found in DeviceProfile'    
      SET @n_Continue=3      
      GOTO EXIT_SP         
   END    
       
   IF @c_TerminateType = '0'    
   BEGIN    
      DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
              
      SELECT D.DevicePosition, D.DeviceType, D.DeviceID    
      FROM dbo.DeviceProfile D WITH (NOLOCK)    
      INNER JOIN dbo.LOC Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID    
      WHERE D.IPAddress = @c_DeviceIP    
      AND Loc.PutawayZone = @c_PutawayZone    
   END     
   ELSE    
   BEGIN    
      DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
              
      SELECT D.DevicePosition, D.DeviceType, D.DeviceID      
      FROM dbo.DeviceProfile D WITH (NOLOCK)    
      INNER JOIN dbo.LOC Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID    
      WHERE D.IPAddress = @c_DeviceIP    
      AND Loc.PutawayZone = @c_PutawayZone    
      AND D.DeviceID = @c_DeviceID    
          
   END    
       
   OPEN CursorPTLTranLightUp                
       
   FETCH NEXT FROM CursorPTLTranLightUp INTO @c_ZoneDeviceID, @c_DeviceType, @c_CurrDeviceID    
       
   WHILE @@FETCH_STATUS <> -1         
   BEGIN    
  
        
  
  
      -- By SHONG     
      -- Comment this section when not working    
      IF EXISTS(SELECT 1 FROM PTLTRAN WITH (NOLOCK)     
                WHERE DeviceID = @c_CurrDeviceID     
                AND DevicePosition = @c_ZoneDeviceID -- (ChewKP01)  
                AND LightUp='1')    
      BEGIN    
   
  
         SET @c_DSPMessage = 'MODULE_TERMINATE<TAB>' + RTRIM(@c_DeviceIP) + '<TAB>' + RTRIM(@c_ZoneDeviceID)    
         EXEC isp_DPC_SendMsg @c_StorerKey, @c_DSPMessage, @b_success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT,     
              @c_DeviceType    
         
         -- (ChewKP02) 
         DECLARE CurPTLTran CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
              
         SELECT PTLKey 
         FROM dbo.PTLTran WITH (NOLOCK)
         WHERE DeviceID = @c_CurrDeviceID   
         AND DevicePosition = @c_ZoneDeviceID  -- (ChewKP01)  
         AND LightUp='1'       
         
         OPEN CurPTLTran                
       
         FETCH NEXT FROM CurPTLTran INTO @n_PTLKey 
             
         WHILE @@FETCH_STATUS <> -1         
         BEGIN    
            
            UPDATE PTLTRAN WITH (ROWLOCK)    
               SET LightUp='0'     
            WHERE PTLKey = @n_PTLKey
            
            FETCH NEXT FROM CurPTLTran INTO @n_PTLKey
                        
         END
         CLOSE CurPTLTran                
         DEALLOCATE CurPTLTran    
      END    
          
      FETCH NEXT FROM CursorPTLTranLightUp INTO @c_ZoneDeviceID, @c_DeviceType, @c_CurrDeviceID    
   END    
   CLOSE CursorPTLTranLightUp                
   DEALLOCATE CursorPTLTranLightUp    
    
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
             COMMIT TRAN      
            
          -- Raise error with severity = 10, instead of the default severity 16.       
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger      
          RAISERROR (@n_err, 10, 1) WITH SETERROR       
            
          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten      
      END         
      ELSE      
      BEGIN      
         ROLLBACK TRAN      
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_DPC_TerminateModule'      
               
         WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started        
         COMMIT TRAN      
               
         RETURN      
      END      
            
   END      
   ELSE      
   BEGIN      
      WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started        
         COMMIT TRAN      
         
      RETURN      
   END            
END    
    
  

GO