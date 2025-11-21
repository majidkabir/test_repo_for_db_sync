SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838PackCfmSP01                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 09-04-2018 1.0  Ung         WMS-3845 Created                         */
/* 12-07-2018 1.1  Ung         WMS-5490 Add sorting process             */
/************************************************************************/

CREATE PROC [RDT].[rdt_838PackCfmSP01] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@cFromDropID  NVARCHAR( 20)
   ,@cPackDtlDropID NVARCHAR( 20)
   ,@cPrintPackList NVARCHAR( 1) OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR(250)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess  INT
   DECLARE @cLoadKey  NVARCHAR( 10)
   DECLARE @cOrderKey NVARCHAR( 10)
   DECLARE @cZone     NVARCHAR( 18)
   DECLARE @nPackQTY  INT
   DECLARE @nPickQTY  INT
   DECLARE @cPickStatus       NVARCHAR(1)
   DECLARE @cPackConfirm      NVARCHAR(1)
   DECLARE @cPackConfirmSite  NVARCHAR(1)
   DECLARE @cPickDetailKey    NVARCHAR(10)
   DECLARE @curPD     CURSOR
   DECLARE @tPickZone TABLE 
   (
      PickZone NVARCHAR( 10) PRIMARY KEY CLUSTERED
   )

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''
   SET @cPackConfirmSite = ''
   SET @nPackQTY = 0
   SET @nPickQTY = 0

   -- Check pack confirm already
   IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')
      GOTO Quit

   /***********************************************************************************************
                                             Pack confirm by site
   ***********************************************************************************************/
   IF @cFromDropID = 'SORTED'
      SET @cPickStatus = '5'
   ELSE IF @cFromDropID = ''
      SET @cPickStatus = '0'
   ELSE
      SET @cPickStatus = '5'

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   INSERT INTO @tPickZone (PickZone)
   SELECT DISTINCT code2
   FROM dbo.CodelkUp WITH (NOLOCK)
   WHERE ListName = 'ALLSorting'
      AND StorerKey = @cStorerKey
      AND Code = @cPackDtlDropID

   -- Calc pack QTY
   SET @nPackQTY = 0
   SELECT @nPackQTY = ISNULL( SUM( QTY), 0) 
   FROM PackDetail WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo
      AND RefNo = @cPackDtlDropID

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.Status < '5'
            AND PD.QTY > 0
            AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick
         SET @cPackConfirmSite = 'N'
      ELSE
         SET @cPackConfirmSite = 'Y'
      
      -- Check fully packed
      IF @cPackConfirmSite = 'Y'
      BEGIN
         SELECT @nPickQTY = SUM( QTY) 
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE RKL.PickSlipNo = @cPickSlipNo
         
         IF @nPickQTY <> @nPackQTY
            SET @cPackConfirmSite = 'N'
      END

      IF @cPackConfirmSite = 'Y'
         SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey
            FROM PickDetail PD WITH (NOLOCK) 
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.Status < '5'
               AND PD.QTY > 0 
               AND PD.Status <> '4'
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.Status < '5'
            AND PD.QTY > 0
            AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick
         SET @cPackConfirmSite = 'N'
      ELSE
         SET @cPackConfirmSite = 'Y'
      
      -- Check fully packed
      IF @cPackConfirmSite = 'Y'
      BEGIN
         SELECT @nPickQTY = SUM( PD.QTY) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE PD.OrderKey = @cOrderKey
         
         IF @nPickQTY <> @nPackQTY
            SET @cPackConfirmSite = 'N'
      END
      
      IF @cPackConfirmSite = 'Y'
         SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND PD.Status <> '4'
   END
   
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.Status < '5'
            AND PD.QTY > 0
            AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick
         SET @cPackConfirmSite = 'N'
      ELSE
         SET @cPackConfirmSite = 'Y'
      
      -- Check fully packed
      IF @cPackConfirmSite = 'Y'
      BEGIN
         SELECT @nPickQTY = SUM( PD.QTY) 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE LPD.LoadKey = @cLoadKey
         
         IF @nPickQTY <> @nPackQTY
            SET @cPackConfirmSite = 'N'
      END
      
      IF @cPackConfirmSite = 'Y'
         SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND PD.Status <> '4'

   END

   -- Custom PickSlip
   ELSE
   BEGIN
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1 
         FROM PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.Status < '5'
            AND PD.QTY > 0
            AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick
         SET @cPackConfirmSite = 'N'
      ELSE
         SET @cPackConfirmSite = 'Y'

      -- Check fully packed
      IF @cPackConfirmSite = 'Y'
      BEGIN
         SELECT @nPickQTY = SUM( PD.QTY) 
         FROM PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE PD.PickSlipNo = @cPickSlipNo
         
         IF @nPickQTY <> @nPackQTY
            SET @cPackConfirmSite = 'N'

      IF @cPackConfirmSite = 'Y'
         SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey
            FROM PickDetail PD WITH (NOLOCK) 
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND PD.Status <> '4'
      END      
   END

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_838PackCfmSP01 -- For rollback or commit only our own transaction

   -- Pack confirm by site
   IF @cPackConfirmSite = 'Y'
   BEGIN
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE PickDetail SET
            Status = '5', 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE PickDetailKey = @cPickDetailKey
         SET @nErrNo = @@ERROR 
         IF @nErrNo <> 0
         BEGIN
            -- SET @nErrNo = 100251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PickCfm Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey   
      END
      
      SET @cPrintPackList = 'Y'
   END
   

   /***********************************************************************************************
                                              Pack confirm all
   ***********************************************************************************************/
   IF @cPackConfirmSite = 'Y'
   BEGIN
      -- Calc pack QTY
      SET @nPackQTY = 0
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
            GOTO RollBackTran
         END

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
      END
   END
   
   COMMIT TRAN rdt_838PackCfmSP01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_838PackCfmSP01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO