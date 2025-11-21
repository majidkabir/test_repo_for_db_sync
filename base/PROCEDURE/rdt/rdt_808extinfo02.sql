SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_808ExtInfo02                                          */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-02-19 1.0  Ung        WMS-8024 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_808ExtInfo02] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @cLight         NVARCHAR( 1),  
   @cDPLKey        NVARCHAR( 10),
   @cCartID        NVARCHAR( 10),
   @cPickZone      NVARCHAR( 10),
   @cMethod        NVARCHAR( 10),
   @cLOC           NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cToteID        NVARCHAR( 20),
   @nQTY           INT,          
   @cNewToteID     NVARCHAR( 20),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,     
   @dLottable05    DATETIME,     
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,     
   @dLottable14    DATETIME,     
   @dLottable15    DATETIME,     
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

   DECLARE @cMethodSP SYSNAME

   IF @nFunc = 808 -- PTLCart
   BEGIN
      IF @nStep = 4 AND    -- Matrix
         @nAfterStep = 1   -- Cart ID
      BEGIN
         -- Get method info
         SET @cMethodSP = ''
         SELECT @cMethodSP = ISNULL( UDF01, '')
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'CartMethod' 
            AND Code = @cMethod 
            AND StorerKey = @cStorerKey
         
         -- rdt_PTLCart_Assign_BatchTotes
         IF @cMethodSP = 'rdt_PTLCart_Assign_BatchTotes01'
         BEGIN
            DECLARE @cBatchKey NVARCHAR(20)
            DECLARE @cMsg1 NVARCHAR(20)
            DECLARE @cMsg2 NVARCHAR(20)
            DECLARE @cMsg3 NVARCHAR(20)
            DECLARE @cMsg4 NVARCHAR(20)
            
            SET @cMsg1 = ''
            SET @cMsg2 = ''
            SET @cMsg3 = ''
            SET @cMsg4 = ''

            -- Get batch
            SELECT TOP 1 @cBatchKey = BatchKey FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
            
            -- Check short pick
            IF EXISTS( SELECT 1 
               FROM PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND PickSlipNo = @cBatchKey
                  AND QTY > 0
                  AND Status = '4')
            BEGIN
               SET @cMsg1 = rdt.rdtgetmessage( 134601, @cLangCode, 'DSP') --SHORT PICK
               SET @cMsg2 = rdt.rdtgetmessage( 134602, @cLangCode, 'DSP') --CONTACT ADMIN
            END
            
            -- Check outstanding replen
            IF EXISTS( SELECT 1 
               FROM PickDetail PD WITH (NOLOCK) 
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE PD.StorerKey = @cStorerKey 
                  AND PD.PickSlipNo = @cBatchKey
                  AND PD.Status < '5'
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND LOC.LocationCategory <> 'MEZZANINE')
            BEGIN
               SET @cMsg3 = rdt.rdtgetmessage( 134603, @cLangCode, 'DSP') --REPLEN NOT FINISH
               SET @cMsg4 = rdt.rdtgetmessage( 134604, @cLangCode, 'DSP') --PICK LATER
            END

            -- Show message
            IF @cMsg1 <> '' OR 
               @cMsg3 <> '' 
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '', @cMsg1, @cMsg2, '', @cMsg3, @cMsg4
               SET @nErrNo = 0
            END
         END      
      END
      
      IF @nAfterStep = 3 -- SKU
      BEGIN
         -- Get method info
         SET @cMethodSP = ''
         SELECT @cMethodSP = ISNULL( UDF01, '')
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'CartMethod' 
            AND Code = @cMethod 
            AND StorerKey = @cStorerKey
         
         -- Assign PickslipPosTote_Lottable
         IF @cMethodSP = 'rdt_PTLCart_Assign_BatchTotes01'
         BEGIN
            DECLARE @cBUSR1 NVARCHAR( 30)

            -- Get SKU info
            SELECT @cBUSR1 = BUSR1
            FROM SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU

            SET @cExtendedInfo = LEFT( ISNULL( @cBUSR1, ''), 20)
         END
      END
   END
   
Quit:

END


GO