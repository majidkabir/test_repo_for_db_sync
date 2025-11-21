SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_830DecodeSP03                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SKU by loc                                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 15-03-2023  YeeKung   1.0   WMS-21872 Created                              */
/* 2024-10-22  PXL009    1.1   FCR-759 ID and UCC Length Issue                */
/******************************************************************************/

CREATE   PROC rdt.rdt_830DecodeSP03 ( 
  @nMobile      INT,               
  @nFunc        INT,               
  @cLangCode    NVARCHAR( 3),      
  @nStep        INT,               
  @nInputKey    INT,               
  @cStorerKey   NVARCHAR( 15),        
  @cFacility    NVARCHAR( 20),   
  @cLOC         NVARCHAR( 10),   
  @cDropid      NVARCHAR( 20),
  @cpickslipno  NVARCHAR( 20), 
  @cBarcode     NVARCHAR( 60),
  @cFieldName   NVARCHAR( 10),     
  @cUPC         NVARCHAR( 20)  OUTPUT,
  @cSKU         NVARCHAR( 20)  OUTPUT,
  @nQTY         INT            OUTPUT,
  @cLottable01  NVARCHAR( 18)  OUTPUT,
  @cLottable02  NVARCHAR( 18)  OUTPUT,
  @cLottable03  NVARCHAR( 18)  OUTPUT,
  @dLottable04  DATETIME       OUTPUT,
  @dLottable05  DATETIME       OUTPUT,
  @cLottable06  NVARCHAR( 30)  OUTPUT,
  @cLottable07  NVARCHAR( 30)  OUTPUT,
  @cLottable08  NVARCHAR( 30)  OUTPUT,
  @cLottable09  NVARCHAR( 30)  OUTPUT,
  @cLottable10  NVARCHAR( 30)  OUTPUT,
  @cLottable11  NVARCHAR( 30)  OUTPUT,
  @cLottable12  NVARCHAR( 30)  OUTPUT,
  @dLottable13  DATETIME       OUTPUT,
  @dLottable14  DATETIME       OUTPUT,
  @dLottable15  DATETIME       OUTPUT,
  @cUserDefine01 NVARCHAR(30)  OUTPUT,
  @nErrNo       INT            OUTPUT,
  @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 830
   BEGIN
      IF @nStep = 3 
      BEGIN
         IF @nInputKey = 1
         BEGIN

            DECLARE  @cStartPos NVARCHAR(20),
                     @cEndPos   NVARCHAR(20),
                     @nStartPos INT,
                     @nEndPos   INT,
                     @cLot      NVARCHAR(20),
                     @bSuccess  INT

            DECLARE @cOrderKey   NVARCHAR( 10)
            DECLARE @cLoadKey    NVARCHAR( 10)
            DECLARE @cZone       NVARCHAR( 18)
            DECLARE @cPickConfirmStatus NVARCHAR( 1)

            IF @cFieldName='SKU'
            BEGIN
               SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
               IF @cPickConfirmStatus = '0'
                  SET @cPickConfirmStatus = '5'

               SELECT @cStartPos= udf01,
                        @cEndPos = udf02
               FROM codelkup (Nolock)
               WHERE listname = 'RDTDecode'
                  AND Storerkey = @cStorerKey
                  AND long = LEN(@cBarcode)

               IF @@ROWCOUNT=0
               BEGIN
                     EXEC [RDT].[rdt_GETSKU]     
                     @cStorerKey   = @cStorerKey      ,
                     @cSKU         = @cBarcode  OUTPUT,
                     @bSuccess     = @bSuccess  OUTPUT,
                     @nErr         = @nErrNo    OUTPUT,
                     @cErrMsg      = @cErrMsg   OUTPUT,
                     @cSKUStatus   = ''

                  IF @bSuccess=0
                  BEGIN
                     SET @nErrNo = 197805
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CodeNoStp
                     GOTO QUIT
                  END
                  ELSE
                  BEGIN
                     SET @cUPC = @cBarcode
                     GOTO QUIT
                  END
               END

               SET @nStartPos = CAST (@cStartPos AS INT)
               SET @nEndPos = CAST (@cEndPos AS INT)
               
               SET @cLot =SUBSTRING( @cBarcode, @nStartPos, @nEndPos - @nStartPos + 1) 

               SELECT   @cUPC = SKU,
                        @cLot = LOT
               FROM Lotattribute (nolock)
               WHERE lottable07 = @cLot
                  AND storerkey = @cStorerkey

               SET @nQTY = 1

               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cLoadKey = ExternOrderKey,
                  @cZone = Zone
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo

               IF @cZone IN ('XD', 'LB', 'LP') 
               BEGIN
                  IF NOT EXISTS(SELECT 1 
                           FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
                              JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
                              JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                           WHERE RKL.PickSlipNo = @cPickSlipNo  
                              AND PD.QTY > 0  
                              AND PD.Status <> '4'  
                              AND PD.Status < @cPickConfirmStatus
                              AND PD.SKU = @cUPC
                              AND PD.lot = @cLot)
                  BEGIN
                     SET @nErrNo = 197801
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ScanSKU
                     GOTO QUIT
                  END
               END
               IF ISNULL(@cLoadKey,'') <>''
               BEGIN
                  IF NOT EXISTS(SELECT 1 
                              FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
                                 JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)      
                                 JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                              WHERE LPD.LoadKey = @cLoadKey    
                                 AND LOC.LOC = @cLOC  
                                 AND PD.QTY > 0  
                                 AND PD.Status <> '4'  
                                 AND PD.Status < @cPickConfirmStatus
                                 AND PD.SKU = @cUPC
                                 AND PD.lot = @cLot)
                  BEGIN
                     SET @nErrNo = 197803
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ScanSKU
                     GOTO QUIT
                  END
               END
               IF ISNULL(@cOrderkey,'') <>''
               BEGIN
                  IF NOT EXISTS(SELECT 1 
                                 FROM dbo.PickDetail PD WITH (NOLOCK)  
                                 JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                              WHERE PD.OrderKey = @cOrderKey  
                                 AND LOC.LOC = @cLOC  
                                 AND PD.QTY > 0  
                                 AND PD.Status <> '4'  
                                 AND PD.Status < @cPickConfirmStatus
                                 AND PD.SKU = @cUPC
                                 AND PD.lot = @cLot)
                  BEGIN
                     SET @nErrNo = 197802
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ScanSKU
                     GOTO QUIT
                  END
               END

               ELSE
               BEGIN
                  IF NOT EXISTS(SELECT 1 
                                 FROM dbo.PickDetail PD WITH (NOLOCK)  
                                    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                                 WHERE PD.PickSlipNo = @cPickSlipNo  
                                    AND LOC.LOC = @cLOC  
                                    AND PD.QTY > 0  
                                    AND PD.Status <> '4'  
                                    AND PD.Status < @cPickConfirmStatus
                                    AND PD.SKU = @cUPC
                                    AND PD.lot = @cLot)
                  BEGIN
                     SET @nErrNo = 197804
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ScanSKU
                     GOTO QUIT
                  END
               END
            END

         END
      END
   END

Quit:

END

GO