SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_839ExtScn01                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-02-26 1.0  Dennis   Draft                                       */
/*                                                                      */
/************************************************************************/

CREATE    PROC [RDT].[rdt_839ExtScn01] (
	@nMobile         INT          
   ,@nFunc           INT          
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT          
   ,@nInputKey       INT          
   ,@cFacility       NVARCHAR( 5) 
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cPickZone       NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@cSuggLOC        NVARCHAR( 10)
   ,@cSuggID         NVARCHAR( 18)
   ,@cSuggSKU        NVARCHAR( 20)
   ,@nSuggQTY        INT          
   ,@cOption         NVARCHAR( 1) 
   ,@cLottableCode   NVARCHAR( 30)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME     
   ,@dLottable05     DATETIME     
   ,@cLottable06     NVARCHAR( 30)
   ,@cLottable07     NVARCHAR( 30)
   ,@cLottable08     NVARCHAR( 30)
   ,@cLottable09     NVARCHAR( 30)
   ,@cLottable10     NVARCHAR( 30)
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME     
   ,@dLottable14     DATETIME     
   ,@dLottable15     DATETIME 
   ,@cBarcode        NVARCHAR( 60) 
   ,@nAction         INT --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
	,@nAfterScn       INT OUTPUT
   ,@nAfterStep      INT OUTPUT 
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR(250) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @nShelfLife FLOAT
   DECLARE @cResultCode NVARCHAR( 60)
   DECLARE
   @nRowCount            INT,
   @cexternReceiptKey    NVARCHAR( 30), 
   @cexternLineNo        NVARCHAR( 30),    
   @nLotNum              INT,
   @cListName            NVARCHAR( 30),
   @cLotValue            NVARCHAR( 30),     
   @cStorerConfig        NVARCHAR( 50),  
   @SQL                  NVARCHAR( MAX),
   @cUserDefine08        NVARCHAR( 30),  
   @nSQLResult           INT,
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeInUse     NVARCHAR( 5),
   @cPalletTypeSave      NVARCHAR( 10),
   @cLott10              NVARCHAR( 30)

   DECLARE 
   @cOrderKey      NVARCHAR( 10) = ''
   ,@cLoadKey       NVARCHAR( 10) = ''
   ,@cZone          NVARCHAR( 10) = ''
   ,@cPSType        NVARCHAR( 10) = ''
   ,@cDocType       NVARCHAR( 1) = ''
   ,@cOrderGroup    NVARCHAR( 20) = ''
   ,@nIsNoEmptyDropID INT = 0

/*   SELECT
   @cLott10 = C_String1,
   @cPalletTypeSave = C_String2
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
*/

   IF @nAction = 1 --Validation
   BEGIN
	   IF @nFunc = 839 
	   BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @nStep = 2 
            BEGIN
               SELECT @cZone = Zone,
                     @cLoadKey = LoadKey,
                     @cOrderKey = OrderKey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo

               -- Get PickSlip type
               IF @@ROWCOUNT = 0
                  SET @cPSType = 'CUSTOM'
               ELSE
               BEGIN
                  IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                     SET @cPSType = 'XD'
                  ELSE IF @cOrderKey = ''
                     SET @cPSType = 'CONSO'
                  ELSE
                     SET @cPSType = 'DISCRETE'
               END

               IF @cPSType = 'CUSTOM'
               BEGIN
                  IF EXISTS(SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                              WHERE PickSlipNo = @cPickSlipNo
                              AND DropID = @cDropID)
                  BEGIN
                     SET @nIsNoEmptyDropID = 1
                  END
               END

               IF @cPSType = 'XD'
               BEGIN
                  IF EXISTS(SELECT 1 FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                              JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                              WHERE RKL.PickSlipNo = @cPickSlipNo
                              AND PD.DropID = @cDropID)
                  BEGIN
                     SET @nIsNoEmptyDropID = 1
                  END
               END

               IF @cPSType = 'DISCRETE'
               BEGIN
                  IF EXISTS(SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                           WHERE OrderKey = @cOrderKey
                              AND DropID = @cDropID)
                  BEGIN
                     SET @nIsNoEmptyDropID = 1
                  END
               END
               IF @cPSType = 'CONSO'
               BEGIN
                  IF EXISTS(SELECT 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                                    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                           WHERE LPD.LoadKey = @cLoadKey
                              AND PD.DropID = @cDropID)
                  BEGIN
                     SET @nIsNoEmptyDropID = 1
                  END
               END
               IF @nIsNoEmptyDropID = 1
               BEGIN
                  SET @nErrNo = 153861
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ClosedDropID'
                  GOTO Quit
               END
            END
         END
		END
      GOTO Quit
	END

Exception:

Quit:
/*
UPDATE RDT.RDTMOBREC SET
   C_String1 = @cLott10,
   C_String2 = @cPalletTypeSave
   WHERE Mobile = @nMobile
*/

END; 

SET QUOTED_IDENTIFIER OFF 

GO