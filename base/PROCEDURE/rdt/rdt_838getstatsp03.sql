SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838GetStatSP03                                  */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Get carton level info for LVSUSA                            */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 06-25-2024 1.0  Jackc       FCR-392 created                          */
/************************************************************************/

CREATE PROC rdt.rdt_838GetStatSP03(
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10)  -- CURRENT/NEXT
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cFromDropID     NVARCHAR( 20)
   ,@cPackDtlDropID  NVARCHAR( 20)
   ,@nCartonNo       INT            OUTPUT
   ,@cLabelNo        NVARCHAR( 20)  OUTPUT
   ,@cCustomNo       NVARCHAR( 5)   OUTPUT
   ,@cCustomID       NVARCHAR( 20)  OUTPUT
   ,@nCartonSKU      INT            OUTPUT
   ,@nCartonQTY      INT            OUTPUT
   ,@nTotalCarton    INT            OUTPUT
   ,@nTotalPick      INT            OUTPUT
   ,@nTotalPack      INT            OUTPUT
   ,@nTotalShort     INT            OUTPUT
   ,@nErrNo          INT            OUTPUT
   ,@cErrMsg         NVARCHAR(250)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR(MAX)
   DECLARE @cSQLParam   NVARCHAR(MAX)
   DECLARE @cGetStatSP  NVARCHAR(20)

   DECLARE @cPackFilter NVARCHAR( MAX) = ''
   DECLARE @cPickFilter NVARCHAR( MAX) = ''
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cDropID     NVARCHAR( 20)
   DECLARE @cRefNo      NVARCHAR( 20)
   DECLARE @cRefNo2     NVARCHAR( 30)
   DECLARE @nRowCount   INT = 0

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Get cartonNo based on FromDropID
   IF EXISTS ( SELECT 1 FROM PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LabelNo = @cFromDropID)
   BEGIN
      SET @cLabelNo = @cFromDropID
   END
   ELSE
   BEGIN
      SELECT @cLabelNo = LabelNo FROM CartonTrack WITH (NOLOCK)
      WHERE TrackingNo = @cFromDropID
         AND KeyName = @cStorerKey
   END



   /*
   SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo
   */
   SET @cSQL = 
      ' SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo) ' + 
      ' FROM dbo.PackDetail PD WITH (NOLOCK) ' + 
      ' WHERE PD.PickSlipNo = @cPickSlipNo '
   SET @cSQLParam = 
      ' @cPickSlipNo    NVARCHAR( 10), ' +
      ' @nTotalCarton   INT OUTPUT '
   EXEC sp_executeSQL @cSQL, @cSQLParam
      ,@cPickSlipNo  = @cPickSlipNo
      ,@nTotalCarton = @nTotalCarton OUTPUT
   
   IF @cType = 'CURRENT'
   BEGIN
      /*
      SELECT TOP 1 
         @nCartonNo = CartonNo, 
         @cLabelNo = LabelNo, 
         @cDropID = DropID, 
         @cRefNo = RefNo, 
         @cRefNo2 = RefNo2
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
      ORDER BY CartonNo
      */
      SET @cSQL = 
         ' SELECT TOP 1 ' + 
            ' @nCartonNo = CartonNo, ' + 
            ' @cLabelNo = LabelNo, ' + 
            ' @cDropID = DropID, ' + 
            ' @cRefNo = RefNo, ' + 
            ' @cRefNo2 = RefNo2 ' + 
         ' FROM dbo.PackDetail PD WITH (NOLOCK) ' + 
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
            ' AND CartonNo = @nCartonNo ' + 
              --CASE WHEN @cPackFilter <> '' THEN @cPackFilter ELSE '' END + 
         ' ORDER BY CartonNo ' 
      SET @cSQLParam = 
         ' @nCartonNo   INT           OUTPUT, ' + 
         ' @cLabelNo    NVARCHAR( 20) OUTPUT, ' + 
         ' @cDropID     NVARCHAR( 20) OUTPUT, ' + 
         ' @cRefNo      NVARCHAR( 20) OUTPUT, ' + 
         ' @cRefNo2     NVARCHAR( 30) OUTPUT, ' + 
         ' @cPickSlipNo NVARCHAR( 10) '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@nCartonNo   = @nCartonNo OUTPUT
         ,@cLabelNo    = @cLabelNo  OUTPUT
         ,@cDropID     = @cDropID   OUTPUT
         ,@cRefNo      = @cRefNo    OUTPUT
         ,@cRefNo2     = @cRefNo2   OUTPUT
         ,@cPickSlipNo = @cPickSlipNo
   END
   
   IF @cType = 'NEXT'
   BEGIN
      /*
      SELECT TOP 1 
         @nCartonNo = CartonNo, 
         @cLabelNo = LabelNo, 
         @cDropID = DropID, 
         @cRefNo = RefNo, 
         @cRefNo2 = RefNo2
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo > @nCartonNo
      ORDER BY CartonNo
      */
      SET @nRowCount = 0
      SET @cSQL = 
         ' SELECT TOP 1 ' + 
            ' @nCartonNo = CartonNo, ' + 
            ' @cLabelNo = LabelNo, ' + 
            ' @cDropID = DropID, ' + 
            ' @cRefNo = RefNo, ' + 
            ' @cRefNo2 = RefNo2 ' + 
         ' FROM dbo.PackDetail PD WITH (NOLOCK) ' + 
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
            ' AND CartonNo > @nCartonNo ' + 
              --CASE WHEN @cPackFilter <> '' THEN @cPackFilter ELSE '' END + 
         ' ORDER BY CartonNo ' + 
         ' SET @nRowCount = @@ROWCOUNT '
      SET @cSQLParam = 
         ' @nCartonNo   INT           OUTPUT, ' + 
         ' @cLabelNo    NVARCHAR( 20) OUTPUT, ' + 
         ' @cDropID     NVARCHAR( 20) OUTPUT, ' + 
         ' @cRefNo      NVARCHAR( 20) OUTPUT, ' + 
         ' @cRefNo2     NVARCHAR( 30) OUTPUT, ' + 
         ' @nRowCount   INT           OUTPUT, ' + 
         ' @cPickSlipNo NVARCHAR( 10) '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@nCartonNo   = @nCartonNo OUTPUT
         ,@cLabelNo    = @cLabelNo  OUTPUT
         ,@cDropID     = @cDropID   OUTPUT
         ,@cRefNo      = @cRefNo    OUTPUT
         ,@cRefNo2     = @cRefNo2   OUTPUT
         ,@nRowCount   = @nRowCount OUTPUT
         ,@cPickSlipNo = @cPickSlipNo
   
      --IF @@ROWCOUNT = 0
      IF @nRowCount = 0
      BEGIN
         /*
         SELECT TOP 1 
            @nCartonNo = CartonNo, 
            @cLabelNo = LabelNo, 
            @cDropID = DropID, 
            @cRefNo = RefNo, 
            @cRefNo2 = RefNo2
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
         ORDER BY CartonNo   
         */
         SET @nRowCount = 0
         SET @cSQL = 
            ' SELECT TOP 1 ' + 
               ' @nCartonNo = CartonNo, ' + 
               ' @cLabelNo = LabelNo, ' + 
               ' @cDropID = DropID, ' + 
               ' @cRefNo = RefNo, ' + 
               ' @cRefNo2 = RefNo2 ' + 
            ' FROM dbo.PackDetail PD WITH (NOLOCK) ' + 
            ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
                 --CASE WHEN @cPackFilter <> '' THEN @cPackFilter ELSE '' END + 
            ' ORDER BY CartonNo ' + 
            ' SET @nRowCount = @@ROWCOUNT '
         SET @cSQLParam = 
            ' @nCartonNo   INT           OUTPUT, ' + 
            ' @cLabelNo    NVARCHAR( 20) OUTPUT, ' + 
            ' @cDropID     NVARCHAR( 20) OUTPUT, ' + 
            ' @cRefNo      NVARCHAR( 20) OUTPUT, ' + 
            ' @cRefNo2     NVARCHAR( 30) OUTPUT, ' + 
            ' @nRowCount   INT           OUTPUT, ' + 
            ' @cPickSlipNo NVARCHAR( 10) ' 
         EXEC sp_executeSQL @cSQL, @cSQLParam
            ,@nCartonNo   = @nCartonNo OUTPUT
            ,@cLabelNo    = @cLabelNo  OUTPUT
            ,@cDropID     = @cDropID   OUTPUT
            ,@cRefNo      = @cRefNo    OUTPUT
            ,@cRefNo2     = @cRefNo2   OUTPUT
            ,@nRowCount   = @nRowCount OUTPUT
            ,@cPickSlipNo = @cPickSlipNo   

         --IF @@ROWCOUNT = 0
         IF @nRowCount = 0
            SELECT 
               @nCartonNo = 0, 
               @cLabelNo = '', 
               @cDropID = '', 
               @cRefNo = '', 
               @cRefNo2 = ''
      END
   END
   
   SELECT 
      @nCartonSKU = COUNT( DISTINCT PD.SKU), 
      @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      AND LabelNo = @cLabelNo

   -- Storer configure
   DECLARE @cCustomCartonNo NVARCHAR(1)
   DECLARE @cCustomCartonID NVARCHAR(1)
   SET @cCustomCartonNo = rdt.rdtGetConfig( @nFunc, 'CustomCartonNo', @cStorerKey)
   SET @cCustomCartonID = rdt.rdtGetConfig( @nFunc, 'CustomCartonID', @cStorerKey)
   
   -- Get customm carton no / label no
   SELECT 
      @cCustomNo = 
         CASE @cCustomCartonNo 
            WHEN '1' THEN LEFT( @cDropID, 5)
            WHEN '2' THEN LEFT( @cRefNo, 5)
            WHEN '3' THEN LEFT( @cRefNo2, 5)
            ELSE CAST( @nCartonNo AS NVARCHAR(5))
         END, 
      @cCustomID = 
         CASE @cCustomCartonID 
            WHEN '1' THEN @cDropID
            WHEN '2' THEN @cRefNo
            WHEN '3' THEN LEFT( @cRefNo2, 20)
            ELSE @cLabelNo
         END
   
   IF @cCustomNo = ''
      SET @cCustomNo = '0'


   /***********************************************************************************************
                                                PackDetail
   ***********************************************************************************************/
   -- Get total pack qty based on label no
   SET @cSQL = 
      ' SELECT @nTotalPack = ISNULL( SUM( PD.QTY), 0) ' + 
      ' FROM dbo.PackDetail PD WITH (NOLOCK) ' + 
      ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
      ' AND LabelNo = @cLabelNo '
   SET @cSQLParam = 
      ' @cPickSlipNo NVARCHAR( 10), ' + 
      ' @cLabelNo    NVARCHAR( 20), ' + 
      ' @nTotalPack  INT OUTPUT '
   EXEC sp_executeSQL @cSQL, @cSQLParam
      ,@cPickSlipNo = @cPickSlipNo
      ,@cLabelNo    = @cLabelNo
      ,@nTotalPack  = @nTotalPack OUTPUT

   /***********************************************************************************************
                                                PickDetail
   ***********************************************************************************************/
   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      /*
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
      WHERE RKL.PickSlipNo = @cPickSlipNo
         AND PD.Status <= '5'
         AND PD.Status <> '4'
      */
      SET @cSQL = 
         ' SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' + 
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.Status <= ''5'' ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.CaseID = @cLabelNo '
            --CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
      SET @cSQLParam = 
         ' @cPickSlipNo NVARCHAR( 10), ' + 
         ' @cLabelNo    NVARCHAR( 20), ' + 
         ' @nTotalPick  INT OUTPUT '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cPickSlipNo  = @cPickSlipNo
         ,@cLabelNo     = @cLabelNo
         ,@nTotalPick   = @nTotalPick OUTPUT
      
      /*
      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
      WHERE RKL.PickSlipNo = @cPickSlipNo
         AND PD.Status = '4'
      */
      SET @cSQL = 
         ' SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' + 
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.Status = ''4'' ' + 
            ' AND PD.CaseID = @cLabelNo '
            --CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
      SET @cSQLParam = 
         ' @cPickSlipNo NVARCHAR( 10), ' + 
         ' @cLabelNo    NVARCHAR( 20), ' + 
         ' @nTotalShort INT OUTPUT '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cPickSlipNo  = @cPickSlipNo
         ,@cLabelNo     = @cLabelNo
         ,@nTotalShort  = @nTotalShort OUTPUT
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      /*
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.Status <= '5'
         AND PD.Status <> '4'
      */
      SET @cSQL = 
         ' SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
         ' WHERE PD.OrderKey = @cOrderKey ' + 
            ' AND PD.Status <= ''5'' ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.CaseID = @cLabelNo '
            --CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
      SET @cSQLParam = 
         ' @cOrderKey      NVARCHAR( 10), ' + 
         ' @cLabelNo       NVARCHAR( 20), ' + 
         ' @nTotalPick     INT OUTPUT '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cOrderKey   = @cOrderKey
         ,@cLabelNo    = @cLabelNo
         ,@nTotalPick  = @nTotalPick OUTPUT
      
      /*
      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.Status = '4'
      */
      SET @cSQL = 
         ' SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
         ' WHERE PD.OrderKey = @cOrderKey ' + 
            ' AND PD.Status = ''4'' ' + 
            ' AND PD.CaseID = @cLabelNo '
            --CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
      SET @cSQLParam = 
         ' @cOrderKey      NVARCHAR( 10), ' + 
         ' @cLabelNo       NVARCHAR( 20), ' + 
         ' @nTotalShort    INT OUTPUT '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cOrderKey    = @cOrderKey
         ,@cLabelNo     = @cLabelNo
         ,@nTotalShort  = @nTotalShort OUTPUT
   END
               
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      /*
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
      WHERE LPD.LoadKey = @cLoadKey  
         AND PD.Status <= '5'
         AND PD.Status <> '4'
      */
      SET @cSQL = 
         ' SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' + 
         ' WHERE LPD.LoadKey = @cLoadKey ' + 
            ' AND PD.Status <= ''5'' ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.CaseID = @cLabelNo '
            --CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
      SET @cSQLParam = 
         ' @cLoadKey       NVARCHAR( 10), ' + 
         ' @cLabelNo       NVARCHAR( 20), ' + 
         ' @nTotalPick     INT OUTPUT '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cLoadKey     = @cLoadKey
         ,@cLabelNo     = @cLabelNo
         ,@nTotalPick   = @nTotalPick OUTPUT
      
      /*
      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
      WHERE LPD.LoadKey = @cLoadKey  
         AND PD.Status = '4'
      */
      SET @cSQL = 
         ' SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' + 
         ' WHERE LPD.LoadKey = @cLoadKey ' + 
            ' AND PD.Status = ''4'' ' + 
            ' AND PD.CaseID = @cLabelNo '
            --CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
      SET @cSQLParam = 
         ' @cLoadKey       NVARCHAR( 10), ' + 
         ' @cLabelNo       NVARCHAR( 20), ' + 
         ' @nTotalShort    INT OUTPUT '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cLoadKey     = @cLoadKey
         ,@cLabelNo     = @cLabelNo
         ,@nTotalShort  = @nTotalShort OUTPUT
   END
   
   -- Custom PickSlip
   ELSE
   BEGIN
      /*
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.Status <= '5'
         AND PD.Status <> '4'
      */
      SET @cSQL = 
         ' SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.Status <= ''5'' ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.CaseID = @cLabelNo '
            --CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
      SET @cSQLParam = 
         ' @cPickSlipNo NVARCHAR( 10), ' + 
         ' @cLabelNo    NVARCHAR( 20), ' + 
         ' @nTotalPick  INT OUTPUT '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cPickSlipNo  = @cPickSlipNo
         ,@cLabelNo     = @cLabelNo
         ,@nTotalPick   = @nTotalPick OUTPUT
      
      /*
      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.Status = '4'
      */
      SET @cSQL = 
         ' SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' +
            ' AND PD.Status = ''4'' ' + 
            ' AND PD.CaseID = @cLabelNo '
            --CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
      SET @cSQLParam = 
         ' @cPickSlipNo NVARCHAR( 10), ' + 
         ' @cLabelNo    NVARCHAR( 20), ' +
         ' @nTotalShort INT OUTPUT '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cPickSlipNo  = @cPickSlipNo
         ,@cLabelNo     = @cLabelNo
         ,@nTotalShort  = @nTotalShort OUTPUT
   END

Quit:

END

GO