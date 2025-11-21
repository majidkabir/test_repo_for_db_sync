SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/            
/* Store procedure: rdt_1651ExtValid01                                  */            
/* Purpose: Modify from rdt_1637ExtValid02                              */            
/*                                                                      */            
/* Modifications log:                                                   */            
/*                                                                      */            
/* Date       Rev  Author     Purposes                                  */            
/* 2018-07-20 1.1  James      WMS-4673-Created                          */      
/* 2020-01-06 1.2  YeeKung    WMS-11663-Container verify status         */      
/*                              (yeekung01)                             */    
/* 2020-04-24 1.3  YeeKung    WMS-13025 Add popup Message (yeekung04)   */  
/* 2020-06-29 1.4  YeeKung    WMS-13771 Change error message(yeekung05) */           
/************************************************************************/            
            
CREATE PROC [RDT].[rdt_1651ExtValid01] (            
   @nMobile                   INT,                     
   @nFunc                     INT,                     
   @cLangCode                 NVARCHAR( 3),            
   @nStep                     INT,                     
   @nInputKey                 INT,                     
   @cStorerkey                NVARCHAR( 15),           
   @cContainerKey             NVARCHAR( 10),           
   @cContainerNo              NVARCHAR( 20),           
   @cMBOLKey                  NVARCHAR( 10),           
   @cSSCCNo                   NVARCHAR( 20),           
   @cPalletKey                NVARCHAR( 18),           
   @cTrackNo                  NVARCHAR( 20),           
   @cOption                   NVARCHAR( 1),           
   @nErrNo                    INT           OUTPUT,            
   @cErrMsg                   NVARCHAR( 20) OUTPUT             
)            
AS            
   DECLARE @cOrderKey      NVARCHAR( 10),          
           @cLOC           NVARCHAR( 10),          
           @cFacility      NVARCHAR( 5),          
           @cInField02     NVARCHAR( 60),          
           @cSeal02        NVARCHAR( 30),          
           @cSeal03        NVARCHAR( 30),           
           @cPalletLoc     NVARCHAR( 10),           
           @cScanCnt       NVARCHAR( 5),          
           @nScanCnt       INT,          
           @nSeal02        INT,          
           @nMBOLCnt       INT,      
           @cStatus        INT      
       
   DECLARE @cErrMsg01         NVARCHAR( 20)      
   DECLARE @cErrMsg02         NVARCHAR( 20)      
   DECLARE @cErrMsg03         NVARCHAR( 20)      
   DECLARE @cErrMsg04         NVARCHAR( 20)      
   DECLARE @cErrMsg05         NVARCHAR( 20)    
          
   SET NOCOUNT ON            
   SET QUOTED_IDENTIFIER OFF            
   SET ANSI_NULLS OFF            
          
   SELECT @cFacility = Facility,          
          @cInField02 = I_Field02          
   FROM RDT.RDTMOBREC WITH (NOLOCK)           
   WHERE Mobile = @nMobile          
          
   IF @nInputKey = 1            
   BEGIN            
      IF @nStep = 1          
      BEGIN          
         SELECT @cSeal02 = Seal02,          
                @cContainerNo = BookingReference,      
                @cStatus   = Status          
         FROM dbo.Container WITH (NOLOCK)          
         WHERE ContainerKey = @cContainerKey          
      
      
         IF ISNULL( @cContainerNo, '') <> ''        
         BEGIN          
            -- If container no has value in table then value is compulsary. If blank then prompt error          
            IF ISNULL( @cInField02, '') = ''         
            BEGIN        
               SET @nErrNo = 126701  -- Container# req          
               GOTO Fail                   
            END        
            ELSE        
            BEGIN        
               -- If container no has value but value diff from user key in then prompt error        
               IF ISNULL( @cContainerNo, '') <> ISNULL( @cInField02, '')        
               BEGIN        
                  SET @nErrNo = 126702  -- Inv Container#         
                  GOTO Fail                  
               END        
            END        
         END          
         ELSE        
         BEGIN        
            -- If container no blank but user key in value then prompt error        
            IF ISNULL( @cContainerNo, '') = '' AND ISNULL( @cInField02, '') <> ''        
            BEGIN        
               SET @nErrNo = 126703  -- Inv Container#         
               GOTO Fail                   
            END        
         END        
        
         IF rdt.rdtIsValidQty( @cSeal02, 1) = 0          
         BEGIN          
            SET @nErrNo = 126704  -- Inv # pallet          
            GOTO Fail                   
         END      
               
         IF (@cStatus<>9)      --(yeekung01)      
         BEGIN      
            SET @nErrNo = 126710  -- StatusNotEq9        
            GOTO Fail        
         END          
      END          
          
      IF @nStep = 3          
      BEGIN          
         -- Pallet not in container          
         IF NOT EXISTS (SELECT 1 FROM dbo.ContainerDetail WITH (NOLOCK) WHERE ContainerKey = @cContainerKey AND PalletKey = @cPalletKey)         
         BEGIN  
            SET @nErrNo = 126711  -- Container# req            
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  --(yeekung05) --  
            'Wrong/Invalid',  
            'Pallet Scanned!',  
            'Please See Your',        
            'leader/supervisor',    
            'for further action.'  
         END          
          
         -- Check if pallet scanned (for 2nd time verify only)          
         IF EXISTS ( SELECT 1 FROM dbo.ContainerDetail WITH (NOLOCK)           
                     WHERE ContainerKey = @cContainerKey           
                     AND   PalletKey = @cPalletKey          
                     AND   [Status] = '5'          
                     AND   (( @nFunc = 1651 AND 1 = 1) OR ( 1 = 0)))          
         BEGIN
            SET @nErrNo = 126712          
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  --(yeekung05)  
            'Wrong/Invalid',  
            'Pallet Scanned!',  
            'Please See Your',        
            'leader/supervisor',    
            'for further action.'         
         END           
      END          
          
      IF @nStep = 6            
      BEGIN          
         SELECT @cSeal02 = Seal02          
         FROM dbo.CONTAINER WITH (NOLOCK)          
         WHERE ContainerKey = @cContainerKey          
          
         SELECT @cScanCnt = COUNT(DISTINCT PalletKey)           
         FROM dbo.CONTAINERDETAIL WITH (NOLOCK)          
         WHERE ContainerKey = @cContainerKey         
         AND Status=5       
          
         IF rdt.rdtIsValidQty( @cSeal02, 1) = 0          
            SET @nSeal02 = 0          
         ELSE          
            SET @nSeal02 = CAST( @cSeal02 AS INT)          
          
         IF rdt.rdtIsValidQty( @cScanCnt, 1) = 0          
            SET @nScanCnt = 0          
         ELSE          
            SET @nScanCnt = CAST( @cScanCnt AS INT)       
                     
          
         IF @nSeal02 > @nScanCnt          
         BEGIN          
            SET @nErrNo = 126709  -- NotAllPalletScanned        
            GOTO Fail                   
         END          
      END          
   END            
      
            
Fail: 

GO