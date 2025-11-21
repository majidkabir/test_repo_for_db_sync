SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1637ExtVal02                                    */  
/* Purpose: Validate pallet id before scanned to truck                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-08-08 1.0  Ung        WMS-2017 Created                          */  
/* 2017-10-02 1.1  Ung        WMS-3128 Fix PalletKey to 30 chars        */  
/* 2018-03-19 1.2  Ung        WMS-4246 Add ECOM validation              */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1637ExtVal02] (  
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nInputKey     INT,           
   @cStorerkey    NVARCHAR( 15), 
   @cContainerKey NVARCHAR( 10), 
   @cContainerNo  NVARCHAR( 20), 
   @cMBOLKey      NVARCHAR( 10), 
   @cSSCCNo       NVARCHAR( 20), 
   @cPalletKey    NVARCHAR( 30), 
   @cTrackNo      NVARCHAR( 20), 
   @cOption       NVARCHAR( 1), 
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT   
)  
AS  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nStep = 3 -- PalletKey
   BEGIN  
      IF @nInputKey = 1  -- ENTER
      BEGIN
         -- Get session info
         DECLARE @cFacility  NVARCHAR( 5)
         SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

         -- Get Pallet info
         DECLARE @cChkStatus NVARCHAR( 10)
         DECLARE @cChkStorerKey NVARCHAR( 15)
         SELECT 
            @cChkStatus = Status, 
            @cChkStorerKey = StorerKey
         FROM Pallet WITH (NOLOCK) 
         WHERE PalletKey = @cPalletKey
         
         -- Check pallet valid
         IF @@ROWCOUNT <> 1
         BEGIN
            SET @nErrNo = 113501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletNotExist
            GOTO Fail         
         END

         -- Check storer
         IF @cChkStorerKey <> @cStorerKey
         BEGIN
            SET @nErrNo = 113502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer
            GOTO Fail         
         END
         
         -- Check status
         IF @cChkStatus <> '9'
         BEGIN
            SET @nErrNo = 113503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletNotClose
            GOTO Fail         
         END
         
         -- Check order status blocked
         IF EXISTS( SELECT 1
            FROM PalletDetail PD WITH (NOLOCK) 
               JOIN CartonTrack CT WITH (NOLOCK) ON (PD.CaseID = CT.TrackingNo)
               JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey)
               JOIN CodeLKUP CL WITH (NOLOCK) ON (CL.ListName = 'SOSTSBLOCK' AND CL.Code = O.SOStatus AND CL.StorerKey = @cStorerKey AND CL.Code2 = @nFunc)
            WHERE PD.PalletKey = @cPalletKey)
         BEGIN
            SET @nErrNo = 113504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Status blocked
            GOTO Fail         
         END
               
         -- Check order in MBOL
         IF EXISTS( SELECT 1
            FROM PalletDetail PD WITH (NOLOCK) 
               JOIN CartonTrack CT WITH (NOLOCK) ON (PD.CaseID = CT.TrackingNo)
               LEFT JOIN MBOLDetail MB WITH (NOLOCK) ON (CT.LabelNo = MB.OrderKey)
            WHERE PD.PalletKey = @cPalletKey
               AND MB.MBOLKey IS NULL)
         BEGIN
            SET @nErrNo = 113505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order removed
            GOTO Fail         
         END
      END
   END  
  
Fail: 
 

GO