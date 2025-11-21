SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/*****************************************************************************/                  
/* Store procedure: ispWCSRO02                                               */                  
/* Copyright      : IDS                                                      */                  
/*                                                                           */                  
/* Purpose: Sub-SP to insert WCSRouting records                              */                  
/*                                                                           */                  
/* Modifications log:                                                        */                  
/*                                                                           */                  
/* Date       Rev  Author   Purposes                                         */                  
/* 2015-05-05 1.0  James    Created                                          */         
/*****************************************************************************/                  
CREATE PROC [dbo].[ispWCSRO02]                  
   @c_StorerKey     NVARCHAR( 15) ,                  
   @c_Facility      NVARCHAR( 10) ,                  
   @c_ToteNo        NVARCHAR( 20) ,                  
   @c_TaskType      NVARCHAR( 10) , -- TaskType = 1810 = Direct from RDT Tote Conveyor Move      
   @c_ActionFlag    NVARCHAR( 1)  , -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual, C = Complete          
   @c_TaskDetailKey NVARCHAR( 10)  = '' ,               
   @c_Username      NVARCHAR( 18) ,       
   @c_RefNo01       NVARCHAR( 60)  = '',  -- WCSTATION if direct from 1810      
   @c_RefNo02       NVARCHAR( 60)  = '',       
   @c_RefNo03       NVARCHAR( 60)  = '',      
   @c_RefNo04       NVARCHAR( 60)  = '',      
   @c_RefNo05       NVARCHAR( 60)  = '',      
   @b_debug         INT     = 0  ,      
   @c_LangCode      NVARCHAR( 3)  ,      
   @n_Func          INT          ,               
   @b_Success       INT          OUTPUT,                  
   @n_ErrNo         INT          OUTPUT,                
   @c_ErrMsg        NVARCHAR( 20) OUTPUT                 
