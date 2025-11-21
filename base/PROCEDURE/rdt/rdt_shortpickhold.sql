SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_ShortPickHold                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Short Pick Reallocate                                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2020-06-16 1.0  James    WMS-12223. Created                          */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_ShortPickHold] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cOrderkey        NVARCHAR( 10),
   @cLOC             NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,
   @cPickDetailKey   NVARCHAR( 10),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
    DECLARE @cAPP_DB_Name         NVARCHAR( 20) = ''  
           ,@cDataStream          VARCHAR( 10)  = ''  
           ,@nThreadPerAcct       INT = 0  
           ,@nThreadPerStream     INT = 0  
           ,@nMilisecondDelay     INT = 0  
           ,@cIP                  NVARCHAR( 20) = ''  
           ,@cPORT                NVARCHAR( 5)  = ''  
           ,@cPORT2               NVARCHAR( 5)  = ''  
           ,@cIniFilePath         NVARCHAR( 200)= ''  
           ,@cCmdType             NVARCHAR( 10) = ''  
           ,@cTaskType            NVARCHAR( 1)  = ''      
           ,@cOrderLineNumber     NVARCHAR( 5)  = ''
           ,@cCommand             NVARCHAR( 1000) = ''
           ,@nContinue            INT = 0
           ,@bSuccess             INT = 0
      
       SELECT @cAPP_DB_Name         = APP_DB_Name,  
              @cDataStream          = DataStream,  
              @nThreadPerAcct       = ThreadPerAcct,  
              @nThreadPerStream     = ThreadPerStream,  
              @nMilisecondDelay     = MilisecondDelay,  
              @cIP                  = [IP],  
              @cPORT                = [PORT],  
              @cIniFilePath         = IniFilePath,  
              @cCmdType             = CmdType,  
              @cTaskType            = TaskType  
       FROM   QCmd_TransmitlogConfig WITH (NOLOCK)  
       WHERE  TableName = 'ShortPickHold'  
       AND   [App_Name] = 'WMS'  
       AND    StorerKey = 'ALL'      
      
      IF ISNULL( @cIP, '') = ''  
      BEGIN  
         SET @nErrNo = 153801    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup QcmdCfg'   
         GOTO RollBackTran  
      END   

      IF ISNULL( @cPickDetailKey, '') <> ''
      BEGIN
         SELECT @cOrderkey = OrderKey,
                @cOrderLineNumber = OrderLineNumber,
                @cSKU = SKU,
                @cLOC = LOC
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE PickDetailKey = @cPickDetailKey
      
         IF @@ROWCOUNT = 0
         BEGIN  
            SET @nErrNo = 153801    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ShortPkNoFound'   
            GOTO RollBackTran  
         END
      END

      SET @cCommand = N'EXEC [dbo].[isp_ProcessShortPickReAllocate]' +    
                        N'  @c_Orderkey = ''' + @cOrderkey + ''' ' +     
                        N', @c_OrderLineNumber = ''' + @cOrderLineNumber + ''' ' +          
                        N', @c_SKU = ''' + @cSKU + ''' ' +    
                        N', @c_LOC = ''' + @cLOC + ''' ' +
                        N', @b_Debug = 0 ' +                            
                        N', @b_Success = 1 ' +     
                        N', @n_Err = 0 ' +     
                        N', @c_ErrMsg = '''' '  
                                                                 
          
      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN         -- Begin our own transaction
      SAVE TRAN rdt_ShortPickHold -- For rollback or commit only our own transaction    
      
      EXEC isp_QCmd_SubmitTaskToQCommander     
              @cTaskType         = 'O' -- D=By Datastream, T=Transmitlog, O=Others           
            , @cStorerKey        = @cStorerKey                                                
            , @cDataStream       = 'ShtPckHld'                                                         
            , @cCmdType          = 'SQL'                                                      
            , @cCommand          = @cCommand                                                  
            , @cTransmitlogKey   = ''                                             
            , @nThreadPerAcct    = @nThreadPerAcct                                                    
            , @nThreadPerStream  = @nThreadPerStream                                                          
            , @nMilisecondDelay  = @nMilisecondDelay                                                          
            , @nSeq              = 1                           
            , @cIP               = @cIP                                             
            , @cPORT             = @cPORT                                                    
            , @cIniFilePath      = @cIniFilePath           
            , @cAPPDBName        = @cAPP_DB_Name                                                   
            , @bSuccess          = @bSuccess OUTPUT      
            , @nErr              = @nErrNo OUTPUT      
            , @cErrMsg           = @cErrMsg OUTPUT    

      IF @nErrNo <> 0
         GOTO RollBackTran

      COMMIT TRAN rdt_ShortPickHold -- Only commit change made in rdt_ShortPickHold
      GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_ShortPickHold -- Only rollback change made in rdt_ShortPickHold
Quit:
   -- Commit until the level we started
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
Fail:

GO