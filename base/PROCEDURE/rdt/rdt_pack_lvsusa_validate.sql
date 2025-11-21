SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Pack_LVSUSA_Validate                            */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2024-10-18 1.0  JCH507      FCR-946 Created                          */
/************************************************************************/

CREATE   PROC rdt.rdt_Pack_LVSUSA_Validate (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10)  -- PICKSLIPNO/SKU/QTY
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cFromDropID     NVARCHAR( 20)
   ,@cPackDtlDropID  NVARCHAR( 20)
   ,@cLabelNo        NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT 
   ,@nCartonNo       INT
   ,@nErrNo          INT   OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @cValidateSP    NVARCHAR(20)

   -- Get storer configure
   SET @cValidateSP = rdt.RDTGetConfig( @nFunc, 'ValidateSP', @cStorerKey)
   IF @cValidateSP = '0'
      SET @cValidateSP = ''

   /***********************************************************************************************
                                              Custom validate
   ***********************************************************************************************/
   -- Custom logic
   IF @cValidateSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cValidateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cPickSlipNo, @cFromDropID, @cPackDtlDropID, @cLabelNo' +
            ' @cSKU, @nQTY, @nCartonNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile        INT,           ' + 
            ' @nFunc          INT,           ' + 
            ' @cLangCode      NVARCHAR( 3),  ' + 
            ' @nStep          INT,           ' + 
            ' @nInputKey      INT,           ' + 
            ' @cFacility      NVARCHAR( 5),  ' + 
            ' @cStorerKey     NVARCHAR( 15), ' +   
            ' @cType          NVARCHAR( 10), ' + 
            ' @cPickSlipNo    NVARCHAR( 10), ' +   
            ' @cFromDropID    NVARCHAR( 20), ' +   
            ' @cPackDtlDropID NVARCHAR( 20), ' + 
            ' @cLabelNo       NVARCHAR( 20), ' + 
            ' @cSKU           NVARCHAR( 20), ' +   
            ' @nQTY           INT,           ' + 
            ' @nCartonNo      INT,           ' + 
            ' @nErrNo         INT           OUTPUT, ' + 
            ' @cErrMsg        NVARCHAR(250) OUTPUT  '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cPickSlipNo, @cFromDropID, @cPackDtlDropID, 
            @cSKU, @nQTY, @nCartonNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard validate
   ***********************************************************************************************/
   DECLARE @cPackFilter          NVARCHAR( MAX) = ''
   DECLARE @cPickFilter          NVARCHAR( MAX) = ''
   DECLARE @cOrderKey            NVARCHAR( 10)
   DECLARE @cLoadKey             NVARCHAR( 10)
   DECLARE @cZone                NVARCHAR( 18)
   DECLARE @cPickStatus          NVARCHAR( 20)
   DECLARE @nPackQTY             INT -- Total Pack Qty in both lableNo
   DECLARE @nPickQTY             INT -- Total Pick Qty in both LabelNo
   DECLARE @nMasterPackQty       INT -- Total Pack Qty in the master lable no
   DECLARE @cPackByFromDropID    NVARCHAR( 1)
   DECLARE @cChkStorerKey        NVARCHAR( 15)
   DECLARE @cMasterLabelNo       NVARCHAR( 20)
   DECLARE @bDebugFlag           BINARY = 0
   

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''
   SET @nPackQTY = 0
   SET @nPickQTY = 0

   IF @bDebugFlag = 1
      SELECT @cLabelNo AS LabelNo, @cType AS ValidationType, @nQty AS Qty, @cSKU AS SKU

   --Check LabelNo
   IF @cType = 'LabelNo'
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM PickDetail WITH (NOLOCK)
                  WHERE Storerkey = @cStorerkey
                     AND CaseId = @cLabelNo
                     AND Status <= 5
                  )
      BEGIN
         SET @nErrNo = 226504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Carton
         GOTO Quit
      END

      IF EXISTS ( SELECT 1 FROM PickDetail WITH (NOLOCK)
                  WHERE Storerkey = @cStorerkey
                     AND CaseId = @cLabelNo
                     AND Status IN ('0','3','9')
                  )
      BEGIN
         SET @nErrNo = 226503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Incorrect PKD status
         GOTO Quit
      END

   END -- check LabelNo

   -- Check QTY
   IF @cType = 'QTY'
   BEGIN
      -- Get storer config
      SET @cPackByFromDropID = rdt.rdtGetConfig( @nFunc, 'PackByFromDropID', @cStorerKey)
      SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)
      
      -- Add default PickStatus 5-picked, if not specified
      IF CHARINDEX( '5', @cPickStatus) = 0
         SET @cPickStatus += ',5'
         
      -- Make PickStatus into comma delimeted, quoted string, in '0','5'... format
      SELECT @cPickStatus = STRING_AGG( QUOTENAME( a.value, ''''), ',')
      FROM 
      (
         SELECT TRIM( value) value FROM STRING_SPLIT( @cPickStatus, ',') WHERE value <> ''
      ) a

      -- Get pick filter
      SELECT @cPickFilter = ISNULL( Long, '')
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'PickFilter'
         AND Code = @nFunc 
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility

      -- Get pack filter
      SELECT @cPackFilter = ISNULL( Long, '')
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'PackFilter'
         AND Code = @nFunc 
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility

      IF @bDebugFlag = 1
         SELECT @cPickStatus AS PickStatus, @cPickFilter AS PickFilter, @cPackFilter AS PackFilter

      -- Get Master Label No
      SELECT @cMasterLabelNo = ISNULL(V_String3,'')
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      IF @cMasterLabelNo = ''
      BEGIN
         SET @nErrNo = 226506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Failed to get MLabelNo
         GOTO Quit
      END

      SELECT @nMasterPackQty = ISNULL( SUM(Qty),0)
      FROM PackDetail WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
         AND SKU = @cSKU
         AND LabelNo = @cMasterLabelNo

      IF @bDebugFlag = 1
         SELECT @cMasterLabelNo AS MasterLabelNo, @nMasterPackQty AS MasterPackQty

      --The input qty cannot be greater than the qty left in the original label no
      IF @nQty > @nMasterPackQty
      BEGIN
         SET @nErrNo = 226508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty too great
         GOTO Quit
      END

      --Not allow to empty the master label no in the New opertaion
      IF @nQty = @nMasterPackQty
      BEGIN
         IF (  SELECT COUNT (DISTINCT SKU)
               FROM PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LabelNo = @cMasterLabelNo
            ) = 1  -- The current packdetail is the last one in the master label no
            BEGIN
               SET @nErrNo = 226509
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Use merge
               GOTO Quit
            END
      END
      
      -- Calc pack QTY in both Master and New
      SET @nPackQTY = 0
     
      SET @cSQL = 
         ' SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM PackDetail PD WITH (NOLOCK) ' + 
         ' WHERE ' +
            CASE WHEN @cLabelNo = '' THEN 'PD.LabelNo = @cMasterLabelNo' ELSE 'PD.LabelNo IN (@cMasterLabelNo, @cLabelNo)' END + 
            ' AND PD.StorerKey = @cStorerKey ' + 
            ' AND PD.SKU = @cSKU '  + 
            CASE WHEN @cFromDropID <> '' AND @cPackByFromDropID = '1' THEN ' AND PD.DropID = @cFromDropID ' ELSE '' END + 
            CASE WHEN @cPackFilter <> '' THEN @cPackFilter ELSE '' END
      SET @cSQLParam = 
         ' @cMasterLabelNo NVARCHAR( 20), ' +
         ' @cLabelNo       NVARCHAR( 20), ' + 
         ' @cStorerKey     NVARCHAR( 15), ' + 
         ' @cSKU           NVARCHAR( 20), ' + 
         ' @cFromDropID    NVARCHAR( 20), ' + 
         ' @nPackQTY       INT OUTPUT '
      EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cMasterLabelNo  = @cMasterLabelNo
         ,@cLabelNo        = @cLabelNo
         ,@cStorerKey      = @cStorerKey 
         ,@cSKU            = @cSKU       
         ,@cFromDropID     = @cFromDropID
         ,@nPackQTY        = @nPackQTY OUTPUT

      IF @bDebugFlag = 1
      BEGIN
         SELECT @cSQL AS PackQtySQL
         SELECT @nPackQty AS PackQty
      END

      SET @cSQL = 
            ' SELECT @nPickQTY = ISNULL( SUM( QTY), 0) ' + 
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
            ' WHERE ' +
               CASE WHEN @cLabelNo = '' THEN 'PD.CaseID = @cMasterLabelNo' ELSE 'PD.CaseID IN (@cMasterLabelNo, @cLabelNo)' END + 
               ' AND PD.StorerKey = @cStorerKey ' + 
               ' AND PD.SKU = @cSKU ' + 
               ' AND PD.Status IN (' + @cPickStatus + ') ' + 
               CASE WHEN @cFromDropID <> '' THEN ' AND PD.DropID = @cFromDropID ' ELSE '' END + 
               CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
         SET @cSQLParam = 
            ' @cMasterLabelNo    NVARCHAR( 20), ' +
            ' @cLabelNo          NVARCHAR( 20), ' +  
            ' @cStorerKey        NVARCHAR( 15), ' + 
            ' @cSKU              NVARCHAR( 20), ' + 
            ' @cFromDropID       NVARCHAR( 20), ' + 
            ' @nPickQTY          INT OUTPUT '
         EXEC sp_executeSQL @cSQL, @cSQLParam
            ,@cMasterLabelNo  = @cMasterLabelNo
            ,@cLabelNo        = @cLabelNo
            ,@cStorerKey      = @cStorerKey
            ,@cSKU            = @cSKU
            ,@cFromDropID     = @cFromDropID
            ,@nPickQTY        = @nPickQTY OUTPUT

         IF @bDebugFlag = 1
         BEGIN
            SELECT @cSQL AS PickQtySQL
            SELECT @nPickQty AS PickQty
         END

         IF @cLabelNo = ''
            SET @nPackQTY = 0
         
         IF @nPackQTY > @nPickQTY
         BEGIN
            SET @nErrNo = 226507
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
            GOTO Quit
         END      

   END -- Qty

   IF @cType = 'SKU'
   BEGIN
      -- Check SKU in Carton
      IF NOT EXISTS( SELECT TOP 1 1
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         WHERE PD.CaseID = @cLabelNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.QTY > 0)
      BEGIN
         SET @nErrNo = 226505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn Carton
         GOTO Quit
      END
   END -- SKU

Quit:

END

GO