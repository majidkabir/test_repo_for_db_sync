SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_838ValidateVLT                                        */
/*                                                                            */
/*                                                                            */
/* Date        Rev   Author   Purposes                                        */
/* 2024-05-20  1.0   PPA374   Corrects Packed and Picked qty and allows to    */
/*                            pack to a different DROPID than "from DROPID"   */
/* 2024-10-11  1.1   PXL009   FCR-778 Violet Pack Changes                     */
/*                            QTY validate ignore packed qty when MoveQTYPack */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_838ValidateVLT] (
@nMobile        INT,             
@nFunc          INT,             
@cLangCode      NVARCHAR( 3),    
@nStep          INT,             
@nInputKey      INT,             
@cFacility      NVARCHAR( 5),    
@cStorerKey     NVARCHAR( 15),     
@cType          NVARCHAR( 10),   
@cPickSlipNo    NVARCHAR( 10),     
@cFromDropID    NVARCHAR( 20),     
@cPackDtlDropID NVARCHAR( 20),   
@cSKU           NVARCHAR( 20),     
@nQTY           INT,             
@nCartonNo      INT,             
@nErrNo         INT           OUTPUT,   
@cErrMsg        NVARCHAR(250) OUTPUT  
) AS

BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @cValidateSP    NVARCHAR(20)

   IF @nFunc = '838'
   BEGIN
      DECLARE @cPackFilter NVARCHAR( MAX) = ''
      DECLARE @cPickFilter NVARCHAR( MAX) = ''
      DECLARE @cOrderKey   NVARCHAR( 10)
      DECLARE @cLoadKey    NVARCHAR( 10)
      DECLARE @cZone       NVARCHAR( 18)
      DECLARE @cPickStatus NVARCHAR( 20)
      DECLARE @nPackQTY    INT
      DECLARE @nPickQTY    INT
      DECLARE @cPackByFromDropID NVARCHAR( 1)
      DECLARE @cMoveQTYPack      NVARCHAR( 20)

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

      SET @cMoveQTYPack = [rdt].[RDTGetConfig]( @nFunc, N'MoveQTYPack', @cStorerKey)

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

         -- Calc pack QTY
         SET @nPackQTY = 0
         /*
         SELECT @nPackQTY = ISNULL( SUM( QTY), 0) 
         FROM PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND (@cFromDropID = '' OR DropID = @cFromDropID)
         */
         SET @cSQL = 
         ' SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM PackDetail PD WITH (NOLOCK) ' + 
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
         ' AND PD.StorerKey = @cStorerKey ' + 
         ' AND PD.SKU = @cSKU '  + 
         CASE WHEN @cFromDropID <> '' AND @cPackByFromDropID = '1' THEN ' AND PD.DropID = @cFromDropID ' ELSE '' END + 
         CASE WHEN @cPackFilter <> '' THEN @cPackFilter ELSE '' END
         SET @cSQLParam = 
         ' @cPickSlipNo NVARCHAR( 10), ' + 
         ' @cStorerKey  NVARCHAR( 15), ' + 
         ' @cSKU        NVARCHAR( 20), ' + 
         ' @cFromDropID NVARCHAR( 20), ' + 
         ' @nPackQTY    INT OUTPUT '
         EXEC sp_executeSQL @cSQL, @cSQLParam
         ,@cPickSlipNo = @cPickSlipNo
         ,@cStorerKey  = @cStorerKey 
         ,@cSKU        = @cSKU       
         ,@cFromDropID = @cFromDropID
         ,@nPackQTY    = @nPackQTY OUTPUT

         -- Add QTY
         SET @nPackQTY = @nPackQTY + @nQTY
      END

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         IF @cType = 'PickSlipNo'
         BEGIN
            -- Check PickSlipNo valid 
            IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.RefKeyLookup RKL WITH (NOLOCK) WHERE RKL.PickSlipNo = @cPickSlipNo)
            BEGIN
               SET @nErrNo = 100351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               GOTO Quit
            END

            -- Check diff storer
            IF EXISTS( SELECT TOP 1 1
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = RKL.Orderkey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
            AND O.StorerKey <> @cStorerKey)
            BEGIN
               SET @nErrNo = 100352
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
               GOTO Quit
            END
         END
      
         ELSE IF @cType = 'SKU'
         BEGIN
            IF @cFromDropID = '' 
            BEGIN
               -- Check SKU in PickSlipNo
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.QTY > 0)
               BEGIN
                  SET @nErrNo = 100353
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
                  SET @cErrMsg = ''
                  GOTO Quit
               END
            END
         
		    ELSE
            BEGIN
               -- Check SKU in DropID
               IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.QTY > 0
               AND PD.DropID = @cFromDropID)
               BEGIN
                  SET @nErrNo = 100369
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
                  SET @cErrMsg = ''
                  GOTO Quit
               END
            END
         END
      
         ELSE IF @cType = 'QTY'
         BEGIN
            /*
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status IN (@cPickStatus) 
            AND (@cFromDropID = '' OR PD.DropID = @cFromDropID)
            */      
            SET @cSQL = 
            ' SELECT @nPickQTY = ISNULL( SUM( QTY), 0) ' + 
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' + 
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.StorerKey = @cStorerKey ' + 
            ' AND PD.SKU = @cSKU ' + 
            ' AND PD.Status IN (' + @cPickStatus + ') ' + 
            --CASE WHEN @cFromDropID <> '' THEN ' AND PD.DropID = @cFromDropID ' ELSE '' END + 
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
            SET @cSQLParam = 
            ' @cPickSlipNo NVARCHAR( 10), ' + 
            ' @cStorerKey  NVARCHAR( 15), ' + 
            ' @cSKU        NVARCHAR( 20), ' + 
            ' @cFromDropID NVARCHAR( 20), ' + 
            ' @nPickQTY    INT OUTPUT '
            EXEC sp_executeSQL @cSQL, @cSQLParam
            ,@cPickSlipNo = @cPickSlipNo
            ,@cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU
            ,@cFromDropID = @cFromDropID
            ,@nPickQTY    = @nPickQTY OUTPUT
		
		    IF @nQTY > 
		    ((select isnull(sum(qty),0) from dbo.RefKeyLookup RKL WITH (NOLOCK) 
		    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
		    WHERE RKL.PickSlipNo = @cPickSlipNo
		    AND PD.StorerKey = @cStorerKey
		    AND PD.SKU = @cSKU
		    AND PD.Status = 5
		    AND PD.DropID = @cFromDropID) - 
         -- when the pickdetail/inventory moved, regardless the qty packed.
         CASE WHEN @cMoveQTYPack = N'1'
         THEN
            (select isnull(sum(qty),0) FROM dbo.PackDetail PD (NOLOCK)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.DropID = @cFromDropID
            AND PD.RefNo2 = @cFromDropID)
         ELSE
            (select isnull(sum(qty),0) FROM dbo.PackDetail PD (NOLOCK)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.RefNo2 = @cFromDropID) 
         END -
		    (select isnull(sum(qty),0) from dbo.PackDetail PD (NOLOCk)
		    WHERE PD.PickSlipNo = @cPickSlipNo
		    AND PD.StorerKey = @cStorerKey
		    AND PD.SKU = @cSKU
		    AND PD.RefNo2 = ''
		    AND PD.DropID = @cPackDtlDropID)) 

		    BEGIN
               SET @nErrNo = 218027
               SET @cErrMsg = 'Over DROPID qty'
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END

            IF @nPackQTY > @nPickQTY
            BEGIN
               SET @nErrNo = 100354
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END
         END
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         IF @cType = 'PickSlipNo'
         BEGIN
            DECLARE @cChkStorerKey NVARCHAR( 15)
            DECLARE @cChkStatus    NVARCHAR( 10)
            DECLARE @cChkSOStatus  NVARCHAR( 10)

            -- Get Order info
            SELECT 
            @cChkStorerKey = StorerKey, 
            @cChkStatus = Status, 
            @cChkSOStatus = SOStatus
            FROM dbo.Orders WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
		    and StorerKey = @cStorerKey
         
            -- Check PickSlipNo valid 
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 100355
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               GOTO Quit
            END
         
            -- Check storer
            IF @cChkStorerKey <> @cStorerKey
            BEGIN
               SET @nErrNo = 100357
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
               GOTO Quit
            END
         
            -- Check order shipped
            IF @cChkStatus > '5'
            BEGIN
               SET @nErrNo = 100356
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order shipped
               GOTO Quit
            END
         
            -- Check order cancel
            IF @cChkSOStatus = 'CANC'
            BEGIN
               SET @nErrNo = 100368
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
               GOTO Quit
            END
         END

         ELSE IF @cType = 'SKU'
         BEGIN
            IF @cFromDropID = '' 
            BEGIN
               -- Check SKU in PickSlipNo
               IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.QTY > 0)
               BEGIN
                  SET @nErrNo = 100358
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
                  SET @cErrMsg = ''
                  GOTO Quit
               END
            END
         
		    ELSE
            BEGIN
               -- Check SKU in PickSlipNo
               IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.QTY > 0
               AND PD.DropID = @cFromDropID)
               BEGIN
                  SET @nErrNo = 100370
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
                  SET @cErrMsg = ''
                  GOTO Quit
               END
            END
         END
      
         ELSE IF @cType = 'QTY'
         BEGIN
            /*
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.OrderKey = @cOrderKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status IN (@cPickStatus) 
            AND (@cFromDropID = '' OR PD.DropID = @cFromDropID)
            */
            SET @cSQL = 
            ' SELECT @nPickQTY = ISNULL( SUM( QTY), 0) ' + 
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
            ' WHERE PD.OrderKey = @cOrderKey ' + 
            ' AND PD.StorerKey = @cStorerKey ' + 
            ' AND PD.SKU = @cSKU ' + 
            ' AND PD.Status IN (' + @cPickStatus + ') ' + 
            --CASE WHEN @cFromDropID <> '' THEN ' AND PD.DropID = @cFromDropID ' ELSE '' END + 
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
            SET @cSQLParam = 
            ' @cOrderKey   NVARCHAR( 10), ' + 
            ' @cStorerKey  NVARCHAR( 15), ' + 
            ' @cSKU        NVARCHAR( 20), ' + 
            ' @cFromDropID NVARCHAR( 20), ' + 
            ' @nPickQTY    INT OUTPUT '
            EXEC sp_executeSQL @cSQL, @cSQLParam
            ,@cOrderKey   = @cOrderKey
            ,@cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU
            ,@cFromDropID = @cFromDropID
            ,@nPickQTY    = @nPickQTY OUTPUT
         
		    IF @nQTY > 
		    ((select isnull(sum(qty),0) FROM dbo.PickDetail PD WITH (NOLOCK)
		    WHERE PD.OrderKey = @cOrderKey
		    AND PD.StorerKey = @cStorerKey
		    AND PD.SKU = @cSKU
		    AND PD.Status = 5
		    AND PD.DropID = @cFromDropID) -
         -- when the pickdetail/inventory moved, regardless the qty packed.
         CASE WHEN @cMoveQTYPack = N'1'
         THEN
            (select isnull(sum(qty),0) FROM dbo.PackDetail PD (NOLOCK)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.DropID = @cFromDropID
            AND PD.RefNo2 = @cFromDropID)
         ELSE
            (select isnull(sum(qty),0) FROM dbo.PackDetail PD (NOLOCK)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.RefNo2 = @cFromDropID)
         END -
		    (select isnull(sum(qty),0) from dbo.PackDetail PD (NOLOCk)
		    WHERE PD.PickSlipNo = @cPickSlipNo
		    AND PD.StorerKey = @cStorerKey
		    AND PD.SKU = @cSKU
		    AND PD.RefNo2 = ''
		    AND PD.DropID = @cPackDtlDropID)) 

		    BEGIN
               SET @nErrNo = 218027
               SET @cErrMsg = 'Over DROPID qty'
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END

            IF @nPackQTY > @nPickQTY
            BEGIN
               SET @nErrNo = 100359
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END
         END
      END
               
      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         IF @cType = 'PickSlipNo'
         BEGIN
            -- Check PickSlip valid
            IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) WHERE LPD.LoadKey = @cLoadKey)
            BEGIN
               SET @nErrNo = 100360
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               GOTO Quit
            END
        
            -- Check diff storer
            IF EXISTS( SELECT TOP 1 1 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
            WHERE LPD.LoadKey = @cLoadKey
            AND O.StorerKey <> @cStorerKey)
            BEGIN
               SET @nErrNo = 100361
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
               GOTO Quit
            END
         END
      
         ELSE IF @cType = 'SKU'
         BEGIN
            IF @cFromDropID = '' 
            BEGIN
               -- Check SKU in PickSlipNo
               IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
               WHERE LPD.LoadKey = @cLoadKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.QTY > 0)
               BEGIN
                  SET @nErrNo = 100362
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
                  SET @cErrMsg = ''
                  GOTO Quit
               END
            END
         
		    ELSE
            BEGIN
               -- Check SKU in PickSlipNo
               IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
               WHERE LPD.LoadKey = @cLoadKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.QTY > 0
               AND PD.DropID = @cFromDropID)
               BEGIN
                  SET @nErrNo = 100371
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
                  SET @cErrMsg = ''
                  GOTO Quit
               END
            END
         END
      
         ELSE IF @cType = 'QTY'
         BEGIN
            /*
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status IN (@cPickStatus) 
            AND (@cFromDropID = '' OR PD.DropID = @cFromDropID)
            */
            SET @cSQL = 
            ' SELECT @nPickQTY = ISNULL( SUM( QTY), 0) ' +
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
            ' WHERE LPD.LoadKey = @cLoadKey ' +
            ' AND PD.StorerKey = @cStorerKey ' +
            ' AND PD.SKU = @cSKU ' +
            ' AND PD.Status IN (' + @cPickStatus + ') ' + 
            -- CASE WHEN @cFromDropID <> '' THEN ' AND PD.DropID = @cFromDropID ' ELSE '' END + 
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
            SET @cSQLParam = 
            ' @cLoadKey    NVARCHAR( 10), ' + 
            ' @cStorerKey  NVARCHAR( 15), ' + 
            ' @cSKU        NVARCHAR( 20), ' + 
            ' @cFromDropID NVARCHAR( 20), ' + 
            ' @nPickQTY    INT OUTPUT '
            EXEC sp_executeSQL @cSQL, @cSQLParam
            ,@cLoadKey    = @cLoadKey
            ,@cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU
            ,@cFromDropID = @cFromDropID
            ,@nPickQTY    = @nPickQTY OUTPUT
         
         IF @nQTY > 
		    ((select isnull(sum(qty),0) FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
		    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
		    WHERE LPD.LoadKey = @cLoadKey
		    AND PD.StorerKey = @cStorerKey
		    AND PD.SKU = @cSKU
		    AND PD.Status = 5
		    AND PD.DropID = @cFromDropID) -
         -- when the pickdetail/inventory moved, regardless the qty packed.
         CASE WHEN @cMoveQTYPack = N'1'
         THEN
            (select isnull(sum(qty),0) FROM dbo.PackDetail PD (NOLOCK)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.DropID = @cFromDropID
            AND PD.RefNo2 = @cFromDropID)
         ELSE
            (select isnull(sum(qty),0) FROM dbo.PackDetail PD (NOLOCK)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.RefNo2 = @cFromDropID)
         END -
         (select isnull(sum(qty),0) from dbo.PackDetail PD (NOLOCk)
		    WHERE PD.PickSlipNo = @cPickSlipNo
		    AND PD.StorerKey = @cStorerKey
		    AND PD.SKU = @cSKU
		    AND PD.RefNo2 = ''
		    AND PD.DropID = @cPackDtlDropID))

		    BEGIN
               SET @nErrNo = 218027
               SET @cErrMsg = 'Over DROPID qty'
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END

            IF @nPackQTY > @nPickQTY
            BEGIN
               SET @nErrNo = 100363
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END
         END
      END
   
      -- Custom PickSlip
      ELSE
      BEGIN
         IF @cType = 'PickSlipNo'
         BEGIN
            -- Check PickSlip valid 
            IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo and Storerkey = @cStorerKey)
            BEGIN
               SET @nErrNo = 100364
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               GOTO Quit
            END

            -- Check diff storer
            IF EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND StorerKey <> @cStorerKey)
            BEGIN
               SET @nErrNo = 100365
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
               GOTO Quit
            END
         END

         ELSE IF @cType = 'SKU'
         BEGIN
            IF @cFromDropID = '' 
            BEGIN
               -- Check SKU in PickSlipNo
               IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.PickDetail PD (NOLOCK) 
               WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.QTY > 0)
               BEGIN
                  SET @nErrNo = 100366
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
                  SET @cErrMsg = ''
                  GOTO Quit
               END
            END
         
		    ELSE
            BEGIN
               -- Check SKU in PickSlipNo
               IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.PickDetail PD (NOLOCK) 
               WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.QTY > 0
               AND PD.DropID = @cFromDropID)
               BEGIN
                  SET @nErrNo = 100372
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInDropID
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
                  SET @cErrMsg = ''
                  GOTO Quit
               END
            END
         END
      
         ELSE IF @cType = 'QTY'
         BEGIN
            /*
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail PD (NOLOCK) 
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status IN (@cPickStatus)
            AND (@cFromDropID = '' OR PD.DropID = @cFromDropID)
            */
            SET @cSQL = 
            ' SELECT @nPickQTY = ISNULL( SUM( QTY), 0) ' + 
            ' FROM dbo.PickDetail PD (NOLOCK) ' + 
            ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.StorerKey = @cStorerKey ' + 
            ' AND PD.SKU = @cSKU ' + 
            ' AND PD.Status IN (' + @cPickStatus + ') ' + 
            -- CASE WHEN @cFromDropID <> '' THEN ' AND PD.DropID = @cFromDropID ' ELSE '' END + 
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
            SET @cSQLParam = 
            ' @cPickSlipNo NVARCHAR( 10), ' + 
            ' @cStorerKey  NVARCHAR( 15), ' + 
            ' @cSKU        NVARCHAR( 20), ' + 
            ' @cFromDropID NVARCHAR( 20), ' + 
            ' @nPickQTY    INT OUTPUT '
            EXEC sp_executeSQL @cSQL, @cSQLParam
            ,@cPickSlipNo = @cPickSlipNo
            ,@cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU
            ,@cFromDropID = @cFromDropID
            ,@nPickQTY    = @nPickQTY OUTPUT

		    IF @nQTY > 
		    ((select isnull(sum(qty),0) FROM dbo.PickDetail PD (NOLOCK)
		    WHERE PD.PickSlipNo = @cPickSlipNo
		    AND PD.StorerKey = @cStorerKey
		    AND PD.SKU = @cSKU
		    AND PD.Status = 5
		    AND PD.DropID = @cFromDropID) -
         -- when the pickdetail/inventory moved, regardless the qty packed.
         CASE WHEN @cMoveQTYPack = N'1'
         THEN
            (select isnull(sum(qty),0) FROM dbo.PackDetail PD (NOLOCK)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.DropID = @cFromDropID
            AND PD.RefNo2 = @cFromDropID)
         ELSE
            (select isnull(sum(qty),0) FROM dbo.PackDetail PD (NOLOCK)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.RefNo2 = @cFromDropID)
         END -
		    (select isnull(sum(qty),0) from dbo.PackDetail PD (NOLOCk)
		    WHERE PD.PickSlipNo = @cPickSlipNo
		    AND PD.StorerKey = @cStorerKey
		    AND PD.SKU = @cSKU
		    AND PD.RefNo2 = ''
		    AND PD.DropID = @cPackDtlDropID))

		    BEGIN
               SET @nErrNo = 218027
               SET @cErrMsg = 'Over DROPID qty'
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END
         
            IF @nPackQTY > @nPickQTY
            BEGIN
               SET @nErrNo = 100367
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END
         END
      END
   END

   Quit:
END


GO