SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/*****************************************************************************/                  
/* Store procedure: ispWCSRO01                                               */                  
/* Copyright      : IDS                                                      */                  
/*                                                                           */                  
/* Purpose: Sub-SP to insert WCSRouting records                              */                  
/*                                                                           */                  
/* Modifications log:                                                        */                  
/*                                                                           */                  
/* Date       Rev  Author   Purposes                                         */                  
/* 2014-03-17 1.0  ChewKP   Created                                          */         
/* 2014-05-27 1.1  ChewKP   Cater for PTS Delete (ChewKP01)                  */       
/* 2014-07-02 1.2  ChewKP   DTC Update (ChewKP02)                            */ 
/*****************************************************************************/                  
CREATE PROC [dbo].[ispWCSRO01]                  
@c_StorerKey     NVARCHAR(15) ,                  
@c_Facility      NVARCHAR(10) ,                  
@c_ToteNo        NVARCHAR(20) ,                  
@c_TaskType      NVARCHAR(10) , -- TaskType = 1810 = Direct from RDT Tote Conveyor Move      
@c_ActionFlag    NVARCHAR(1)  , -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual, C = Complete          
@c_TaskDetailKey NVARCHAR(10)  = '' ,               
@c_Username      NVARCHAR(18) ,       
@c_RefNo01       NVARCHAR(60)  = '',  -- WCSTATION if direct from 1810      
@c_RefNo02       NVARCHAR(60)  = '',       
@c_RefNo03       NVARCHAR(60)  = '',      
@c_RefNo04       NVARCHAR(60)  = '',      
@c_RefNo05       NVARCHAR(60)  = '',      
@b_debug         INT     = 0  ,      
@c_LangCode      NVARCHAR(3)  ,      
@n_Func          INT          ,               
@b_Success       INT         OUTPUT,                  
@n_ErrNo         INT         OUTPUT,                
@c_ErrMsg        NVARCHAR(20) OUTPUT                 
AS                  
BEGIN                
  SET NOCOUNT ON                  
  SET ANSI_NULLS OFF  
  SET QUOTED_IDENTIFIER OFF  
  SET CONCAT_NULL_YIELDS_NULL OFF              
                    
  DECLARE @n_continue  INT,                   
          @n_starttcnt INT                  
                  
  DECLARE @c_StoreGroup   NVARCHAR(20),                  
          @c_FinalWCSZone NVARCHAR(10),                  
          @c_WCSKey       NVARCHAR(10),                  
          @c_ToLOC        NVARCHAR(10),                  
          @c_WCSStation   NVARCHAR(20),                
          @c_WaveKey      NVARCHAR(10),      
          @c_InsertActionFlag NVARCHAR(1),      
          @c_ConsigneeKey NVARCHAR(15),       
          @c_PutawayZone  NVARCHAR(10),      
          @c_OriActionFlag NVARCHAR(1),    
          @c_LoadKey       NVARCHAR(10),   
          @c_TaskToLoc     NVARCHAR(10),
          @c_DetailInsertActionFlag NVARCHAR(1),
          @c_SourceType    NVARCHAR(30),
          @c_DPPToLoc      NVARCHAR(10),
          @c_PickMethod    NVARCHAR(10),
          @n_CountTask     INT,
          @c_OrderKey      NVARCHAR(10),
          @c_AreaKey       NVARCHAR(10),
          @c_DPPFromLoc    NVARCHAR(10),
          @c_CloseTote     NVARCHAR(1) 
            
             
                       
                    
  DECLARE @n_RowRef       INT                  
                  
  SELECT @n_Continue = 1,                 
         @b_success = 1,                 
         @n_starttcnt=@@TRANCOUNT,                 
         @c_ErrMsg='',                 
         @n_ErrNo = 0                
                           
  --SET @c_OrderGroup   = ''        
  SET @c_FinalWCSZone = ''           
  SET @c_WCSStation   = ''        
  SET @c_WaveKey      = ''          
  SET @c_InsertActionFlag = ''      
  SET @c_WCSKey       = ''      
  SET @c_TaskToLoc    = ''
  SET @c_DetailInsertActionFlag = ''
  
        
  BEGIN TRAN      
   
  
         
  IF NOT EXISTS ( SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)      
                  WHERE StorerKey = @c_StorerKey       
                  AND ConfigKey = 'WCS'      
                  AND SValue = '1' )       
  BEGIN      
      GOTO Quit_SP      
  END       
  
  -- Delete Existing Routing Before Insert --
  
  IF ISNULL(@c_TaskDetailKey,'') <> ''
  BEGIN
     SELECT  @c_WaveKey     = WaveKey    
           , @c_TaskToLoc   = ToLoc  
           , @c_SourceType  = SourceType
           , @c_DPPToLoc    = ToLoc
           , @c_PickMethod  = PickMethod -- (ChewKP02) 
     FROM dbo.TaskDetail WITH (NOLOCK)      
     WHERE TaskDetailKey = @c_TaskDetailKey      
     AND StorerKey = @c_StorerKey      
  END
  ELSE
  BEGIN
     SET @c_PickMethod = @c_RefNo02
     SET @C_OrderKey   = @c_RefNo03
     SET @c_AreaKey    = @c_RefNo04
     SET @c_CloseTote  = @c_RefNo05
  END
    
  IF @c_TaskType = 'SPK'    
  BEGIN    
    SET @c_LoadKey = @c_RefNo01    
    
    SELECT Top 1 @c_WaveKey = UserDefine09 
    FROM dbo.Orders WITH (NOLOCK) 
    WHERE LoadKey = @c_LoadKey 
    AND StorerKey = @c_StorerKey 
    
  END   




        
  SELECT TOP 1  @c_StoreGroup = CASE WHEN O.Type = 'N' THEN O.OrderGroup + O.SectionKey ELSE 'OTHERS' END      
             , @c_ConsigneeKEy = OD.UserDefine02      
  FROM dbo.PickDetail PD WITH (NOLOCK)           
  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey AND O.StorerKey = PD.StorerKey          
  INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey      
  WHERE PD.DropID  = @c_ToteNo          
  AND PD.StorerKey = @c_StorerKey      
  AND PD.TaskDetailKey = CASE WHEN ISNULL(@c_TaskDetailKey,'')  <> '' THEN ISNULL(@c_TaskDetailKey,'')  ELSE PD.TaskDetailKey END    
  AND O.LoadKey = CASE WHEN ISNULL(@c_LoadKey,'') <> '' THEN ISNULL(@c_LoadKey,'') ELSE O.LoadKey END    
  AND PD.CaseID = ''
            
        
  SELECT @c_ToLoc = Loc       
  FROM StoreToLocDetail WITH (NOLOCK)      
  WHERE ConsigneeKey = @c_ConsigneeKey       
  AND StoreGroup = @c_StoreGroup      
  
  

  IF @c_SourceType = 'RPF' -- PA Task FROM RPF
  BEGIN                  
     SELECT @c_PutawayZone = PutawayZone       
     FROM dbo.Loc WITH (NOLOCK)       
     WHERE Loc = @c_DPPToLoc       

  END      
  ELSE
  BEGIN      
     SELECT @c_PutawayZone = PutawayZone       
     FROM dbo.Loc WITH (NOLOCK)       
     WHERE Loc = @c_ToLoc      
  END
   
        
  IF @c_TaskType = 'RPF'      
  BEGIN          
    
            

       SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')
       FROM CODELKUP WITH (NOLOCK)                  
       WHERE Listname = 'WCSSTATION'                  
       AND   Code = @c_PutawayZone       

  END             
  ELSE IF @c_TaskType = 'PTS'      
  BEGIN      
           
   

       SET @c_WCSStation = @c_RefNo01
       
       IF @c_ActionFlag = 'D'
       BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                     WHERE ToteNo = @c_ToteNo
                     AND TaskType = @c_TaskType 
                     AND StorerKey = @c_StorerKey 
                     AND ActionFlag = 'D') 
         BEGIN
            GOTO  QUIT_SP
         END                     
                     
      END  
       
       
           
           
  END      
  ELSE IF @c_TaskType = 'PA'      
  BEGIN      

     SELECT @c_PutawayZone = PutawayZone       
     FROM dbo.Loc WITH (NOLOCK)       
     WHERE Loc = ISNULL(RTRIM(@c_TaskToLoc),'') 
  
     
     SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')                  
     FROM CODELKUP WITH (NOLOCK)                  
     WHERE Listname = 'WCSSTATION'                  
     AND   Code = @c_PutawayZone       
           
         
           
  END                  
  ELSE IF @c_TaskType = 'SPK'      
  BEGIN      
     
     
     SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')                  
     FROM CODELKUP WITH (NOLOCK)                  
     WHERE Listname = 'WCSSTATION'                  
     AND   Code = @c_PutawayZone   
     
     IF EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                WHERE ToteNo = @c_ToteNo 
                AND Initial_Final_Zone <> @c_WCSStation
                AND Status = '0' ) 
     BEGIN
      
         UPDATE dbo.WCSrouting WITH (ROWLOCK) 
         SET Status = '9'
         WHERE ToteNo = @c_ToteNo 
         AND Initial_Final_Zone NOT IN (  @c_WCSStation , 'C01' ) 
         AND Status = '0'         
         
         IF @@ERROR <> 0 
         BEGIN
             SET    @n_continue = 3                  
             SET    @n_ErrNo = 85966                   
             SET    @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo ,@c_LangCode ,'DSP') --'UpdWCSFail'             
             GOTO Quit_SP    
         END
         
     END                
     
     IF @c_ActionFlag = 'N'
     BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                     WHERE ToteNo = @c_ToteNo
                     AND Initial_Final_Zone = @c_WCSStation
                     AND Status = '0' ) 
         BEGIN
            GOTO  QUIT_SP
         END                     
                     
     END  
     ELSE IF @c_ActionFlag = 'S'
     BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                     WHERE ToteNo = @c_ToteNo
                     AND Initial_Final_Zone = 'C01'
                     AND Status = '0' ) 
         BEGIN
            -- Check If there is Open Orders 
            GOTO QUIT_SP
         END  
     END
     ELSE IF @c_ActionFlag = 'D'
     BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                     WHERE ToteNo = @c_ToteNo
                     AND ActionFlag = 'D'  ) 
         BEGIN
             IF EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                        WHERE ToteNo = @c_ToteNo
                        AND Status = '0')
             BEGIN                     
               GOTO QUIT_SP
             END
         END  
     END
     
       
           
           
  END         
  ELSE IF @c_TaskType = '1810'      
  BEGIN      
    SET @c_WCSStation = @c_RefNo01      
  END      
  ELSE IF @c_TaskType = 'PK' -- (ChewKP02)
  BEGIN
     
     INSERT INTO TraceInfo (TraceName , timeIn , col1 , col2, col3, col4, col5  )      
     VALUES ('WCS' , GETDATE() , 'PK', @c_CloseTote ,@c_PickMethod,  @c_OrderKey, @c_ToteNo )    
  
     IF @c_CloseTote = '1'
     BEGIN
         IF ISNULL(RTRIM(@c_PickMethod),'')  = 'SINGLES'
         BEGIN
            SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')                  
            FROM CODELKUP WITH (NOLOCK)                  
            WHERE Listname = 'WCSSTATION'                  
            AND   Code = 'SINGLES'
         END
         ELSE IF ISNULL(RTRIM(@c_PickMethod),'')  = 'MULTIS'
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                         WHERE StorerKey = @c_StorerKey
                         AND OrderKey = @c_OrderKey
                         --AND DropID <> ''
                         GROUP BY OrderKey 
                         HAVING COUNT (DISTINCT DROPID ) > 1
                          ) 
             BEGIN            
                SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')
                FROM CODELKUP WITH (NOLOCK)                  
                WHERE Listname = 'WCSSTATION'                  
                AND   Code = 'MULTISG'
             END
             ELSE
             BEGIN
                SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')
                FROM CODELKUP WITH (NOLOCK)                  
                WHERE Listname = 'WCSSTATION'                  
                AND   Code = 'MULTIS'
             END
         END
         GOTO CONTINUE_PROCESS
     END



     IF ISNULL(RTRIM(@c_PickMethod),'')  = 'SINGLES'
     BEGIN
        SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')                  
        FROM CODELKUP WITH (NOLOCK)                  
        WHERE Listname = 'WCSSTATION'                  
        AND   Code = 'SINGLES'
     END
     ELSE IF ISNULL(RTRIM(@c_PickMethod),'')  = 'MULTIS'
     BEGIN
        
        


        SELECT @n_CountTask = Count ( DISTINCT AreaKey ) 
        FROM dbo.TaskDetail WITH (NOLOCK)
        WHERE TaskType   = 'PK'
          AND PickMethod = 'MULTIS'
          AND DropID     = @c_ToteNo 
          AND Status     IN ( '0', '3'  ) 
          AND OrderKey   = @c_OrderKey
          
          
        

        IF @n_CountTask = 1 OR  ISNULL(@n_CountTask,0 )  = 0 
        BEGIN 
          IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                      WHERE StorerKey = @c_StorerKey
                      AND OrderKey = @c_OrderKey
                      AND DropID <> ''
                      GROUP BY OrderKey 
                      HAVING COUNT (DISTINCT DROPID ) > 1
                       ) 
          BEGIN            
             SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')
             FROM CODELKUP WITH (NOLOCK)                  
             WHERE Listname = 'WCSSTATION'                  
             AND   Code = 'MULTISG'
          END
          ELSE
          BEGIN
             SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')
             FROM CODELKUP WITH (NOLOCK)                  
             WHERE Listname = 'WCSSTATION'                  
             AND   Code = 'MULTIS'
          END
        END 
        ELSE IF @n_CountTask > 1 
        BEGIN
           
           SELECT Top 1 @c_DPPFromLoc = FromLoc
           FROM dbo.TaskDetail WITH (NOLOCK) 
           WHERE DropID = @c_ToteNo
           AND OrderKey = @c_OrderKey
           AND AreaKey  <> @c_AreaKey 
           AND Status <> '9'
           Order by AreaKey

           SELECT Top 1 @c_PutawayZone = PutawayZone       
           FROM dbo.Loc WITH (NOLOCK)       
           WHERE Loc = @c_DPPFromLoc  
           
           SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')                  
           FROM CODELKUP WITH (NOLOCK)                  
           WHERE Listname = 'WCSSTATION'                  
           AND   Code = @c_PutawayZone      
        END

        
     END
      
     CONTINUE_PROCESS:

     IF EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                WHERE ToteNo = @c_ToteNo 
                AND Initial_Final_Zone <> @c_WCSStation
                AND Status = '0' ) 
     BEGIN
      
         UPDATE dbo.WCSrouting WITH (ROWLOCK) 
         SET Status = '9'
         WHERE ToteNo = @c_ToteNo 
         AND Initial_Final_Zone NOT IN (  @c_WCSStation , 'C01' ) 
         AND Status = '0'         
         
         IF @@ERROR <> 0 
         BEGIN
             SET    @n_continue = 3                  
             SET    @n_ErrNo = 85966                   
             SET    @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo ,@c_LangCode ,'DSP') --'UpdWCSFail'             
             GOTO Quit_SP    
         END
         
     END                
     
     IF @c_ActionFlag = 'N'
     BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                     WHERE ToteNo = @c_ToteNo
                     AND Initial_Final_Zone = @c_WCSStation
                     AND Status = '0' ) 
         BEGIN
            GOTO  QUIT_SP
         END                     
                     
     END  
     ELSE IF @c_ActionFlag = 'S'
     BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                     WHERE ToteNo = @c_ToteNo
                     AND Initial_Final_Zone = 'C01'
                     AND Status = '0' ) 
         BEGIN
            -- Check If there is Open Orders 
            GOTO QUIT_SP
         END  
     END
     ELSE IF @c_ActionFlag = 'D'
     BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                     WHERE ToteNo = @c_ToteNo
                     AND ActionFlag = 'D'  ) 
         BEGIN
             IF EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)
                        WHERE ToteNo = @c_ToteNo
                        AND Status = '0')
             BEGIN                     
               GOTO QUIT_SP
             END
         END  
     END
     
  END
  ELSE IF @c_TaskType = 'KIT'      
  BEGIN      
   
     
     SELECT @c_PutawayZone = PutawayZone       
     FROM dbo.Loc WITH (NOLOCK)       
     WHERE Loc = ISNULL(RTRIM(@c_RefNo01),'') 
  
     
     SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')                  
     FROM CODELKUP WITH (NOLOCK)                  
     WHERE Listname = 'WCSSTATION'                  
     AND   Code = @c_PutawayZone  
      
  END
     
  INSERT INTO TraceInfo (TraceName , timeIn , col1 , col2, col3, col4  )      
  VALUES ('WCS' , GETDATE() , '1', @c_WCSStation ,@c_ActionFlag,  @c_WCSKey )       
        

  INSERT INTO TraceInfo (TraceName , timeIn , col1 , col2, col3, col4  )      
  VALUES ('WCS' , GETDATE() , '2', @c_WCSStation ,@c_ActionFlag,  @c_WCSKey )       
        
  IF @c_TaskType = '1810' AND @c_WCSStation = ''      
  BEGIN      
     SET @c_ActionFlag = 'D'      
  END      
  ELSE IF @c_TaskType = '1810'      
  BEGIN      
       IF @c_ActionFlag = 'D'     
       BEGIN     
           SET @c_OriActionFlag = @c_ActionFlag                
           SET @c_ActionFlag = 'N'      
       END    
    
  END      
  ELSE IF @c_TaskType <> '1810'    
  BEGIN      
         

     IF @c_ActionFlag <> 'S' AND @c_ActionFlag <> 'D'  -- (ChewKP01)
     BEGIN    
         IF @c_TaskType IN ( 'SPK', 'PK') AND @c_ActionFlag = 'F'
         BEGIN
            SET @c_ActionFlag = 'N'      
         END
         ELSE
         BEGIN
            SET @c_ActionFlag = 'N'      
         END
         
     END    
         
  END      
        
  INSERT INTO TraceInfo (TraceName , timeIn , col1 , col2, col3, col4  )      
  VALUES ('WCS' , GETDATE() , '3', @c_WCSStation ,@c_ActionFlag,  @c_WCSKey )       
        
            
                
      
       
  IF @c_ActionFlag = 'N'      
  BEGIN      
       --SET @c_InsertActionFlag = 'I' 
       
       
       IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK) 
                   WHERE ToteNo = @c_ToteNo
                   AND Status = '0'
                   AND Final_Zone <> @c_WCSStation ) 
       BEGIN
            SET @c_InsertActionFlag = 'U'      
       END 
       ELSE
       BEGIN                     
            SET @c_InsertActionFlag = 'I'      
       END 
       
       SET @c_DetailInsertActionFlag = 'I'
       
          
       
             
       EXECUTE nspg_GetKey                  
             'WCSKey',                  
             8,                     
             @c_WCSKey      OUTPUT,                  
             @b_success     OUTPUT,                  
             @n_ErrNo       OUTPUT,                  
             @c_ErrMsg      OUTPUT                  
                  
                  
       IF @n_ErrNo <> 0                   
       BEGIN                  
          SET    @n_continue = 3                  
          SET    @n_ErrNo = 85951                   
          SET    @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo ,@c_LangCode ,'DSP') --'GetWCSKeyFail'             
          GOTO Quit_SP                  
       END             
           
          INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, WaveKey, TaskType)                  
          VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''), ISNULL(@c_WCSStation,''), @c_InsertActionFlag,  @c_StorerKey, @c_Facility, @c_WaveKey, @c_TaskType) -- Insert                  
             
       IF @@ERROR  <> 0                   
       BEGIN                  
           SET @n_continue = 4                  
           SET @n_ErrNo = 85952                  
           SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo ,@c_LangCode ,'DSP') --'InsWCSFail'                 
           GOTO Quit_SP
       END                 
             
       IF @c_OriActionFlag = 'D'    
       BEGIN    
          INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)                  
          VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''), @c_OriActionFlag) -- Insert                  
       END    
       ELSE      
       BEGIN    
         INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)                  
         VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''), @c_DetailInsertActionFlag) -- Insert                  
           
       END      
       IF @@ERROR <> 0                   
       BEGIN                  
           SELECT @n_continue = 3                  
           SELECT @n_ErrNo = 85953                  
           SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + 'InsWCSDetFail'                  
           GOTO Quit_SP                
       END                  
       
       
       
                            
       
  END      
  ELSE IF @c_ActionFlag = 'S'      
  BEGIN      

     
     SELECT @c_FinalWCSZone = Short           
     FROM dbo.CodeLkup WITH (NOLOCK)          
     WHERE Listname = 'WCSROUTE'          
     AND Code = 'QC'         
         
                  
     SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')                  
     FROM CODELKUP WITH (NOLOCK)                  
     WHERE Listname = 'WCSSTATION'                  
     AND   Code = @c_FinalWCSZone  
     
     IF EXISTS ( SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK) 
                 WHERE ToteNo = @c_ToteNo
                 AND Status = '0'
                 AND Final_Zone <> @c_WCSStation ) 
     BEGIN
         SET @c_InsertActionFlag = 'U'      
     END 
     ELSE
     BEGIN                     
         SET @c_InsertActionFlag = 'I'      
     END 
     
           
     EXECUTE nspg_GetKey                  
           'WCSKey',                  
           8,                     
           @c_WCSKey      OUTPUT,                  
           @b_success     OUTPUT,                  
           @n_ErrNo       OUTPUT,                  
           @c_ErrMsg      OUTPUT                  
                
                
     IF @n_ErrNo <> 0                   
     BEGIN                  
        SET    @n_continue = 3        
        SET    @n_ErrNo = 85955                   
        SET    @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo ,@c_LangCode ,'DSP') --'GetWCSKeyFail'             
        GOTO Quit_SP                  
     END             
           
     INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, WaveKey, TaskType)                  
     VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''), ISNULL(@c_WCSStation,''), @c_InsertActionFlag,  @c_StorerKey, @c_Facility, @c_WaveKey, @c_TaskType) -- Insert                  
           
     IF @@ERROR  <> 0                   
     BEGIN                  
         SET @n_continue = 3
         SET @n_ErrNo = 85956                  
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo ,@c_LangCode ,'DSP') --'InsWCSFail'                 
         GOTO Quit_SP                  
     END           
           
     INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)                  
     VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''), 'I') -- Insert                  
             
             
     IF @@ERROR <> 0                   
     BEGIN                  
           SELECT @n_continue = 3                  
           SELECT @n_ErrNo = 85965      
           SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + 'InsWCSDetFail'                  
           GOTO Quit_SP                  
     END         
          
           
           
           
  END      
  ELSE IF @c_ActionFlag = 'D'      
  BEGIN      
     SET @c_InsertActionFlag = 'D'      
           
                    
             EXECUTE nspg_GetKey                  
             'WCSKey',                  
             8,                     
             @c_WCSKey      OUTPUT,                  
             @b_success     OUTPUT,                  
             @n_ErrNo       OUTPUT,                  
             @c_ErrMsg      OUTPUT                  
                  
                  
             IF @n_ErrNo <> 0                   
             BEGIN                  
                SET    @n_continue = 3                  
                SET    @n_ErrNo = 85958               
                SET    @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo ,@c_LangCode ,'DSP') --'GetWCSKeyFail'             
                GOTO Quit_SP                  
             END             
                   
             INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, WaveKey, TaskType, Status)                  
             VALUES (@c_WCSKey, @c_ToteNo, '', '', @c_InsertActionFlag,  @c_StorerKey, @c_Facility, @c_WaveKey, @c_TaskType,  '9') -- Insert                  
                   
             IF @@ERROR  <> 0                   
             BEGIN                  
                 SET @n_continue = 4                  
                 SET @n_ErrNo = 85959              
                 SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo ,@c_LangCode ,'DSP') --'InsWCSFail'                 
                 GOTO Quit_SP                  
             END             

  END      
  ELSE IF @c_ActionFlag = 'U'      
  BEGIN      
            
      UPDATE dbo.WCSRouting       
      SET ActionFlag = @c_ActionFlag       
      WHERE WCSKey = @c_WCSKey      
            
      IF @@ERROR <> 0       
      BEGIN      
           SELECT @n_continue = 3                  
           SELECT @n_ErrNo = 85964      
           SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + 'UpdWCSFail'             
      END      
            
            INSERT INTO TraceInfo (TraceName , timeIn , col1 , col2, col3, col4  )      
            VALUES ('WCS' , GETDATE() , '4', @c_WCSStation ,@c_ActionFlag,  @c_WCSKey )       
            
      IF @c_OriActionFlag = 'D'      
      BEGIN      
          IF NOT EXISTS ( SELECT 1 FROM dbo.WCSRoutingDetail WITH (NOLOCK)       
                          WHERE WCSKey = @c_WCSKey       
                          AND ToteNo = @c_ToteNo      
                          AND ActionFlag = 'D'      
                          AND Zone  = ISNULL(@c_WCSStation,''))       
          BEGIN      
             INSERT INTO dbo.WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)                  
             VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''), 'D') -- DELETE              
          END      
      END      
      ELSE IF @c_OriActionFlag = 'N'      
      BEGIN      
         IF NOT EXISTS ( SELECT 1 FROM dbo.WCSRoutingDetail WITH (NOLOCK)       
                          WHERE WCSKey   = @c_WCSKey       
                          AND ToteNo     = @c_ToteNo      
                          AND ActionFlag = 'I'       
                          AND Zone       = ISNULL(@c_WCSStation,''))       
         BEGIN      
             INSERT INTO dbo.WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)                  
             VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''), 'I') -- INSERT              
                   
             INSERT INTO TraceInfo (TraceName , timeIn , col1 , col2, col3, col4  )      
             VALUES ('WCS' , GETDATE() , '5', @c_WCSStation ,@c_ActionFlag,  @c_WCSKey )       
             
         END      
      END      
      ELSE IF @c_OriActionFlag = 'S'      
      BEGIN      
                 
           SELECT @c_FinalWCSZone = Short           
           FROM dbo.CodeLkup WITH (NOLOCK)          
           WHERE Listname = 'WCSROUTE'          
           AND Code = 'QC'         
                  
                
      
           SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')                  
           FROM CODELKUP WITH (NOLOCK)                  
           WHERE Listname = 'WCSSTATION'                  
           AND   Code = @c_FinalWCSZone       
      
      
           
           IF NOT EXISTS ( SELECT 1 FROM dbo.WCSRoutingDetail WITH (NOLOCK)       
                          WHERE WCSKey   = @c_WCSKey       
                          AND ToteNo     = @c_ToteNo      
                          AND ActionFlag = 'I'       
                          AND Zone       = ISNULL(@c_WCSStation,''))       
         BEGIN      
             INSERT INTO dbo.WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)                  
             VALUES (@c_WCSKey, @c_ToteNo, @c_WCSStation, 'I') -- INSERT              
         END      
      END      
            
  END      
  ELSE IF @c_ActionFlag = 'C'      
  BEGIN      
      UPDATE dbo.WCSRouting       
      SET Status = '9'       
      WHERE WCSKey = @c_WCSKey      
      AND WaveKey = @c_WaveKey       
      AND Status = '0'      
      AND ToteNo = @c_ToteNo    
            
      IF @@ERROR <> 0       
      BEGIN      
           SELECT @n_continue = 3                  
           SELECT @n_ErrNo = 85966      
           SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + 'UpdWCSFail'             
      END      
            
      UPDATE dbo.WCSRoutingDetail      
         SET Status = '9'        
      WHERE WCSKey = @c_WCSKey      
      AND Status = '0'      
         
      IF @@ERROR <> 0       
      BEGIN      
           SELECT @n_continue = 3                  
           SELECT @n_ErrNo = 85967      
           SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + 'UpdWCSDetailFail'             
      END      
  END      
                    
  Gen_WCS_Records:                  
                 
  EXEC dbo.isp_WMS2WCSRouting                  
        @c_WCSKey,                  
        @c_StorerKey,                  
        @b_Success OUTPUT,                  
        @n_ErrNo  OUTPUT,                   
        @c_ErrMsg OUTPUT                  
                  
  IF @n_ErrNo <> 0                   
  BEGIN                  
     SELECT @n_continue = 3                  
     SELECT @n_ErrNo = @n_ErrNo                   
     SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' ' + ISNULL(RTRIM(@c_ErrMsg), '')                 
     GOTO Quit_SP              
  END                  
                    
                  
  Skip_WCS_Records:                  
                  
  Quit_SP:                  
  IF @n_continue=3  -- Error Occured - Process And Return                  
  BEGIN                  
      SELECT @b_success = 0                  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt                  
      BEGIN                  
         ROLLBACK TRAN                  
      END                  
      ELSE                  
      BEGIN                  
         WHILE @@TRANCOUNT > @n_starttcnt                  
         BEGIN                  
            COMMIT TRAN                  
         END                  
      END                  
                
                      
      EXECUTE nsp_logerror @n_ErrNo, @c_ErrMsg, 'ispWCSRO01'                  
      --RAISERROR @n_ErrNo @c_ErrMsg                 
      RETURN                  
  END                  
  ELSE                  
  BEGIN                  
      SELECT @b_success = 1                  
      WHILE @@TRANCOUNT > @n_starttcnt                  
      BEGIN                  
         COMMIT TRAN                  
      END                  
      
      
      RETURN                  
  END                  
END          
      


GO