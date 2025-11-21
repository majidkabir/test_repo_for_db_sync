SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593CartonLBL05                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-11-07 1.0  Ung        WMS-6882 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593CartonLBL05] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- DropID
   @cParam2    NVARCHAR(20),
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

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cFacility     NVARCHAR( 5)
   DECLARE @cLabelNo      NVARCHAR( 20)
   DECLARE @cLabelLine    NVARCHAR( 5)
   DECLARE @cPickSlipNo   NVARCHAR( 10)
   DECLARE @cSite         NVARCHAR( 20)
   DECLARE @cPackConfirmSite  NVARCHAR(1)
   DECLARE @nQTY          INT
   DECLARE @nCartonNo     INT
   DECLARE @nTranCount    INT
   DECLARE @nRowCount     INT

   -- Parameter mapping
   SET @cLabelNo = @cParam1

   -- Check blank
   IF @cLabelNo = ''
   BEGIN
      SET @nErrNo = 131501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need LabelNo
      GOTO Quit
   END

   -- Get PackDetail info
   SELECT TOP 1 
      @cPickSlipNo = PickSlipNo, 
      @nCartonNo = CartonNo, 
      @cLabelLine = LabelLine, 
      @cSite = RefNo, 
      @nQTY = QTY
   FROM PackDetail (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo
   ORDER BY LabelLine

   SET @nRowCount = @@ROWCOUNT

   -- Check LabelNo valid
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 131502
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo
      GOTO Quit
   END

/*
   -- Check single SKU
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 131503
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --MultiSKUCarton
      GOTO Quit
   END
*/
   -- Check packed
   IF @nQTY > 0
   BEGIN
      SET @nErrNo = 131504
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Carton scanned
      GOTO Quit
   END
      
   -- Check outstanding
   IF EXISTS( SELECT TOP 1 1
      FROM PickDetail (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND CaseID = @cLabelNo
         AND QTY > 0
         AND Status IN ('0', '4'))
   BEGIN
      SET @nErrNo = 131506
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Carton NotDone
      GOTO Quit
   END

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_593CartonLBL05
   
   WHILE @cLabelLine <> ''
   BEGIN
      UPDATE PackDetail SET
         QTY = ExpQTY, 
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE()
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND LabelLine = @cLabelLine
      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN rdt_593CartonLBL05
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         SET @nErrNo = 131505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Carton scanned
         GOTO Quit
      END

      -- Check next line
      SELECT TOP 1 
         @cPickSlipNo = PickSlipNo, 
         @nCartonNo = CartonNo, 
         @cLabelLine = LabelLine
      FROM PackDetail (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND LabelLine > @cLabelLine
      ORDER BY LabelLine 

      IF @@ROWCOUNT = 0
         BREAK
   END

   COMMIT TRAN rdt_593CartonLBL05
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
   

   /***********************************************************************************************  
                                              Ship label
   ***********************************************************************************************/  
   -- Get session info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper,
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   DECLARE @cShipLabel NVARCHAR( 20)
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)  
   IF @cShipLabel = '0'  
      SET @cShipLabel = ''
      
   -- Ship label
   IF @cShipLabel <> ''   
   BEGIN  
      -- Common params  
      DECLARE @tShipLabel AS VariableTable  
      INSERT INTO @tShipLabel (Variable, Value) VALUES   
         ( '@cStorerKey',     @cStorerKey),   
         ( '@cPickSlipNo',    @cPickSlipNo),   
         ( '@cPackDtlDropID', @cSite),   
         ( '@cLabelNo',       @cLabelNo),   
         ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))  

      -- Print label  
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
         @cShipLabel, -- Report type  
         @tShipLabel, -- Report params  
         'rdtfnc_Pack',   
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
         GOTO Quit  
   END  


   /***********************************************************************************************  
                                              Pack list
   ***********************************************************************************************/  
   -- Check if last carton
   IF NOT EXISTS( SELECT TOP 1 1
      FROM PackDetail (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND RefNo = @cSite
         AND QTY = 0)
   BEGIN
      SET @cPackConfirmSite = 'Y'
      
      DECLARE @cPackList NVARCHAR( 20)
      SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)  
      IF @cPackList = '0'  
         SET @cPackList = ''  
         
      -- Pack list
      IF @cPackList <> ''
      BEGIN
         -- Get report param  
         DECLARE @tPackList AS VariableTable  
         INSERT INTO @tPackList (Variable, Value) VALUES   
            ( '@cPickSlipNo',    @cPickSlipNo),   
            ( '@cPackDtlDropID', @cSite)  

         -- Print packing list  
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
            @cPackList, -- Report type  
            @tPackList, -- Report params  
            'rdt_593CartonLBL05',   
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT  
         IF @nErrNo <> 0  
            GOTO Quit  
      END
   END

   /***********************************************************************************************
                                              Pack confirm all sites
   ***********************************************************************************************/
   IF @cPackConfirmSite = 'Y'
   BEGIN
      DECLARE @cLoadKey       NVARCHAR( 10)
      DECLARE @cOrderKey      NVARCHAR( 10)
      DECLARE @cZone          NVARCHAR( 18)
      DECLARE @cPackConfirm   NVARCHAR( 1)
      DECLARE @nPackQTY       INT
      DECLARE @nPickQTY       INT
      
      SET @cOrderKey = ''
      SET @cLoadKey = ''
      SET @cZone = ''
      SET @nPackQTY = 0
      SET @nPickQTY = 0
   
      -- Get PickHeader info
      SELECT TOP 1
         @cOrderKey = OrderKey,
         @cLoadKey = ExternOrderKey,
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo
      
      -- Calc pack QTY
      SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND PD.Status = '4') -- Short
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'
         
         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPickQTY = SUM( QTY) 
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
            
            IF @nPickQTY <> @nPackQTY
               SET @cPackConfirm = 'N'
         END
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND PD.Status = '4')  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'
         
         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPickQTY = SUM( PD.QTY) 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.OrderKey = @cOrderKey
            
            IF @nPickQTY <> @nPackQTY
               SET @cPackConfirm = 'N'
         END
      END
      
      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND PD.Status = '4')  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'
         
         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPickQTY = SUM( PD.QTY) 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
            
            IF @nPickQTY <> @nPackQTY
               SET @cPackConfirm = 'N'
         END
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1 
            FROM PickDetail PD WITH (NOLOCK) 
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND PD.Status = '4')  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'

         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPickQTY = SUM( PD.QTY) 
            FROM PickDetail PD WITH (NOLOCK) 
            WHERE PD.PickSlipNo = @cPickSlipNo
            
            IF @nPickQTY <> @nPackQTY
               SET @cPackConfirm = 'N'
         END
      END

      -- Pack confirm
      IF @cPackConfirm = 'Y'
      BEGIN
         -- Pack confirm
         UPDATE PackHeader SET 
            Status = '9', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo
         SET @nErrNo = @@ERROR 
         IF @nErrNo <> 0
         BEGIN
            -- SET @nErrNo = 100251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
            GOTO Quit
         END
