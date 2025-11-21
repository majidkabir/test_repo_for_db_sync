SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdt_593ShipLabel10                                     */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2017-11-24 1.0  Ung      WMS-3507 Created                               */  
/* 2018-05-15 1.1  JyhBin   Fixed NIKECN changes on WMS-3845               */
/* 2019-07-20 1.2  CheeMun  INC0784332 - Add Variable for ConfirmSP        */ 
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593ShipLabel10] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  -- Carton no
   @cParam3    NVARCHAR(20),    
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount	   INT
   DECLARE @nRowCount      INT

   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)

   DECLARE @cID            NVARCHAR( 18)
   DECLARE @cChkLOC        NVARCHAR( 10)
   DECLARE @cChkSKU        NVARCHAR( 20)      
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @nQTY           INT
   DECLARE @nQTYAllocated  INT
   DECLARE @nQTYPicked     INT
   DECLARE @nPalletCnt     FLOAT
   DECLARE @nTotal         INT
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelNo       NVARCHAR( 20) 
   DECLARE @cSerialNo      NVARCHAR( 30) 
   DECLARE @nSerialQTY     INT
   DECLARE @cShipLabel     NVARCHAR( 10)
   DECLARE @cFromDropID    NVARCHAR( 20)-- JyhBin
   DECLARE @cPackDtlDropID NVARCHAR( 20)-- JyhBin
   DECLARE @cPrintPackList NVARCHAR( 1) -- JyhBin

   --INC0784332 (START)  
   DECLARE @nBulkSNO        INT  
		  ,@nBulkSNOQTY     INT  
		  ,@cPackData1      NVARCHAR( 30)  
		  ,@cPackData2      NVARCHAR( 30)  
		  ,@cPackData3      NVARCHAR( 30)  
   --INC0784332 (END)  
   

   SET @nTranCount = @@TRANCOUNT

   -- Screen mapping
   SET @cID = @cParam1

   -- Check blank
   IF @cID = '' 
   BEGIN
      SET @nErrNo = 117251  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need ID
      GOTO Quit  
   END

   -- Get session info  
   SELECT   
      @cFacility = Facility, 
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   -- Get pallet info
   SELECT
      @cSKU = LLI.SKU, 
      @cLOC = LLI.LOC, 
      @nQTY = ISNULL( SUM( LLI.QTY), 0),  
      @nQTYAllocated = ISNULL( SUM( QTYAllocated), 0),  
      @nQTYPicked = ISNULL( SUM( LLI.QTYPicked), 0)
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
      AND LLI.StorerKey = @cStorerKey
      AND LLI.ID = @cID
      AND LLI.QTY > 0
   GROUP BY LLI.LOC, LLI.SKU

   SET @nRowCount = @@ROWCOUNT 

   -- Check ID valid
   IF @nRowCount = 0
   BEGIN  
      SET @nErrNo = 117252  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID not exist
      GOTO Quit  
   END  

   IF @nRowCount > 1
   BEGIN
      -- Get pallet info
      SELECT TOP 1 
         @cChkSKU = LLI.SKU, 
         @cChkLOC = LLI.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LLI.StorerKey = @cStorerKey
         AND LLI.ID = @cID
         AND LLI.QTY > 0
         AND (LLI.SKU <> @cSKU 
          OR  LLI.LOC <> @cLOC)
   
      -- Check ID in multi LOC
      IF @cLOC <> @cChkLOC
      BEGIN
         SET @nErrNo = 117253  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID Multi LOC
         GOTO Quit  
      END

      -- Check multi SKU
      IF @cSKU <> @cChkSKU
      BEGIN
         SET @nErrNo = 117254  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID multi SKU
         GOTO Quit  
      END
   END

   -- Check allocated
   IF @nQTYAllocated > 0
   BEGIN  
      SET @nErrNo = 117255  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID allocated
      GOTO Quit  
   END 
   
   -- Check picked
   IF @nQTYPicked = 0
   BEGIN  
      SET @nErrNo = 117256  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID not picked
      GOTO Quit  
   END

   -- Check available
   IF @nQTY <> @nQTYPicked
   BEGIN  
      SET @nErrNo = 117257  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID NotFullPick
      GOTO Quit  
   END

   -- Check pallet info
   SELECT @nPalletCnt = Pack.Pallet
   FROM SKU WITH (NOLOCK)
      JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU
      
   -- Check full pallet
   IF @nQTY <> CAST( @nPalletCnt AS INT)
   BEGIN  
      SET @nErrNo = 117258  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not FullPallet
      GOTO Quit  
   END
   
   -- Get OrderKey
   SELECT TOP 1 
      @cOrderKey = OrderKey
   FROM PickDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cSKU 
      AND LOC = @cLOC
      AND ID = @cID
      AND Status = '5'
   
   -- Check multi order
   IF EXISTS( SELECT 1 
      FROM PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU 
         AND LOC = @cLOC
         AND ID = @cID
         AND Status = '5'
         AND OrderKey <> @cOrderKey)
   BEGIN  
      SET @nErrNo = 117259  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID multi order
      GOTO Quit  
   END
   
   -- Get PickSlip
   SET @cPickSlipNo = ''
   SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   IF @cPickSlipNo = ''
   BEGIN  
      SET @nErrNo = 117260  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID no PickSlip
      GOTO Quit  
   END

   -- Check serial no SKU
   IF NOT EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND SerialNoCapture = '1')
   BEGIN  
      SET @nErrNo = 117261 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID no PickSlip
      GOTO Quit  
   END

   -- Check serial no HOLD
   IF EXISTS( SELECT 1 
      FROM SerialNo WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU 
         AND ID = @cID 
         AND (Status = 'H' OR ExternStatus = 'H'))
   BEGIN  
      SET @nErrNo = 117262  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SN is HOLD
      GOTO Quit  
   END
      
   -- Get total serial no
   SELECT @nTotal = SUM( QTY)
   FROM SerialNo WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cSKU 
      AND ID = @cID 
      AND Status IN ('1', '6') -- Received, packed
      
   -- Check total serial no
   IF @nTotal <> @nQTY
   BEGIN  
      SET @nErrNo = 117263 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SN not full PL
      GOTO Quit  
   END
      
   -- Check ID packed
   IF EXISTS( SELECT 1
      FROM PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND DropID = @cID)
   BEGIN  
      SET @nErrNo = 117264
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID packed
      GOTO Quit  
   END
   
   -- Check serial no packed (in other pickslip)
   IF EXISTS( SELECT TOP 1 1
      FROM SerialNo SNO WITH (NOLOCK) 
         JOIN PackSerialNo PSNO WITH (NOLOCK) ON (SNO.StorerKey = PSNO.StorerKey AND SNO.SKU = PSNO.SKU AND SNO.SerialNo = PSNO.SerialNo)
     WHERE SNO.StorerKey = @cStorerKey 
         AND SNO.SKU = @cSKU 
         AND SNO.ID = @cID
         AND SNO.Status = '1'
         AND PSNO.PickSlipNo <> @cPickSlipNo)
   BEGIN  
      SET @nErrNo = 117265
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SNO packed
      GOTO Quit  
   END

   /*-------------------------------------------------------------------------------  
  
                                       Auto packing  
  
   -------------------------------------------------------------------------------*/  
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_593ShipLabel10  -- For rollback or commit only our own transaction

   DECLARE @curSNO CURSOR
   SET @curSNO = CURSOR FOR
      SELECT SerialNo, QTY
      FROM SerialNo WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU 
         AND ID = @cID
         AND Status = '1'
   OPEN @curSNO
   FETCH NEXT FROM @curSNO INTO @cSerialNo, @nSerialQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Pack carton
      SET @nCartonNo = 0
      EXEC rdt.rdt_838ConfirmSP01 @nMobile, 838, @cLangCode, @nStep, 1, @cFacility, @cStorerKey
         ,@cPickSlipNo     = @cPickSlipNo
         ,@cFromDropID     = @cID
         ,@cSKU            = @cSKU 
         ,@nQTY            = 1
         ,@cUCCNo          = '' 
         ,@cSerialNo       = @cSerialNo
         ,@nSerialQTY      = @nSerialQTY
         ,@cPackDtlRefNo   = ''
         ,@cPackDtlRefNo2  = ''
         ,@cPackDtlUPC     = ''
         ,@cPackDtlDropID  = @cID
         ,@nCartonNo       = @nCartonNo OUTPUT
         ,@cLabelNo        = @cLabelNo  OUTPUT
         ,@nErrNo          = @nErrNo    OUTPUT
         ,@cErrMsg         = @cErrMsg   OUTPUT
		 ,@nBulkSNO        = @nBulkSNO     --INC0784332  
		 ,@nBulkSNOQTY     = @nBulkSNOQTY  --INC0784332  
		 ,@cPackData1      = @cPackData1   --INC0784332    
		 ,@cPackData2      = @cPackData2   --INC0784332    
		 ,@cPackData3      = @cPackData3   --INC0784332
		 
      IF @nErrNo <> 0
         GOTO RollBackTran

      FETCH NEXT FROM @curSNO INTO @cSerialNo, @nSerialQTY
   END

   COMMIT TRAN rdt_593ShipLabel10
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

   SET @cShipLabel = rdt.RDTGetConfig( 838, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''

   -- Ship label
   IF @cShipLabel <> '' 
   BEGIN
      -- Common params
      DECLARE @tShipLabel AS VariableTable
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cFromDropID', @cID)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, 838, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
         @cShipLabel, -- Report type
         @tShipLabel, -- Report params
         'rdt_593ShipLabel10', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

   -- Pack confirm
   EXEC rdt.rdt_Pack_PackConfirm @nMobile, 838, @cLangCode, @nStep, 1, @cFacility, @cStorerKey
      ,@cPickSlipNo
	  ,@cFromDropID			  -- JyhBin
      ,@cPackDtlDropID		  -- JyhBin
      ,@cPrintPackList OUTPUT -- JyhBin
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_593ShipLabel10
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO