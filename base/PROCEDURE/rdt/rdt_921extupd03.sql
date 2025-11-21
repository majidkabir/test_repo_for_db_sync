SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_921ExtUpd03                                     */  
/* Purpose: Pack confirm                                                */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-07-14 1.2  Ung        WMS-459 Created                           */
/* 2017-11-09 1.3  Ung        Performance tuning                        */
/************************************************************************/  
CREATE PROC [RDT].[rdt_921ExtUpd03] (  
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nInputKey      INT,           
   @cStorerKey     NVARCHAR( 15), 
   @cFacility      NVARCHAR( 5),  
   @cDropID        NVARCHAR( 20), 
   @cLabelNo       NVARCHAR( 20), 
   @cOrderKey      NVARCHAR( 10), 
   @cCartonNo      NVARCHAR( 5),  
   @cPickSlipNo    NVARCHAR( 10), 
   @cCartonType    NVARCHAR( 10), 
   @cCube          NVARCHAR( 20), 
   @cWeight        NVARCHAR( 20), 
   @cLength        NVARCHAR( 20), 
   @cWidth         NVARCHAR( 20), 
   @cHeight        NVARCHAR( 20), 
   @cRefNo         NVARCHAR( 20), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    

DECLARE @nTranCount  INT
SET @nTranCount = @@TRANCOUNT

IF @nFunc = 921 -- Capture PackInfo
BEGIN  
   IF @nStep = 2 -- Packinfo
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE @nCartonCnt     INT
         DECLARE @nTotalCarton   INT
      
         -- Check pack confirm already
         IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')
            GOTO Quit
      
         -- Get total carton
         SELECT @nCartonCnt = COUNT(1) FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
         SELECT @nTotalCarton = COUNT( DISTINCT LabelNo) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickslipNo = @cPickSlipNo
      
         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_921ExtUpd03 -- For rollback or commit only our own transaction
      
         -- Pack confirm
         IF @nTotalCarton > 0 AND @nTotalCarton = @nCartonCnt
         BEGIN
            IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '9')
            BEGIN
               -- Pack confirm
               UPDATE PackHeader WITH (ROWLOCK) SET 
                  Status = '9', 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE PickSlipNo = @cPickSlipNo
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 100251
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
                  GOTO RollBackTran
               END
            END
            
            -- Get storer config
            DECLARE @b_success   INT
            DECLARE @n_err       INT
            DECLARE @c_authority NVARCHAR(30)
            DECLARE @c_errmsg    NVARCHAR(250)
            EXECUTE nspGetRight
               NULL,        -- facility  
               @cStorerKey, -- Storerkey  
               NULL,        -- Sku  
               'AssignPackLabelToOrdCfg',   
               @b_success     OUTPUT, 
               @c_authority   OUTPUT, 
               @n_err         OUTPUT, 
               @c_errmsg      OUTPUT  
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 100252
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- GetRight Fail
               GOTO RollBackTran
            END
            ELSE IF @c_authority = '1'
            BEGIN
               -- Copy PackDetail.LabelNo to PackDetail.DropID
               EXEC isp_AssignPackLabelToOrderByLoad
                  @cPickSlipNo, 
                  @b_success  OUTPUT, 
                  @n_err      OUTPUT, 
                  @c_errmsg   OUTPUT
               IF @b_success <> 1 OR @n_err <> 0
               BEGIN
                  SET @nErrNo = 100253
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Lbl2DropIDFail
                  GOTO RollBackTran
               END
            END                  
         END
      
         COMMIT TRAN rdt_921ExtUpd03
         GOTO Quit
      END
   END
END
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_921ExtUpd03 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO