SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_TCP_VC_prTaskLUTPrint                          */    
/* Creation Date: 29-Oct-2014                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purposes: This message informs the host system that labels should be */    
/*           printed for the assignment specified in the message.       */    
/*                                                                      */  
/* Parameters Definition:                                               */    
/* @c_Operation                                                         */  
/*        0 = Print chase labels for the assignment                     */  
/*        1 = Print container label for specified system-generated      */  
/*            container ID                                              */  
/* Updates:                                                             */    
/* Date         Author    Purposes                                      */    
/************************************************************************/    
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPrint] (    
    @c_TranDate      NVARCHAR(20)    
   ,@c_DevSerialNo   NVARCHAR(20)    
   ,@c_OperatorID    NVARCHAR(20)    
   ,@c_GroupID       NVARCHAR(100)        
   ,@c_AssignMntID   NVARCHAR(10)     
   ,@c_Operation     INT      -- 0 = Case Label, 1 = System Generated ID          
   ,@c_ContainerID   NVARCHAR(20)  
   ,@n_PrinterNo     INT = 0  
   ,@n_ReprintLabel  INT = 0  -- 0 = Printing labels for the first time   
   ,@n_SerialNo      INT        
   ,@c_RtnMessage    NVARCHAR(500) OUTPUT        
   ,@b_Success       INT = 1 OUTPUT    
   ,@n_Error         INT = 0 OUTPUT    
   ,@c_ErrMsg        NVARCHAR(255) = '' OUTPUT     
    
)    
AS    
BEGIN    
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.    
                                            -- 98: Critical error. If this error is received,     
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.     
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,     
                                            --     but does not force the operator to sign off.    
         , @c_Message            NVARCHAR(400)    
         , @c_AreaKey            NVARCHAR(10)    
         , @c_SuggToLoc          NVARCHAR(10)    
         , @c_LangCode           NVARCHAR(10)           
         , @c_RDTBartenderSP     NVARCHAR(40)    
         , @c_LabelPrinter       NVARCHAR(10)   
         , @n_Func               INT   
         , @n_Mobile             INT  
         , @c_DropID             NVARCHAR(20)           
         , @c_ExecStatements     NVARCHAR(4000)       
         , @c_ExecArguments      NVARCHAR(4000)     
         , @c_Storerkey          NVARCHAR(15)      
                     
                      
   -- Initial Variable Here...  
   SET @n_Func = 20201  
   SET @c_Operation = 0  -- Print chase labels for the assignment  
   SET @c_RDTBartenderSP      = ''    
   SET @c_LabelPrinter        = ''    
        
   SELECT @c_AreaKey   = r.V_String1,     
          @c_SuggToLoc = r.V_Loc,   
          @c_Storerkey = r.StorerKey,   
          @n_Mobile    = r.Mobile,
          @c_DropID    = r.V_CaseID
   FROM RDT.RDTMOBREC r WITH (NOLOCK)    
   WHERE r.UserName = @c_OperatorID     
   AND   r.DeviceID = @c_DevSerialNo    
  
   SELECT @c_LangCode = r.DefaultLangCode             
   FROM rdt.RDTUser r WITH (NOLOCK)   
   WHERE r.UserName = @c_OperatorID    
     
   SELECT @c_LabelPrinter = r.PrinterID     
   FROM rdt.RDTPrinter AS r WITH (NOLOCK)    
   WHERE r.VoicePrinterNo = @n_PrinterNo    
        
  
   SET @c_ErrMsg = ''  
   SET @c_RtnMessage = ''  
     
   SET @c_RDTBartenderSP = ''            
   SET @c_RDTBartenderSP = rdt.RDTGetConfig( @n_Func, 'RDTBartenderSP', @c_Storerkey)         
   


   IF @c_RDTBartenderSP <> ''        
   BEGIN        
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @c_RDTBartenderSP AND type = 'P')        
      BEGIN        
       
         SET @c_ExecStatements = N'EXEC rdt.' + RTRIM( @c_RDTBartenderSP) +         
                                '   @n_Func                 ' +                           
                                ' , @c_LangCode             ' +              
                                ' , @c_LabelPrinter         ' +           
                                ' , @c_DropID               ' +        
                                ' , @c_GroupID              ' +        
                                ' , @c_AssignMntID          ' +  
                                ' , @c_OperatorID           ' +         
                                ' , @n_Error       OUTPUT   ' +        
                                ' , @c_ErrMSG      OUTPUT   '         
         
        SET @c_ExecArguments =         
                  N'@n_Func          int,                ' +            
                   '@c_LangCode      nvarchar(3),        ' +            
                   '@c_LabelPrinter  nvarchar(10),       ' +           
                   '@c_DropID        nvarchar(20),       ' +            
                   '@c_GroupID       nvarchar(20),       ' +  
                   '@c_AssignMntID   nvarchar(10),       ' +      
                   '@c_OperatorID    nvarchar(18),       ' +        
                   '@n_Error         int  OUTPUT,           ' +        
                   '@c_ErrMSG        nvarchar(1024) OUTPUT  '         
                              
                   
        EXEC sp_executesql @c_ExecStatements, @c_ExecArguments,                              
                     @n_Func                                         
                   , @c_LangCode                            
                   , @c_LabelPrinter                    
                   , @c_DropID 
                   , @c_GroupID         
                   , @c_AssignMntID      
                   , @c_OperatorID        
                   , @n_Error       OUTPUT           
                   , @c_ErrMSG      OUTPUT           
                    
           

            IF @n_Error <> 0            
            BEGIN            
               SET @c_ErrMSG = 'Genereate Label Failed'           
            END          
            ELSE  
            BEGIN  
               UPDATE VAD  
               SET  
                  EditDate = GETDATE(),  
                  EditWho = @c_OperatorID,  
                  LabelPrinted = 'Y'  
               FROM VoiceAssignmentDetail VAD   
               JOIN TaskDetail AS td WITH (NOLOCK) ON td.TaskDetailKey = VAD.TaskDetailKey  
               WHERE AssignmentID = @c_AssignMntID  
               AND  VAD.LabelPrinted <> 'Y'   
               AND  td.DropID = @c_DropID   
            END  
            
            
        END        
   END        
  
   SET @c_RtnMessage = ISNULL(@c_ErrorCode, '0') + ',' +     
                       ISNULL(@c_Message,'')    
                                                  
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0     
   BEGIN    
      SET @c_RtnMessage = "0,"    
   END    
     
    
END

GO