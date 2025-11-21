SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_JACKWExtInfoSP04                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get the order details using refno from packdetail and       */
/*          display the collection date for the parcel on screen so     */
/*          that it can be put in the correct cage                      */
/*                                                                      */
/* Called from: rdtfnc_Return                                           */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 06-08-2014 1.0  James    SOS328456 - Created                         */
/************************************************************************/

CREATE PROC [dbo].[isp_JACKWExtInfoSP04] (
   @nMobile          INT,   
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,   
   @nInputKey        INT,    
   @cStorerkey       NVARCHAR( 15), 
   @cMbolKey         NVARCHAR( 10),   
   @cToteNo          NVARCHAR( 20),   
   @cOption          NVARCHAR( 1),   
   @cOrderkey        NVARCHAR( 10),    
   @c_oFieled01      NVARCHAR( 20)   OUTPUT 
 )
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @dDeliveryDate  DATETIME, 
           @cDay           NVARCHAR( 20), 
           @cDayFactor     NVARCHAR( 20) 

   IF @nInputKey <> 1 AND @nStep <> 2
      GOTO Quit

   SET @c_oFieled01 = ''

   -- If Orders.Delivery date is not blank/null then goto screen 3 (james08)
   SELECT @dDeliveryDate = DeliveryDate 
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey
      AND ISNULL(DeliveryDate, '') <> ''

   IF ISNULL(@dDeliveryDate, '') = ''
      GOTO Quit

   SET @cDay = UPPER(DATENAME(dw, @dDeliveryDate))
   
   SELECT @cDayFactor = Short 
   FROM dbo.CODELKUP WITH (NOLOCK) 
   WHERE StorerKey = @cStorerkey
   AND   ListName = 'DAYFACTOR'
   AND   Code = @cDay

   IF RDT.rdtIsInteger(@cDayFactor) = 0
      SET @cDayFactor = '0'

   SET @c_oFieled01 = @dDeliveryDate - CAST( @cDayFactor AS INT)
   
   Quit:

END

GO