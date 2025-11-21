SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry11                                       */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-01-28 1.0  Ung        WMS-18845 Created                            */
/***************************************************************************/
CREATE PROC [RDT].[rdt_727Inquiry11] (
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

   SET @nErrNo = 0

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep = 2 -- Inquiry sub module
      BEGIN
         DECLARE @cFacility   NVARCHAR( 5)
         DECLARE @cID         NVARCHAR( 18)
         DECLARE @cReceiptKey NVARCHAR( 10) = ''
         DECLARE @nUCCCount   INT

         -- Parameter mapping
         SET @cID = @cParam1

         -- Check blank
         IF @cID = '' 
         BEGIN
            SET @nErrNo = 181554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Pallet ID
            GOTO QUIT
         END
         
         -- Get session info
         SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
         
         -- Get pallet ID info
         SELECT TOP 1 
            @cReceiptKey = ReceiptKey
         FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND ID = @cID
            AND Status <> '9'
         
         -- Check pallet valid
         IF @cReceiptKey = ''
         BEGIN
         	SET @nErrNo = 181555
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad pallet ID
            GOTO QUIT
         END
         
         -- Get pallet ID info
         SELECT @nUCCCount = COUNT( DISTINCT UCCNo)
         FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND ReceiptKey = @cReceiptKey
            AND ID = @cID
            AND Status <> '9'
         
         -- Get label
         SET @c_oFieled01 = rdt.rdtgetmessage( 181551, @cLangCode, 'DSP') --ASN: 
         SET @c_oFieled02 = @cReceiptKey
         SET @c_oFieled03 = ''
         SET @c_oFieled04 = rdt.rdtgetmessage( 181552, @cLangCode, 'DSP') --PALLET ID:
         SET @c_oFieled05 = @cID
         SET @c_oFieled06 = ''
         SET @c_oFieled07 = rdt.rdtgetmessage( 181553, @cLangCode, 'DSP') --UCC COUNT:
         SET @c_oFieled08 = CAST( @nUCCCount AS NVARCHAR( 5))
         SET @c_oFieled09 = ''
         SET @c_oFieled10 = ''
         
      	SET @nNextPage = 1  
      END
   END

Quit:

END

GO