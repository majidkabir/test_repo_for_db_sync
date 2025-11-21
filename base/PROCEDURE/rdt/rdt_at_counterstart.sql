SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
                          
/***************************************************************************/              
/* Store procedure: rdt_AT_CounterStart                                    */              
/*                                                                         */              
/* Modifications log:                                                      */              
/*                                                                         */              
/* Date       Rev  Author   Purposes                                       */              
/* 2022-03-25 1.0  yeekung    WMS-18920 Created                            */   
/* 2023-04-25 1.1  yeekung   WMS-22395 Add storerconfig altref (yeekung01) */
/***************************************************************************/              
              
CREATE    PROC [RDT].[rdt_AT_CounterStart] (              
   @nMobile       INT,                  
   @nFunc         INT,                  
   @cLangCode     NVARCHAR( 3),                       
   @nInputKey     INT,                  
   @cFacility     NVARCHAR( 5),         
   @cStorerKey    NVARCHAR( 15),        
   @cOption       NVARCHAR( 1),
   @cRefNo1       NVARCHAR( 20),
   @cInput01      NVARCHAR( 20),
   @cInput02      NVARCHAR( 20),
   @cInput03      NVARCHAR( 20),
   @cInput04      NVARCHAR( 20),
   @cActivityStatus NVARCHAR(20),
   @nStep         INT          OUTPUT,  
   @nScn          INT          OUTPUT,         
   @cOutField01  NVARCHAR( 20) OUTPUT,           
   @cOutField02  NVARCHAR( 20) OUTPUT,              
   @cOutField03  NVARCHAR( 20) OUTPUT,            
   @cOutField04  NVARCHAR( 20) OUTPUT,            
   @cOutField05  NVARCHAR( 20) OUTPUT,            
   @cOutField06  NVARCHAR( 20) OUTPUT,            
   @cOutField07  NVARCHAR( 20) OUTPUT,            
   @cOutField08  NVARCHAR( 20) OUTPUT,            
   @cOutField09  NVARCHAR( 20) OUTPUT,            
   @cOutField10  NVARCHAR( 20) OUTPUT,           
   @cOutField11  NVARCHAR( 20) OUTPUT,  
   @cExtendedinfo NVARCHAR(20)  OUTPUT,           
   @nErrNo        INT           OUTPUT,           
   @cErrMsg       NVARCHAR( 20) OUTPUT                  
)              
AS              
   SET NOCOUNT ON              
   SET QUOTED_IDENTIFIER OFF              
   SET ANSI_NULLS OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cDoorBooking NVARCHAR(20),
           @cUserName    NVARCHAR(20),
           @cBookStatus  NVARCHAR(20),
           @cNewStatus   NVARCHAR(20),
           @cLong        NVARCHAR(20),
           @cEventCode   NVARCHAR(20),
           @cMenuOption  NVARCHAR(1),
           @cDriverName  NVARCHAR(30),
           @cLicenseNo   NVARCHAR(30)
   DECLARE @cGroup       NVARCHAR(20)

   DECLARE @cScnAltRef NVARCHAR(20)
   
   SET @cDoorBooking= rdt.RDTGetConfig( @nFunc, 'DoorBooking', @cStorerKey)
   
   SET @cScnAltRef = rdt.RDTGetConfig( @nFunc, 'BOScnALTRef', @cStorerKey)
   IF ISNULL(@cScnAltRef,'') in (0,'')
      SET @cScnAltRef =''


   SELECT @cUserName=username,
          @cMenuOption=V_string5
   FROM rdt.rdtmobrec (NOLOCK) 
   where mobile=@nMobile

   IF  @nStep =1    --(yeekung04)
   BEGIN            
      -- Get even to capture           
      SELECT                   
         @cOutField01    = udf01,
         @cOutField04   = udf02,
         @cOutField05    = udf03
      FROM dbo.CodeLkup WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
         AND ListName = 'RDTAcTrack'    
         AND code=@cOption   

      GOTO QUIT
   END    

   IF  @nStep = 2    
   BEGIN   
      IF @cDoorBooking='1'
      BEGIN
         IF NOT EXISTS(SELECT 1
                        FROM BOOKING_OUT (NOLOCK)
                        WHERE BookingNo=CASE WHEN ISNULL(@cScnAltRef,'')='' THEN @cRefNo1 ELSE bookingno END
                           AND AltReference =CASE WHEN ISNULL(@cScnAltRef,'')='' THEN AltReference ELSE @cRefNo1 END --yeekung01
                           AND facility=@cFacility)
         BEGIN
            SET @nErrNo = 185101 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvApptNo
            GOTO QUIT
         END

         SELECT @cBookStatus=status
         FROM BOOKING_OUT (NOLOCK)
         WHERE bookingno=@cRefNo1

         IF NOT EXISTS (SELECT 1
                        FROM CODELKUP (NOLOCK)
                        WHERE Listname = 'BkStatusO'
                        AND storerkey=@cStorerKey
                        AND Notes2=@nFunc
                        AND code in('5','6')
                        AND @cBookStatus IN(udf01,udf02)
                        AND notes=@cActivityStatus--'1'
                        )
         BEGIN
            SET @nErrNo = 185102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvStatus
            GOTO QUIT
         END


         SELECT @cOutField10=description
         FROM CODELKUP (NOLOCK)
         WHERE Listname = 'BkStatusO'
            AND storerkey=@cStorerKey
            AND Notes2=@nFunc
            AND code = @cBookStatus

         SELECT  
            @cDriverName =  DriverName,
            @cLicenseNo = licenseno
         FROM BOOKING_OUT (NOLOCK)
         WHERE BookingNo = CASE WHEN ISNULL(@cScnAltRef,'')='' THEN @cRefNo1 ELSE bookingno END
            AND AltReference =CASE WHEN ISNULL(@cScnAltRef,'')='' THEN AltReference ELSE @cRefNo1 END --yeekung01

         IF @cOption='9'
         BEGIN
            IF NOT EXISTS (SELECT 1 
                           FROM Booking_Event
                           WHERE bookingno=@cRefNo1
                           AND eventcode='05') AND
               NOT EXISTS (SELECT 1 
                           FROM Booking_Event
                           WHERE bookingno=@cRefNo1
                           AND eventcode='09')
            BEGIN
               SET @nErrNo = 185105
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvApptNo
               GOTO QUIT
            END
         END

         SELECT   @cOutField01 = 'Appt No:',
                  @cOutField02 = bookingno,
                  @cOutField03 = 'Hauler:',
                  @cOutField04 =  carrierkey,
                  @cOutField05 = 'Booking Date:',
                  @cOutField06 = BookingDate,
                  @cOutField07 = 'LoadingBay:',
                  @cOutField08 = Loc,
                  @cOutField09 = 'Status'
         FROM BOOKING_OUT (NOLOCK)
         WHERE bookingno=@cRefNo1

         SET  @cOutField11= CASE WHEN @cActivityStatus = '1' THEN 'Counter Start' 
                              WHEN @cActivityStatus = '9' THEN 'Counter End' END

         SET @nStep= @nStep+1
         SET @nScn= @nScn+1
      END
      ELSE
      BEGIN
         IF @cOption='1'
         BEGIN
            EXEC RDT.rdt_STD_EventLog
           @cActionType   = '3', -- insert Function
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerKey,
           @cRefNo1       = 'Counter',
           @nStep         = @nStep,
           @cRefNo2       = @cRefNo1,
           @cRefNo3       = 'Start'
         END
         IF @cOption='9'
         BEGIN
            EXEC RDT.rdt_STD_EventLog
           @cActionType   = '3', -- insert Function
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerKey,
           @cRefNo1       = 'Counter',
           @nStep         = @nStep,
           @cRefNo2       = @cRefNo1,
           @cRefNo3       = 'End'
         END


         SELECT @cGroup=OpsPosition
         FROM rdt.rdtuser (NOLOCK)
         WHERE USERNAME=@cusername
   
         -- Prepare next screen var        
         SELECT @cOutField01='1-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='1'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField02='2-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='2'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField03='3-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='3'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField04='4-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='4'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField05='5-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='5'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField06='6-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='6'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField07='7-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='7'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField08='8-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='8'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField09='9-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='9'  AND CHARINDEX(@cGroup,short)<>'0'      
            
         SET @nStep= @nStep-1
         SET @nScn= @nScn-1
      END
      
      GOTO QUIT
   END  

   IF  @nStep = 3   
   BEGIN 
      IF @nInputKey='1'
      BEGIN
         SET  @cOutField01    = ''
         SET  @cOutField02    = ''
         SET  @cOutField03    = ''
         SET  @cOutField04    = ''
         SET  @cOutField05    = ''
         SET  @cOutField06    = ''
         SET  @cOutField07    = ''
         SET  @cOutField08    = ''
         SET  @cOutField09    = ''
         SET  @cOutField10    = ''

         SELECT   @cOutField01 = 'Appt No:',
                  @cOutField02 = bookingno
         FROM BOOKING_OUT (NOLOCK)
         WHERE BookingNo = CASE WHEN ISNULL(@cScnAltRef,'')='' THEN @cRefNo1 ELSE bookingno END
            AND AltReference =CASE WHEN ISNULL(@cScnAltRef,'')='' THEN AltReference ELSE @cRefNo1 END --yeekung01

         SELECT   @cOutField03 = 'Driver Name:',
                  @cOutField04 =  DriverName,
                  @cOutField05 = 'License No:',
                  @cOutField06 = licenseno
         FROM BookingVehicle (NOLOCK)
         WHERE bookingno=@cRefNo1

         SET  @cOutField11= CASE WHEN @cActivityStatus = '1' THEN 'Counter Start' 
                                 WHEN @cActivityStatus = '9' THEN 'Counter End' END

         SET @nStep= @nStep+1
         SET @nScn= @nScn+1
      END
      ELSE
      BEGIN
         
        SET  @cOutField01    = ''
        SET  @cOutField02    = ''
        SET  @cOutField03    = ''
        SET  @cOutField04    = ''
        SET  @cOutField05    = ''
        SET  @cOutField06    = ''
        SET  @cOutField07    = ''
        SET  @cOutField08    = ''
        SET  @cOutField09    = ''
        SET  @cOutField10    = ''
        SET  @cOutField11    = ''

         -- Get even to capture           
         SELECT                   
            @cOutField01    = udf01,
            @cOutField04    = udf02,
            @cOutField05    = udf03
         FROM dbo.CodeLkup WITH (NOLOCK)         
         WHERE StorerKey = @cStorerKey        
            AND ListName = 'RDTAcTrack'    
            AND code=@cMenuOption   
      END
      GOTO QUIT
   END 

   IF  @nStep = 4  
   BEGIN 
      IF @nInputKey='1'
      BEGIN
         IF @cOption='1'
         BEGIN
            SELECT @cBookStatus=status
            FROM BOOKING_OUT (NOLOCK)
            WHERE BookingNo = CASE WHEN ISNULL(@cScnAltRef,'')='' THEN @cRefNo1 ELSE bookingno END
               AND AltReference =CASE WHEN ISNULL(@cScnAltRef,'')='' THEN AltReference ELSE @cRefNo1 END --yeekung01

            SELECT @cNewStatus=code ,@cLong=long
            FROM CODELKUP (NOLOCK)
            WHERE Listname = 'BkStatusO'
               AND storerkey=@cStorerKey
               AND Notes2=@nFunc
               AND @cBookStatus IN (udf01,udf02)
               AND code in('5','6')
               AND notes=@cActivityStatus--'1'

            SELECT @cEventCode=code 
            FROM CODELKUP (NOLOCK)
            WHERE Listname = 'EVENTCODE'
            AND storerkey=@cStorerKey
            AND long=@cActivityStatus
            AND udf01 = @cNewStatus

            UPDATE BOOKING_OUT
            SET drivername=@cInput01,
                  licenseno=@cInput02,
                  status = @cNewStatus
            WHERE BookingNo = CASE WHEN ISNULL(@cScnAltRef,'')='' THEN @cRefNo1 ELSE bookingno END
               AND AltReference =CASE WHEN ISNULL(@cScnAltRef,'')='' THEN AltReference ELSE @cRefNo1 END

            IF @@ERROR<>0
            BEGIN
               SET @nErrNo = 185103
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdBOFail
               GOTO QUIT
            END

            INSERT INTO Booking_Event(bookingno,bookingtype,AddDate,EventDate,EditDate,UserDefine01,userdefine02,userdefine03,EventCode,ItrStatus)
            Values(@cRefNo1,'O',GETDATE(),GETDATE(),GETDATE(),@cLong,@cInput01,@cInput02,@cEventCode,@cActivityStatus)

            IF @@ERROR<>0
            BEGIN
               SET @nErrNo = 185104
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsBEFail
               GOTO QUIT
            END

           IF NOT EXISTS ( SELECT 1 FROM BookingVehicle (nolock)
                            WHERE bookingno=@cRefNo1)
            BEGIN
               INSERT INTO BookingVehicle(bookingno,bookingtype,AddDate,AddWho,DriverName,LicenseNo)
               Values(@cRefNo1,'O',GETDATE(),@cUserName,@cInput01,@cInput02)

               IF @@ERROR<>0
               BEGIN
                  SET @nErrNo = 185054
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsBEFail
                  GOTO QUIT
               END
            END
            ELSE
            BEGIN
               UPDATE BookingVehicle WITH (ROWLOCK)
               SET DriverName=@cInput01,
                  LicenseNo=@cInput02,
                  bookingtype='O'
               WHERE bookingno=@cRefNo1

               IF @@ERROR<>0
               BEGIN
                  SET @nErrNo = 185054
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsBEFail
                  GOTO QUIT
               END
            END
         END

         SET  @cOutField01    = ''
         SET  @cOutField02    = ''
         SET  @cOutField03    = ''
         SET  @cOutField04    = ''
         SET  @cOutField05    = ''
         SET  @cOutField06    = ''
         SET  @cOutField07    = ''
         SET  @cOutField08    = ''
         SET  @cOutField09    = ''
         SET  @cOutField10    = ''
         SET  @cOutField11    = ''


         SELECT @cGroup=OpsPosition
         FROM rdt.rdtuser (NOLOCK)
         WHERE USERNAME=@cusername
   
         -- Prepare next screen var        
         SELECT @cOutField01='1-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='1'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField02='2-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='2'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField03='3-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='3'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField04='4-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='4'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField05='5-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='5'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField06='6-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='6'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField07='7-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='7'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField08='8-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='8'  AND CHARINDEX(@cGroup,short)<>'0'     
         SELECT @cOutField09='9-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='9'  AND CHARINDEX(@cGroup,short)<>'0'      
           
          -- Screen mapping
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3  
      END
      ELSE
      BEGIN

         SELECT @cOutField10=description
         FROM CODELKUP (NOLOCK)
         WHERE Listname = 'BkStatusO'
            AND storerkey=@cStorerKey
            AND Notes2=@nFunc
            AND code = @cBookStatus

         SELECT   @cOutField01 = 'Appt No:',
                  @cOutField02 = bookingno,
                  @cOutField03 = 'Hauler:',
                  @cOutField04 =  carrierkey,
                  @cOutField05 = 'Booking Date:',
                  @cOutField06 = BookingDate,
                  @cOutField07 = 'LoadingBay:',
                  @cOutField08 = Loc,
                  @cOutField09 = 'Status'
         FROM BOOKING_OUT (NOLOCK)
         WHERE BookingNo = CASE WHEN ISNULL(@cScnAltRef,'')='' THEN @cRefNo1 ELSE bookingno END
            AND AltReference =CASE WHEN ISNULL(@cScnAltRef,'')='' THEN AltReference ELSE @cRefNo1 END --yeekung01

         SET  @cOutField11= CASE WHEN @cActivityStatus = '1' THEN 'Counter Start' 
                              WHEN @cActivityStatus = '9' THEN 'Counter End' END
      END

      GOTO QUIT
   END 
              
Quit:       

GO