/*
         -- Get storer config
         DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            '', --@c_sku
            'AssignPackLabelToOrdCfg',
            @bSuccess                 OUTPUT,
            @cAssignPackLabelToOrdCfg OUTPUT,
            @nErrNo                   OUTPUT,
            @cErrMsg                  OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran

         -- Assign
         IF @cAssignPackLabelToOrdCfg = '1'
         BEGIN
            -- Update PickDetail, base on PackDetail.DropID
            EXEC isp_AssignPackLabelToOrderByLoad
                @cPickSlipNo
               ,@bSuccess OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         -- Get storer config
         DECLARE @cDefault_PackInfo NVARCHAR(1)
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            '', --@c_sku
            'Default_PackInfo',
            @bSuccess          OUTPUT,
            @cDefault_PackInfo OUTPUT,
            @nErrNo            OUTPUT,
            @cErrMsg           OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
            
         IF @cDefault_PackInfo = '1'
         BEGIN
            IF EXISTS( SELECT 1 
               FROM PackDetail PD WITH (NOLOCK)
                  LEFT JOIN PackInfo PInf WITH (NOLOCK) ON (PD.PickSlipNo = PInf.PickSlipNo AND PD.CartonNo = PInf.CartonNo)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PInf.PickSlipNo IS NULL)
            BEGIN
               DECLARE @nCartonNo      INT 
               DECLARE @nWeight        FLOAT
               DECLARE @nCube          FLOAT
               DECLARE @nQTY           INT
               DECLARE @cCartonType    NVARCHAR( 10)
               DECLARE @nCartonWeight  FLOAT
               DECLARE @nCartonCube    FLOAT
               DECLARE @nCartonLength  FLOAT
               DECLARE @nCartonWidth   FLOAT
               DECLARE @nCartonHeight  FLOAT

               -- Get carton info
               SET @cCartontype = ''
               SELECT TOP 1 
                  @cCartonType = CartonType, 
                  @nCartonWeight = ISNULL( CartonWeight, 0), 
                  @nCartonCube = ISNULL( Cube, 0), 
                  @nCartonLength = ISNULL( CartonLength, 0),
                  @nCartonWidth  = ISNULL( CartonWidth, 0), 
                  @nCartonHeight = ISNULL( CartonHeight, 0)
               FROM Storer S WITH (NOLOCK)
                  JOIN Cartonization C WITH (NOLOCK) ON (S.CartonGroup = C.CartonizationGroup)
               WHERE S.StorerKey = @cStorerKey
               ORDER BY C.UseSequence
               
               -- Loop missing PackInfo
               SET @curPD = CURSOR FOR
                  SELECT DISTINCT PD.CartonNo
                  FROM PackDetail PD WITH (NOLOCK)
                     LEFT JOIN PackInfo PInf WITH (NOLOCK) ON (PD.PickSlipNo = PInf.PickSlipNo AND PD.CartonNo = PInf.CartonNo)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND PInf.PickSlipNo IS NULL
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @nCartonNo
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Get PackDetail info
                  SELECT 
                     @nQTY = SUM( PD.QTY), 
                     @nWeight = SUM( PD.QTY * SKU.STDGrossWGT), 
                     @nCube = SUM( PD.QTY * SKU.STDCube)
                  FROM PackDetail PD WITH (NOLOCK) 
                     JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND PD.CartonNo = @nCartonNo               
                  
                  -- Calc weight, cube
                  SET @nWeight = @nWeight + @nCartonWeight 
                  IF @nCartonCube <> 0
                     SET @nCube = @nCartonCube            

                  -- Insert PackInfo
                  INSERT INTO PackInfo (PickSlipNo, CartonNo, Weight, Cube, Qty, Cartontype, Length, Width, Height)
                  VALUES (@cPickSlipNo, @nCartonNo, @nWeight, @nCube, @nQTY, @cCartonType, @nCartonLength, @nCartonWidth, @nCartonHeight)
                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 100252
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- INS PKInf Fail
                     GOTO RollBackTran
                  END
                  
                  FETCH NEXT FROM @curPD INTO @nCartonNo
               END
            END
         END
*/
      END
   END
  
Quit:
      

GO