AS                  
BEGIN                
   SET NOCOUNT ON                  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF              

   DECLARE @nTranCount     INT

   DECLARE 
      @c_Init_Final_Zone   NVARCHAR( 10), 
      @c_FinalWCSZone      NVARCHAR( 10), 
      @c_FinalLoc          NVARCHAR( 10), 
      @c_Station           NVARCHAR( 10), 
      @c_WCSKey            NVARCHAR( 10),
      @c_WCSStation        NVARCHAR( 10),
      @n_StationCnt        INT,
      @n_Count             INT
      
                       
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN ispWCSRO02

   IF @c_ActionFlag = 'N'
   BEGIN
      -- Cancel all route be
      SET @c_Init_Final_Zone = ''    
      SET @c_FinalWCSZone = ''    

      SELECT TOP 1 
         @c_FinalWCSZone = Final_Zone,    
         @c_Init_Final_Zone = Initial_Final_Zone    
      FROM dbo.WCSRouting WITH (NOLOCK)    
      WHERE ToteNo = @c_ToteNo    
      AND   ActionFlag = 'I'    
      ORDER BY WCSKey Desc    

      SET @c_WCSKey = ''
      EXECUTE nspg_GetKey         
         'WCSKey',         
         10,         
         @c_WCSKey   OUTPUT,         
         @b_Success  OUTPUT,         
         @n_ErrNo    OUTPUT,         
         @c_ErrMsg   OUTPUT          
                  
      IF @n_ErrNo<>0        
      BEGIN        
         SET @n_ErrNo = 108901
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --GetWCSKey Fail
         GOTO RollBackTran  
      END          
                  
      INSERT INTO dbo.WCSRouting 
         (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)        
      VALUES        
         ( @c_WCSKey, @c_ToteNo, ISNULL(@c_Init_Final_Zone,''), ISNULL(@c_FinalWCSZone,''), 'D', @c_StorerKey, @c_Facility, '', 'ToteMove') 
            
      SELECT @n_ErrNo = @@ERROR          

      IF @n_ErrNo<>0        
      BEGIN        
         SET @n_ErrNo = 108902
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --CrtRouteFail
         GOTO RollBackTran  
      END         
                  
      -- Update WCSRouting.Status = '5' When Delete          
      UPDATE dbo.WCSRouting WITH (ROWLOCK) SET
         STATUS = '5'        
      WHERE ToteNo = @c_ToteNo          

      SELECT @n_ErrNo = @@ERROR          
      IF @n_ErrNo<>0        
      BEGIN        
         SET @n_ErrNo = 108903
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UpdRouteFail
         GOTO RollBackTran     
      END         

      EXEC dbo.isp_WMS2WCSRouting  
           @c_WCSKey,  
           @c_StorerKey,  
           @b_Success OUTPUT,  
           @n_ErrNo  OUTPUT,   
           @c_ErrMsg OUTPUT  
     
      IF @n_ErrNo <> 0   
      BEGIN  
         SET @n_ErrNo = 108904
         SET @c_ErrMsg = rdt.rdtgetmessage( 71125, @c_LangCode, 'DSP') --CrtWCSRECFail
         GOTO RollBackTran  
      END

      SET @c_Station = @c_RefNo01
      
      -- Insert Routing Record Here
      SET @c_FinalLoc = ''
      SELECT @c_FinalLoc = SHORT 
      FROM   dbo.Codelkup WITH (NOLOCK)
      WHERE  LISTNAME = 'WCSSTATION'
      AND    Code = @c_Station

      IF ISNULL(RTRIM(@c_FinalLoc),'') = ''  
      BEGIN
         SET @n_ErrNo = 108905
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --BAD Station
         GOTO RollBackTran  
      END
            
      EXECUTE nspg_GetKey  
         'WCSKey',  
         10,     
         @c_WCSKey      OUTPUT,  
         @b_Success     OUTPUT,  
         @n_ErrNo       OUTPUT,  
         @c_ErrMsg      OUTPUT  

      IF @n_ErrNo <> 0   
      BEGIN
         SET @n_ErrNo = 108906
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --GetWCSKey Fail
         GOTO RollBackTran  
      END

      INSERT INTO dbo.WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)  
      VALUES (@c_WCSKey, @c_ToteNo, '', @c_FinalLoc, 'I',  @c_StorerKey, @c_Facility, '', 'ToteMove') -- Insert  

      SELECT @n_ErrNo = @@ERROR  
      IF @n_ErrNo <> 0   
      BEGIN
         SET @n_ErrNo = 108907
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --CrtRouteFail
         GOTO RollBackTran  
      END

      SET @c_WCSStation = ''
      SELECT @c_WCSStation = SHORT 
      FROM   dbo.Codelkup WITH (NOLOCK)
      WHERE  LISTNAME = 'WCSSTATION'
      AND    Code = @c_Station

      INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)  
      VALUES (@c_WCSKey, @c_ToteNo, @c_WCSStation, 'I') -- Insert  

      SELECT @n_ErrNo = @@ERROR  
      IF @n_ErrNo <> 0   
      BEGIN
         SET @n_ErrNo = 108908
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --CrtRouteFaild
         GOTO RollBackTran  
      END

      IF NOT EXISTS (SELECT 1 FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @c_WCSKey)  
      BEGIN  
         DELETE FROM WCSRouting   
         WHERE WCSKey = @c_WCSKey  
      END  
      ELSE  
      BEGIN  
         EXEC dbo.isp_WMS2WCSRouting  
              @c_WCSKey,  
              @c_StorerKey,  
              @b_Success OUTPUT,  
              @n_ErrNo  OUTPUT,   
              @c_ErrMsg OUTPUT  
        
         IF @n_ErrNo <> 0   
         BEGIN  
            SET @n_ErrNo = 108909
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --CrtWCSRECFail
            GOTO RollBackTran  
         END
      END  
      -- Insert Routing Record End
   END   -- IF @c_ActionFlag = 'N'

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN ispWCSRO02
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN   
END          
      


GO