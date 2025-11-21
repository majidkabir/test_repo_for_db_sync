SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653DecodeSP03                                  */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Insert TrackingID                                           */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-10-17  1.0  yeekung WMS-20927. Created                         */  
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1653DecodeSP03] (    
   @nMobile         INT,            
   @nFunc           INT,            
   @cLangCode       NVARCHAR( 3),   
   @nStep           INT,            
   @nInputKey       INT,            
   @cFacility       NVARCHAR( 5),   
   @cStorerKey      NVARCHAR( 15),  
   @cPalletKey      NVARCHAR( 20),   
   @cCartonType     NVARCHAR( 10),   
   @cMBOLKey        NVARCHAR( 10),   
   @cTrackNo        NVARCHAR( 60)  OUTPUT,
   @cOrderKey       NVARCHAR( 10)  OUTPUT,
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT 
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cInTrackNo     NVARCHAR( 40) = ''

   SET @cInTrackNo = @ctrackno

   IF NOT EXISTS (SELECT 1 FROM orders (nolock)
               where trackingno=@cInTrackNo
               and storerkey=@cstorerkey)
   BEGIN
      SET @nErrNo = 192651 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidCaseID  
      GOTO Quit  
   END

   IF EXISTS (SELECT 1 FROM palletdetail (nolock)
              where palletkey=@cPalletKey
                  AND storerkey=@cStorerkey
                  AND trackingno=@cInTrackNo)
   BEGIN
      SET @nErrNo = 192653 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DuplicateCaseiD  
      GOTO Quit  
   END

   SELECT TOP 1 @cTrackNo=pd.labelno
   FROM packdetail PD (NOLOCK)
   JOIN packheader PH (NOLOCK) ON PD.pickslipno=PH.pickslipno
   JOIN orders OD (NOLOCK) ON OD.orderkey =PH.orderkey
   WHERE trackingno=@cInTrackNo
   AND PD.labelno NOT IN ( SELECT caseid
                        FROM palletdetail (Nolock)
                        where palletkey=@cPalletKey
                           AND storerkey=@cStorerkey
                           AND trackingno=@cInTrackNo)
   and pd.storerkey=@cstorerkey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 192652 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DuplicateCaseiD  
      GOTO Quit  
   END



QUIT:    
END    

GO