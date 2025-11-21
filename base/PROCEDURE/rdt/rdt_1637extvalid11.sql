SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1637ExtValid11                                  */  
/* Purpose: Validate pallet id before scanned to truck                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* rdt_1637ExtVal02->rdt_1637ExtValid11                                 */
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-09-17 1.0  YeeKung    WMS-15187 Created                         */  
/************************************************************************/  
   
CREATE PROC [RDT].[rdt_1637ExtValid11] (  
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
            SET @nErrNo = 159201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletNotExist
            GOTO Fail         
         END

         -- Check storer
         IF @cChkStorerKey <> @cStorerKey
         BEGIN
            SET @nErrNo = 159202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer
            GOTO Fail         
         END
         
         -- Check status
         IF @cChkStatus <> '9'
         BEGIN
            SET @nErrNo = 159203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletNotClose
            GOTO Fail         
         END
         
         -- Check order status blocked
         IF EXISTS( SELECT 1
            FROM PalletDetail PD WITH (NOLOCK) 
               JOIN PackDetail PA WITH (NOLOCK) ON (PD.CaseID = PA.LabelNo)
               JOIN PackHeader PH WITH (NOLOCK) ON (PA.pickslipno = PH.pickslipno)
               JOIN Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
               JOIN CodeLKUP CL WITH (NOLOCK) ON (CL.ListName = 'STSBLOCK ' AND CL.Code = O.status AND CL.StorerKey = @cStorerKey AND CL.Code2 = @nFunc)
            WHERE PD.PalletKey = @cPalletKey)
         BEGIN
            SET @nErrNo = 159204
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Status blocked
            GOTO Fail         
         END

          -- Check order status blocked
         IF EXISTS( SELECT 1
            FROM PalletDetail PD WITH (NOLOCK) 
               JOIN PackDetail PA WITH (NOLOCK) ON (PD.CaseID = PA.LabelNo)
               JOIN PackHeader PH WITH (NOLOCK) ON (PA.pickslipno = PH.pickslipno)
               JOIN Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
               JOIN CodeLKUP CL WITH (NOLOCK) ON (CL.ListName = 'STSBLOCK ' AND CL.Code = O.status AND CL.StorerKey = @cStorerKey AND CL.Code2 = @nFunc)
            WHERE PD.PalletKey = @cPalletKey
               AND O.status< 5)
         BEGIN
            SET @nErrNo = 159205
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
            SET @nErrNo = 159206
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order removed
            GOTO Fail         
         END
      END
   END  
  
Fail: 
 

GO