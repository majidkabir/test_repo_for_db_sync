SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Store procedure: rdt_1637ExtValid02                                  */          
/* Purpose: Validate pallet id before scanned to truck                  */          
/*                                                                      */          
/* Modifications log:                                                   */          
/*                                                                      */          
/* Date       Rev  Author   Purposes                                    */          
/* 2017-09-15 1.0  ChewKP   WMS-1993 Created                            */    
/* 2020-01-23 1.1  YeeKung  WMS-11662 Check MBOL (yeekung01)            */       
/* 2022-10-27 1.2  CALVIN   JSM-105362 Orderkey to Userdefine02 (CLVN01)*/
/************************************************************************/          
          
CREATE   PROC [RDT].[rdt_1637ExtValid02] (          
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
           @nMBOLCnt       INT        
        
   DECLARE @cErrMsg1       NVARCHAR( 20),         
           @cErrMsg2       NVARCHAR( 20),        
           @cErrMsg3       NVARCHAR( 20),         
           @cErrMsg4       NVARCHAR( 20),        
           @cErrMsg5       NVARCHAR( 20)        
        
   SET NOCOUNT ON          
   SET QUOTED_IDENTIFIER OFF          
   SET ANSI_NULLS OFF          
        
   SELECT @cFacility = Facility,        
          @cInField02 = I_Field02        
   FROM RDT.RDTMOBREC WITH (NOLOCK)         
   WHERE Mobile = @nMobile        
        
   IF @nInputKey = 1          
   BEGIN          
      IF @nStep = 1  -- (james02)        
      BEGIN        
         SELECT @cSeal02 = Seal02,        
                @cContainerNo = BookingReference        
         FROM dbo.Container WITH (NOLOCK)        
         WHERE ContainerKey = @cContainerKey        
        
         -- If container no not key in or is blank in container table, prompt error        
         IF ISNULL( @cInField02, '') = '' OR ISNULL( @cContainerNo, '') = ''        
         BEGIN        
            SET @nErrNo = 115101  -- Container# req        
            GOTO Fail                 
         END        
        
         IF rdt.rdtIsValidQty( @cSeal02, 1) = 0        
         BEGIN        
            SET @nErrNo = 115102  -- Inv # pallet        
            GOTO Fail                 
         END        
      END        
        
      IF @nStep = 3        
      BEGIN        
--         SELECT @nMBOLCnt = COUNT( DISTINCT OD.MBOLKEY)        
--         FROM dbo.PickDetail PD WITH (NOLOCK)        
--         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)        
--         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)        
--         WHERE PD.StorerKey = @cStorerKey        
--         AND   PD.ID = @cPalletKey        
--         AND   PD.Status < '9'        
--         AND   LOC.Facility = @cFacility        
        
         SELECT @nMBOLCnt = COUNT( DISTINCT O.MBOLKEY)        
         FROM dbo.PalletDetail PD WITH (NOLOCK)        
         JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.UserDefine02 = O.OrderKey AND PD.StorerKey = O.StorerKey)        
         WHERE PD.StorerKey = @cStorerKey        
         AND   PD.PalletKey = @cPalletKey        
         AND   PD.Status = '9'        
        
                          
        
         -- Check if pallet contain > 1 mbol        
         IF @nMBOLCnt > 1           BEGIN        
            SET @nErrNo = 115103  -- ID in >1 mbol        
            GOTO Fail                 
         END        
        
         -- Check if pallet belong to correct mbol        
         SELECT TOP 1 @cOrderKey = UserDefine02,        
                      @cLOC = PD.LOC        
         FROM dbo.PalletDetail PD WITH (NOLOCK)        
         WHERE StorerKey = @cStorerKey        
         AND   PalletKey = @cPalletKey        
         AND   PD.Status = '9'        
                 
                 
         -- Check if pallet in palletdetail table        
         IF ISNULL(@cOrderKey,'')  = ''         
         BEGIN        
            SET @nErrNo = 115105  -- ID not in PLTD        
            GOTO Fail                 
         END        
                 
         -- Validate pallet id         
         IF NOT EXISTS ( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK)        
                         WHERE MBOLKey = @cMBOLKey        
                         AND   OrderKey = @cOrderKey)        
         BEGIN        
            SET @nErrNo = 115104  -- ID not in mbol        
            GOTO Fail                 
         END        
        
                
        
         SELECT @cSeal02 = Seal02,         
                @cSeal03 = Seal03         
         FROM dbo.CONTAINER WITH (NOLOCK)        
         WHERE ContainerKey = @cContainerKey        
        
         SELECT @cScanCnt = COUNT(DISTINCT PalletKey)         
         FROM dbo.CONTAINERDETAIL WITH (NOLOCK)        
         WHERE ContainerKey = @cContainerKey        
        
         IF rdt.rdtIsValidQty( @cSeal02, 1) = 0        
            SET @nSeal02 = 0        
         ELSE        
            SET @nSeal02 = CAST( @cSeal02 AS INT)        
        
         IF rdt.rdtIsValidQty( @cScanCnt, 1) = 0        
            SET @nScanCnt = 0        
         ELSE        
            SET @nScanCnt = CAST( @cScanCnt AS INT)        
        
         -- Check over scanned. + 1 pallet here         
         -- as it is still not inserted into containerdetail        
         IF @nSeal02 < (@nScanCnt + 1)        
         BEGIN        
            SET @nErrNo = 115106  -- Over scanned        
            GOTO Fail                 
         END        
        
         --SET @cPalletLoc = ''        
         --SELECT TOP 1 @cPalletLoc = LLI.LOC         
         --FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)         
         --JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)        
         --WHERE LLI.StorerKey = @cStorerKey         
         --AND   LLI.ID = @cPalletKey         
         --AND   LOC.Facility = @cFacility        
         --AND   LOC.LocationCategory = 'STAGING'        
         --AND   Qty > 0        
        
         --IF ISNULL( @cPalletLoc, '') <> ISNULL( @cSeal03, '')        
         --BEGIN        
         --   SET @nErrNo = 115107  -- Over scanned        
         --   GOTO Fail                 
               
         --END        
      END        
        
      IF @nStep = 6          
      BEGIN        
         SELECT @cSeal02 = Seal02        
         FROM dbo.CONTAINER WITH (NOLOCK)        
         WHERE ContainerKey = @cContainerKey        
        
         SELECT @cScanCnt = COUNT(DISTINCT PalletKey)         
         FROM dbo.CONTAINERDETAIL WITH (NOLOCK)        
         WHERE ContainerKey = @cContainerKey   
        
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
             
            SET @nErrNo = 115108        
            GOTO Fail                 
         END       
    
         DECLARE @cContainerCount INT    
    
         SELECT @cContainerCount=count(1)--count(PD.userdefine02)-MD.TotalCartons    
         FROM dbo.CONTAINER C WITH (NOLOCK)     
         JOIN dbo.MBOL MD (NOLOCK) ON MD.MBOLKEY=C.MBOLKEY    
         WHERE MD.MBOLKEY= @cMBOLKey    
         AND C.status=0    
    
         IF @cContainerCount=1    
         BEGIN    
                
            DECLARE @cContainerkey2 NVARCHAR(20)    
    
            DECLARE Container_Cursor CURSOR FOR    
            SELECT DISTINCT C.ContainerKey     
            FROM dbo.CONTAINER C WITH (NOLOCK)     
            JOIN dbo.MBOL MD (NOLOCK) ON MD.MBOLKEY=C.MBOLKEY    
            WHERE MD.MBOLKEY= @cMBOLKey    
    
            OPEN Container_Cursor    
    
            FETCH NEXT FROM Container_Cursor    
            INTO @cContainerkey2;    
                
            WHILE @@FETCH_STATUS = 0     
            BEGIN      
    
               DECLARE @cOrderkey2 NVARCHAR(20)--(yeekung01)    
    
               DECLARE SKU_Cursor CURSOR FOR    
               SELECT DISTINCT PD.Userdefine02 FROM CONTAINERDETAIL CD (NOLOCK)    
               JOIN PALLETDETAIL PD (NOLOCK) ON CD.PALLETKEY=PD.PALLETKEY    
               WHERE CD.Containerkey=@cContainerkey2    
             
               OPEN SKU_CURSOR    
    
               FETCH NEXT FROM SKU_CURSOR    
               INTO @cOrderkey2;    
    
               WHILE @@FETCH_STATUS = 0    
               BEGIN    
                  SELECT 1    
                  FROM dbo.PICKDETAIL (NOLOCK)    
                  WHERE orderkey=@cOrderkey2    
                  AND SKU NOT IN ( SELECT pd.sku FROM CONTAINERDETAIL CD (NOLOCK)    
                  JOIN PALLETDETAIL PD (NOLOCK) ON CD.PALLETKEY=PD.PALLETKEY    
                  WHERE PD.USERDEFINE02=@cOrderkey2)    --(CLVN01)
    
                  IF @@ROWCOUNT >= 1    
                  BEGIN     
                     SET @nErrNo = 115109 -- SKU NOT Tally     
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv field name      
                     CLOSE SKU_CURSOR      
                     DEALLOCATE SKU_CURSOR    
                     CLOSE Container_Cursor      
                     DEALLOCATE Container_Cursor         
                     GOTO FAIL                     
                  
                  END    
                  ELSE     
                  BEGIN    
                     SELECT 1    
                     FROM dbo.PACKDETAIL PD (NOLOCK)    
                     JOIN dbo.PALLETDETAIL PDL (NOLOCK)    
                     ON PDL.CASEID=PD.LABELNO AND PD.SKU=PDL.SKU    
                     WHERE PDl.UserDefine02=@cOrderkey2    
                     GROUP BY PD.SKU    
                     HAVING SUM(PD.QTY) <> SUM(PDL.QTY)    
    
                     IF @@ROWCOUNT >= 1    
                     BEGIN     
                        SET @nErrNo = 115110  -- QTY NOT Tally      
                        SET @cErrMsg =@cOrderkey2-- rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
                        CLOSE SKU_CURSOR      
                        DEALLOCATE SKU_CURSOR    
                        CLOSE Container_Cursor      
                        DEALLOCATE Container_Cursor       
                        GOTO FAIL           
                     END    
    
                  END    
    
                  FETCH NEXT FROM SKU_CURSOR    
                  INTO @cOrderkey2;    
    
               END    
    
               FETCH NEXT FROM Container_Cursor    
               INTO @cContainerkey2;    
             
               CLOSE SKU_CURSOR      
               DEALLOCATE SKU_CURSOR       
            END    
    
            CLOSE Container_Cursor      
            DEALLOCATE Container_Cursor     
         END     
    
      END        
   END          
          
Fail: 

GO