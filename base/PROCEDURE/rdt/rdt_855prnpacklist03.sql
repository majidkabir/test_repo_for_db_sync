SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_855PrnPackList03                                */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Print pack list after all carton of a SITE completed        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-10-30 1.0  Ung        WMS-6842 Created                          */
/* 2018-12-12 1.1  Ung        WMS-6842 Add pack confirm                 */
/* 2018-11-19 1.2  Ung        WMS-6932 Add ID param                     */
/* 2019-03-29 1.3  James      WMS-8002 Add TaskDetailKey param (james01)*/
/* 2021-10-21 1.4  James      WMS-18152 Add logic to determine whether  */
/*                            print packing list or not (james02)       */
/* 2022-07-18 1.5  Ung        WMS-20261 Add AssignPackLabelToOrdCfg     */
/************************************************************************/

CREATE   PROC [RDT].[rdt_855PrnPackList03] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cRefNo          NVARCHAR( 10),
   @cPickSlipNo     NVARCHAR( 10),
   @cLoadKey        NVARCHAR( 10),
   @cOrderKey       NVARCHAR( 10),
   @cDropID         NVARCHAR( 20),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cOption         NVARCHAR( 1),
   @cType           NVARCHAR( 10),
   @nErrNo          INT                OUTPUT, 
   @cErrMsg         NVARCHAR( 20)      OUTPUT, 
   @cPrintPackList  NVARCHAR( 1)  = '' OUTPUT, 
   @cID             NVARCHAR( 18) = '',
   @cTaskDetailKey  NVARCHAR( 10) = ''
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cLabelPrinter  NVARCHAR( 10) 
   DECLARE @cStorerKey     NVARCHAR( 15) 
   DECLARE @cFacility      NVARCHAR( 5) 
   DECLARE @cSite          NVARCHAR( 20)
   DECLARE @cPackConfirmSite  NVARCHAR(1)
   DECLARE @nPrintPackList INT
   
   -- Get session info
   SELECT 
      @cPaperPrinter = Printer_Paper, 
      @cLabelPrinter = Printer, 
      @cStorerKey = StorerKey, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile   

   -- Check whether need to print pack list
   IF @cType = 'CHECK'
   BEGIN
      -- Get PackDetail info
      SELECT TOP 1 
         @cPickSlipNo = PickSlipNo, 
         @cSite = RefNo
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND LabelNo = @cDropID
      
      -- Check PackDetail of site completed
      IF EXISTS( SELECT 1 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND RefNo = @cSite
            AND ExpQTY <> QTY)
         SET @cPrintPackList = '0' -- No
      ELSE
         SET @cPrintPackList = '1' -- Yes
   END

   -- Print pack list
   IF @cType = 'PRINT'
   BEGIN
      /*
      IF @cOption = '9' -- No
      BEGIN
         SET @nErrNo = 92806
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Pack List
         GOTO Fail
      END
      */
      
      IF @cOption = '1' -- Yes
      BEGIN
         SET @cPackConfirmSite = 'Y'
         
         DECLARE @cPackList NVARCHAR(20)
         SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)
         IF @cPackList = '0'
            SET @cPackList = ''
         
         -- Pack list
         IF @cPackList <> '' 
         BEGIN
            -- Get PackDetail info
            SELECT TOP 1 
               @cPickSlipNo = PickSlipNo, 
               @cSite = RefNo
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND LabelNo = @cDropID      

            SELECT @cLoadKey = LoadKey
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            
            SELECT @cOrderKey = OrderKey
            FROM dbo.LoadPlanDetail WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey
            
            IF NOT EXISTS ( SELECT 1 FROM dbo.Storer ST WITH (NOLOCK)
                            JOIN dbo.Orders O WITH (NOLOCK) ON ( ST.StorerKey = O.ConsigneeKey)
                            WHERE O.OrderKey = @cOrderKey
                            AND   ST.[type] = '2'
                            AND   ST.SUSR3 = 'PL')
            BEGIN

            
               DECLARE @tPackList AS VariableTable
               INSERT INTO @tPackList (Variable, Value) VALUES 
                  ( '@cPickSlipNo',    @cPickSlipNo), 
                  ( '@cPackDtlDropID', @cSite)

               -- Print packing list
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                  @cPackList, -- Report type
                  @tPackList, -- Report params
                  'rdt_855PrnPackList03', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END
   END

   /***********************************************************************************************
                                              Pack confirm all sites
   ***********************************************************************************************/
   IF @cPackConfirmSite = 'Y'
   BEGIN
      DECLARE @cZone          NVARCHAR( 18)
      DECLARE @cPackConfirm   NVARCHAR( 1)
      DECLARE @nPackQTY       INT
      DECLARE @nPickQTY       INT
      
      SET @cOrderKey = ''
      SET @cLoadKey = ''
      SET @cZone = ''
      SET @nPackQTY = 0
      SET @nPickQTY = 0

      -- Get PackDetail info
      SELECT @cPickSlipNo = PickSlipNo
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND LabelNo = @cDropID
   
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

         -- Get storer config
         DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1), @bSuccess INT
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
            GOTO Quit

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
               GOTO Quit
         END

/*
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
   
Fail:  
   RETURN  
Quit:  
   SET @nErrNo = 0 -- Not stopping error           


GO