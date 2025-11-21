SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_855ExtValid07                                   */
/* Copyright      : Maersk                                              */
/* Customer: Granite                                                    */
/*                                                                      */
/* Purpose: Check if VAS is needed or not                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2024-06-13  1.0  NLT013   FCR-386. Created                           */
/* 2025-02-08  1.1  Deenis   FCR-1109 Step 99 Validation                */
/************************************************************************/
  
CREATE   PROC [RDT].[rdt_855ExtValid07] (  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cRefNo         NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cDropID        NVARCHAR( 20),
   @cLoadKey       NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cID            NVARCHAR( 18) = '',
   @cTaskDetailKey NVARCHAR( 10) = '',
   @tExtValidate   VariableTable READONLY

) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE 
         @cInputKey        NVARCHAR(1),
         @cOption          NVARCHAR(1),
         @nRowCount        INT,
         @cNAMVAS855       NVARCHAR(1),
         @cPPAStatus       NVARCHAR(1),
         @nScn             INT

   
   SELECT @cInputKey = Value FROM @tExtValidate WHERE Variable = '@nInputKey'
   SELECT @cOption = Value FROM @tExtValidate WHERE Variable = '@cOption'
   SELECT
   @nScn       = Scn
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Variable mapping

   IF @nFunc = 855   -- Function ID
   BEGIN
      IF @nStep = 1 OR ( @nStep = 99 AND @nScn = 814) -- Drop ID
      BEGIN
         IF @cInputKey = '1'  -- Enter
         BEGIN
            DECLARE 
               @nPackedQty        INT,
               @nPickedQty       INT

            SELECT @nRowCount = COUNT(1)
            FROM dbo.PickDetail  WITH(NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ISNULL(CaseID, '') = @cDropID
               AND Status < '5'

            IF @nRowCount > 0
            BEGIN
               SET @nErrNo = 216806
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Pick is not finished
               GOTO Quit
            END

            SELECT @nPackedQty = SUM(Qty)
            FROM dbo.PackDetail  WITH(NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ISNULL(LabelNo, '') = @cDropID

            SELECT @nPickedQty = SUM(Qty)
            FROM dbo.PickDetail  WITH(NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ISNULL(CaseID, '') = @cDropID

            IF @nPackedQty <> @nPickedQty
            BEGIN
               SET @nErrNo = 216801
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- QTY:PICK<>PACK
               GOTO Quit
            END
         END
      END
      ELSE IF @nStep = 3  -- SKU
      BEGIN
         IF @cInputKey = '1'  -- Enter
         BEGIN
            DECLARE @cSKU NVARCHAR(20)
            DECLARE @cPreviousSKU NVARCHAR(20)
            DECLARE @nTotalPQty INT
            DECLARE @nTotalCQty INT

            SELECT @cSKU = Value FROM @tExtValidate WHERE Variable = '@cSKU'

            --If any short comfirmed, cannot continue aduit
            SELECT @nRowCount = COUNT(1) 
            FROM rdt.RDTPPA WITH(NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND DropID = @cDropID
               AND Status = '2'
            
            IF @nRowCount > 0
            BEGIN
               SET @nErrNo = 216804
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- NeedQC
               GOTO Quit
            END

            SELECT @cPreviousSKU = O_Field02
            FROM RDT.RDTMOBREC WITH(NOLOCK)
            WHERE Mobile = @nMobile
               AND ISNULL(V_String2, '') = @cDropID

            IF @cPreviousSKU IS NOT NULL AND TRIM(@cPreviousSKU) <> '' AND TRIM(@cPreviousSKU) <> @cSKU
            BEGIN
               SELECT @nTotalPQty = SUM(PQty), @nTotalCQty = SUM(CQty)
               FROM RDT.RDTPPA WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND DropID = @cDropID
                  AND Sku = @cPreviousSKU

               -- If previous SKU is not finished, cannot scan other SKU
               IF @nTotalPQty <> @nTotalCQty
               BEGIN
                  SET @nErrNo = 216802
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidSKU
                  GOTO Quit
               END
            END 

            SELECT @cPPAStatus = Status
            FROM RDT.RDTPPA WITH(NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND DropID = @cDropID
               AND Sku = @cSKU

            IF @cPPAStatus = '2'
            BEGIN
               SET @nErrNo = 216804
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- NeedQC
               GOTO Quit
            END
            ELSE IF @cPPAStatus = '5'
            BEGIN
               SET @nErrNo = 216805
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- AuditFinished
               GOTO Quit
            END
         END
      END
      ELSE IF @nStep = 4  -- Discrepency 
      BEGIN
         IF @cInputKey = '1'  -- Enter
         BEGIN
            IF @cOption <> '1'
            BEGIN
               SET @nErrNo = 216803
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvlidOption
               GOTO Quit
            END
         END
      END
   END

Quit:
END  


GO