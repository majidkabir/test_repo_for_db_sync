SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_593Print28                                      */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Print PDF                                                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2020-04-06  1.0  James    WMS-12367. Created                         */  
/* 2020-10-02  1.1  James    WMS-15422 Gen 20 digits labelno for case   */
/*                           with uom = 2 (james01)                     */
/* 2021-11-25  1.2  Chermain WMS-18429 Add check loadKey Validation (cc01)*/
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_593Print28] (  
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- StorerKey
   @cParam2    NVARCHAR(20),  -- OrderKey
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT 
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cPickSlipNo       NVARCHAR( 10)     
   DECLARE @cLabelNo          NVARCHAR( 20)     
   DECLARE @nCartonNo         INT
   DECLARE @nInputKey         INT
   DECLARE @cLabelPrinter     NVARCHAR( 10)
   DECLARE @cPaperPrinter     NVARCHAR( 10)  
   DECLARE @cCartonLbl        NVARCHAR( 10)
   DECLARE @cShipLabel        NVARCHAR( 10)
   DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @cDropID           NVARCHAR( 20)
   DECLARE @nTranCount        INT
   DECLARE @cSSCCLabelNo      NVARCHAR( 20)
   DECLARE @cLabelLine        NVARCHAR( 5)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cChkLoadPlan      NVARCHAR( 1)   --(cc01)

   -- Check blank
   IF ISNULL( @cParam1, '') = '' 
   BEGIN    
      SET @nErrNo = 150751     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value    
      GOTO Quit    
   END  

   -- Check UCC (label no) validity
   SELECT TOP 1 @cLabelNo = LabelNo
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   LabelNo = @cParam1
   ORDER BY 1

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 150752     
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv UCC No    
      GOTO Quit    
   END

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @nInputKey = InputKey,
          @cFacility = Facility
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT TOP 1
            @cPickSlipNo = PickSlipNo,
            @nCartonNo = CartonNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   LabelNo = @cLabelNo
   ORDER BY 1

   SELECT TOP 1 @cDropID = Dropid
   FROM dbo.PICKDETAIL WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND   CaseID = @cLabelNo
   ORDER BY 1
   
   SET @cCartonLbl = rdt.RDTGetConfig( @nFunc, 'CartonLabel', @cStorerKey)
   IF @cCartonLbl = '0'
      SET @cCartonLbl = ''

   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''
      
   SET @cChkLoadPlan = rdt.RDTGetConfig( @nFunc, 'ChkLoadPlan', @cStorerKey)
   IF @cChkLoadPlan = '0'
      SET @cChkLoadPlan = ''         
      
      ---	IF new RDT.storerConfig is enabled AND IF EXISTS Orders.LoadKey is empty WHERE Orders.OrderKey = PickDetail.OrderKey AND PickDetail.CaseID = scanned labelno 
      --AND PickDetail.UOM = æ2Æ and PickDetail.Status < æ9Æ
   IF @cChkLoadPlan = '1'
   BEGIN
   	IF EXISTS (SELECT 1
   	   FROM Orders O WITH (NOLOCK)
   	   JOIN pickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey AND O.StorerKey = PD.Storerkey)
   	   WHERE O.StorerKey = @cStorerKey
   	   AND PD.caseID = @cLabelNo
   	   AND PD.UOM = '2'
   	   AND PD.[Status] < '9'
   	   AND O.LoadKey = '')
      BEGIN
      	SET @nErrNo = 150757     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No LoadPlan      
         GOTO Quit   
      END   	   
   END
   
   IF @cOption = '1' -- Print ship label
      SET @cCartonLbl = ''

   IF @cOption = '2' -- Print carton label
      SET @cShipLabel = ''

   IF @cOption = '3'
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
                  WHERE Storerkey = @cStorerKey
                  AND   CaseID = @cLabelNo
                  AND   UOM = '2'
                  AND   [Status] < '9')
      BEGIN
         IF ISNUMERIC( @cLabelNo) = 0 OR LEN( RTRIM( @cLabelNo)) < 20
         BEGIN
            SET @nTranCount = @@TRANCOUNT  
            BEGIN TRAN  -- Begin our own transaction  
            SAVE TRAN rdt_593Print28 -- For rollback or commit only our own transaction  
      
            SET @cSSCCLabelNo = ''
            SET @nErrNo = 0
            EXEC RDT.rdt_GenUCCLabelNo
               @cStorerKey = @cStorerKey,
               @nMobile    = @nMobile,
               @cLabelNo   = @cSSCCLabelNo   OUTPUT,
               @cLangCode  = @cLangCode,
               @nErrNo     = @nErrNo         OUTPUT,
               @cErrMsg    = @cErrMsg        OUTPUT 

            IF @nErrNo <> 0 
               GOTO RollBackTran

            IF ISNULL( @cSSCCLabelNo, '') = ''
            BEGIN
               SET @nErrNo = 150753     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen SSCC Fail    
               GOTO RollBackTran    
            END

            DECLARE @curUpdPick  CURSOR
            SET @curUpdPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT PickDetailKey, TaskDetailKey
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   CaseID = @cLabelNo
            AND   UOM = '2'
            AND   [Status] < '9'
            ORDER BY 1
            OPEN @curUpdPick
            FETCH NEXT FROM @curUpdPick INTO @cPickDetailKey, @cTaskDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.PICKDETAIL SET
                  CaseID = @cSSCCLabelNo,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 150754     
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd CaseID Fail    
                  GOTO RollBackTran    
               END
         
               UPDATE dbo.TaskDetail SET 
                  CaseID = @cSSCCLabelNo, 
                  TrafficCop = NULL,   -- status will be 9 since the printing happens after replen
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE TaskDetailKey = @cTaskDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 150756     
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd CaseID Fail    
                  GOTO RollBackTran    
               END
               
               FETCH NEXT FROM @curUpdPick INTO @cPickDetailKey, @cTaskDetailKey
            END


            DECLARE @curUpdPack  CURSOR
            SET @curUpdPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT LabelLine
            FROM dbo.PACKDETAIL WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cLabelNo
            AND   CartonNo = @nCartonNo
            ORDER BY 1
            OPEN @curUpdPack
            FETCH NEXT FROM @curUpdPack INTO @cLabelLine
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.PACKDETAIL SET
                  LabelNo = @cSSCCLabelNo,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickSlipNo = @cPickSlipNo
               AND   LabelNo = @cLabelNo
               AND   CartonNo = @nCartonNo
            
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 150755     
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Label# Fail    
                  GOTO RollBackTran    
               END
         
               FETCH NEXT FROM @curUpdPack INTO @cLabelLine
            END
         
            SET @cLabelNo = @cSSCCLabelNo

            GOTO CommitTrans  
  
            RollBackTran:  
                  ROLLBACK TRAN rdt_593Print28  
  
            CommitTrans:  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
      
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END
         
   IF @cCartonLbl <> ''
   BEGIN
      DECLARE @tCARTONLBL AS VariableTable
      INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
      INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
      INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)
      INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@cFromLabelNo',  @cLabelNo)
      INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@cToLabelNo',    @cLabelNo)
      INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@cDropID',       @cDropID)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
         @cCartonLbl,  -- Report type
         @tCARTONLBL, -- Report params
         'rdt_593Print28', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT 
   END
   
   
   IF @cShipLabel <> ''
   BEGIN
      DECLARE @tSHIPPLABEL AS VariableTable
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cFromLabelNo',  @cLabelNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cToLabelNo',    @cLabelNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cDropID',       @cDropID)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
         @cShipLabel,  -- Report type
         @tSHIPPLABEL, -- Report params
         'rdt_593Print28', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT 
   END

Quit: 
       
      
END  


GO