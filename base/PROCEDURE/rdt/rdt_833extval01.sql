SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_833ExtVal01                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check if Case ID or Serial No duplicate                           */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 02-aPR-2019  James     1.0   WMS8119 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_833ExtVal01]
   @nMobile      INT,
   @nFunc        INT,
   @nStep        INT,
   @nInputKey    INT,
   @cLangCode    NVARCHAR( 3),
   @cStorerkey   NVARCHAR( 15),
   @cWaveKey     NVARCHAR( 10),
   @cDropID      NVARCHAR( 20),
   @cSKU         NVARCHAR( 20),
   @cCaseID      NVARCHAR( 20),
   @cSerialNo    NVARCHAR( MAX),
   @cErrType     NVARCHAR( 20) OUTPUT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cZone          NVARCHAR( 10),
           @cPH_OrderKey   NVARCHAR( 10),
           @cTempSerialNo  NVARCHAR( 60),
           @nCaseCount           INT,
           @nPD_Qty              INT,
           @nLen                 INT,
           @nStart               INT,
           @nSerialNo_Cnt        INT,
           @nSerialNo_Len        INT,
           @fCaseCount           FLOAT,
           @cPickConfirmStatus   NVARCHAR( 1),
           @cDataCapture         NVARCHAR( 1),
           @cSerialNoCapture     NVARCHAR( 1),
           @nSrDelimiter         INT,
           @nSrLength            INT

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   IF @nStep = 1 --  PickSlipNo
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF NOT EXISTS ( SELECT 1
            FROM dbo.PickDetail PD (NOLOCK)     
            JOIN dbo.WaveDetail WD (NOLOCK) ON (PD.OrderKey = WD.OrderKey)    
            WHERE WD.WaveKey = @cWaveKey
            AND   PD.Status < @cPickConfirmStatus
            AND   PD.Status <> '4'
            AND   PD.QTY > 0
            AND   PD.UOM = '2'
            AND   PD.StorerKey  = @cStorerKey)
         BEGIN
            SET @nErrNo = 137201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Fully Picked'
            GOTO Quit
         END  
      END
   END

   IF @nStep = 2 --  SKU/Case ID/Serial No
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF NOT EXISTS ( SELECT 1
            FROM dbo.PickDetail PD (NOLOCK)     
            JOIN dbo.WaveDetail WD (NOLOCK) ON (PD.OrderKey = WD.OrderKey)    
            WHERE WD.WaveKey = @cWaveKey
            AND   PD.Status <= @cPickConfirmStatus
            AND   PD.Status <> '4'
            AND   PD.QTY > 0
            AND   PD.UOM = '2'
            AND   PD.StorerKey  = @cStorerKey
            AND   PD.Sku = @cSKU)
         BEGIN
            SET @cErrType = 'SKU'
            SET @nErrNo = 137202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU NotExists'
            GOTO Quit
         END

         IF EXISTS ( SELECT 1
            FROM dbo.PickDetail PD (NOLOCK)     
            JOIN dbo.WaveDetail WD (NOLOCK) ON (PD.OrderKey = WD.OrderKey)    
            WHERE WD.WaveKey = @cWaveKey
            AND   PD.Status <> '4'
            AND   PD.QTY > 0
            AND   PD.UOM = '2'
            AND   PD.StorerKey  = @cStorerKey
            AND   PD.CaseID = @cCaseID)
         BEGIN
            SET @cErrType = 'CASEID'
            SET @nErrNo = 137203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Duplicate CaseID'
            GOTO Quit
         END

         -- Get SKU info  
         SELECT @cDataCapture = DataCapture, 
                @cSerialNoCapture = SerialNoCapture
         FROM SKU WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey   
         AND   SKU = @cSKU  

         --Get sku case cnt
         SET @fCaseCount = 0
         SELECT @fCaseCount = PACK.CaseCnt
         FROM dbo.PACK PACK WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE SKU.Storerkey = @cStorerKey
         AND   SKU.SKU = @cSKU

         SET @nCaseCount = rdt.rdtFormatFloat( @fCaseCount)

         IF ISNULL( @nCaseCount, 0) <= 0
         BEGIN
            SET @cErrType = 'SKU'
            SET @nErrNo = 137208
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Casecnt = 0'
            GOTO Quit
         END

         IF @cSerialNoCapture IN ('1', '3') -- 1=Inbound and outbound, 3=outbound only 
         BEGIN
            SET @nStart = 1
            SELECT @nLen = CHARINDEX( ',', @cSerialNo, @nStart)
            SET @cTempSerialNo = SUBSTRING( @cSerialNo, @nStart, @nLen - 1)

            IF EXISTS ( SELECT 1 FROM dbo.PackSerialNo WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND SerialNo = @cTempSerialNo)
            BEGIN
               SET @cErrType = 'SERIALNO'
               SET @nErrNo = 137204
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Duplicate Serial'
               GOTO Quit
            END

            SET @nSerialNo_Cnt = 0

            --Get # of serial no within the string
            SET @nSerialNo_Cnt = SUM( LEN( RTRIM( @cSerialNo)) - LEN( REPLACE( RTRIM( @cSerialNo), ',', '')) + 1) 

            IF @nSerialNo_Cnt <> @nCaseCount
            BEGIN
               SET @cErrType = 'SERIALNO'
               SET @nErrNo = 137205
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SrCntNotMatch'
               GOTO Quit
            END

            SET @nSrDelimiter = CHARINDEX(',', @cSerialNo)
            SET @nSrLength = LEN( SUBSTRING( @cSerialNo, 1, @nSrDelimiter - 1))

            -- Check len of serial no (only check total length)
            -- 12345678, 12345679, 123456790....1 serial no = 8 digits
            -- (8 x 48) + 47 ','(comma)
            IF LEN( RTRIM( @cSerialNo)) <> ( ( @nSrLength * @fCaseCount) + (@fCaseCount - 1))
            BEGIN
               SET @cErrType = 'SERIALNO'
               SET @nErrNo = 137206
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SrLenNotMatch'
               GOTO Quit
            END

            SELECT @nPD_Qty = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD (NOLOCK)     
            JOIN dbo.WaveDetail WD (NOLOCK) ON (PD.OrderKey = WD.OrderKey)    
            WHERE WD.WaveKey = @cWaveKey
            AND   PD.Status < @cPickConfirmStatus
            AND   PD.Status <> '4'
            AND   PD.QTY > 0
            AND   PD.UOM = '2'
            AND   PD.StorerKey  = @cStorerKey

            IF @nSerialNo_Cnt > @nPD_Qty
            BEGIN
               SET @cErrType = 'SERIALNO'
               SET @nErrNo = 137207
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Scanned'
               GOTO Quit
            END
         END

         IF @cDataCapture IN ('1', '3') -- 1=Inbound and outbound, 3=outbound only 
         BEGIN
            -- Check if user key in > 1 LOT#
            IF LEN( @cSerialNo) - LEN( REPLACE( @cSerialNo, ',', '')) > 0
            BEGIN
               SET @cErrType = 'SERIALNO'
               SET @nErrNo = 137210
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Data'
               GOTO Quit
            END

            SELECT @nPD_Qty = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD (NOLOCK)     
            JOIN dbo.WaveDetail WD (NOLOCK) ON (PD.OrderKey = WD.OrderKey)    
            WHERE WD.WaveKey = @cWaveKey
            AND   PD.Status < @cPickConfirmStatus
            AND   PD.Status <> '4'
            AND   PD.QTY > 0
            AND   PD.SKU = @cSKU
            AND   PD.UOM = '2'
            AND   PD.StorerKey  = @cStorerKey

            IF @nCaseCount > @nPD_Qty
            BEGIN
               SET @cErrType = 'SERIALNO'
               SET @nErrNo = 137209
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Scanned'
               GOTO Quit
            END
         END

         IF NOT EXISTS (
            SELECT 1
            FROM ( 
               SELECT PickDetailKey, Qty
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE WaveKey = @cWaveKey
               AND   StorerKey = @cStorerKey
               AND   UOM = '2'
               AND   Status < @cPickConfirmStatus
               AND   Status <> '4'
               AND   SKU = @cSKU
               GROUP BY PickDetailKey, Qty
               HAVING ( Qty % @nCaseCount = 0)) A) -- filter pickdetail line that only contain full case qty
         BEGIN
            SET @cErrType = 'SKU'
            SET @nErrNo = 137211
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Scanned'
            GOTO Quit
         END
      END
   END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO