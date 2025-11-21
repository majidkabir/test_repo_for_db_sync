SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Store procedure: rdt_1637ExtValid10                                  */    
/* Purpose: Validate pallet id before scanned to truck                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2022-01-27 1.0  YeeKung   WMS-18739 Created                          */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1637ExtValid10] (    
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
  
   DECLARE @cOrderKey NVARCHAR(20)  
  
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
            SET @nErrNo = 181301  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletNotExist  
            GOTO Fail           
         END  
  
         -- Check storer  
         IF @cChkStorerKey <> @cStorerKey  
         BEGIN  
            SET @nErrNo = 181302  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer  
            GOTO Fail           
         END  
  
   DECLARE @cDoctype NVARCHAR(20)  
  
   SELECT @cDoctype=o.DocType  
         FROM PalletDetail PD WITH (NOLOCK)   
            JOIN CartonTrack CT WITH (NOLOCK) ON (PD.CaseID = CT.TrackingNo)  
            JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey)  
         WHERE PD.PalletKey = @cPalletKey  
   AND PD.storerkey=@cStorerkey  
           
         -- Check status  
         IF @cChkStatus <> '9' AND @cDoctype<>'N'  
         BEGIN  
            SET @nErrNo = 181303  
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
            SET @nErrNo = 181304  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Status blocked  
            GOTO Fail           
         END  
                 
         -- Check order in MBOL  
         IF NOT EXISTS( SELECT 1  
            FROM PalletDetail PD WITH (NOLOCK)   
               JOIN CartonTrack CT WITH (NOLOCK) ON (PD.CaseID = CT.TrackingNo)  
               LEFT JOIN MBOLDetail MB WITH (NOLOCK) ON (CT.LabelNo = MB.OrderKey)  
            WHERE PD.PalletKey = @cPalletKey  
               AND ISNULL(MB.MBOLKey,'') <>'')AND @cDoctype='N'  
         BEGIN  
            SET @nErrNo = 181305  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order removed  
            GOTO Fail           
         END  
  
         -- Check if pallet belong to correct mbol  
         SELECT TOP 1 @cOrderKey = OrderKey  
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)  
         WHERE StorerKey = @cStorerKey  
            AND ID = @cPalletKey  
            AND PD.Status < '9'  
            AND LOC.Facility = @cFacility  
  
         -- Validate pallet id  
         IF NOT EXISTS ( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK)  
                        WHERE MBOLKey = @cMBOLKey  
                           AND OrderKey = @cOrderKey)  
         BEGIN  
            SET @nErrNo = 181307 -- ID not in mbol  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order removed  
            GOTO Fail      
         END  
      END  
   END    
    
Fail:   
   
 

GO