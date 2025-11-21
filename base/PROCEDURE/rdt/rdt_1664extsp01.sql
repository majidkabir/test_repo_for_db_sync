SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1664ExtSP01                                     */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: TrackMBOL_Creation                                          */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2014-07-03 1.0  ChewKP   SOS#303800 Created                          */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1664ExtSP01]    
 @nMobile        INT, 
 @nFunc          INT, 
 @cLangCode      NVARCHAR( 3),  
 @cUserName      NVARCHAR( 18), 
 @cFacility      NVARCHAR( 5),  
 @cStorerKey     NVARCHAR( 15), 
 @cOrderKey      NVARCHAR( 20), 
 @cMBOLKey       NVARCHAR( 20), 
 @cTrackNo       NVARCHAR( 20),           
 @cTrackOrderWeight NVARCHAR(1) OUTPUT, 
 @nErrNo         INT            OUTPUT,
 @cErrMsg        NVARCHAR( 20)  OUTPUT
     
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   SELECT @cTrackORderWeight = ISNULL(Short,'') 
   FROM dbo.CodeLkup WITH (NOLOCK)
   WHERE Listname = 'RDTMBOL'
   AND Code = @cFacility
   AND StorerKey = @cStorerKey
   
   
   
QUIT:    
END -- End Procedure  

GO