SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1643ExtInfo01                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Show the container to which the parcel has to put into      */    
/*                                                                      */    
/* Called from: rdtfnc_Scan_To_Van_MBOL_Creation                        */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 02-02-2015  1.0  James       SOS332388 Created                       */   
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1643ExtInfo01]    
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,       
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15), 
   @cMbolKey        NVARCHAR( 10), 
   @cToteNo         NVARCHAR( 20), 
   @cOption         NVARCHAR( 20), 
   @cOrderkey       NVARCHAR( 10), 
   @coFieled01      NVARCHAR( 20) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cC_Zip            NVARCHAR( 18), 
           @cIncoTerm         NVARCHAR( 10), 
           @cPutAwayZone      NVARCHAR( 10), 
           @cPTSLOC           NVARCHAR( 10), 
           @nErrNo            INT, 
           @cErrMsg           NVARCHAR( 20), 
           @cErrMsg1          NVARCHAR( 20), 
           @cErrMsg2          NVARCHAR( 20), 
           @cErrMsg3          NVARCHAR( 20), 
           @cErrMsg4          NVARCHAR( 20), 
           @cErrMsg5          NVARCHAR( 20), 
           @cErrMsg6          NVARCHAR( 20), 
           @cErrMsg7          NVARCHAR( 20) 

   SET @coFieled01 = ''
   
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         SELECT @cC_Zip = C_Zip, 
                @cIncoTerm = IncoTerm 
          FROM dbo.Orders WITH (NOLOCK) 
          WHERE StorerKey = @cStorerKey 
          AND   OrderKey = @cOrderKey

         -- Only for Incoterm = 'CC'
         IF @cIncoTerm <> 'CC'
            GOTO Quit

         -- some consignee does not have c_zip setup
         IF ISNULL( @cC_Zip, '') = ''
            SET @cPutAwayZone = ''
         ELSE
            SELECT TOP 1 @cPutAwayZone = LOC.PutAwayZone 
            FROM dbo.StoreToLocDetail STL WITH (NOLOCK) 
            JOIN dbo.Storer ST WITH (NOLOCK) ON ( STL.ConsigneeKey = ST.StorerKey )
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (STL.LOC = LOC.LOC)
            WHERE STL.Status = '1'
            AND   ST.Consigneefor = 'JACKW' 
            AND   ST.Zip = @cC_Zip
            AND   ST.Type = '2'


         SET @nErrNo = 0
         SET @cErrMsg1 = ' PLACE PARCEL'
         SET @cErrMsg2 = ' IN CONTAINER'
         SET @cErrMsg3 = ''
         SET @cErrMsg4 = CASE WHEN ISNULL( @cPutAwayZone, '') = '' 
                           THEN 'STORE NOT FOUND' 
                           ELSE '   ' + @cPutAwayZone 
                           END
         SET @cErrMsg5 = ''
         SET @cErrMsg6 = '   THEN'
         SET @cErrMsg7 = ' PRESS ESC'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
         @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5, @cErrMsg6, @cErrMsg7

         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
         END

         
      END
   END

   QUIT:

END -- End Procedure    

GO