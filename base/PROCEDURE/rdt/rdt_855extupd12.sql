SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_855ExtUpd12                                           */
/* Copyright      : Maersk                                                    */
/*                                                                            */                  
/* Purpose: Insert msg queue for the sku                                      */  
/*                                                                            */  
/* Modifications log:                                                         */ 
/* Date       Rev  Author   Purposes                                          */
/* 2024-03-27  1.0  yeekung  UWP-16955. Created                               */  
/******************************************************************************/

CREATE   PROC rdt.rdt_855ExtUpd12 (
   @nMobile      INT,   
   @nFunc        INT,   
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,   
   @nInputKey    INT,   
   @cStorerKey   NVARCHAR( 15),    
   @cRefNo       NVARCHAR( 10),   
   @cPickslipNo  NVARCHAR( 10),   
   @cLoadKey     NVARCHAR( 10),   
   @cOrderKey    NVARCHAR( 10),   
   @cDropID      NVARCHAR( 20),   
   @cSKU         NVARCHAR( 20),    
   @nQty         INT,    
   @cOption      NVARCHAR( 1),    
   @nErrNo       INT           OUTPUT,    
   @cErrMsg      NVARCHAR( 20) OUTPUT,   
   @cID          NVARCHAR( 18) = '',  
   @cTaskDetailKey   NVARCHAR( 10) = '',  
   @cReasonCode  NVARCHAR(20) OUTPUT   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 855 -- PTLPiece
   BEGIN
      IF @nStep = 3 -- Matrix
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            DECLARE @i         INT = 1
            DECLARE @cMsg      NVARCHAR(20)
            DECLARE @cMsg2     NVARCHAR(20)
            DECLARE @cMsg01    NVARCHAR(20)
            DECLARE @cMsg02    NVARCHAR(20)
            DECLARE @cMsg03    NVARCHAR(20)
            DECLARE @cMsg04    NVARCHAR(20)
            DECLARE @cMsg05    NVARCHAR(20)
            DECLARE @cMsg06    NVARCHAR(20)
            DECLARE @cMsg07    NVARCHAR(20)
            DECLARE @cMsg08    NVARCHAR(20)
            DECLARE @cMsg09    NVARCHAR(20)
            DECLARE @cMsg10    NVARCHAR(20)
            DECLARE @nPDQTY    INT
            DECLARE @nVariance INT
            DECLARE @cFacility NVARCHAR(20)
            DECLARE @nCSKU     INT
            DECLARE @nCQTY     INT
            DECLARE @nPSKU     INT
            DECLARE @nPQTY     INT
            DECLARE @nPPAQTY   INT

            EXEC [RDT].[rdt_PostPickAudit_GetStat]
               @nMobile = @nMobile,
               @nFunc = @nFunc,
               @cRefNo = '',
               @cPickSlipNo = '',
               @cLoadKey = '',
               @cOrderKey = '',
               @cDropID = @cDropID,
               @cID = '',
               @cTaskDetailKey = '',
               @cStorer = @cStorerKey,
               @cFacility = @cFacility,
               @cUOM = '',
               @nCSKU = @nCSKU OUTPUT,
               @nCQTY = @nCQTY OUTPUT,
               @nPSKU = @nPSKU OUTPUT,
               @nPQTY = @nPQTY OUTPUT,
               @nVariance = @nVariance OUTPUT
   
            IF @nVariance = 1
            BEGIN
            
               SET @i = 1
               SET @cMsg = ''
               SET @cMsg01 = ''
               SET @cMsg02 = ''
               SET @cMsg03 = ''
               SET @cMsg04 = ''
               SET @cMsg05 = ''
               SET @cMsg06 = ''
               SET @cMsg07 = ''
               SET @cMsg08 = ''
               SET @cMsg09 = ''
               SET @cMsg10 = ''
                         
               DECLARE @cCurSKU CURSOR

               IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorerKey) = '1'
               BEGIN
                  SET @cCurSKU = CURSOR FOR
                  SELECT  PD.SKU, ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                     INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
                  WHERE PD.StorerKey = @cStorerkey
                     AND PD.DropID = @cDropID
                  GROUP BY PD.StorerKey, PD.SKU
               END
               ELSE IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorerKey) = '1'
               BEGIN
                  SET @cCurSKU = CURSOR FOR
                  SELECT  PD.SKU, ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                     INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
                  WHERE PD.StorerKey = @cStorerkey
                     AND PD.LabelNo = @cDropID
                  GROUP BY PD.StorerKey, PD.SKU

               END
               ELSE IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey) = '1'
               BEGIN
                  SET @cCurSKU = CURSOR FOR
                  SELECT  PD.SKU, ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.StorerKey = @cStorerKey
                     AND PD.CaseID = @cDropID
                     AND PD.ShipFlag <> 'Y'
                  GROUP BY PD.StorerKey, PD.SKU
               END
               ELSE
               BEGIN
                  SET @cCurSKU = CURSOR FOR
                  SELECT  PD.SKU, ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.StorerKey = @cStorerkey
                     AND PD.DropID = @cDropID
                     AND PD.ShipFlag <> 'Y'
                  GROUP BY PD.StorerKey, PD.SKU
               END

               
               OPEN @cCurSKU
               FETCH NEXT FROM @cCurSKU INTO @cSKU, @nPDQTY
               WHILE @@FETCH_STATUS = 0
               BEGIN

                  SELECT @nPPAQTY = ISNULL( SUM( CQTY), 0)
                  FROM rdt.rdtPPA WITH (NOLOCK)
                  WHERE StorerKey = @cStorerkey
                     AND DropID = @cDropID
                  GROUP BY StorerKey, SKU

                  SET @nPPAQTY = CASE WHEN ISNULL(@nPPAQTY,'') = '' THEN 0 ELSE @nPPAQTY END

                  SET @cMsg = @cSKU
                  SET @cMsg2 = @nPPAQTY + '/' + @nPDQTY
                  
                  IF @i = 1
                  BEGIN
                     SET @cMsg01 = @cMsg
                     SET @cMsg02 = @cMsg
                  END
                  ELSE IF @i = 2
                  BEGIN
                     SET @cMsg03 = @cMsg
                     SET @cMsg04 = @cMsg
                  END
                  ELSE IF @i = 3
                  BEGIN
                     SET @cMsg05 = @cMsg
                     SET @cMsg06 = @cMsg
                  END
                  ELSE IF @i = 4
                  BEGIN
                     SET @cMsg07 = @cMsg
                     SET @cMsg08 = @cMsg
                  END
                  ELSE IF @i = 5
                  BEGIN
                     SET @cMsg09 = @cMsg
                     SET @cMsg10 = @cMsg
                  END

                  SET @i = @i + 1
                  IF @i > 5
                  BEGIN
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg, 
                        @cMsg01, 
                        @cMsg02, 
                        @cMsg03, 
                        @cMsg04, 
                        @cMsg05, 
                        @cMsg06, 
                        @cMsg07, 
                        @cMsg08, 
                        @cMsg09, 
                        @cMsg10

                     SET @cMsg01 = ''
                     SET @cMsg02 = ''
                     SET @cMsg03 = ''
                     SET @cMsg04 = ''
                     SET @cMsg05 = ''
                     SET @cMsg06 = ''
                     SET @cMsg07 = ''
                     SET @cMsg08 = ''
                     SET @cMsg09 = ''
                     SET @cMsg10 = ''

                     SET @nErrNo = 0

                     SET @i = 1
                  END

                  
                  FETCH NEXT FROM @cCurSKU INTO @cSKU, @nPDQTY
               END
                           
               -- Prompt outstanding
               IF @cMsg01 <> ''
               BEGIN
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg, 
                     @cMsg01, 
                     @cMsg02, 
                     @cMsg03, 
                     @cMsg04, 
                     @cMsg05, 
                     @cMsg06, 
                     @cMsg07, 
                     @cMsg08, 
                     @cMsg09, 
                     @cMsg10

                  SET @nErrNo = 0

               END
            END
         END
      END
   END

Quit:

END

GO