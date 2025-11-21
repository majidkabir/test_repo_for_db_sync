SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry13                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-04-05 1.0  Ung        WMS-19199 Created                            */
/***************************************************************************/

CREATE PROC [RDT].[rdt_727Inquiry13] (
 	@nMobile      INT,  
   @nFunc        INT,  
   @nStep        INT,  
   @cLangCode    NVARCHAR(3),  
   @cStorerKey   NVARCHAR(15),  
   @cOption      NVARCHAR(1),  
   @cParam1      NVARCHAR(20),  
   @cParam2      NVARCHAR(20),  
   @cParam3      NVARCHAR(20),  
   @cParam4      NVARCHAR(20),  
   @cParam5      NVARCHAR(20),  
   @c_oFieled01  NVARCHAR(20) OUTPUT,  
   @c_oFieled02  NVARCHAR(20) OUTPUT,  
   @c_oFieled03  NVARCHAR(20) OUTPUT,  
   @c_oFieled04  NVARCHAR(20) OUTPUT,  
   @c_oFieled05  NVARCHAR(20) OUTPUT,  
   @c_oFieled06  NVARCHAR(20) OUTPUT,  
   @c_oFieled07  NVARCHAR(20) OUTPUT,  
   @c_oFieled08  NVARCHAR(20) OUTPUT,  
   @c_oFieled09  NVARCHAR(20) OUTPUT,  
   @c_oFieled10  NVARCHAR(20) OUTPUT,  
   @c_oFieled11  NVARCHAR(20) OUTPUT,  
   @c_oFieled12  NVARCHAR(20) OUTPUT,  
   @nNextPage    INT          OUTPUT,  
   @nErrNo       INT          OUTPUT,  
   @cErrMsg      NVARCHAR(20) OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cLabel_PalletID NVARCHAR( 20)
   DECLARE @cLabel_UCC      NVARCHAR( 20)
   DECLARE @cLabel_Position NVARCHAR( 20)

   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cUCCNo      NVARCHAR( 20)
   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cPosition   NVARCHAR( 10)
   DECLARE @cDesc       NVARCHAR( 5)
   DECLARE @nRowCount   INT

   SET @nErrNo = 0

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep IN (2, 3) -- Inquiry sub module, 2=param screen, 3=result screen
      BEGIN
         -- Parameter mapping
         IF @nStep = 2
            SET @cUCCNo = @cParam1
         IF @nStep = 3
            SELECT @cUCCNo = I_Field12 FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
            
         -- Check blank
         IF @cUCCNo = '' 
         BEGIN
            SET @nErrNo = 185451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need UCC
            GOTO QUIT
         END
  
         -- Check UCC valid
         IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCCNo)
         BEGIN
            SET @nErrNo = 185452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
            GOTO QUIT
         END

         -- Get session info
         SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

         -- Get UCC info
         SELECT 
            @cID = ID, 
            @cPosition = Position
         FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND UCCNo = @cUCCNo
         SET @nRowCount = @@ROWCOUNT

         -- Check UCC pre-palletize 
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 185453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotPrePallet
            GOTO QUIT
         END
         
         -- Get SKU info
         SELECT @cDesc = LEFT( ISNULL( Description, ''), 5)
         FROM dbo.CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'PreRcvLane'
            AND Code = @cPosition
            AND StorerKey = @cStorerKey
         
         -- Get label
         SET @cLabel_UCC      = rdt.rdtgetmessage( 185454, @cLangCode, 'DSP') --UCC NO:
         SET @cLabel_PalletID = rdt.rdtgetmessage( 185455, @cLangCode, 'DSP') --PALLET ID:
         SET @cLabel_Position = rdt.rdtgetmessage( 185456, @cLangCode, 'DSP') --POSITION:
         
         SET @c_oFieled01 = @cLabel_UCC --UCC NO: 
         SET @c_oFieled02 = @cUCCNo
         SET @c_oFieled03 = ''
         SET @c_oFieled04 = @cLabel_PalletID --PALLET ID: 
         SET @c_oFieled05 = @cID
         SET @c_oFieled06 = ''
         SET @c_oFieled07 = RTRIM( @cLabel_Position) + ' ' + @cDesc
         SET @c_oFieled08 = ''
         SET @c_oFieled09 = ''
         SET @c_oFieled10 = ''
         -- SET @c_oFieled09 = rdt.rdtFormatString( @cDescr, 1, 20)
         -- SET @c_oFieled10 = rdt.rdtFormatString( @cDescr, 21, 20)
         -- SET @c_oFieled11 = '' --reserved
         
      	IF @nStep = 2
            SET @nNextPage = 0  
      	IF @nStep = 3
            SET @nNextPage = -1  
      END
   END

Quit:

END

GO