SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/******************************************************************************/    
/* Store procedure: rdt_1663ExtUpd01                                          */    
/* Copyright      : LF Logistics                                              */    
/*                                                                            */    
/* Date       Rev  Author   Purposes                                          */    
/* 2017-06-07 1.0  Ung      WMS-2016 Migrated from TrackNoMBOL_Creation       */    
/* 2017-08-16 1.1  Ung      WMS-2692 Change param                             */    
/*                          Add configurable interface                        */    
/* 2017-10-16 1.2  Ung      Performance tuning (remove @tVar)                 */    
/* 2018-11-11 1.3  James    Performance tuning (james01)                      */   
/* 2021-10-13 1.4  YeeKung  WMS-18033 Add key2 to 9 (yeekung01)               */ 
/* 2022-05-12 1.5  Ung      WMS-19643 Add SOCFMITF                            */
/******************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1663ExtUpd01](    
   @nMobile       INT,    
   @nFunc         INT,    
   @cLangCode     NVARCHAR( 3),    
   @nStep         INT,    
   @nInputKey     INT,    
   @cFacility     NVARCHAR( 5),    
   @cStorerKey    NVARCHAR( 15),    
   @cPalletKey    NVARCHAR( 20),     
   @cPalletLOC    NVARCHAR( 10),     
   @cMBOLKey      NVARCHAR( 10),     
   @cTrackNo      NVARCHAR( 20),     
   @cOrderKey     NVARCHAR( 10),     
   @cShipperKey   NVARCHAR( 15),      
   @cCartonType   NVARCHAR( 10),      
   @cWeight       NVARCHAR( 10),     
   @cOption       NVARCHAR( 1),      
   @nErrNo        INT            OUTPUT,    
   @cErrMsg       NVARCHAR( 20)  OUTPUT    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @bSuccess INT    
    
   IF @nFunc = 1663 -- TrackNoToPallet    
   BEGIN    
      IF @nStep = 3 OR -- Track no    
         @nStep = 4 OR -- Weight    
         @nStep = 5    -- Carton type    
      BEGIN    
         IF @nInputKey = 1 -- ENTER    
         BEGIN    
            -- MBOLDetail created    
            IF EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)    
            BEGIN    
               DECLARE @nOrderTrackNo  INT    
               DECLARE @nPalletTrackNo INT    
               DECLARE @cOtherTrackNo  NVARCHAR( 20)    
               DECLARE @nRowCount INT    
                      
               -- Get other carton in order    
               SELECT @cOtherTrackNo = TrackingNo    
               FROM CartonTrack WITH (NOLOCK, INDEX = idx_cartontrack_LabelNo)   -- (james01)     
               WHERE LabelNo = @cOrderKey    
                  AND CarrierName = @cShipperKey    
                  AND TrackingNo <> @cTrackNo    
               SET @nRowCount = @@ROWCOUNT    
                   
               -- Order only 1 carton    
               IF @nRowCount = 0    
               BEGIN    
                  SET @nOrderTrackNo = 1    
                  SET @nPalletTrackNo = 1    
               END    
                   
               -- Order has 2 cartons    
               ELSE IF @nRowCount = 1    
               BEGIN    
                  SET @nOrderTrackNo = 2    
                  SET @nPalletTrackNo = 1    
                      
                  -- Check other carton in had scanned to pallet    
                  IF EXISTS( SELECT 1    
                     FROM PalletDetail WITH (NOLOCK)    
                     WHERE StorerKey = @cStorerKey    
                        AND CaseID = @cOtherTrackNo)    
                  BEGIN    
                     SET @nPalletTrackNo = 2    
                  END    
               END    
                   
               -- Order more then 2 cartons    
               ELSE     
               BEGIN    
                  SET @nOrderTrackNo = @nRowCount + 1    
                      
                  SELECT @nPalletTrackNo = COUNT(1)    
                  FROM PalletDetail WITH (NOLOCK)    
                  WHERE StorerKey = @cStorerKey    
                     AND CaseID IN (    
                        SELECT TrackingNo    
                        FROM CartonTrack WITH (NOLOCK)     
                        WHERE LabelNo = @cOrderKey    
                           AND CarrierName = @cShipperKey)    
               END                   
                   
               -- All track no of the order scanned    
               IF @nPalletTrackNo > 0 AND     
                  @nOrderTrackNo > 0 AND     
                  @nPalletTrackNo = @nOrderTrackNo     
               BEGIN
                  DECLARE @cCode       NVARCHAR(30)
                  DECLARE @cShort      NVARCHAR(10)
                  DECLARE @cTableName  NVARCHAR(30)
                  DECLARE @cNotes2     NVARCHAR(MAX)
                  DECLARE @cSendITF    NVARCHAR(1)

                  -- Get order confirm interface info
                  SELECT TOP 1
                     @cCode = Code, 
                     @cShort = ISNULL( Short, ''),
                     @cTableName = LEFT( ISNULL( Long, ''), 30),
                     @cNotes2 = ISNULL( Notes2, '')
                  FROM CodeLKUP WITH (NOLOCK)
                  WHERE ListName = 'SOCFMITF'
                     AND StorerKey = @cStorerKey
                     AND Code2 = @nFunc
                  ORDER BY Code
                  SET @nRowCount = @@ROWCOUNT

                  -- Send order confirm (could be multiple records, each different criteria). Avoid cursor for performance
                  WHILE @nRowCount > 0
                  BEGIN                     
                     -- Check order criteria
                     IF @cNotes2 = ''
                        SET @cSendITF = 'Y'
                     ELSE
                     BEGIN
                        DECLARE @cSQL NVARCHAR( MAX)
                        DECLARE @cSQLParam NVARCHAR( MAX)

                        SET @cSendITF = 'N'
                        SET @cSQL = 'SELECT @cSendITF = ''Y'' FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey ' + @cNotes2
                        SET @cSQLParam =
                           ' @cOrderKey NVARCHAR( 10), ' +
                           ' @cSendITF  NVARCHAR( 1) OUTPUT '
                        EXEC sp_executeSQL @cSQL, @cSQLParam,
                           @cOrderKey = @cOrderKey,
                           @cSendITF = @cSendITF OUTPUT
                     END

                     IF @cSendITF = 'Y'
                     BEGIN
                        IF @cShort = '2'
                           EXEC dbo.ispGenTransmitLog2
                                @cTableName  -- TableName
                              , @cOrderKey   -- Key1
                              , 'RDT_9'      -- Key2
                              , @cStorerKey  -- Key3
                              , ''           -- Batch
                              , @bSuccess  OUTPUT
                              , @nErrNo    OUTPUT
                              , @cErrMsg   OUTPUT
                        ELSE
                           EXEC dbo.ispGenTransmitLog3
                                @cTableName  -- TableName
                              , @cOrderKey   -- Key1
                              , 'RDT_9'      -- Key2
                              , @cStorerKey  -- Key3
                              , ''           -- Batch
                              , @bSuccess  OUTPUT
                              , @nErrNo    OUTPUT
                              , @cErrMsg   OUTPUT
                        IF @bSuccess <> 1
                        BEGIN
                           SET @nErrNo = 111451    
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG Fail  
                           GOTO Quit
                        END
                     END
                  
                     -- Get next record
                     SELECT TOP 1
                        @cCode = Code, 
                        @cShort = ISNULL( Short, ''),
                        @cTableName = LEFT( ISNULL( Long, ''), 30),
                        @cNotes2 = ISNULL( Notes2, '')
                     FROM CodeLKUP WITH (NOLOCK)
                     WHERE ListName = 'SOCFMITF'
                        AND StorerKey = @cStorerKey
                        AND Code2 = @nFunc
                        AND Code > @cCode
                     ORDER BY Code
                     SET @nRowCount = @@ROWCOUNT
                  END
                  
                  -- Get carrier interface info
                  SELECT     
                     @cShort = ISNULL( Short, ''),     
                     @cTableName = LEFT( ISNULL( Long, ''), 30)    
                  FROM CodeLKUP WITH (NOLOCK)    
                  WHERE ListName = 'CARRIERITF'    
                     AND Code = @cShipperKey    
                     AND StorerKey = @cStorerKey    
                     AND Code2 = @nFunc    
                      
                  -- Send carrier interface
                  IF @@ROWCOUNT > 0    
                  BEGIN    
                     IF @cShort = '2'    
                        EXEC dbo.ispGenTransmitLog2    
                             @cTableName  -- TableName    
                           , @cOrderKey   -- Key1    
                           , '9'           -- Key2    --(yeekung01)
                           , @cStorerKey  -- Key3    
                           , ''           -- Batch    
                           , @bSuccess  OUTPUT    
                           , @nErrNo    OUTPUT    
                           , @cErrMsg   OUTPUT    
                     ELSE    
                        EXEC dbo.ispGenTransmitLog3     
                             @cTableName  -- TableName    
                           , @cOrderKey   -- Key1    
                           , '9'           -- Key2   --(yeekung01) 
                           , @cStorerKey  -- Key3    
                           , ''           -- Batch    
                           , @bSuccess  OUTPUT    
                           , @nErrNo    OUTPUT    
                           , @cErrMsg   OUTPUT    
                     IF @bSuccess <> 1    
                     BEGIN    
                        SET @nErrNo = 111452    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG Fail    
                        GOTO Quit    
                     END    
                  END    
               END    
            END    
         END    
      END    
   END    
    
Quit:    
    
END 

GO