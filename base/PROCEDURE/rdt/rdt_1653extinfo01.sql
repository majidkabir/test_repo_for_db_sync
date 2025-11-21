SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653ExtInfo01                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Display total carton scanned to pallet                      */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-03-08  1.0  James    WMS-19061. Created                         */  
/* 2022-09-15  1.1  James    WMS-20667 Add Lane (james01)               */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1653ExtInfo01] (    
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTrackNo       NVARCHAR( 40),
   @cOrderKey      NVARCHAR( 20),
   @cPalletKey     NVARCHAR( 20),
   @cMBOLKey       NVARCHAR( 10),
   @cLane          NVARCHAR( 20),
   @tExtInfoVar    VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @nCtnCount   INT
   DECLARE @nRowRef     INT

   IF @nAfterStep = 1   -- Only go back step 1 need show ctn count
   BEGIN
      IF @nInputKey IN ( 0, 1)   -- Press Enter/ESC also need show ctn count
      BEGIN
      	SELECT @nCtnCount = COUNT( DISTINCT UserDefine02)
      	FROM dbo.PALLETDETAIL WITH (NOLOCK)
      	WHERE PalletKey = @cPalletKey
      	AND   StorerKey = @cStorerKey
         AND   ISNULL( UserDefine02, '') <> ''
         AND   [Status] = '0'
         
         SET @cExtendedInfo = 'TTL SCN: ' + CAST( @nCtnCount AS NVARCHAR( 5))
      END
   END
   GOTO Quit
   
   Quit:  
    
END    

GO