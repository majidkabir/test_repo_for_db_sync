SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Store procedure: rdt_PalletInquiry_RemoveCarton                      */        
/* Copyright      : IDS                                                 */        
/*                                                                      */        
/* Called from: rdtfnc_PalletInquiry                                    */        
/*                                                                      */        
/* Purpose: Remove carton from pallet                                   */        
/*                                                                      */        
/* Modifications log:                                                   */        
/* Date        Rev  Author   Purposes                                   */        
/* 2022-09-20  1.0  James    WMS-20742. Created                         */      
/* 2022-10-20  1.1  LZG      Fixed Pallet not fully reopened issue(ZG01)*/
/************************************************************************/        

CREATE PROC [RDT].[rdt_PalletInquiry_RemoveCarton] (        
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @nStep          INT,    
   @nInputKey      INT,    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cPalletKey     NVARCHAR( 20),    
   @cOrderKey      NVARCHAR( 10),    
   @cCartonId      NVARCHAR( 20),    
   @cOption        NVARCHAR( 10),    
   @cType          NVARCHAR( 10),    
   @tPalletInq     VariableTable READONLY,    
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT    
) AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
    
   DECLARE @cSQL           NVARCHAR( MAX)    
   DECLARE @cSQLParam      NVARCHAR( MAX)    
   DECLARE @cRemoveCartonSP  NVARCHAR( 20)    
    
   -- Get storer config    
   SET @cRemoveCartonSP = rdt.RDTGetConfig( @nFunc, 'RemoveCartonSP', @cStorerKey)    
   IF @cRemoveCartonSP = '0'    
      SET @cRemoveCartonSP = ''    
    
   /***********************************************************************************************    
                                        Custom remove carton sp    
   ***********************************************************************************************/    
   -- Check confirm SP blank    
   IF @cRemoveCartonSP <> ''    
   BEGIN    
      -- Confirm SP    
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cRemoveCartonSP) +    
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
         ' @cPalletKey, @cOrderKey, @cCartonId, @cOption, @cType, ' +    
         ' @tPalletInq, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
      SET @cSQLParam =    
         ' @nMobile        INT,           ' +    
         ' @nFunc          INT,           ' +    
         ' @cLangCode      NVARCHAR( 3),  ' +    
         ' @nStep          INT,           ' +    
         ' @nInputKey      INT,           ' +    
         ' @cFacility      NVARCHAR( 5) , ' +    
         ' @cStorerKey     NVARCHAR( 15), ' +    
         ' @cPalletKey     NVARCHAR( 20), ' +    
         ' @cOrderKey      NVARCHAR( 10), ' +    
         ' @cCartonId      NVARCHAR( 20), ' +    
         ' @cOption        NVARCHAR( 10), ' +    
         ' @cType          NVARCHAR( 10), ' +    
         ' @tPalletInq     VariableTable READONLY, ' +    
         ' @nErrNo         INT           OUTPUT, ' +    
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '    
    
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
         @cPalletKey, @cOrderKey, @cCartonId, @cOption, @cType,    
         @tPalletInq, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
      GOTO Quit    
   END    
    
   /***********************************************************************************************    
                                      Standard remove carton    
   ***********************************************************************************************/    
   DECLARE @nTranCount     INT    
   DECLARE @cPalletLineNumber NVARCHAR( 5)      
   DECLARE @cMBOLKey          NVARCHAR( 10)    
   DECLARE @cMbolLineNumber   NVARCHAR( 5)    
   DECLARE @cCaseId           NVARCHAR( 20)    
   DECLARE @curDeLPlt         CURSOR    
   DECLARE @curDelMbol        CURSOR    
       
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_DelPltDtl -- For rollback or commit only our own transaction    
    
   DECLARE @tMBOLKey TABLE        
      (        
         MBOLKey  NVARCHAR( 10) NOT NULL      
         PRIMARY KEY CLUSTERED             
         (            
         [MBOLKey]            
         )            
      )    
    
   INSERT INTO @tMBOLKey (MBOLKey)    
   SELECT DISTINCT MBOLKey    
   FROM dbo.Orders O WITH (NOLOCK)    
   WHERE O.StorerKey = @cStorerKey    
   AND   EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL PD WITH (NOLOCK)    
                  WHERE PD.StorerKey = O.StorerKey    
                  AND   pd.PalletKey = @cPalletKey    
                  AND   PD.UserDefine01 = O.OrderKey)  
  
   IF @cType = 'ALL'    
   BEGIN    
      SET @curDeLPlt = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
      SELECT PalletLineNumber    
      FROM dbo.PalletDetail WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND   PalletKey = @cPalletKey    
      OPEN @curDeLPlt    
      FETCH NEXT FROM @curDeLPlt INTO @cPalletLineNumber    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
       UPDATE PALLETDETAIL SET ArchiveCop = '9'     
       WHERE PalletKey = @cPalletKey     
       AND   PalletLineNumber = @cPalletLineNumber    
           
       IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 191751    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltDtl Err    
            GOTO RollBackTran_DelPltDtl    
         END    
    
         DELETE FROM PALLETDETAIL    
         WHERE PalletKey = @cPalletKey    
         AND PalletLineNumber = @cPalletLineNumber    
    
       IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 191752    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltDtl Err    
            GOTO RollBackTran_DelPltDtl    
         END    
    
       FETCH NEXT FROM @curDeLPlt INTO @cPalletLineNumber    
      END    
          
      UPDATE PALLET SET ArchiveCop = '9' WHERE PalletKey = @cPalletKey    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 191753    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltHdr Err    
         GOTO RollBackTran_DelPltDtl    
      END    
    
      DELETE FROM PALLET WHERE PalletKey = @cPalletKey    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 191754    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltHdr Err    
         GOTO RollBackTran_DelPltDtl    
      END    
   END    
   ELSE    
   BEGIN    
      SELECT @cCaseId = CaseId    
      FROM dbo.PALLETDETAIL WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND   PalletKey = @cPalletKey    
      AND   CaseId = @cCartonId    
        
      IF ISNULL(@cCaseId, '') <> ''  
      BEGIN   
         -- Bypass trigger and reopen the Pallet  
         UPDATE PALLET SET Status = '0', ArchiveCop = NULL WHERE PalletKey = @cPalletKey   
           
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 191755    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltHdr Err    
            GOTO RollBackTran_DelPltDtl    
         END    
         
         -- Bypass trigger and reopen the Pallet  
         UPDATE PalletDetail SET Status = '0', ArchiveCop = NULL WHERE PalletKey = @cPalletKey  -- ZG01 
         
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 191755    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltHdr Err    
            GOTO RollBackTran_DelPltDtl    
         END   
         
         -- Update ArchiveCop back to NULL to prevent it from being archived   
         --UPDATE PALLET SET ArchiveCop = NULL WHERE PalletKey = @cPalletKey        -- ZG01
         --
         --IF @@ERROR <> 0    
         --BEGIN    
         --   SET @nErrNo = 191756    
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltHdr Err    
         --   GOTO RollBackTran_DelPltDtl    
         --END    
      END   
           
      SET @curDeLPlt = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
      SELECT PalletLineNumber    
      FROM dbo.PalletDetail WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND   PalletKey = @cPalletKey    
      AND   CaseId = @cCaseId    
      OPEN @curDeLPlt    
      FETCH NEXT FROM @curDeLPlt INTO @cPalletLineNumber    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         UPDATE PALLETDETAIL SET ArchiveCop = '9'     
         WHERE PalletKey = @cPalletKey     
         AND   PalletLineNumber = @cPalletLineNumber    
           
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 191757    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltDtl Err    
            GOTO RollBackTran_DelPltDtl    
         END    
    
         DELETE FROM PALLETDETAIL    
         WHERE PalletKey = @cPalletKey    
         AND PalletLineNumber = @cPalletLineNumber    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 191758    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltDtl Err    
            GOTO RollBackTran_DelPltDtl    
         END    
    
         FETCH NEXT FROM @curDeLPlt INTO @cPalletLineNumber    
      END    
        
      -- Delete Pallet if no detail  
      IF NOT EXISTS (  
         SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey    
         AND   PalletKey = @cPalletKey)    
      BEGIN   
         DELETE FROM PALLET WHERE PalletKey = @cPalletKey    
           
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 191759    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PltHdr Err    
            GOTO RollBackTran_DelPltDtl    
         END    
      END   
   END    
     
   -- Delete MBOLDetail once the order's cartons are completely removed from pallets  
   SET @curDelMbol = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
   SELECT MD.MBOLKey, MbolLineNumber    
   FROM dbo.MBOLDETAIL MD WITH (NOLOCK)    
   JOIN @tMBOLKey t ON ( MD.MbolKey = t.MBOLKey)    
   WHERE NOT EXISTS (  
      SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND UserDefine01 = MD.OrderKey)  
   OPEN @curDelMbol    
   FETCH NEXT FROM @curDelMbol INTO @cMBOLKey, @cMBOLLineNumber    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      DELETE FROM MBOLDetail     
      WHERE MbolKey = @cMBOLKey     
      AND   MbolLineNumber = @cMbolLineNumber    
        
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 191760    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del MBDtl Err    
         GOTO RollBackTran_DelPltDtl    
      END    
          
      FETCH NEXT FROM @curDelMbol INTO @cMBOLKey, @cMBOLLineNumber    
   END    
   CLOSE @curDelMbol    
   DEALLOCATE @curDelMbol    
     
   -- Delete MBOL once all MBOLDetail lines are removed  
   SET @curDelMbol = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
   SELECT MbolKey    
   FROM @tMBOLKey t   
   WHERE NOT EXISTS (  
      SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK)  
      WHERE MBOLKey = t.MBOLKey)  
   OPEN @curDelMbol    
   FETCH NEXT FROM @curDelMbol INTO @cMBOLKey    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      DELETE FROM MBOL WHERE MbolKey = @cMBOLKey    
        
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 191761    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del MBHdr Err    
         GOTO RollBackTran_DelPltDtl    
      END    
   FETCH NEXT FROM @curDelMbol INTO @cMBOLKey    
   END  
     
   COMMIT TRAN rdt_DelPltDtl    
    
   GOTO Quit_DelPltDtl    
    
   RollBackTran_DelPltDtl:    
      ROLLBACK TRAN -- Only rollback change made here    
   Quit_DelPltDtl:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN    
    
   Quit:    
END 

GO