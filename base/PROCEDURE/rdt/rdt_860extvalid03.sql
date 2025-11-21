SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_860ExtValid03                                   */
/* Purpose: copy from rdtDSGPickExtVal                                  */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2022-03-09   yeekung   1.0   WMS18588 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_860ExtValid03]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cSuggLOC        NVARCHAR( 10)
   ,@cLOC            NVARCHAR( 10)
   ,@cID             NVARCHAR( 18)
   ,@cDropID         NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@nTaskQTY        INT
   ,@nPQTY           INT
   ,@cUCC            NVARCHAR( 20)
   ,@cOption         NVARCHAR( 1)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT  
   DECLARE @n_err       INT  
   DECLARE @c_errmsg    NVARCHAR( 250)  
  
   DECLARE @cActID            NVARCHAR( 18),  
           @cBUSR2            NVARCHAR( 30),  
           @cLottable03_Act   NVARCHAR( 18)  

   DECLARE  @cErrMsg1 NVARCHAR(20),
            @cErrMsg2 NVARCHAR(20)
   
  
   IF @nFunc = 860 -- Pick SKU/UPC  
   BEGIN  
      IF @nStep = 2 -- DropID  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Check blank  
            IF @cDropID = ''  
            BEGIN  
               SET @nErrNo = 183951  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID  
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID  
            END  
         END  
      END  

      IF @nStep = 4 -- qty  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Check blank  
            IF @nPQTY < @nTaskQTY 
            BEGIN  
   
               IF rdt.RDTGetConfig( @nFunc, 'DISABLESHORTPICK', @cStorerkey) = '1'
               BEGIN
                  SET @cErrMsg1 ='NOT ALLOW'  
                  SET @cErrMsg2 = 'SHORT PICK' 
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                     @cErrMsg1, 
                     @cErrMsg2,
                     '',
                     '',
                     '',
                     '',
                     'Please Press Esc',
                     'To Proceed'  
                  SET @nErrNo='183955'
                  GOTO quit  
               END
            END  
         END  
      END 

      IF @nStep = 8 -- DropID  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Check blank  
            IF @cOption = '1'  
            BEGIN  

               IF rdt.RDTGetConfig( @nFunc, 'DISABLESHORTPICK', @cStorerkey) = '1'
               BEGIN
                  SET @cErrMsg1 ='NOT ALLOW'  
                  SET @cErrMsg2 = 'SHORT PICK' 
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                     @cErrMsg1, 
                     @cErrMsg2,
                     '',
                     '',
                     '',
                     '',
                     'Please Press Esc',
                     'To Proceed'  
                  SET @nErrNo='183955'
                  GOTO quit  
               END
            END  
         END  
      END 
   END  
  
   IF @nFunc = 862 -- Pick pallet  
   BEGIN  
      IF @nStep = 6 -- ID  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Get Act ID scanned  
            SELECT @cActID = I_Field14 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile  
  
            -- Get SKU info  
            SELECT @cBUSR2 =   
               CASE BUSR2  
                  WHEN 'PALLET' THEN 'RM-PALLET' -- Raw material, pick by pallet  
                  WHEN 'CRTID'  THEN 'RM-CASE'   -- Raw material, pick by case  
                  ELSE 'FG'                      -- Finish good,  pick by pallet  
               END  
            FROM SKU WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey   
               AND SKU = @cSKU  
               /*  
            -- RM carton, must provide drop ID  
            IF @cBUSR2 = 'CRTID' AND @cDropID = ''  
            BEGIN  
               SET @nErrNo = 183952  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID  
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID  
            END  
  
            -- RM pallet, FG pallet, don't need drop ID  
            IF @cBUSR2 IN ('RM-PALLET', 'FG') AND @cDropID <> ''  
            BEGIN  
               SET @nErrNo = 183953  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DontNeedDropID  
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID  
            END  
            */  
            -- Check pallet or carton ID in QC status  
            IF @cActID <> ''  
            BEGIN  
               SET @cLottable03_Act = ''  
  
               IF @cBUSR2 = 'PALLET'  
               BEGIN  
                  -- Get L03 of actual pallet ID  
                  SELECT @cLottable03_Act = Lottable03  
                  FROM LOTxLOCxID LLI WITH (NOLOCK)  
                     JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)  
                  WHERE LLI.ID = @cActID  
                     AND LLI.QTY-LLI.QTYPicked > 0  
                     AND LLI.SKU = @cSKU  
                     AND LLI.LOC = @cLOC  
               END  
        
               IF @cBUSR2 = 'CRTID'  
               BEGIN  
                  -- Get L03 of actual carton  
                  SELECT @cLottable03_Act = Lottable03  
                  FROM LOTxLOCxID LLI WITH (NOLOCK)  
                     JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)  
                  WHERE LA.Lottable01 = @cActID  
                     AND LLI.QTY-LLI.QTYPicked > 0  
                     AND LLI.SKU = @cSKU  
                     AND LLI.LOC = @cLOC  
               END  
        
               -- Check QC status  
               IF @cLottable03_Act <> ''  
               BEGIN  
                  IF EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'QCStatus' AND Code = @cLottable03_Act AND StorerKey = @cStorerKey AND Code2 = @nFunc)  
                  BEGIN  
                     SET @nErrNo = 183954  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QC ID CantPick'  
                     EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID  
                  END  
               END  
            END  
         END  
      END  
   END  
  
END

Quit:

GO