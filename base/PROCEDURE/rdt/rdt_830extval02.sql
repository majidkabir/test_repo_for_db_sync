SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_830ExtVal02                                     */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: If user login with pref uom then only allow to key in       */
/*          pref uom qty                                                */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-12-23  1.0  James       WMS-11487. Created                      */
/* 2020-01-13  1.3  James       WMS-11714. Add checking whether dropid  */
/*                              is mandatory value (james01)            */
/* 2020-12-22  1.4 YeeKung      WMS15995 Add Pickzone (yeekung01)       */ 
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_830ExtVal02]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cPickZone     NVARCHAR( 10), --(yeekung01)
   @cSuggLOC      NVARCHAR( 10), 
   @cLOC          NVARCHAR( 10), 
   @cDropID       NVARCHAR( 20), 
   @cSKU          NVARCHAR( 20), 
   @cLottable01   NVARCHAR( 18), 
   @cLottable02   NVARCHAR( 18), 
   @cLottable03   NVARCHAR( 18), 
   @dLottable04   DATETIME,      
   @dLottable05   DATETIME,      
   @cLottable06   NVARCHAR( 30), 
   @cLottable07   NVARCHAR( 30), 
   @cLottable08   NVARCHAR( 30), 
   @cLottable09   NVARCHAR( 30), 
   @cLottable10   NVARCHAR( 30), 
   @cLottable11   NVARCHAR( 30), 
   @cLottable12   NVARCHAR( 30), 
   @dLottable13   DATETIME,      
   @dLottable14   DATETIME,      
   @dLottable15   DATETIME,      
   @nTaskQTY      INT,           
   @nQTY          INT,           
   @cToLOC        NVARCHAR( 10), 
   @cOption       NVARCHAR( 1),  
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cPUOM        NVARCHAR( 10)
   DECLARE @cUserName    NVARCHAR( 18)
   DECLARE @cInField15   NVARCHAR( 60)
   DECLARE @cLocationType  NVARCHAR( 10)
   
   IF @nFunc = 830 -- PickSKU
   BEGIN
      IF @nStep = 2 -- LOC, DropID
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SELECT @cLocationType = LocationType
            FROM dbo.LOC WITH (NOLOCK)
            WHERE LOC = @cLOC
            AND   Facility = @cFacility
            
            -- If location type setup in codelkup and drop id value is blank, prompt error
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE LISTNAME = 'PICKCHKDID'
                        AND   Code = @cLocationType
                        AND   Storerkey = @cStorerKey
                        AND   code2 = @nFunc) AND ISNULL( @cDropID, '') = ''
            BEGIN
               SET @nErrNo = 147202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DROPID req
               GOTO Quit
            END
         END
      END
      
      IF @nStep = 4 -- Qty
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cUserName = USERNAME, 
                   @cInField15 = I_Field15
            FROM RDT.RDTMOBREC WITH (NOLOCK) 
            WHERE Mobile = @nMobile
            
            SELECT @cPUOM = DefaultUOM 
            FROM rdt.rdtUser WITH (NOLOCK) 
            WHERE UserName = @cUserName

            -- User login with pref uom
            IF @cPUOM <> '6'
            BEGIN
               -- User key in master uom, prompt error. only pref uom allow
               IF @cInField15 <> ''
               BEGIN
                  SET @nErrNo = 147201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Piece not allow
                  GOTO Quit
               END
            END
         END
      END
   END
   
Quit:

END

GO