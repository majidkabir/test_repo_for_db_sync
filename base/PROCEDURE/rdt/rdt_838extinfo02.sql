SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtInfo02                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 17-04-2018 1.0 Ung         WMS-3845 Created                          */
/* 12-07-2018 1.1 Ung         WMS-5490 Add sorting process              */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtInfo02] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cVAS_Activity     NVARCHAR( 20)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cLoadKey          NVARCHAR( 10)
   DECLARE @cZone             NVARCHAR( 18)
   DECLARE @nVAS              INT
   DECLARE @nCount            INT
   DECLARE @nRowCount         INT

   DECLARE @cErrMsg01         NVARCHAR( 20)
   DECLARE @cErrMsg02         NVARCHAR( 20)
   DECLARE @cErrMsg03         NVARCHAR( 20)
   DECLARE @cErrMsg04         NVARCHAR( 20)
   DECLARE @cErrMsg05         NVARCHAR( 20)
   
   DECLARE @cFromDropID       NVARCHAR( 20)
   DECLARE @cPackDtlDropID    NVARCHAR( 20)
   DECLARE @cPickStatus       NVARCHAR( 1)
   DECLARE @cVAS_OrderKey     NVARCHAR( 10)
   DECLARE @cVAS_OrderLineNo  NVARCHAR( 5)
   DECLARE @cNotes            NVARCHAR( 20)

   DECLARE @curVAS CURSOR

   DECLARE @tPickZone TABLE 
   (
      PickZone NVARCHAR( 10) PRIMARY KEY CLUSTERED  
   )

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 3 AND 
         @nAfterStep = 3 -- SKU QTY loop
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check SKU key-in
            IF EXISTS( SELECT 1 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile AND I_Field03 = '')
               GOTO Quit

            SET @cVAS_OrderKey = ''

            -- Variable mapping
            SELECT @cPickSlipNo = Value FROM @tVar WHERE Variable = '@cPickSlipNo'
            SELECT @cFromDropID = Value FROM @tVar WHERE Variable = '@cFromDropID'
            SELECT @cPackDtlDropID = Value FROM @tVar WHERE Variable = '@cPackDtlDropID'
            SELECT @cSKU = Value FROM @tVar WHERE Variable = '@cSKU'

            INSERT INTO @tPickZone (PickZone)
            SELECT Code2
            FROM dbo.CodelkUp WITH (NOLOCK)
            WHERE ListName = 'ALLSorting'
               AND StorerKey = @cStorerKey
               AND Code = @cPackDtlDropID
   
            -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cLoadKey = ExternOrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            -- Get PickStatus
            IF @cFromDropID = 'SORTED'
               SET @cPickStatus = '5'
            ELSE IF @cFromDropID = ''
               SET @cPickStatus = '0'
            ELSE
               SET @cPickStatus = '5'

            -- Cross dock PickSlip
            IF @cZone IN ('XD', 'LB', 'LP')
            BEGIN
               SELECT TOP 1 
                  @cVAS_OrderKey = PD.OrderKey, 
                  @cVAS_OrderLineNo = PD.OrderLineNumber
               FROM dbo.PickDetail PD (NOLOCK) 
                  JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
               WHERE RPL.PickslipNo = @cPickSlipNo    
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.Status >= @cPickStatus
                  AND PD.Status <> '4'
                  AND PD.DropID = @cFromDropID
            END
            
            -- Discrete PickSlip
            ELSE IF @cOrderKey <> ''
            BEGIN
               SELECT TOP 1 
                  @cVAS_OrderKey = PD.OrderKey, 
                  @cVAS_OrderLineNo = PD.OrderLineNumber
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.Status >= @cPickStatus
                  AND PD.DropID = @cFromDropID
            END
            
            -- Conso PickSlip
            ELSE IF @cLoadKey <> ''
            BEGIN
               IF @cFromDropID = ''  
                  SELECT TOP 1   
                     @cVAS_OrderKey = PD.OrderKey,   
                     @cVAS_OrderLineNo = PD.OrderLineNumber  
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
                     JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)  
                  WHERE LPD.LoadKey = @cLoadKey  
                     AND PD.StorerKey = @cStorerKey  
                     AND PD.SKU = @cSKU  
                     AND PD.Status >= @cPickStatus  
                     AND PD.DropID = '' -- @cFromDropID  
               ELSE  
               SELECT TOP 1 
                  @cVAS_OrderKey = PD.OrderKey, 
                  @cVAS_OrderLineNo = PD.OrderLineNumber
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
               WHERE LPD.LoadKey = @cLoadKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.Status >= @cPickStatus
                  AND PD.DropID = @cFromDropID
            END

            -- Custom PickSlip
            ELSE
               SELECT TOP 1 
                  @cVAS_OrderKey = PD.OrderKey, 
                  @cVAS_OrderLineNo = PD.OrderLineNumber
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.Status >= @cPickStatus
                  AND PD.DropID = @cFromDropID

            -- Get VAS instruction
            SET @cNotes = ''
            SELECT @cNotes = SUBSTRING( Note1, 1, 20)
               FROM dbo.OrderDetailRef WITH (NOLOCK)
               WHERE OrderKey = @cVAS_OrderKey
                  AND OrderLineNumber = @cVAS_OrderLineNo
                  AND StorerKey = @cStorerKey
                  AND ParentSKU = @cSKU
            SET @nRowCount = @@ROWCOUNT
            
            IF @nRowCount = 0
               GOTO Quit
               
            ELSE IF @nRowCount = 1
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cNotes
               SET @nErrNo = 0
               GOTO Quit
            END
               
            ELSE
            BEGIN
               SET @cErrMsg01 = ''
               SET @cErrMsg02 = ''
               SET @cErrMsg03 = ''
               SET @cErrMsg04 = ''
               SET @cErrMsg05 = ''
               SET @nCount = 1

               -- Loop VAS instruction
               SET @curVAS = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT Note1
                  FROM dbo.OrderDetailRef WITH (NOLOCK)
                  WHERE OrderKey = @cVAS_OrderKey
                     AND OrderLineNumber = @cVAS_OrderLineNo
                     AND StorerKey = @cStorerKey
                     AND ParentSKU = @cSKU
                  ORDER BY 1
               OPEN @curVAS
               FETCH NEXT FROM @curVAS INTO @cVAS_Activity
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF @nCount = 1 SET @cErrMsg01 = '1. ' + @cVAS_Activity ELSE
                  IF @nCount = 2 SET @cErrMsg02 = '2. ' + @cVAS_Activity ELSE
                  IF @nCount = 3 SET @cErrMsg03 = '3. ' + @cVAS_Activity ELSE
                  IF @nCount = 4 SET @cErrMsg04 = '4. ' + @cVAS_Activity ELSE
                  IF @nCount = 5 SET @cErrMsg05 = '5. ' + @cVAS_Activity

                  SET @nCount = @nCount + 1

                  FETCH NEXT FROM @curVAS INTO @cVAS_Activity
               END

               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05

               SET @nErrNo = 0
            END
         END
      END
   END

Quit:

END

GO